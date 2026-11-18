import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import '../invest/invest_screen.dart';

class WhereToCutScreen extends ConsumerStatefulWidget {
  const WhereToCutScreen({super.key});
  @override
  ConsumerState<WhereToCutScreen> createState() => _WhereToCutScreenState();
}
class _WhereToCutScreenState extends ConsumerState<WhereToCutScreen> {
  final _selected = <int>{0, 1, 2};
  static const _tips = [
    ('Food delivery', 15000, 'Ordered 8 times this month'),
    ('Subscriptions', 8000, '3 services not used for 30 days'),
    ('Taxi', 8000, 'Replace 4 of 9 rides with transit'),
  ];
  int get totalSelected => _selected.fold(0, (sum, index) => sum + _tips[index].$2);

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeControllerProvider);
    final goal = finance.goals.isEmpty ? null : finance.goals.first;
    return Scaffold(appBar: AppBar(title: const Text('Where to cut')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      SurfaceCard(color: AppColors.mintLight, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('You can free up ${formatTenge(totalSelected)} per month', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 5), const Text('Suggestions are based on fictional sample spending, not a bank analysis.', style: TextStyle(color: AppColors.muted, fontSize: 11))])),
      const SizedBox(height: 16),
      for (var i = 0; i < _tips.length; i++) CheckboxListTile(contentPadding: EdgeInsets.zero, activeColor: AppColors.firefly, title: Text(_tips[i].$1, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${formatTenge(_tips[i].$2)} · ${_tips[i].$3}', style: const TextStyle(fontSize: 11, color: AppColors.muted)), value: _selected.contains(i), onChanged: (value) => setState(() { if (value == true) { _selected.add(i); } else { _selected.remove(i); } })),
      const SizedBox(height: 12),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('If you apply selected tips', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 5), Text(goal == null ? 'Your goal estimate will update after you create a goal.' : 'Your ${goal.name} plan can include ${formatTenge(totalSelected)} more per month.'), const SizedBox(height: 4), const Text('These are planning suggestions only; no spending is changed.', style: TextStyle(color: AppColors.muted, fontSize: 11))])),
      const SizedBox(height: 18),
      PrimaryAction(label: 'Apply selected', onPressed: _apply),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
    ])));
  }

  Future<void> _apply() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cut_suggestions_monthly', totalSelected);
    await prefs.setStringList('cut_suggestions', _selected.map((i) => _tips[i].$1).toList());
    if (!mounted) return;
    showMessage(context, 'Plan saved. No transactions or spending were changed.');
    Navigator.pop(context);
  }
}

class AutoSaveScreen extends StatelessWidget {
  const AutoSaveScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Auto-save')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    const SurfaceCard(color: AppColors.mintLight, child: Text('Coming later', style: TextStyle(fontWeight: FontWeight.w700))),
    const SizedBox(height: 16),
    const SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Save without thinking about it', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 8), Text('Automatic transfers are not available. SmartSave will not move money in this MVP.'), SizedBox(height: 14), LabeledValue(label: 'Demo schedule', value: '23 000 ₸ on the 1st'), LabeledValue(label: 'Destination', value: 'Selected savings goal')])),
    const SizedBox(height: 18),
    PrimaryAction(label: 'Notify me when available', onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('notify_auto_save', true); if (context.mounted) showMessage(context, 'Interest saved locally. No transfer was scheduled.'); }),
  ])));
}

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('For you')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    const SurfaceCard(color: AppColors.mintLight, child: Text('Moderate · Kazakhstan · sample recommendations', style: TextStyle(fontWeight: FontWeight.w600))),
    const SizedBox(height: 12),
    _RecommendationCard(label: 'Stock', title: 'Halyk Bank (HSBK)', reason: 'Medium risk, illustrative fit for a Moderate profile. Sample company context only.', source: 'Source: sample KASE data', onTap: () => _push(context, const StockDetailsScreen(stock: ('Halyk Bank', 'HSBK', 'Medium', '245,00 ₸', '+1,8%', true)))),
    const SizedBox(height: 10),
    _RecommendationCard(label: 'Deposit', title: 'Freedom Bank · 19.50% ГЭСВ', reason: 'Highest example 3-month rate among the local sample products.', source: 'Source: fictional prototype rate cards', onTap: () => _push(context, DepositRatesScreen())),
    const SizedBox(height: 10),
    _RecommendationCard(label: 'Cushion', title: 'Keep 3 months of spending in a deposit', reason: 'An educational example for unexpected expenses, based on sample records.', source: 'Source: fictional demo transactions', onTap: () => showMessage(context, 'This is an illustrative suggestion, not a personalized recommendation.')),
    const SizedBox(height: 12),
    const Text('Not investment advice. Verify information with its source before making decisions.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
  ])));
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.label, required this.title, required this.reason, required this.source, required this.onTap});
  final String label, title, reason, source; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SurfaceCard(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(color: AppColors.prussianBlue, fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 5), Text(reason, style: const TextStyle(fontSize: 12, color: AppColors.muted)), const SizedBox(height: 6), Text(source, style: const TextStyle(fontSize: 10, color: AppColors.muted)), Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onTap, child: const Text('Why this?')))]));
}

class NoResultsScreen extends StatelessWidget {
  const NoResultsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Deposits')), body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: SurfaceCard(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.search_off, color: AppColors.muted, size: 42), const SizedBox(height: 12), const Text('No deposits match your filters', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), const Text('Try fewer filters or a different term. Rates are compared across the local sample catalogue.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)), const SizedBox(height: 12), PrimaryAction(label: 'Reset filters', onPressed: () => Navigator.pop(context)), TextButton(onPressed: () => Navigator.pop(context), child: const Text('Remove top-up filter'))]))))));
}

void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
