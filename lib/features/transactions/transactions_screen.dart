import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/finance_repository.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import '../advice/advice_screens.dart';

const transactionCategories = ['Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Other'];

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  String _category = 'All';
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeControllerProvider);
    final query = _search.text.trim().toLowerCase();
    final items = finance.transactions.where((item) => (_category == 'All' || item.category == _category) && (query.isEmpty || item.merchant.toLowerCase().contains(query) || item.note.toLowerCase().contains(query))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: SafeArea(child: finance.isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.firefly)) : ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 92), children: [
        TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search merchant or note', contentPadding: EdgeInsets.symmetric(vertical: 10))),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', ...transactionCategories]
                .map((category) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Pill(label: category, selected: _category == category, onTap: () => setState(() => _category = category)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty) const _NoTransactions() else ..._groupTransactions(items).entries.map((group) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 7, top: 4), child: Text(group.key, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600))),
          for (final item in group.value) Padding(padding: const EdgeInsets.only(bottom: 8), child: TransactionTile(item: item, onTap: () => _push(context, TransactionDetailsScreen(transaction: item)))),
        ])),
      ])),
      floatingActionButton: FloatingActionButton(onPressed: () => _push(context, const AddTransactionScreen()), backgroundColor: AppColors.gold, foregroundColor: AppColors.firefly, child: const Icon(Icons.add, size: 28)),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item, required this.onTap});
  final FinanceTransaction item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SurfaceCard(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), onTap: onTap, child: Row(children: [
        const CircleAvatar(radius: 16, backgroundColor: AppColors.mintLight, child: Icon(Icons.receipt_long_outlined, size: 17, color: AppColors.muted)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.merchant, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), Text('${item.category} · ${_time(item.occurredAt)}', style: const TextStyle(fontSize: 11, color: AppColors.muted))])),
        Text(formatSignedTenge(item.amount, income: item.isIncome), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: item.isIncome ? AppColors.success : AppColors.firefly)),
      ]));
}

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({super.key, required this.transaction});
  final FinanceTransaction transaction;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Transaction'), actions: [IconButton(tooltip: 'Delete transaction', onPressed: () async { await ref.read(financeControllerProvider).deleteTransaction(transaction.id!); if (context.mounted) Navigator.pop(context); }, icon: const Icon(Icons.delete_outline))]), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    Text(formatSignedTenge(transaction.amount, income: transaction.isIncome), textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4), Text(transaction.merchant, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6), Text('${formatShortDate(transaction.occurredAt)} · ${_time(transaction.occurredAt)} · local demo', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    const SizedBox(height: 24),
    SurfaceCard(child: Column(children: [LabeledValue(label: 'Category', value: transaction.category), const Divider(height: 1), LabeledValue(label: 'Date', value: formatShortDate(transaction.occurredAt)), const Divider(height: 1), LabeledValue(label: 'Source', value: transaction.source), const Divider(height: 1), LabeledValue(label: 'Note', value: transaction.note.isEmpty ? 'Add a note' : transaction.note)])),
    const SizedBox(height: 14),
    const SurfaceCard(color: AppColors.mintLight, child: Text('Changes to this local demo transaction update spending analytics and budgets automatically.', style: TextStyle(fontSize: 12))),
    const SizedBox(height: 22),
    PrimaryAction(label: 'Edit transaction', onPressed: () => _push(context, AddTransactionScreen(transaction: transaction))),
  ])));
}

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});
  final FinanceTransaction? transaction;
  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.transaction?.amount.toString() ?? '');
  late final _merchant = TextEditingController(text: widget.transaction?.merchant ?? '');
  late final _note = TextEditingController(text: widget.transaction?.note ?? '');
  late bool _income = widget.transaction?.isIncome ?? false;
  late String _category = widget.transaction?.category ?? 'Food';
  late DateTime _date = widget.transaction?.occurredAt ?? DateTime.now();
  @override
  void dispose() { _amount.dispose(); _merchant.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.parse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    try {
      await ref.read(financeControllerProvider).saveTransaction(FinanceTransaction(id: widget.transaction?.id, amount: amount, isIncome: _income, category: _income ? 'Income' : _category, merchant: _merchant.text.trim(), occurredAt: _date, note: _note.text.trim()));
      if (mounted) Navigator.pop(context);
    } catch (error) { if (mounted) showMessage(context, error.toString()); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.transaction == null ? 'Add transaction' : 'Edit transaction')), body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(24), children: [
    SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Expense')), ButtonSegment(value: true, label: Text('Income'))], selected: {_income}, onSelectionChanged: (value) => setState(() => _income = value.first)),
    const SizedBox(height: 18),
    TextFormField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', suffixText: '₸'), validator: (value) { final amount = int.tryParse(value?.replaceAll(RegExp(r'[^0-9]'), '') ?? ''); return amount == null || amount <= 0 ? 'Enter an amount greater than zero.' : null; }),
    const SizedBox(height: 14),
    TextFormField(controller: _merchant, decoration: const InputDecoration(labelText: 'Merchant or description'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter a description.' : null),
    const SizedBox(height: 14),
    if (!_income) DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Category'), items: transactionCategories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _category = value ?? 'Food')),
    const SizedBox(height: 8),
    ListTile(contentPadding: EdgeInsets.zero, title: const Text('Date'), subtitle: Text(formatShortDate(_date)), trailing: const Icon(Icons.calendar_today), onTap: () async { final date = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1))); if (date != null) setState(() => _date = date); }),
    TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
    const SizedBox(height: 22),
    PrimaryAction(label: 'Save', onPressed: _save),
  ]))));
}

