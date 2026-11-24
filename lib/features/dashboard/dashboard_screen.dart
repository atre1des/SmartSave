import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
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

  void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    final spending = finance.spending;
    final topSpending = spending.entries.where((e) => e.key != 'Health').toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final goals = finance.goals;
    final loadError = finance.loadError;

    return Scaffold(
      body: SafeArea(
        child: finance.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.firefly))
            : loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.l10n.localRecordsLoadError, textAlign: TextAlign.center),
                      TextButton(onPressed: finance.refresh, child: Text(context.l10n.retry)),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: finance.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    // Header with greeting and profile avatar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getGreeting(context), style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 2),
                              Text(context.l10n.yourFinances, style: Theme.of(context).textTheme.headlineMedium),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.openAccount,
                          onPressed: () => ref.read(selectedTabIndexProvider.notifier).state = 4,
                          icon: const CircleAvatar(
                            backgroundColor: AppColors.mintLight,
                            foregroundColor: AppColors.firefly,
                            child: Text('Y', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Total balance card
                    InkWell(
                      onTap: () => _push(context, const TotalBalanceDetailScreen()),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.firefly,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.totalBalance, style: TextStyle(color: AppColors.mint, fontSize: 12)),
                          const SizedBox(height: 3),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              context.formatTenge(finance.balance),
                              style: const TextStyle(fontSize: 30, height: 1.35, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(context.l10n.spentMonth, style: TextStyle(color: AppColors.mint, fontSize: 11)),
                          Text(context.formatTenge(finance.monthlySpend), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                        ),
                        ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Grid - Banking app style shortcuts
                    _QuickActionsGrid(),
                    const SizedBox(height: 20),

                    // Goal Progress Section (preserved from original)
                    if (goals.isNotEmpty) ...[
                      SectionHeading(context.l10n.goalProgress, trailing: context.l10n.myGoals, onTrailing: () => _push(context, const GoalsScreen())),
                      const SizedBox(height: 12),
                      _GoalProgressCard(goals: goals.take(2).toList()),
                    ] else ...[
                      SectionHeading(context.l10n.goals),
                      const SizedBox(height: 12),
                        SurfaceCard(
                          color: AppColors.mintLight,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.noGoals, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(context.l10n.createGoalHint, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              const SizedBox(height: 12),
                              PrimaryAction(
                                label: context.l10n.createFirstGoal,
                                onPressed: () => _push(context, const GoalsScreen()),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),

                    // Top spending this month
                    SectionHeading(context.l10n.topSpending, trailing: context.l10n.seeAll, onTrailing: () => _push(context, const SpendingAnalyticsScreen())),
                    if (topSpending.isEmpty)
                      Text(context.l10n.addTransactionsHint, style: TextStyle(color: AppColors.muted))
                    else
                      for (final entry in topSpending.take(3))
                        _SpendingBar(label: entry.key, amount: entry.value, max: topSpending.first.value),

                    const SizedBox(height: 12),

                    // Recent transactions
                    SectionHeading(context.l10n.recent, trailing: context.l10n.seeAll, onTrailing: () => _push(context, const TransactionsScreen())),
                    for (final transaction in finance.transactions.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _RecentTransaction(
                          transaction: transaction,
                          onTap: () => _push(context, TransactionDetailsScreen(transaction: transaction)),
                        ),
                      ),
                  ],
              ),
            ),
      ),
    );
  }
}

class _QuickActionsGrid extends ConsumerWidget {
  const _QuickActionsGrid();

  void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

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
        Text(context.l10n.quickActions, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.firefly)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate aspect ratio based on available width to prevent overflow
            final cardWidth = (constraints.maxWidth - 12) / 2; // 12 = crossAxisSpacing
            // Fixed card height accommodates a two-line title and a two-line
            // description: padding 32 + icon 52 + gaps 16 + label ~38 +
            // description ~31 ≈ 169, rounded up to 172 for safety.
            final estimatedHeight = 172.0;
            final aspectRatio = cardWidth / estimatedHeight;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: aspectRatio.clamp(0.5, 2.0),
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) => actions[index],
            );
          },
        ),
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.firefly, size: 28),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: AppColors.muted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({required this.goals});
  final List<SavingsGoal> goals;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: goals.map((goal) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SingleGoalCard(goal: goal),
      )).toList(),
    );
  }
}

class _SingleGoalCard extends StatelessWidget {
  const _SingleGoalCard({required this.goal});
  final SavingsGoal goal;

  int _monthsLeft(DateTime deadline) {
    return ((deadline.year - DateTime.now().year) * 12 + deadline.month - DateTime.now().month).clamp(0, 120);
  }

  @override
  Widget build(BuildContext context) {
    final monthly = monthlyGoalContribution(targetTenge: goal.target, savedTenge: goal.saved, monthsRemaining: _monthsLeft(goal.deadline));

    return SurfaceCard(
      onTap: () => _push(context, GoalProgressScreen(goal: goal)),
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
                    Text(goal.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.amountOf(context.formatTenge(goal.saved), context.formatTenge(goal.target)),
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${goal.progressPercent}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressTrack(value: goal.target == 0 ? 0 : goal.saved / goal.target, height: 10),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(context.l10n.monthsLeft(_monthsLeft(goal.deadline)), style: Theme.of(context).textTheme.bodySmall),
              Text(context.l10n.monthEstimate(context.formatTenge(monthly)), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendingBar extends StatelessWidget {
  const _SpendingBar({required this.label, required this.amount, required this.max});
  final String label;
  final int amount;
  final int max;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.firefly))),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ProgressTrack(value: max == 0 ? 0 : amount / max, height: 8, color: label == 'Shopping' ? AppColors.gold : label == 'Transport' ? AppColors.mint : AppColors.firefly))),
        SizedBox(width: 92, child: Text(context.formatTenge(amount), textAlign: TextAlign.right, style: const TextStyle(color: AppColors.firefly, fontWeight: FontWeight.w600, fontSize: 13))),
      ],
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
        const CircleAvatar(radius: 14, backgroundColor: AppColors.mintLight, child: SizedBox.shrink()),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(transaction.merchant, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${transaction.category} · ${_time(transaction.occurredAt)}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ])),
        Text(context.formatSignedTenge(transaction.amount, income: transaction.isIncome), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.firefly)),
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
        appBar: AppBar(
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
            Text(context.l10n.addTransactionsHint, style: TextStyle(color: AppColors.muted))
          else
            ...[for (final entry in topSpending.take(3)) _SpendingBar(label: entry.key, amount: entry.value, max: topSpending.first.value)],
          const SizedBox(height: 12),
          SectionHeading(context.l10n.spendingByCategory, trailing: context.l10n.analytics, onTrailing: () => _push(context, const SpendingAnalyticsScreen())),
          for (final entry in topSpending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(entry.key, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.firefly))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ProgressTrack(value: topSpending.first.value == 0 ? 0 : entry.value / topSpending.first.value, height: 8, color: entry.key == 'Shopping' ? AppColors.gold : entry.key == 'Transport' ? AppColors.mint : AppColors.firefly))),
                  SizedBox(width: 92, child: Text(context.formatTenge(entry.value), textAlign: TextAlign.right, style: const TextStyle(color: AppColors.firefly, fontWeight: FontWeight.w600, fontSize: 13))),
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