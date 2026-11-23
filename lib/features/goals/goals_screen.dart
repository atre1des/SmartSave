import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import '../advice/advice_screens.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: const Text('My Goals'),
      ),
      body: SafeArea(child: finance.isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.firefly))
        : ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(24)), child: Text('●  Free cash this month: ${formatTenge((52000 - (finance.monthlySpend - 312400)).clamp(0, 52000))}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            if (finance.goals.isEmpty) const _EmptyGoals() else for (final goal in finance.goals) ...[
              GoalCard(goal: goal, onTap: () => _push(context, GoalProgressScreen(goal: goal))),
              const SizedBox(height: 12),
            ],
            PrimaryAction(label: 'New goal', onPressed: () => _push(context, const GoalEditorScreen())),
          ])));
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap});
  final SavingsGoal goal;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SurfaceCard(padding: const EdgeInsets.all(15), onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.titleMedium)), Text('${goal.progressPercent}%', style: Theme.of(context).textTheme.titleMedium)]),
        const SizedBox(height: 9),
        ProgressTrack(value: goal.target == 0 ? 0 : goal.saved / goal.target),
        const SizedBox(height: 8),
        Text('${formatTenge(goal.saved)} / ${formatTenge(goal.target)} · ${_monthsLeft(goal.deadline)} months left', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        const Text('On track', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
      ]));
}

class GoalProgressScreen extends ConsumerWidget {
  const GoalProgressScreen({super.key, required this.goal});
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(financeControllerProvider).goals.where((item) => item.id == goal.id).firstOrNull ?? goal;
    final months = _monthsLeft(current.deadline).clamp(1, 120).toInt();
    final monthly = monthlyGoalContribution(targetTenge: current.target, savedTenge: current.saved, monthsRemaining: months);
    return Scaffold(appBar: AppBar(title: Text(current.name)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Center(child: Column(children: [Text('${current.progressPercent}%', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700)), const SizedBox(height: 12), ProgressTrack(value: current.target == 0 ? 0 : current.saved / current.target, height: 14), const SizedBox(height: 10), Text('${formatTenge(current.saved)} saved', style: const TextStyle(color: AppColors.muted))])),
      const SizedBox(height: 20),
      SurfaceCard(child: Column(children: [LabeledValue(label: 'Saved', value: formatTenge(current.saved)), const Divider(height: 1), LabeledValue(label: 'Left', value: formatTenge(current.remaining)), const Divider(height: 1), LabeledValue(label: 'Per month', value: formatTenge(monthly))])),
      const SizedBox(height: 18),
      const SectionHeading('Monthly reminder'),
      const SurfaceCard(child: Text('Every 1st · reminder only. SmartSave does not move money.', style: TextStyle(color: AppColors.muted))),
      const SizedBox(height: 18),
      const SectionHeading('Milestones'),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${current.progressPercent >= 50 ? '✓ ' : '○ '}50% reached'), const SizedBox(height: 12), Text('${current.progressPercent >= 75 ? '✓ ' : '○ '}75% · ${formatShortDate(current.deadline)}'), const SizedBox(height: 12), Text('${current.progressPercent == 100 ? '✓ ' : '○ '}Goal · ${formatShortDate(current.deadline)}')])),
      const SizedBox(height: 18),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Auto-save · coming later'), subtitle: const Text('No automatic transfers are available in this demo.'), trailing: const Icon(Icons.chevron_right), onTap: () => _push(context, const AutoSaveScreen())),
      const SizedBox(height: 10),
      PrimaryAction(label: 'Add money', onPressed: () => _contribute(context, ref, current)),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => _push(context, GoalEditorScreen(goal: current)), child: const Text('Edit goal')),
      TextButton(onPressed: () => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Delete goal?'), content: const Text('This also removes its local contribution history.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), TextButton(onPressed: () async { Navigator.pop(dialogContext); await ref.read(financeControllerProvider).deleteGoal(current.id!); if (context.mounted) Navigator.pop(context); }, child: const Text('Delete'))])), child: const Text('Delete goal', style: TextStyle(color: AppColors.wine))),
    ])));
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref, SavingsGoal goal) async {
    var input = '';
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add money to goal'),
        content: TextField(
          onChanged: (value) => input = value,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount in ₸'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(input.replaceAll(RegExp(r'[^0-9]'), ''));
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (amount == null || goal.id == null) return;
    try { await ref.read(financeControllerProvider).addContribution(goal.id!, amount); } catch (error) { if (context.mounted) showMessage(context, error.toString()); }
  }
}

