import 'package:flutter/foundation.dart';

import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../shared/widgets.dart';
import '../../l10n/app_locale.dart';
import 'models.dart';
import 'openrouter_provider.dart';

/// AI-powered financial assistant service that proxies through the backend to OpenRouter
class SmartSaveAIAssistantService {
  SmartSaveAIAssistantService(this.repository, {OpenRouterProvider? provider})
    : _provider = provider ?? OpenRouterProvider();

  final FinanceRepository repository;
  final OpenRouterProvider _provider;

  /// Current conversation mode
  AssistantMode _mode = AssistantMode.beginner;

  /// Gets the current conversation mode
  AssistantMode get mode => _mode;

  /// Sets the conversation mode
  void setMode(AssistantMode mode) => _mode = mode;

  Future<bool> get isProxyReachable => _provider.checkBackendHealth();

  /// Builds the system prompt based on mode and user's financial context.
  ///
  /// [financialContext] must already be built by the caller via
  /// [_buildFinancialContext] so the context is fetched exactly once per
  /// request.
  String _buildSystemPrompt(String financialContext, String languageCode) {
    final basePrompt =
        '''You are SmartSave Assistant, an AI financial assistant for a personal finance app in Kazakhstan (KZT currency).

Reply in the language of the latest user message (English, Kazakh, or Russian) unless the user explicitly requests a different language. For mixed messages, use the dominant language or the requested language. If unclear, use this app language code: $languageCode. Preserve user-entered record text, names and ticker symbols. Preserve Markdown and KZT amounts.

Your role:
- Help users understand their financial situation using their actual saved data
- Explain financial concepts in plain language (Kazakhstan context)
- Compare options (deposits, investments, savings strategies) with realistic scenarios
- Ask clarifying questions when information is missing
- Never promise guaranteed returns or give personalized financial advice
- Always distinguish between: verified facts, user-provided info, assumptions, and AI analysis
- Use the financial context provided to give relevant, grounded responses
- Mention that investments can lose value and past performance ≠ future results

Data context (Kazakhstan):
- Currency: Tenge (KZT)
- Major banks: Kaspi.kz, Halyk Bank, Freedom Bank, Bereke Bank, Eurasian Bank, Bank CenterCredit, Bank RBK
- Exchanges: KASE (Kazakhstan Stock Exchange), AIX (Astana International Exchange)
- Deposit insurance: KDIF (limits apply)
- Typical deposit rates: 15-20% ГЭСВ (effective annual rate)
- Key economic factors: tenge exchange rate, oil prices, interest rates

Financial calculations:
- Use simple interest for deposits: principal × nominal_rate_bps × months / 120000
- Monthly goal contribution: ceil((target - saved) / months_remaining)
- All amounts in integer tenge (₸)

CRITICAL — current market data:
- You do NOT have live access to stock prices, exchange rates, dividend announcements, company results, or market news.
- NEVER invent or guess current prices, exchange rates, dividends, financial results, or announcements.
- If the user asks for data you do not have, say plainly that you do not have current data and explain how they can verify it (KASE site, AIX site, National Bank of Kazakhstan).

Response style:
- Use Markdown formatting for clear, readable responses
- Use headings (##, ###) to organize responses into logical sections when the answer is long
- Use bold for important amounts, key terms, and conclusions
- Use bullet points for lists of options, tips, or factors
- Use numbered lists for step-by-step procedures
- Use blockquotes for important notes or warnings
- Keep paragraphs short (2-4 sentences max)
- Separate sections with blank lines
- Beginner-friendly explanations unless user indicates experience
- Include relevant disclaimers naturally (not overwhelming)
- Ask follow-up questions to clarify user intent
- Suggest concrete next steps in the app
- Prefer short, actionable responses over long reports
- Do not use headings for very short/simple responses
- Do not over-format simple conversational answers''';

    if (_mode == AssistantMode.beginner) {
      return '$basePrompt\n\nThe user is NEW TO INVESTING. Explain all terms (deposits, shares, IPOs, bonds, diversification, liquidity, risk). Ask one or two questions at a time. Use analogies. Never assume knowledge. Use simple language with clear structure.';
    } else {
      return '$basePrompt\n\nThe user UNDERSTANDS INVESTING. Be concise and analytical. Focus on comparisons, scenarios, risk analysis, and thesis monitoring. Skip basic definitions unless asked. Use structured Markdown for clarity.';
    }
  }

