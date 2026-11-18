import 'dart:async';

import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../shared/widgets.dart';
import 'models.dart';
import 'openrouter_provider.dart';

/// AI-powered financial assistant service that connects to OpenRouter via backend proxy
class SmartSaveAssistantService {
  SmartSaveAssistantService(this.repository, {OpenRouterProvider? provider})
      : _provider = provider ?? OpenRouterProvider();

  final FinanceRepository repository;
  final OpenRouterProvider _provider;

  /// Current conversation mode
  AssistantMode _mode = AssistantMode.beginner;

  /// Gets the current conversation mode
  AssistantMode get mode => _mode;

  /// Sets the conversation mode
  void setMode(AssistantMode mode) => _mode = mode;

  /// Builds financial context from SmartSave data for the AI
  Future<String> _buildFinancialContext() async {
    final contextParts = <String>[];

    // Balance and spending
    final balance = await repository.totalBalance();
    final monthlySpend = await repository.spentThisMonth();
    contextParts.add('Current balance: ${formatTenge(balance)}');
    contextParts.add('Monthly spending: ${formatTenge(monthlySpend)}');

    // Budgets
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

    // Goals
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

    // Deposits
    final deposits = await repository.deposits();
    if (deposits.isNotEmpty) {
      final topDeposits = deposits.take(3).map((d) => '${d.bank} ${d.product}: ${(d.effectiveRateBps / 100).toStringAsFixed(2)}% ГЭСВ, ${d.termMonths}mo, top-up: ${d.topUp ? "yes" : "no"}, withdrawal: ${d.withdrawal ? "yes" : "no"}').join('; ');
      contextParts.add('Sample deposit products: $topDeposits');
    }

    // Investment theses
    final theses = await repository.investmentTheses();
    if (theses.isNotEmpty) {
      final thesisLines = theses.take(3).map((t) => '${t.securityName} (${t.ticker}): ${t.rationale.isEmpty ? "no rationale" : t.rationale}').join('; ');
      contextParts.add('Investment theses: $thesisLines');
    }

    // Portfolio holdings
    final holdings = await repository.portfolioHoldings();
    if (holdings.isNotEmpty) {
      final holdingLines = holdings.map((h) => '${h.securityName} (${h.ticker}): ${formatTenge(h.marketValueKzt)}, FX sens: ${h.fxSensitivityPctPerPct ?? "N/A"}, Oil sens: ${h.oilSensitivityPctPerPct ?? "N/A"}, Rate sens: ${h.rateSensitivityPctPerPoint ?? "N/A"}').join('; ');
      contextParts.add('Portfolio holdings: $holdingLines');
    } else {
      contextParts.add('No portfolio holdings recorded.');
    }

    return contextParts.join('\n');
  }

  /// Builds the system prompt based on mode
  String _buildSystemPrompt() {
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

Response style:
- Clear, structured answers with bullet points when helpful
- Beginner-friendly explanations unless user indicates experience
- Include relevant disclaimers naturally (not overwhelming)
- Ask follow-up questions to clarify user intent
- Suggest concrete next steps in the app''';

    if (_mode == AssistantMode.beginner) {
      return '$basePrompt\n\nThe user is NEW TO INVESTING. Explain all terms (deposits, shares, IPOs, bonds, diversification, liquidity, risk). Ask one or two questions at a time. Use analogies. Never assume knowledge.';
    } else {
      return '$basePrompt\n\nThe user UNDERSTANDS INVESTING. Be concise and analytical. Focus on comparisons, scenarios, risk analysis, and thesis monitoring. Skip basic definitions unless asked.';
    }
  }

  /// Sends a message and gets a full response (non-streaming)
  Future<String> sendMessage(String prompt) async {
    final context = await _buildFinancialContext();
    final systemPrompt = _buildSystemPrompt();

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

  /// Sends a message and streams the response
  Stream<AIStreamChunk> sendMessageStream(String prompt) async* {
    final context = await _buildFinancialContext();
    final systemPrompt = _buildSystemPrompt();

    final messages = [
      AIMessage.system('$systemPrompt\n\nUser financial context:\n$context'),
      AIMessage.user(prompt),
    ];

    if (!_provider.isConfigured) {
      // Fallback to local rule-based response
      final fallback = _getLocalFallback(prompt, 'API not configured');
      yield AIStreamChunk(content: fallback, isDone: true);
      return;
    }

    await for (final chunk in _provider.sendMessageStream(messages: messages)) {
      if (chunk.isDone) {
        if (chunk.error != null) {
          // On error, yield fallback
          final fallback = _getLocalFallback(prompt, chunk.error);
          yield AIStreamChunk(content: fallback, isDone: true);
        } else {
          yield chunk;
        }
        return;
      }
      yield chunk;
    }
  }

  /// Local fallback using the existing rule-based logic
  String _getLocalFallback(String prompt, String? error) {
    final query = prompt.trim().toLowerCase();

    if (query.isEmpty) {
      return 'Ask me about your saved spending, budgets, goals, or investment thesis workflow.';
    }

    // This mirrors the existing FinancialAssistantService logic but as fallback
    if (query.contains('budget') || query.contains('spend')) {
      return 'I\'m currently in offline mode (${error ?? 'API unavailable'}). Here\'s what I can tell you from local data: Use the spending and budget screens to see your category breakdowns. The AI assistant needs an API key to provide detailed analysis.';
    }

    if (query.contains('goal') || query.contains('save for') || query.contains('savings')) {
      return 'I\'m in offline mode (${error ?? 'API unavailable'}). Check the Goals tab for your saved goals and monthly contribution estimates.';
    }

    if (query.contains('investment') || query.contains('thesis') || query.contains('stock') || query.contains('share')) {
      return 'I\'m in offline mode (${error ?? 'API unavailable'}). Open Invest → Investment Intelligence to manage your investment theses and portfolio assumptions.';
    }

    if (query.contains('liquid')) {
      return 'Liquidity analysis compares hypothetical orders with historical volume you enter. It\'s a scenario tool, not real order-book data. Open Invest → Investment Intelligence → Liquidity tab.';
    }

    if (query.contains('tenge') || query.contains('oil') || query.contains('interest rate') || query.contains('scenario') || query.contains('ripple')) {
      return 'Economic Ripple simulates portfolio impact from macro shocks using your entered sensitivities. Open Invest → Investment Intelligence → Economic Ripple tab.';
    }

    if (query.contains('balance') || query.contains('account')) {
      return 'Your local demo balance and spending are shown on the Home screen. The AI needs an API key for detailed analysis.';
    }

    return 'I\'m running in offline mode (${error ?? 'API unavailable'}). Set OPENROUTER_API_KEY to enable AI responses. I can help with spending, budgets, goals, and investment research using your saved SmartSave data.';
  }

  /// Closes the provider
  void dispose() {
    _provider.dispose();
  }
}