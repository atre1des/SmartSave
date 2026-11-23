import 'package:flutter/foundation.dart';

import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../shared/widgets.dart';
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

  /// Whether the AI service is available (backend reachable)
  /// This checks actual backend connectivity.
  Future<bool> get isAvailable async => await _provider.checkBackendHealth();

  /// Gets the current model being used
  String get currentModel => _provider.currentModel;

  /// Builds the system prompt based on mode and user's financial context.
  ///
  /// [financialContext] must already be built by the caller via
  /// [_buildFinancialContext] so the context is fetched exactly once per
  /// request.
  String _buildSystemPrompt(String financialContext) {
    final basePrompt = '''You are SmartSave Assistant, an AI financial assistant for a personal finance app in Kazakhstan (KZT currency).

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
      final budgetLines = budgets.entries.map((e) {
        final spent = spending[e.key] ?? 0;
        final remaining = e.value - spent;
        return '${e.key}: budget ${formatTenge(e.value)}, spent ${formatTenge(spent)}, ${remaining >= 0 ? 'remaining ${formatTenge(remaining)}' : 'over by ${formatTenge(-remaining)}'}';
      }).join('; ');
      contextParts.add('Budgets: $budgetLines');
    }

    final goals = await repository.goals();
    if (goals.isNotEmpty) {
      final now = DateTime.now();
      final goalLines = goals.map((g) {
        final months = ((g.deadline.year - now.year) * 12 + g.deadline.month - now.month).clamp(1, 120);
        final monthly = monthlyGoalContribution(
          targetTenge: g.target,
          savedTenge: g.saved,
          monthsRemaining: months,
        );
        return '${g.name}: target ${formatTenge(g.target)}, saved ${formatTenge(g.saved)} (${g.progressPercent}%), deadline ${g.deadline.month}/${g.deadline.year}, suggested ${formatTenge(monthly)}/month';
      }).join('; ');
      contextParts.add('Goals: $goalLines');
    } else {
      contextParts.add('No savings goals set.');
    }

    final deposits = await repository.deposits();
    if (deposits.isNotEmpty) {
      final topDeposits = deposits.take(3).map((d) => '${d.bank} ${d.product}: ${(d.effectiveRateBps / 100).toStringAsFixed(2)}% ГЭСВ, ${d.termMonths}mo, top-up: ${d.topUp ? "yes" : "no"}, withdrawal: ${d.withdrawal ? "yes" : "no"}').join('; ');
      contextParts.add('Sample deposit products: $topDeposits');
    }

    final theses = await repository.investmentTheses();
    if (theses.isNotEmpty) {
      final thesisLines = theses.take(3).map((t) => '${t.securityName} (${t.ticker}): ${t.rationale.isEmpty ? "no rationale" : t.rationale}').join('; ');
      contextParts.add('Investment theses: $thesisLines');
    }

    final holdings = await repository.portfolioHoldings();
    if (holdings.isNotEmpty) {
      final holdingLines = holdings.map((h) => '${h.securityName} (${h.ticker}): ${formatTenge(h.marketValueKzt)}, FX sens: ${h.fxSensitivityPctPerPct ?? "N/A"}, Oil sens: ${h.oilSensitivityPctPerPct ?? "N/A"}, Rate sens: ${h.rateSensitivityPctPerPoint ?? "N/A"}').join('; ');
      contextParts.add('Portfolio holdings: $holdingLines');
    } else {
      contextParts.add('No portfolio holdings recorded.');
    }

    return contextParts.join('\n');
  }

  /// Sends a message and gets a full response (non-streaming)
  Future<String> sendMessage(String prompt) async {
    final context = await _buildFinancialContext();
    final systemPrompt = _buildSystemPrompt(context);

    final messages = [
      AIMessage.system('$systemPrompt\n\nUser financial context:\n$context'),
      AIMessage.user(prompt),
    ];

    final result = await _provider.sendMessage(messages: messages);

    if (result.success && result.content != null) {
      return result.content!;
    } else {
      // Fallback to local rule-based response if API fails
      return _getLocalFallback(prompt, result.error);
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
  Stream<AIStreamChunk> sendMessageStream(String prompt) async* {
    final context = await _buildFinancialContext();
    final systemPrompt = _buildSystemPrompt(context);

    final messages = [
      AIMessage.system('$systemPrompt\n\nUser financial context:\n$context'),
      AIMessage.user(prompt),
    ];
    debugPrint('[AIAssistantService] Built messages: ${messages.length} messages');

    final isBackendHealthy = await _provider.checkBackendHealth();
    debugPrint('[AIAssistantService] Backend health check: $isBackendHealthy');

    if (!isBackendHealthy) {
      final fallback = _getLocalFallback(prompt, 'Backend not reachable');
      yield AIStreamChunk(content: fallback, isDone: true);
      return;
    }

    try {
      await for (final chunk in _provider.sendMessageStream(messages: messages)) {
        if (chunk.isDone) {
          if (chunk.error != null) {
            yield chunk;
          } else {
            debugPrint('[AIAssistantService] Stream completed successfully');
            yield chunk;
          }
          return;
        }
        yield chunk;
      }

      debugPrint('[AIAssistantService] Provider stream ended without terminal chunk');
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: 'The AI service ended the response unexpectedly. Please try again.',
      );
    } catch (e) {
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: 'Stream failed: ${e.toString()}',
      );
    }
  }

  String _getLocalFallback(String prompt, String? error) {
    final query = prompt.trim().toLowerCase();

    if (query.isEmpty) {
      return 'Ask me about your saved spending, budgets, goals, or investment thesis workflow.';
    }

    if (error != null) {
      return 'I\'m currently unable to connect to the AI service ($error). '
          'Here\'s what I can tell you from your local data: '
          '${_getLocalRuleResponse(query)}';
    }

    return _getLocalRuleResponse(query);
  }

  String _getLocalRuleResponse(String query) {
    if (query.contains('budget') || query.contains('spend')) {
      return 'I\'m currently in offline mode. Use the spending and budget screens to see your category breakdowns. The AI assistant needs the backend to provide detailed analysis.';
    }

    if (query.contains('goal') || query.contains('save for') || query.contains('savings')) {
      return 'I\'m in offline mode. Check the Goals tab for your saved goals and monthly contribution estimates.';
    }

    if (query.contains('investment') || query.contains('thesis') || query.contains('stock') || query.contains('share')) {
      return 'I\'m in offline mode. Open Invest → Investment Intelligence to manage your investment theses and portfolio assumptions.';
    }

    if (query.contains('liquid')) {
      return 'Liquidity analysis compares hypothetical orders with historical volume you enter. It\'s a scenario tool, not real order-book data. Open Invest → Investment Intelligence → Liquidity tab.';
    }

    if (query.contains('tenge') || query.contains('oil') || query.contains('interest rate') || query.contains('scenario') || query.contains('ripple')) {
      return 'Economic Ripple simulates portfolio impact from macro shocks using your entered sensitivities. Open Invest → Investment Intelligence → Economic Ripple tab.';
    }

    if (query.contains('balance') || query.contains('account')) {
      return 'Your local demo balance and spending are shown on the Home screen. The AI needs the backend running for detailed analysis.';
    }

    return 'I\'m running in offline mode (${_provider.isConfigured ? "backend issue" : "no OPENROUTER_API_KEY configured"}). Start the backend (npm start in backend/) to enable AI responses. I can help with spending, budgets, goals, and investment research using your saved SmartSave data.';
  }

  void dispose() {
    _provider.dispose();
  }
}