class GoalEditorScreen extends ConsumerStatefulWidget {
  const GoalEditorScreen({super.key, this.goal});
  final SavingsGoal? goal;
  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.goal?.name ?? '');
  late final _target = TextEditingController(text: widget.goal == null ? '' : widget.goal!.target.toString());
  late DateTime _deadline = widget.goal?.deadline ?? DateTime(DateTime.now().year, DateTime.now().month + 4, 1);
  String _purpose = 'Purchase';

  @override
  void dispose() { _name.dispose(); _target.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final target = int.parse(_target.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final goal = SavingsGoal(id: widget.goal?.id, name: _name.text.trim(), target: target, saved: widget.goal?.saved ?? 0, deadline: _deadline, purpose: _purpose);
    try {
      await ref.read(financeControllerProvider).saveGoal(goal);
      if (mounted) Navigator.pop(context);
    } catch (error) { if (mounted) showMessage(context, error.toString()); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.goal == null ? 'New goal' : 'Edit goal')), body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(24), children: [
    TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Goal name'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter a goal name.' : null),
    const SizedBox(height: 16),
    TextFormField(controller: _target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target amount', suffixText: '₸'), validator: (value) { final amount = int.tryParse(value?.replaceAll(RegExp(r'[^0-9]'), '') ?? ''); return amount == null || amount <= 0 ? 'Enter a positive target.' : null; }),
    const SizedBox(height: 16),
    ListTile(contentPadding: EdgeInsets.zero, title: const Text('Deadline'), subtitle: Text(formatShortDate(_deadline)), trailing: const Icon(Icons.calendar_month), onTap: () async { final date = await showDatePicker(context: context, initialDate: _deadline, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650))); if (date != null) setState(() => _deadline = date); }),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: _purpose, decoration: const InputDecoration(labelText: 'Purpose'), items: const ['Purchase', 'Travel', 'Car', 'Education', 'Safety cushion'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _purpose = value ?? 'Purchase')),
    const SizedBox(height: 18),
    const SurfaceCard(color: AppColors.mintLight, child: Text('A concrete goal and deadline help estimate how much to save each month.', style: TextStyle(fontSize: 12))),
    const SizedBox(height: 22),
    PrimaryAction(label: 'Save goal', onPressed: _save),
    if (widget.goal != null) TextButton(onPressed: () => _push(context, SavingsPlanScreen(goal: widget.goal!)), child: const Text('See savings plan')),
  ]))));
}

class SavingsPlanScreen extends StatelessWidget {
  const SavingsPlanScreen({super.key, required this.goal});
  final SavingsGoal goal;
  @override
  Widget build(BuildContext context) {
    final months = _monthsLeft(goal.deadline).clamp(1, 120).toInt();
    final monthly = monthlyGoalContribution(targetTenge: goal.target, savedTenge: goal.saved, monthsRemaining: months);
    return Scaffold(appBar: AppBar(title: const Text('Savings plan')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Text(goal.name, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      SurfaceCard(child: Column(children: [LabeledValue(label: 'Target amount', value: formatTenge(goal.target)), LabeledValue(label: 'Deadline', value: formatShortDate(goal.deadline)), LabeledValue(label: 'Save every month', value: formatTenge(monthly))])),
      const SizedBox(height: 18),
      const SectionHeading('Projected savings'),
      for (var step = 0; step <= months && step < 6; step++) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(step == 0 ? 'Now' : 'Month $step'), trailing: Text(formatTenge((goal.saved + monthly * step).clamp(0, goal.target)))),
      const SurfaceCard(color: AppColors.paleGold, child: Text('Estimate only. The plan assumes a steady monthly contribution and does not move money.', style: TextStyle(fontSize: 12))),
      const SizedBox(height: 20),
      PrimaryAction(label: 'Save goal', onPressed: () => Navigator.pop(context)),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Adjust')),
    ])));
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Column(children: [Icon(Icons.flag_outlined, size: 48, color: AppColors.muted), SizedBox(height: 12), Text('No goals yet'), Text('Create a goal to start tracking progress.', style: TextStyle(color: AppColors.muted))]));
}

int _monthsLeft(DateTime deadline) { final now = DateTime.now(); return ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(0, 120); }
void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