  /// Builds financial context from user's saved data
  Future<String> _buildFinancialContext() async {
    final contextParts = <String>[];

    final balance = await repository.totalBalance();
    final monthlySpend = await repository.spentThisMonth();
    contextParts.add('Current balance: ${formatTenge(balance)}');
    contextParts.add('Monthly spending: ${formatTenge(monthlySpend)}');

    final budgets = await repository.budgets();
    final spending = await repository.spendingByCategory();
    if (budgets.isNotEmpty) {
      final budgetLines = budgets.entries
          .map((e) {
            final spent = spending[e.key] ?? 0;
            final remaining = e.value - spent;
            return '${e.key}: budget ${formatTenge(e.value)}, spent ${formatTenge(spent)}, ${remaining >= 0 ? 'remaining ${formatTenge(remaining)}' : 'over by ${formatTenge(-remaining)}'}';
          })
          .join('; ');
      contextParts.add('Budgets: $budgetLines');
    }

    final goals = await repository.goals();
    if (goals.isNotEmpty) {
      final now = DateTime.now();
      final goalLines = goals
          .map((g) {
            final months =
                ((g.deadline.year - now.year) * 12 +
                        g.deadline.month -
                        now.month)
                    .clamp(1, 120);
            final monthly = monthlyGoalContribution(
              targetTenge: g.target,
              savedTenge: g.saved,
              monthsRemaining: months,
            );
            return '${g.name}: target ${formatTenge(g.target)}, saved ${formatTenge(g.saved)} (${g.progressPercent}%), deadline ${g.deadline.month}/${g.deadline.year}, suggested ${formatTenge(monthly)}/month';
          })
          .join('; ');
      contextParts.add('Goals: $goalLines');
    } else {
      contextParts.add('No savings goals set.');
    }

    final deposits = await repository.deposits();
    if (deposits.isNotEmpty) {
      final topDeposits = deposits
          .take(3)
          .map(
            (d) =>
                '${d.bank} ${d.product}: ${(d.effectiveRateBps / 100).toStringAsFixed(2)}% ГЭСВ, ${d.termMonths}mo, top-up: ${d.topUp ? "yes" : "no"}, withdrawal: ${d.withdrawal ? "yes" : "no"}',
          )
          .join('; ');
      contextParts.add('Sample deposit products: $topDeposits');
    }

    final theses = await repository.investmentTheses();
    if (theses.isNotEmpty) {
      final thesisLines = theses
          .take(3)
          .map(
            (t) =>
                '${t.securityName} (${t.ticker}): ${t.rationale.isEmpty ? "no rationale" : t.rationale}',
          )
          .join('; ');
      contextParts.add('Investment theses: $thesisLines');
    }

    final holdings = await repository.portfolioHoldings();
    if (holdings.isNotEmpty) {
      final holdingLines = holdings
          .map(
            (h) =>
                '${h.securityName} (${h.ticker}): ${formatTenge(h.marketValueKzt)}, FX sens: ${h.fxSensitivityPctPerPct ?? "N/A"}, Oil sens: ${h.oilSensitivityPctPerPct ?? "N/A"}, Rate sens: ${h.rateSensitivityPctPerPoint ?? "N/A"}',
          )
          .join('; ');
      contextParts.add('Portfolio holdings: $holdingLines');
    } else {
      contextParts.add('No portfolio holdings recorded.');
    }

    return contextParts.join('\n');
  }

