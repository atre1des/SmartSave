import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import 'investment_intelligence_screen.dart';
import 'invest_screen.dart';
import 'stocks_screen.dart';

class InvestHubScreen extends ConsumerStatefulWidget {
  const InvestHubScreen({super.key});

  @override
  ConsumerState<InvestHubScreen> createState() => _InvestHubScreenState();
}

class _InvestHubScreenState extends ConsumerState<InvestHubScreen> {
  void _openFeature(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(authStateProvider).valueOrNull?.displayName ?? 'User';
    final finance = ref.watch(financeControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: finance.isLoading
            ? Center(child: CircularProgressIndicator(color: context.colors.text))
            : RefreshIndicator(
                onRefresh: finance.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    // Personalized greeting
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Should we begin, $userName?',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.investExploreIntro,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.muted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: context.colors.subtleSurface,
                          foregroundColor: context.colors.text,
                          child: const Icon(Icons.psychology_outlined, size: 28),
                        ),
                      ],
                    ),
                    // Investment Intelligence
                    SectionHeading(context.l10n.investmentIntelligence, trailing: context.l10n.explore, onTrailing: () => _openFeature(const InvestmentIntelligenceScreen())),
                    const SizedBox(height: 12),
                    SurfaceCard(
                      onTap: () => _openFeature(const InvestmentIntelligenceScreen()),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.colors.subtleSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.psychology_outlined, color: context.colors.text, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.aiBeginners,
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.investBasicsIntro,
                                      style: TextStyle(color: context.colors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: context.colors.muted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.colors.noticeSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.description_outlined, color: context.colors.warning, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.thesisReview,
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.thesisTrackingIntro,
                                      style: TextStyle(color: context.colors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: context.colors.muted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.colors.noticeSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.waves_outlined, color: context.colors.error, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.liquidityAnalysis,
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.liquidityExecutionIntro,
                                      style: TextStyle(color: context.colors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: context.colors.muted),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.colors.subtleSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.timeline_outlined, color: context.colors.progress, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.economicRipple,
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.macroImpactIntro,
                                      style: TextStyle(color: context.colors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: context.colors.muted),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stocks for You
                    SectionHeading(context.l10n.stocksForYou, trailing: context.l10n.viewAll, onTrailing: () => _openFeature(const StocksScreen())),
                    const SizedBox(height: 12),
                    _StocksPreview(onTap: () => _openFeature(const StocksScreen())),
                    const SizedBox(height: 24),

                    // Bonds
                    SectionHeading(context.l10n.bonds, trailing: context.l10n.comingSoon, onTrailing: () => _openFeature(const BondsScreen())),
                    const SizedBox(height: 12),
                    SurfaceCard(
                      color: context.colors.subtleSurface,
                      onTap: () => _openFeature(const BondsScreen()),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.account_balance_outlined, color: context.colors.text, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.bondOpportunities,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.bondIntro,
                                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: context.colors.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Auto Invest
                    SectionHeading(context.l10n.autoInvest, trailing: context.l10n.setUp, onTrailing: () => _openFeature(const AutoInvestScreen())),
                    const SizedBox(height: 12),
                    SurfaceCard(
                      color: context.colors.noticeSurface,
                      onTap: () => _openFeature(const AutoInvestScreen()),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.autorenew_outlined, color: context.colors.warning, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.recurringInvestment,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.createAllocation,
                                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: context.colors.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.demoTransfersNotice,
                      style: TextStyle(color: context.colors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StocksPreview extends ConsumerWidget {
  const _StocksPreview({required this.onTap});
  final VoidCallback onTap;

  // Sample stocks - same as InvestScreen
  static const List<(String, String, String, String, String, bool)> _stocks = [
    ('Halyk Bank', 'HSBK', 'Medium', '245,00 ₸', '+1,8%', true),
    ('Kaspi.kz', 'KSPI', 'Medium', '42 300 ₸', '+0,6%', true),
    ('KEGOC', 'KEGC', 'Low', '1 480 ₸', '−0,4%', true),
    ('Kazatomprom', 'KAP', 'High', '21 900 ₸', '+2,3%', false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the same sample stocks as the current InvestScreen
    return Column(
      children: [
        ..._stocks.take(3).map(
          (stock) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _StockTile(stock: stock, onTap: () => _push(context, StockDetailsScreen(stock: stock))),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(context.l10n.viewAllStocks, style: TextStyle(color: context.colors.action, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.stock, required this.onTap});
  final (String, String, String, String, String, bool) stock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: context.colors.subtleSurface,
          child: Text(
            stock.$2.substring(0, 2),
            style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stock.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('${stock.$2} · ${stock.$3} risk', style: TextStyle(color: context.colors.muted, fontSize: 11)),
              Text(
                stock.$6 ? context.l10n.fitsProfile : context.l10n.aboveProfile,
                style: TextStyle(fontSize: 10, color: stock.$6 ? context.colors.positive : context.colors.error),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(stock.$4, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(stock.$5, style: TextStyle(fontSize: 12, color: stock.$5.startsWith('+') ? context.colors.positive : context.colors.error)),
          ],
        ),
      ],
    ),
  );
}

class BondsScreen extends StatelessWidget {
  const BondsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.bonds)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SurfaceCard(
            color: context.colors.subtleSurface,
            child: Text(context.l10n.noLiveBonds, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          SectionHeading(context.l10n.whatPlanned),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.governmentBonds),
                SizedBox(height: 12),
                Text(context.l10n.corporateBonds),
                SizedBox(height: 12),
                Text(context.l10n.bondFilters),
                SizedBox(height: 12),
                Text(context.l10n.bondExplanations),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.bondDataNotice,
            style: TextStyle(color: context.colors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          PrimaryAction(
            label: context.l10n.notifyAvailable,
            onPressed: () => showMessage(context, context.l10n.notificationSaved),
          ),
        ],
      ),
    ),
  );
}

class AutoInvestScreen extends ConsumerStatefulWidget {
  const AutoInvestScreen({super.key});

  @override
  ConsumerState<AutoInvestScreen> createState() => _AutoInvestScreenState();
}

class _AutoInvestScreenState extends ConsumerState<AutoInvestScreen> {
  final _amount = TextEditingController(text: '50000');
  int _frequency = 1; // 1 = monthly, 2 = quarterly
  int? _selectedGoalId;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeControllerProvider);
    final goals = finance.goals;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.autoInvest)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              context.l10n.createRecurringPlan,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.illustrativePlan,
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Amount
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.l10n.amountPerPeriod, suffixText: '₸'),
            ),
            const SizedBox(height: 16),

            // Frequency
            Text(context.l10n.frequency, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Pill(
                    label: context.l10n.monthly,
                    selected: _frequency == 1,
                    onTap: () => setState(() => _frequency = 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Pill(
                    label: context.l10n.quarterly,
                    selected: _frequency == 2,
                    onTap: () => setState(() => _frequency = 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Goal selection
            if (goals.isNotEmpty) ...[
              Text(context.l10n.optionalGoal, style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _selectedGoalId,
                decoration: InputDecoration(labelText: context.l10n.selectGoal),
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.noGoalLinked)),
                  for (final goal in goals)
                    DropdownMenuItem(value: goal.id, child: Text(goal.name)),
                ],
                onChanged: (value) => setState(() => _selectedGoalId = value),
              ),
              const SizedBox(height: 24),
            ],

            // Illustrative allocation
            SectionHeading(context.l10n.sampleAllocation),
            SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.moderateAllocation,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _AllocationRow(label: context.l10n.conservativeDeposits, percent: 40, color: context.colors.progress),
                  _AllocationRow(label: context.l10n.kazakhBankShares, percent: 35, color: context.colors.text),
                  _AllocationRow(label: context.l10n.bonds, percent: 15, color: context.colors.warning),
                  _AllocationRow(label: context.l10n.cashReserve, percent: 10, color: context.colors.highlight),
                ],
              ),
            ),
            const SizedBox(height: 24),

            PrimaryAction(
              label: context.l10n.savePlan,
              onPressed: () {
                showMessage(context, context.l10n.planSaved);
              },
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.planLocalOnly,
              style: TextStyle(color: context.colors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.label, required this.percent, required this.color});
  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );
}

void _push(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));