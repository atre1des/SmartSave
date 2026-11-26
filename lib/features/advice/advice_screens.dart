import '../../l10n/app_locale.dart';

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
    return Scaffold(appBar: EditorialHeader(title: Text(context.l10n.whereToCut)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      RecordGroup(color: context.colors.subtleSurface, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('You can free up ${context.formatTenge(totalSelected)} per month', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 5), Text(context.l10n.fictionalSpending, style: TextStyle(color: context.colors.muted, fontSize: 11))])),
      const SizedBox(height: 16),
      for (var i = 0; i < _tips.length; i++) CheckboxListTile(contentPadding: EdgeInsets.zero, activeColor: context.colors.text, title: Text(_tips[i].$1, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${context.formatTenge(_tips[i].$2)} · ${_tips[i].$3}', style: TextStyle(fontSize: 11, color: context.colors.muted)), value: _selected.contains(i), onChanged: (value) => setState(() { if (value == true) { _selected.add(i); } else { _selected.remove(i); } })),
      const SizedBox(height: 12),
      RecordGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.selectedTips, style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 5), Text(goal == null ? context.l10n.goalAfterCreate : 'Your ${goal.name} plan can include ${context.formatTenge(totalSelected)} more per month.'), const SizedBox(height: 4), Text(context.l10n.planningOnly, style: TextStyle(color: context.colors.muted, fontSize: 11))])),
      const SizedBox(height: 18),
      PrimaryAction(label: context.l10n.applySelected, onPressed: _apply),
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.notNow)),
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
  Widget build(BuildContext context) => Scaffold(appBar: EditorialHeader(title: Text(context.l10n.autoSave)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    RecordGroup(color: context.colors.subtleSurface, child: Text(context.l10n.comingLater, style: TextStyle(fontWeight: FontWeight.w700))),
    const SizedBox(height: 16),
    RecordGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.saveWithoutThinking, style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 8), Text(context.l10n.autoTransferUnavailable), SizedBox(height: 14), LabeledValue(label: context.l10n.demoSchedule, value: '23 000 ₸ on the 1st'), LabeledValue(label: context.l10n.destination, value: 'Selected savings goal')])),
    const SizedBox(height: 18),
    PrimaryAction(label: context.l10n.notifyAvailable, onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('notify_auto_save', true); if (context.mounted) showMessage(context, context.l10n.interestSaved); }),
  ])));
}

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: EditorialHeader(title: Text(context.l10n.forYou)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    RecordGroup(color: context.colors.subtleSurface, child: Text(context.l10n.moderateSampleAdvice, style: TextStyle(fontWeight: FontWeight.w600))),
    const SizedBox(height: 12),
    _RecommendationCard(label: context.l10n.stock, title: 'Halyk Bank (HSBK)', reason: 'Medium risk, illustrative fit for a Moderate profile. Sample company context only.', source: 'Source: sample KASE data', onTap: () => _push(context, const StockDetailsScreen(stock: ('Halyk Bank', 'HSBK', 'Medium', '245,00 ₸', '+1,8%', true)))),
    const SizedBox(height: 10),
    _RecommendationCard(label: context.l10n.deposit, title: context.l10n.sampleFreedomRate, reason: 'Highest example 3-month rate among the local sample products.', source: 'Source: fictional prototype rate cards', onTap: () => _push(context, DepositRatesScreen())),
    const SizedBox(height: 10),
    _RecommendationCard(label: context.l10n.cushion, title: context.l10n.threeMonthReserve, reason: 'An educational example for unexpected expenses, based on sample records.', source: 'Source: fictional demo transactions', onTap: () => showMessage(context, context.l10n.sampleSuggestion)),
    const SizedBox(height: 12),
    Text(context.l10n.verifyAdvice, style: TextStyle(color: context.colors.muted, fontSize: 11)),
  ])));
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.label, required this.title, required this.reason, required this.source, required this.onTap});
  final String label, title, reason, source; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => RecordGroup(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: TextStyle(color: context.colors.action, fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 5), Text(reason, style: TextStyle(fontSize: 12, color: context.colors.muted)), const SizedBox(height: 6), Text(source, style: TextStyle(fontSize: 10, color: context.colors.muted)), Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onTap, child: Text(context.l10n.whyThis)))]));
}

class NoResultsScreen extends StatelessWidget {
  const NoResultsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: EditorialHeader(title: Text(context.l10n.deposits)), body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: RecordGroup(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_off, color: context.colors.muted, size: 42), const SizedBox(height: 12), Text(context.l10n.noMatchingDeposits, style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(context.l10n.filterCatalogue, textAlign: TextAlign.center, style: TextStyle(color: context.colors.muted, fontSize: 12)), const SizedBox(height: 12), PrimaryAction(label: context.l10n.resetFilters, onPressed: () => Navigator.pop(context)), TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.removeTopUp))]))))));
}

void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
