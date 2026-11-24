import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/glass.dart';
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
  bool _research = false;

  void _openFeature(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeControllerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: finance.isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.colors.text),
              )
            : RefreshIndicator(
                onRefresh: finance.refresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Text(
                      context.l10n.investmentIntelligence,
                      style: glassTitle(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.investExploreIntro,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        for (final (research, label) in [
                          (false, context.l10n.stocksForYou),
                          (true, context.l10n.explore),
                        ])
                          Expanded(
                            child: Semantics(
                              selected: _research == research,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _research = research),
                                style: TextButton.styleFrom(
                                  foregroundColor: _research == research
                                      ? context.colors.text
                                      : context.colors.muted,
                                  backgroundColor: _research == research
                                      ? context.colors.action.withValues(
                                          alpha: .12,
                                        )
                                      : null,
                                  minimumSize: const Size(48, 48),
                                ),
                                child: Text(label, textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    if (!_research)
                      _StocksPreview(
                        onTap: () => _openFeature(const StocksScreen()),
                        onAssistant: () =>
                            _openFeature(const InvestmentIntelligenceScreen()),
                      ),
                    if (_research)
                      for (final (index, icon, title, detail) in [
                        (
                          0,
                          Icons.auto_awesome,
                          context.l10n.aiBeginners,
                          context.l10n.investBasicsIntro,
                        ),
                        (
                          1,
                          Icons.description_outlined,
                          context.l10n.thesisReview,
                          context.l10n.thesisTrackingIntro,
                        ),
                        (
                          2,
                          Icons.waves_outlined,
                          context.l10n.liquidityAnalysis,
                          context.l10n.liquidityExecutionIntro,
                        ),
                        (
                          3,
                          Icons.timeline_outlined,
                          context.l10n.economicRipple,
                          context.l10n.macroImpactIntro,
                        ),
                      ])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: context.colors.action),
                          title: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            detail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: context.colors.muted,
                          ),
                          onTap: () => _openFeature(
                            InvestmentIntelligenceScreen(initialTab: index),
                          ),
                        ),
                    const SizedBox(height: 20),

                    // Bonds
                    SectionHeading(
                      context.l10n.bonds,
                      trailing: context.l10n.comingSoon,
                      onTrailing: () => _openFeature(const BondsScreen()),
                    ),
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
                            child: Icon(
                              Icons.account_balance_outlined,
                              color: context.colors.text,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.bondOpportunities,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.bondIntro,
                                  style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: context.colors.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Auto Invest
                    SectionHeading(
                      context.l10n.autoInvest,
                      trailing: context.l10n.setUp,
                      onTrailing: () => _openFeature(const AutoInvestScreen()),
                    ),
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
                            child: Icon(
                              Icons.autorenew_outlined,
                              color: context.colors.warning,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.recurringInvestment,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.createAllocation,
                                  style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: context.colors.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.demoTransfersNotice,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StocksPreview extends ConsumerWidget {
  const _StocksPreview({required this.onTap, required this.onAssistant});
  final VoidCallback onTap;
  final VoidCallback onAssistant;

  // Sample stocks - same as InvestScreen
  static const List<(String, String, String, String, String, bool)> _stocks = [
    ('Halyk Bank', 'HSBK', 'Medium', '245,00 ₸', '+1,8%', true),
    ('Kaspi.kz', 'KSPI', 'Medium', '42 300 ₸', '+0,6%', true),
    ('KEGOC', 'KEGC', 'Low', '1 480 ₸', '−0,4%', true),
    ('Kazatomprom', 'KAP', 'High', '21 900 ₸', '+2,3%', false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final numeric = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.sampleStockNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.stockPriceChange,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final stock in _stocks) ...[
          _StockMovement(ticker: stock.$2, change: stock.$5),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onAssistant,
            icon: const Icon(Icons.auto_awesome, size: 17),
            label: Text(context.l10n.aiBeginners),
          ),
        ),
        const SizedBox(height: 10),
        for (final stock in _stocks.take(3)) ...[
          Divider(height: 1, color: colors.outline),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(stock.$1),
            subtitle: Text(
              stock.$6 ? context.l10n.fitsProfile : context.l10n.aboveProfile,
            ),
            trailing: Text(stock.$4, style: numeric),
            onTap: () => _push(context, StockDetailsScreen(stock: stock)),
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: onTap,
            child: Text(context.l10n.viewAllStocks),
          ),
        ),
      ],
    );
  }
}

class _StockMovement extends StatelessWidget {
  const _StockMovement({required this.ticker, required this.change});

  final String ticker;
  final String change;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gain = change.startsWith('+');
    final magnitude = double.parse(
      change.substring(1, change.length - 1).replaceAll(',', '.'),
    );
    final fraction = (magnitude / 2.3).clamp(0.0, 1.0);
    final numberStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        SizedBox(width: 50, child: Text(ticker, style: numberStyle)),
        Expanded(
          child: ExcludeSemantics(
            child: SizedBox(
              height: 23,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final midpoint = constraints.maxWidth / 2;
                  final width = midpoint * fraction;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(height: 1, color: colors.outline),
                      Container(width: 1, color: colors.muted),
                      Positioned(
                        left: gain ? midpoint : midpoint - width,
                        width: width,
                        height: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: gain ? colors.action : colors.warning,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(change, style: numberStyle, textAlign: TextAlign.end),
        ),
      ],
    );
  }
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
