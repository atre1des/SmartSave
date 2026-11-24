import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../shared/widgets.dart';
import '../../l10n/app_locale.dart';

class FinancialAssistantService {
  const FinancialAssistantService(this.repository);

  final FinanceRepository repository;

  Future<String> answer(String prompt, {String languageCode = 'en'}) async {
    final strings = assistantStrings(prompt, languageCode);
    final localized = strings.localeName != 'en';
    String money(int amount) => localizedTenge(amount, strings.localeName);
    final query = prompt.trim().toLowerCase();
    if (query.isEmpty) {
      if (localized) return strings.localAssistantHint;
      return 'Ask me about your saved spending, budgets, goals, or investment thesis workflow.';
    }

    if (RegExp(r'budget|spend|бюджет|шығын|расход|трат').hasMatch(query)) {
      final values = await Future.wait<Object>([
        repository.spendingByCategory(),
        repository.budgets(),
        repository.spentThisMonth(),
      ]);
      final spending = values[0] as Map<String, int>;
      final budgets = values[1] as Map<String, int>;
      final total = values[2] as int;
      if (spending.isEmpty) {
        if (localized) {
          return '${strings.localNoExpenses}\n\n${strings.localExpenseNotice}';
        }
        return 'There are no saved expense records for this month yet. Add a transaction to begin tracking spending.\n\nSource: local SmartSave transactions and budgets. Seeded rows are labelled as demo data in the app.';
      }
      final rows = spending.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final details = rows
          .take(4)
          .map((entry) {
            final limit = budgets[entry.key];
            if (localized) {
              final category = strings.categoryName(entry.key);
              final amount = money(entry.value);
              final text = limit == null
                  ? strings.localExpenseRow(category, amount)
                  : strings.localBudgetRow(category, amount, money(limit));
              return '• $text';
            }
            if (limit == null) {
              return '• ${entry.key}: ${formatTenge(entry.value)} spent; no budget set.';
            }
            final remaining = limit - entry.value;
            final remainingLabel = remaining >= 0
                ? '${formatTenge(remaining)} remaining'
                : '${formatTenge(-remaining)} over budget';
            return '• ${entry.key}: ${formatTenge(entry.value)} spent of ${formatTenge(limit)}; $remainingLabel.';
          })
          .join('\n');
      if (localized) {
        return '${strings.localExpenseTotal(money(total))}\n$details\n\n${strings.localExpenseNotice}';
      }
      return 'You have ${formatTenge(total)} in recorded expenses this month.\n$details\n\nThis is a summary, not a spending recommendation. It uses saved local transaction and budget records; sample transactions may be fictional demo data.';
    }

    if (RegExp(
      r'goal|save for|savings|мақсат|жинақ|цел[ьи]|накопл',
    ).hasMatch(query)) {
      final goals = await repository.goals();
      if (goals.isEmpty) {
        if (localized) return '${strings.localNoGoals} ${strings.offlineGoals}';
        return 'You have no saved savings goals yet. Create one in the Goals tab to see its progress and a monthly contribution estimate.';
      }
      final now = DateTime.now();
      final details = goals
          .map((goal) {
            final months =
                ((goal.deadline.year - now.year) * 12 +
                        goal.deadline.month -
                        now.month)
                    .clamp(1, 120);
            final monthly = monthlyGoalContribution(
              targetTenge: goal.target,
              savedTenge: goal.saved,
              monthsRemaining: months,
            );
            if (localized) {
              return '• ${strings.localGoalRow(goal.name, money(goal.saved), money(goal.target), money(monthly))}';
            }
            return '• ${goal.name}: ${goal.progressPercent}% saved (${formatTenge(goal.saved)} of ${formatTenge(goal.target)}); about ${formatTenge(monthly)} per month for $months months.';
          })
          .join('\n');
      if (localized) return '$details\n\n${strings.localGoalNotice}';
      return 'Here is the current plan from your saved goals:\n$details\n\nThe monthly amounts are arithmetic estimates based on each saved target, balance and deadline. They do not move money.';
    }

    if (RegExp(
      r'investment|thesis|stock|share|инвест|тезис|акци',
    ).hasMatch(query)) {
      final theses = await repository.investmentTheses();
      if (theses.isEmpty) {
        if (localized) {
          return '${strings.offlineInvestment} ${strings.localThesisNotice}';
        }
        return 'You have no saved investment theses yet. Open Invest → Investment Intelligence to record a security, your reasoning, risks and testable conditions. SmartSave has no live market feed and does not recommend buying or selling.';
      }
      final details = theses
          .take(5)
          .map(
            (thesis) =>
                '• ${thesis.ticker} — ${thesis.securityName}${thesis.horizon.isEmpty ? '' : ' · ${thesis.horizon}'}',
          )
          .join('\n');
      if (localized) return '$details\n\n${strings.localThesisNotice}';
      return 'Your saved thesis list:\n$details\n\nThe local assessment compares user-entered numeric evidence with user-entered thresholds. It does not fetch issuer disclosures or verify market facts. Open Investment Intelligence to inspect each thesis and its assessment history.';
    }

    if (RegExp(r'liquid|өтімді|ликвид').hasMatch(query)) {
      if (localized) return strings.offlineLiquidity;
      return 'The Liquidity tab compares an order with a dated average volume that you enter. Its participation-rate result is a historical-volume scenario, not current order-book depth or an execution-price prediction. No KASE/AIX market-volume feed is connected.';
    }

    if (query.contains('tenge') ||
        query.contains('oil') ||
        query.contains('interest rate') ||
        query.contains('scenario') ||
        query.contains('ripple') ||
        RegExp(r'теңге|мұнай|сценар|нефт|ставк').hasMatch(query)) {
      if (localized) return strings.offlineScenario;
      return 'Economic Ripple applies your saved KZT holding values and optional sensitivities to a hypothetical tenge, oil-price or interest-rate change. Unknown sensitivities stay unestimated. The output is a scenario, not a forecast or a measured issuer sensitivity.';
    }

    if (RegExp(r'balance|account|қалдық|баланс|счёт').hasMatch(query)) {
      final values = await Future.wait<int>([
        repository.totalBalance(),
        repository.spentThisMonth(),
      ]);
      if (localized) {
        return strings.localBalanceSummary(money(values[0]), money(values[1]));
      }
      return 'Your local demo balance is ${formatTenge(values[0])}; recorded spending this month is ${formatTenge(values[1])}. These totals come from the app’s local SQLite records and fictional seed data, not a connected bank.';
    }

    if (localized) {
      return '${strings.localAssistantHint}\n\n${strings.localDisclosure}';
    }
    return 'I can summarize saved spending and budgets, explain goal estimates, list your saved investment theses, and explain the liquidity and economic scenario tools. Try one of the suggested questions below. I use local rules and saved demo data; no generative AI or external market feed is connected.';
  }
}