class SpendingAnalyticsScreen extends ConsumerWidget {
  const SpendingAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    final data = Map<String, int>.from(finance.spending);
    if (data.containsKey('Health')) { data['Other'] = (data['Other'] ?? 0) + data.remove('Health')!; }
    final total = data.values.fold<int>(0, (sum, value) => sum + value);
    final colors = [AppColors.firefly, AppColors.gold, AppColors.mint, AppColors.prussianBlue, AppColors.lime];
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(appBar: AppBar(title: const Text('Spending')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(onPressed: () => showMessage(context, 'Showing recorded transactions for the current month.'), icon: const Icon(Icons.chevron_left)), Text('${_monthName(DateTime.now().month)} ${DateTime.now().year}', style: Theme.of(context).textTheme.titleMedium), IconButton(onPressed: () => showMessage(context, 'No future transactions yet.'), icon: const Icon(Icons.chevron_right))]),
      const SizedBox(height: 10),
      Center(child: SizedBox(width: 190, height: 190, child: CustomPaint(painter: _DonutPainter(values: sorted.map((e) => e.value).toList(), colors: colors), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(formatTenge(total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const Text('spent', style: TextStyle(fontSize: 11, color: AppColors.muted))]))))),
      const SizedBox(height: 20),
      for (var i = 0; i < sorted.length; i++) _AnalyticsCategoryRow(entry: sorted[i], color: colors[i % colors.length], percent: total == 0 ? 0 : sorted[i].value * 100 ~/ total, onTap: () => _push(context, CategoryDetailsScreen(category: sorted[i].key))),
      const SizedBox(height: 18),
      SectionHeading('Compared with ${_monthName(DateTime(DateTime.now().year, DateTime.now().month - 1).month)}'),
      FutureBuilder<Map<String, int>>(
        future: ref.read(financeRepositoryProvider).spendingChangePercent(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Could not load the spending comparison.');
          }
          if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(color: AppColors.mint));
          return Column(children: [
            for (final category in ['Food', 'Shopping', 'Transport'])
              if (snapshot.data!.containsKey(category))
                _ComparisonLine(label: category, value: '${snapshot.data![category]! > 0 ? '+' : snapshot.data![category]! < 0 ? '−' : ''}${snapshot.data![category]!.abs()}%', isUp: snapshot.data![category]! > 0)
              else
                ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(category), trailing: const Text('—', style: TextStyle(color: AppColors.muted))),
          ]);
        },
      ),
      const SizedBox(height: 14),
      SurfaceCard(color: AppColors.paleRose, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Food budget', style: TextStyle(color: AppColors.wine, fontWeight: FontWeight.w600)), Text('${formatTenge(finance.spending['Food'] ?? 0)} spent of ${formatTenge(finance.budgetLimits['Food'] ?? 0)}', style: const TextStyle(fontSize: 12)), TextButton(onPressed: () => _editBudget(context, ref, finance.budgetLimits['Food'] ?? 95000), child: const Text('Edit monthly budget')), TextButton(onPressed: () => _push(context, const WhereToCutScreen()), child: const Text('Where to cut'))])),
    ])));
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref, int current) async {
    final controller = TextEditingController(text: current.toString());
    final value = await showDialog<int>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Food monthly budget'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: '₸')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { final amount = int.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')); if (amount == null) return; Navigator.pop(dialogContext, amount); }, child: const Text('Save'))]));
    controller.dispose();
    if (value != null) await ref.read(financeControllerProvider).saveBudget('Food', value);
  }
}