  /// Sends a message and gets a full response (non-streaming)
  Future<String> sendMessage(
    String prompt, {
    String languageCode = 'en',
  }) async {
    final context = await _buildFinancialContext();
    final systemPrompt = _buildSystemPrompt(context, languageCode);

    final messages = [
      AIMessage.system('$systemPrompt\n\nUser financial context:\n$context'),
      AIMessage.user(prompt),
    ];

    final result = await _provider.sendMessage(messages: messages);

    if (result.success && result.content != null) {
      return result.content!;
    } else {
      // Fallback to local rule-based response if API fails
      return _localFallback(prompt, languageCode, offline: false);
    }
  }

  /// Sends a message and streams the response.
  ///
  /// Contract:
  /// - On success, yields content chunks, then a final chunk with `isDone: true`
  ///   and `error: null`. The screen finalizes the assistant message.
  /// - On generation failure, yields a single chunk with `isDone: true` and a
  ///   non-null `error`. It does NOT yield an assistant-content chunk. The screen
  ///   removes the placeholder bubble and shows the error banner.
  /// - On backend being unreachable, yields a single local fallback chunk.
  Stream<AIStreamChunk> sendMessageStream(
    String prompt, {
    String languageCode = 'en',
    ValueChanged<bool?>? onProxyStatus,
  }) async* {
    final context = await _buildFinancialContext();
    final systemPrompt = _buildSystemPrompt(context, languageCode);

    final messages = [
      AIMessage.system('$systemPrompt\n\nUser financial context:\n$context'),
      AIMessage.user(prompt),
    ];
    debugPrint(
      '[AIAssistantService] Built messages: ${messages.length} messages',
    );

    onProxyStatus?.call(null);
    final isBackendHealthy = await _provider.checkBackendHealth();
    onProxyStatus?.call(isBackendHealthy);
    debugPrint('[AIAssistantService] Backend health check: $isBackendHealthy');

    if (!isBackendHealthy) {
      final fallback = _localFallback(prompt, languageCode, offline: true);
      yield AIStreamChunk(content: fallback, isDone: false);
      yield const AIStreamChunk(content: '', isDone: true);
      return;
    }

    try {
      var receivedTerminal = false;
      await for (final chunk in _provider.sendMessageStream(
        messages: messages,
      )) {
        receivedTerminal = chunk.isDone;
        yield chunk;
      }
      if (receivedTerminal) return;

      debugPrint(
        '[AIAssistantService] Provider stream ended without terminal chunk',
      );
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error:
            'The AI service ended the response unexpectedly. Please try again.',
      );
    } catch (e) {
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: 'Stream failed: ${e.toString()}',
      );
    }
  }

  String _localFallback(
    String prompt,
    String languageCode, {
    required bool offline,
  }) {
    final strings = assistantStrings(prompt, languageCode);
    final query = prompt.toLowerCase();
    final topic = switch (query) {
      _ when RegExp(r'budget|spend|шығын|бюджет|расход').hasMatch(query) =>
        strings.offlineSpending,
      _
          when RegExp(
            r'goal|save for|savings|жинақ|мақсат|накопл|цел[ьи]',
          ).hasMatch(query) =>
        strings.offlineGoals,
      _ when RegExp(r'liquid|өтімді|ликвид').hasMatch(query) =>
        strings.offlineLiquidity,
      _
          when RegExp(
            r'tenge|oil|interest rate|scenario|ripple|теңге|мұнай|сценар|нефт|ставк',
          ).hasMatch(query) =>
        strings.offlineScenario,
      _
          when RegExp(
            r'investment|thesis|stock|share|инвест|тезис|акци',
          ).hasMatch(query) =>
        strings.offlineInvestment,
      _ when RegExp(r'balance|account|қалдық|баланс|счёт').hasMatch(query) =>
        strings.offlineBalance,
      _ => '',
    };
    final intro = offline ? strings.aiOfflineReply : strings.aiRequestFailed;
    return topic.isEmpty ? intro : '$intro\n\n$topic';
  }

  void dispose() {
    _provider.dispose();
  }
}
