import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/glass.dart';
import '../../shared/widgets.dart';
import '../goals/goals_screen.dart';
import '../invest/investment_intelligence_screen.dart';
import '../transactions/transactions_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return context.l10n.morning;
    } else if (hour < 17) {
      return context.l10n.afternoon;
    } else {
      return context.l10n.evening;
    }
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    final spending = finance.spending;
    final topSpending =
        spending.entries.where((e) => e.key != 'Health').toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final goals = finance.goals;
    final loadError = finance.loadError;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: finance.isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.colors.text),
              )
            : loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.localRecordsLoadError,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: finance.refresh,
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: finance.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    // Header with greeting and profile avatar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(context),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.yourFinances,
                                style: glassTitle(context),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.openAccount,
                          onPressed: () =>
                              ref
                                      .read(selectedTabIndexProvider.notifier)
                                      .state =
                                  4,
                          icon: CircleAvatar(
                            backgroundColor: context.colors.subtleSurface,
                            foregroundColor: context.colors.text,
                            child: const Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _BalanceOverview(
                      balance: finance.balance,
                      monthlySpend: finance.monthlySpend,
                      spending: finance.spending,
                      budgetLimits: finance.budgetLimits,
                      onBalance: () =>
                          _push(context, const TotalBalanceDetailScreen()),
                      onSpending: () =>
                          _push(context, const SpendingAnalyticsScreen()),
                      onInvest: () =>
                          ref.read(selectedTabIndexProvider.notifier).state = 3,
                    ),
                    const SizedBox(height: 30),
                    SectionHeading(
                      context.l10n.recent,
                      trailing: context.l10n.seeAll,
                      onTrailing: () =>
                          _push(context, const TransactionsScreen()),
                    ),
                    if (finance.transactions.isNotEmpty)
                      Material(
                        color: context.colors.isDark
                            ? Color.alphaBlend(
                                context.colors.text.withValues(alpha: .07),
                                context.colors.canvas,
                              )
                            : context.colors.surface,
                        borderRadius: BorderRadius.circular(28),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (index, transaction)
                                in finance.transactions.take(2).indexed) ...[
                              if (index > 0)
                                const Divider(
                                  height: 1,
                                  indent: 64,
                                  endIndent: 16,
                                ),
                              _ActivityRow(
                                transaction: transaction,
                                onTap: () => _push(
                                  context,
                                  TransactionDetailsScreen(
                                    transaction: transaction,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 28),
                    // Goal Progress Section (preserved from original)
                    if (goals.isNotEmpty) ...[
                      SectionHeading(
                        context.l10n.goalProgress,
                        trailing: context.l10n.myGoals,
                        onTrailing: () => _push(context, const GoalsScreen()),
                      ),
                      const SizedBox(height: 12),
                      _GoalProgressCard(goals: goals.take(2).toList()),
                    ] else ...[
                      SectionHeading(context.l10n.goals),
                      const SizedBox(height: 12),
                      SurfaceCard(
                        color: context.colors.subtleSurface,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.noGoals,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.l10n.createGoalHint,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryAction(
                              label: context.l10n.createFirstGoal,
                              onPressed: () =>
                                  _push(context, const GoalsScreen()),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    SectionHeading(
                      context.l10n.topSpending,
                      trailing: context.l10n.seeAll,
                      onTrailing: () =>
                          _push(context, const SpendingAnalyticsScreen()),
                    ),
                    if (topSpending.isEmpty)
                      Text(
                        context.l10n.addTransactionsHint,
                        style: TextStyle(color: context.colors.muted),
                      )
                    else
                      for (final entry in topSpending.take(3))
                        _SpendingBar(
                          label: entry.key,
                          amount: entry.value,
                          max: topSpending.first.value,
                        ),
                    const SizedBox(height: 28),
                    _QuickActionsGrid(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({
    required this.balance,
    required this.monthlySpend,
    required this.spending,
    required this.budgetLimits,
    required this.onBalance,
    required this.onSpending,
    required this.onInvest,
  });

  final int balance;
  final int monthlySpend;
  final Map<String, int> spending;
  final Map<String, int> budgetLimits;
  final VoidCallback onBalance;
  final VoidCallback onSpending;
  final VoidCallback onInvest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final budget = budgetLimits.entries
        .where((entry) => entry.value > 0)
        .firstOrNull;
    final numerals = glassTitle(context).copyWith(
      fontSize: 66,
      letterSpacing: -4,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(.42, .05),
              radius: .72,
              colors: [
                colors.progress.withValues(alpha: colors.isDark ? .18 : .17),
                colors.canvas.withValues(alpha: 0),
              ],
            ),
          ),
          child: InkWell(
            onTap: onBalance,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 29, 0, 27),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.totalBalance,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 20,
                        color: colors.action,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(context.formatTenge(balance), style: numerals),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.spentMonth),
          subtitle: budget == null
              ? null
              : Text(
                  '${budget.key} · ${context.l10n.budgetSpent(context.formatTenge(spending[budget.key] ?? 0), context.formatTenge(budget.value))}',
                ),
          trailing: Text(
            context.formatTenge(monthlySpend),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          onTap: onSpending,
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.investmentIntelligence),
          subtitle: Text(context.l10n.stocksBondsOpportunities),
          trailing: Icon(
            Icons.arrow_outward_rounded,
            size: 18,
            color: colors.action,
          ),
          onTap: onInvest,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _QuickActionsGrid extends ConsumerWidget {
  const _QuickActionsGrid();

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _openThesisAutopsy(BuildContext context) {
    _push(context, InvestmentIntelligenceScreen(initialTab: 1));
  }

  void _openLiquidityAnalysis(BuildContext context) {
    _push(context, InvestmentIntelligenceScreen(initialTab: 2));
  }

  void _openEconomicRipple(BuildContext context) {
    _push(context, InvestmentIntelligenceScreen(initialTab: 3));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QuickActionItem(
        icon: Icons.auto_awesome,
        label: context.l10n.beginInvesting,
        description: context.l10n.aiGuidedWorkflow,
        onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 2,
      ),
      _QuickActionItem(
        icon: Icons.savings_outlined,
        label: context.l10n.deposit,
        description: context.l10n.openOrAddDeposit,
        onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 1,
      ),
      _QuickActionItem(
        icon: Icons.trending_up,
        label: context.l10n.opportunities,
        description: context.l10n.stocksBondsOpportunities,
        onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 3,
      ),
      _QuickActionItem(
        icon: Icons.description_outlined,
        label: context.l10n.thesisReview,
        description: context.l10n.reviewInvestDecisions,
        onTap: () => _openThesisAutopsy(context),
      ),
      _QuickActionItem(
        icon: Icons.swap_vert,
        label: context.l10n.liquidityAnalysis,
        description: context.l10n.cashConversion,
        onTap: () => _openLiquidityAnalysis(context),
      ),
      _QuickActionItem(
        icon: Icons.timeline_outlined,
        label: context.l10n.economicRipple,
        description: context.l10n.economicChanges,
        onTap: () => _openEconomicRipple(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.quickActions,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: context.colors.text,
          ),
        ),
        const SizedBox(height: 12),
        for (final action in actions) action,
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: context.colors.action),
    title: Text(label, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(description, style: Theme.of(context).textTheme.bodySmall),
    trailing: Icon(Icons.chevron_right, color: context.colors.muted),
    onTap: onTap,
  );
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({required this.goals});
  final List<SavingsGoal> goals;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(27),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < goals.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _SingleGoalCard(goal: goals[i]),
          ],
        ],
      ),
    );
  }
}

class _SingleGoalCard extends StatelessWidget {
  const _SingleGoalCard({required this.goal});
  final SavingsGoal goal;

  int _monthsLeft(DateTime deadline) {
    return ((deadline.year - DateTime.now().year) * 12 +
            deadline.month -
            DateTime.now().month)
        .clamp(0, 120);
  }

  @override
  Widget build(BuildContext context) {
    final monthly = monthlyGoalContribution(
      targetTenge: goal.target,
      savedTenge: goal.saved,
      monthsRemaining: _monthsLeft(goal.deadline),
    );

    return InkWell(
      onTap: () => _push(context, GoalProgressScreen(goal: goal)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.amountOf(
                          context.formatTenge(goal.saved),
                          context.formatTenge(goal.target),
                        ),
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${goal.progressPercent}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProgressTrack(
              value: goal.target == 0 ? 0 : goal.saved / goal.target,
              height: 5,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  context.l10n.monthsLeft(_monthsLeft(goal.deadline)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  context.l10n.monthEstimate(context.formatTenge(monthly)),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingBar extends StatelessWidget {
  const _SpendingBar({
    required this.label,
    required this.amount,
    required this.max,
  });
  final String label;
  final int amount;
  final int max;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.colors.text),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ProgressTrack(
              value: max == 0 ? 0 : amount / max,
              height: 8,
              color: label == 'Shopping'
                  ? context.colors.warning
                  : label == 'Transport'
                  ? context.colors.progress
                  : context.colors.text,
            ),
          ),
        ),
        SizedBox(
          width: 92,
          child: Text(
            context.formatTenge(amount),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.transaction, required this.onTap});
  final FinanceTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: context.colors.action.withValues(alpha: .10),
            foregroundColor: context.colors.action,
            child: Icon(
              transaction.isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchant,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${transaction.category} · ${_time(transaction.occurredAt)}',
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
              ],
            ),
          ),
          Text(
            context.formatSignedTenge(
              transaction.amount,
              income: transaction.isIncome,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.text,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecentTransaction extends StatelessWidget {
  const _RecentTransaction({required this.transaction, required this.onTap});
  final FinanceTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    onTap: onTap,
    child: Row(
      children: [
        CircleAvatar(radius: 14, backgroundColor: context.colors.subtleSurface, child: SizedBox.shrink()),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(transaction.merchant, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${transaction.category} · ${_time(transaction.occurredAt)}', style: TextStyle(fontSize: 11, color: context.colors.muted)),
        ])),
        Text(context.formatSignedTenge(transaction.amount, income: transaction.isIncome), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.text)),
      ],
    ),
  );
}

class TotalBalanceDetailScreen extends ConsumerWidget {
  const TotalBalanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: EditorialHeader(
          leading: BackButton(),
          title: Text(context.l10n.totalBalanceTitle),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Spending'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Spending tab - reuse SpendingAnalyticsScreen content
            _SpendingTabContent(),
            // Transactions tab - reuse TransactionsScreen content
            _TransactionsTabContent(),
          ],
        ),
      ),
    );
  }
}