class _AnalyticsCategoryRow extends StatelessWidget {
  const _AnalyticsCategoryRow({required this.entry, required this.color, required this.percent, required this.onTap});
  final MapEntry<String, int> entry;
  final Color color;
  final int percent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))), Text(formatTenge(entry.value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(width: 12), SizedBox(width: 42, child: Text('$percent%', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, fontSize: 12)))])));
}

class CategoryDetailsScreen extends ConsumerWidget {
  const CategoryDetailsScreen({super.key, this.category = 'Food'});
  final String category;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    final amount = finance.spending[category] ?? 0;
    final budget = finance.budgetLimits[category] ?? 0;
    final transactions = finance.transactions.where((t) => t.category == category && !t.isIncome).take(3).toList();
    return Scaffold(appBar: AppBar(title: Text(category)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('This month', style: TextStyle(color: AppColors.muted)), const SizedBox(height: 5), Text(formatTenge(amount), style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 15),
      SurfaceCard(color: amount > budget ? AppColors.paleRose : AppColors.mintLight, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Monthly budget ${formatTenge(budget)}', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), ProgressTrack(value: budget == 0 ? 0 : amount / budget, color: amount > budget ? AppColors.wine : AppColors.mint), const SizedBox(height: 8), Text(amount > budget ? '${formatTenge(amount - budget)} over' : '${formatTenge(budget - amount)} left'), TextButton(onPressed: () => _editBudget(context, ref, budget), child: const Text('Edit budget'))])),
      const SizedBox(height: 20), const SectionHeading('Top spends'),
      for (final item in transactions) ListTile(contentPadding: EdgeInsets.zero, title: Text(item.merchant), trailing: Text(formatTenge(item.amount))),
      const SurfaceCard(color: AppColors.paleGold, child: Text('Recurring-spend examples are sample insights, not a bank-import analysis.', style: TextStyle(fontSize: 12))),
      TextButton.icon(onPressed: () => _push(context, const WhereToCutScreen()), icon: const Icon(Icons.lightbulb_outline), label: const Text('Where to cut')),
    ])));
  }
  Future<void> _editBudget(BuildContext context, WidgetRef ref, int current) async {
    final controller = TextEditingController(text: current.toString());
    final value = await showDialog<int>(context: context, builder: (dialogContext) => AlertDialog(title: Text('$category monthly budget'), content: TextField(controller: controller, keyboardType: TextInputType.number), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { final number = int.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')); if (number != null) Navigator.pop(dialogContext, number); }, child: const Text('Save'))]));
    controller.dispose();
    if (value != null) await ref.read(financeControllerProvider).saveBudget(category, value);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(rect.deflate(4), start, sweep, false, Paint()..color = colors[i % colors.length]..style = PaintingStyle.stroke..strokeWidth = 30);
      start += sweep + .018;
    }
  }
  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values;
}

class _ComparisonLine extends StatelessWidget {
  const _ComparisonLine({required this.label, required this.value, required this.isUp});
  final String label; final String value; final bool isUp;
  @override
  Widget build(BuildContext context) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(label, style: const TextStyle(fontSize: 13)), trailing: Container(width: 76, padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: isUp ? AppColors.paleRose : AppColors.mintLight, borderRadius: BorderRadius.circular(16)), child: Text(value, textAlign: TextAlign.center, style: TextStyle(color: isUp ? AppColors.wine : AppColors.firefly, fontWeight: FontWeight.w600, fontSize: 12))));
}

class _NoTransactions extends StatelessWidget {
  const _NoTransactions();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 70), child: Column(children: [Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.muted), SizedBox(height: 12), Text('No transactions found'), Text('Try another search or add a transaction.', style: TextStyle(color: AppColors.muted))]));
}

Map<String, List<FinanceTransaction>> _groupTransactions(List<FinanceTransaction> items) {
  final groups = <String, List<FinanceTransaction>>{};
  final now = DateTime.now();
  for (final item in items) {
    final date = item.occurredAt;
    final label = date.year == now.year && date.month == now.month && date.day == now.day ? 'Today' : date.year == now.year && date.month == now.month && date.day == now.day - 1 ? 'Yesterday' : formatShortDate(date);
    groups.putIfAbsent(label, () => []).add(item);
  }
  return groups;
}

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _monthName(int month) => const ['January','February','March','April','May','June','July','August','September','October','November','December'][month - 1];
void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
