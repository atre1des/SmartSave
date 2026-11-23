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
            ? const Center(child: CircularProgressIndicator(color: AppColors.firefly))
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
                                'SmartSave can help you explore investment options and see how they fit your goals.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: AppColors.mintLight,
                          foregroundColor: AppColors.firefly,
                          child: const Icon(Icons.psychology_outlined, size: 28),
                        ),
                      ],
                    ),
                    // Investment Intelligence
                    SectionHeading('Investment Intelligence', trailing: 'Explore', onTrailing: () => _openFeature(const InvestmentIntelligenceScreen())),
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
                                  color: AppColors.mintLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.psychology_outlined, color: AppColors.firefly, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'AI Investing for Beginners',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Learn the basics, ask questions, and build confidence step by step.',
                                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.muted),
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
                                  color: AppColors.paleGold,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.description_outlined, color: AppColors.gold, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Thesis Autopsy',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Record your investment reasoning, test assumptions against evidence, and track validity over time.',
                                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.muted),
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
                                  color: AppColors.paleRose,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.waves_outlined, color: AppColors.wine, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Liquidity Analysis',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Understand how easily an investment can be sold and what order size means for execution.',
                                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.muted),
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
                                  color: AppColors.mintLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.timeline_outlined, color: AppColors.mint, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Economic Ripple',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Simulate how macro shocks like tenge depreciation or oil price changes affect your portfolio.',
                                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.muted),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stocks for You
                    SectionHeading('Stocks for You', trailing: 'View all', onTrailing: () => _openFeature(const StocksScreen())),
                    const SizedBox(height: 12),
                    _StocksPreview(onTap: () => _openFeature(const StocksScreen())),
                    const SizedBox(height: 24),

                    // Bonds
                    SectionHeading('Bonds', trailing: 'Coming soon', onTrailing: () => _openFeature(const BondsScreen())),
                    const SizedBox(height: 12),
                    SurfaceCard(
                      color: AppColors.mintLight,
                      onTap: () => _openFeature(const BondsScreen()),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance_outlined, color: AppColors.firefly, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bond Opportunities',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Explore government and corporate bonds with verified terms and risk profiles.',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Auto Invest
                    SectionHeading('Auto Invest', trailing: 'Set up', onTrailing: () => _openFeature(const AutoInvestScreen())),
                    const SizedBox(height: 12),
                    SurfaceCard(
                      color: AppColors.paleGold,
                      onTap: () => _openFeature(const AutoInvestScreen()),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.autorenew_outlined, color: AppColors.gold, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recurring Investment Plan',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Set an amount, frequency, and goal. SmartSave will create an illustrative allocation plan.',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Educational demo only. No automatic purchases or bank transfers are performed.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
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
          child: const Text('View all stocks →', style: TextStyle(color: AppColors.prussianBlue, fontWeight: FontWeight.w600)),
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
          backgroundColor: AppColors.mintLight,
          child: Text(
            stock.$2.substring(0, 2),
            style: const TextStyle(color: AppColors.firefly, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stock.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('${stock.$2} · ${stock.$3} risk', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              Text(
                stock.$6 ? '✓ Fits your profile' : '! Above your profile',
                style: TextStyle(fontSize: 10, color: stock.$6 ? AppColors.success : AppColors.wine),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(stock.$4, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(stock.$5, style: TextStyle(fontSize: 12, color: stock.$5.startsWith('+') ? AppColors.success : AppColors.wine)),
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
    appBar: AppBar(title: const Text('Bonds')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SurfaceCard(
            color: AppColors.mintLight,
            child: Text('Bond opportunities are not yet connected to live data.', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          const SectionHeading('What is planned'),
          const SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Government bonds (Kazakhstan Ministry of Finance)'),
                SizedBox(height: 12),
                Text('2. Corporate bonds from major issuers'),
                SizedBox(height: 12),
                Text('3. Filter by maturity, yield, and credit quality'),
                SizedBox(height: 12),
                Text('4. Beginner-friendly explanations of bond mechanics'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Real bond data requires verified sources. No purchase or transfer is performed in this demo.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          PrimaryAction(
            label: 'Notify me when available',
            onPressed: () => showMessage(context, 'Notification preference saved for this demo session.'),
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
      appBar: AppBar(title: const Text('Auto Invest')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Create a recurring investment plan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is an illustrative plan only. No automatic purchases or bank transfers will be performed.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Amount
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount per period', suffixText: '₸'),
            ),
            const SizedBox(height: 16),

            // Frequency
            const Text('Frequency', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Pill(
                    label: 'Monthly',
                    selected: _frequency == 1,
                    onTap: () => setState(() => _frequency = 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Pill(
                    label: 'Quarterly',
                    selected: _frequency == 2,
                    onTap: () => setState(() => _frequency = 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Goal selection
            if (goals.isNotEmpty) ...[
              const Text('Link to goal (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _selectedGoalId,
                decoration: const InputDecoration(labelText: 'Select a goal'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No goal linked')),
                  for (final goal in goals)
                    DropdownMenuItem(value: goal.id, child: Text(goal.name)),
                ],
                onChanged: (value) => setState(() => _selectedGoalId = value),
              ),
              const SizedBox(height: 24),
            ],

            // Illustrative allocation
            const SectionHeading('Illustrative Allocation'),
            SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Based on a Moderate risk profile, your recurring amount would be split as:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _AllocationRow(label: 'Deposits (conservative)', percent: 40, color: AppColors.mint),
                  _AllocationRow(label: 'Bank shares (Kazakhstan)', percent: 35, color: AppColors.firefly),
                  _AllocationRow(label: 'Bonds', percent: 15, color: AppColors.gold),
                  _AllocationRow(label: 'Cash reserve', percent: 10, color: AppColors.lime),
                ],
              ),
            ),
            const SizedBox(height: 24),

            PrimaryAction(
              label: 'Save plan',
              onPressed: () {
                showMessage(context, 'Illustrative recurring investment plan saved. No real transactions performed.');
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'This plan is saved locally for your reference only. Automatic execution requires a licensed broker integration.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
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