class _SpendingTabContent extends ConsumerWidget {
  const _SpendingTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    final spending = finance.spending;
    final topSpending = spending.entries.where((e) => e.key != 'Health').toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: finance.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          SectionHeading(context.l10n.topSpending, trailing: context.l10n.seeAll, onTrailing: () => _push(context, const SpendingAnalyticsScreen())),
          if (topSpending.isEmpty)
            Text(context.l10n.addTransactionsHint, style: TextStyle(color: context.colors.muted))
          else
            ...[for (final entry in topSpending.take(3)) _SpendingBar(label: entry.key, amount: entry.value, max: topSpending.first.value)],
          const SizedBox(height: 12),
          SectionHeading(context.l10n.spendingByCategory, trailing: context.l10n.analytics, onTrailing: () => _push(context, const SpendingAnalyticsScreen())),
          for (final entry in topSpending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(entry.key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.text))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ProgressTrack(value: topSpending.first.value == 0 ? 0 : entry.value / topSpending.first.value, height: 8, color: entry.key == 'Shopping' ? context.colors.warning : entry.key == 'Transport' ? context.colors.progress : context.colors.text))),
                  SizedBox(width: 92, child: Text(context.formatTenge(entry.value), textAlign: TextAlign.right, style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600, fontSize: 13))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionsTabContent extends ConsumerWidget {
  const _TransactionsTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    return RefreshIndicator(
      onRefresh: finance.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          SectionHeading(context.l10n.recent, trailing: context.l10n.seeAll, onTrailing: () => _push(context, const TransactionsScreen())),
          for (final transaction in finance.transactions.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _RecentTransaction(
                transaction: transaction,
                onTap: () => _push(context, TransactionDetailsScreen(transaction: transaction)),
              ),
            ),
        ],
      ),
    );
  }
}

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
