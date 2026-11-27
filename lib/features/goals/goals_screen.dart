import '../../l10n/app_locale.dart';

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
      appBar: EditorialHeader(
        leading: BackButton(),
        title: Text(context.l10n.myGoals),
      ),
      body: SafeArea(child: finance.isLoading
        ? Center(child: CircularProgressIndicator(color: context.colors.text))
        : ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: context.colors.subtleSurface, borderRadius: BorderRadius.circular(24)), child: Text('●  ${context.l10n.monthlyFreeCash(context.formatTenge((52000 - (finance.monthlySpend - 312400)).clamp(0, 52000)))}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            if (finance.goals.isEmpty) const _EmptyGoals() else for (final goal in finance.goals) ...[
              GoalCard(goal: goal, onTap: () => _push(context, GoalProgressScreen(goal: goal))),
              const SizedBox(height: 12),
            ],
            PrimaryAction(label: context.l10n.newGoal, onPressed: () => _push(context, const GoalEditorScreen())),
          ])));
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap});
  final SavingsGoal goal;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => RecordGroup(
    color: context.colors.accentSurface(
      goal.progressPercent >= 100 ? context.colors.premium : context.colors.highlight,
    ),
    padding: const EdgeInsets.all(15), onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.titleMedium)), Text(context.formatPercent(goal.progressPercent), style: Theme.of(context).textTheme.titleMedium)]),
        const SizedBox(height: 9),
        ProgressTrack(
          value: goal.target == 0 ? 0 : goal.saved / goal.target,
          color: goal.progressPercent >= 100 ? context.colors.premium : context.colors.positive,
        ),
        const SizedBox(height: 8),
        Text('${context.formatTenge(goal.saved)} / ${context.formatTenge(goal.target)} · ${context.l10n.monthsLeft(_monthsLeft(goal.deadline))}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(context.l10n.onTrack, style: TextStyle(color: context.colors.positive, fontSize: 11, fontWeight: FontWeight.w600)),
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
    return Scaffold(appBar: EditorialHeader(title: Text(current.name)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      FinancialFigure(
        context.formatPercent(current.progressPercent),
        label: context.l10n.amountSaved(context.formatTenge(current.saved)),
      ),
      const SizedBox(height: 12),
      ProgressTrack(value: current.target == 0 ? 0 : current.saved / current.target, height: 8),
      const SizedBox(height: 20),
      RecordGroup(child: Column(children: [LabeledValue(label: context.l10n.saved, value: context.formatTenge(current.saved)), const Divider(height: 1), LabeledValue(label: context.l10n.left, value: context.formatTenge(current.remaining)), const Divider(height: 1), LabeledValue(label: context.l10n.perMonth, value: context.formatTenge(monthly))])),
      const SizedBox(height: 18),
      SectionHeading(context.l10n.monthlyReminder),
      RecordGroup(child: Text(context.l10n.reminderFirst, style: TextStyle(color: context.colors.muted))),
      const SizedBox(height: 18),
      SectionHeading(context.l10n.milestones),
      RecordGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${current.progressPercent >= 50 ? '✓ ' : '○ '}50% reached'), const SizedBox(height: 12), Text('${current.progressPercent >= 75 ? '✓ ' : '○ '}75% · ${context.formatShortDate(current.deadline)}'), const SizedBox(height: 12), Text('${current.progressPercent == 100 ? '✓ ' : '○ '}Goal · ${context.formatShortDate(current.deadline)}')])),
      const SizedBox(height: 18),
      ListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.autoSaveLater), subtitle: Text(context.l10n.noTransfers), trailing: const Icon(Icons.chevron_right), onTap: () => _push(context, const AutoSaveScreen())),
      const SizedBox(height: 10),
      PrimaryAction(label: context.l10n.addMoney, onPressed: () => _contribute(context, ref, current)),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => _push(context, GoalEditorScreen(goal: current)), child: Text(context.l10n.editGoal)),
      TextButton(onPressed: () => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(context.l10n.deleteGoalQuestion), content: Text(context.l10n.deleteGoalNotice), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.l10n.cancel)), TextButton(onPressed: () async { Navigator.pop(dialogContext); await ref.read(financeControllerProvider).deleteGoal(current.id!); if (context.mounted) Navigator.pop(context); }, child: Text(context.l10n.delete))])), child: Text(context.l10n.deleteGoal, style: TextStyle(color: context.colors.error))),
    ])));
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref, SavingsGoal goal) async {
    var input = '';
    final amount = await showEditorSheet<int>(
      context: context,
      builder: (dialogContext) => EditorSheet(
        title: Text(context.l10n.addMoneyGoal),
        content: TextField(
          onChanged: (value) => input = value,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.l10n.amountTenge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(input.replaceAll(RegExp(r'[^0-9]'), ''));
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: Text(context.l10n.save),
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
  Widget build(BuildContext context) => Scaffold(appBar: EditorialHeader(title: Text(widget.goal == null ? context.l10n.newGoal : context.l10n.editGoal)), body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(24), children: [
    TextFormField(controller: _name, decoration: InputDecoration(labelText: context.l10n.goalName), validator: (value) => value == null || value.trim().isEmpty ? 'Enter a goal name.' : null),
    const SizedBox(height: 16),
    TextFormField(controller: _target, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.l10n.target, suffixText: '₸'), validator: (value) { final amount = int.tryParse(value?.replaceAll(RegExp(r'[^0-9]'), '') ?? ''); return amount == null || amount <= 0 ? 'Enter a positive target.' : null; }),
    const SizedBox(height: 16),
    ListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.deadline), subtitle: Text(context.formatShortDate(_deadline)), trailing: const Icon(Icons.calendar_month), onTap: () async { final date = await showDatePicker(context: context, initialDate: _deadline, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650))); if (date != null) setState(() => _deadline = date); }),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: _purpose, decoration: InputDecoration(labelText: context.l10n.purpose), items: const ['Purchase', 'Travel', 'Car', 'Education', 'Safety cushion'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _purpose = value ?? 'Purchase')),
    const SizedBox(height: 18),
    RecordGroup(color: context.colors.subtleSurface, child: Text(context.l10n.goalDeadlineExplainer, style: TextStyle(fontSize: 12))),
    const SizedBox(height: 22),
    PrimaryAction(label: context.l10n.saveGoal, onPressed: _save),
    if (widget.goal != null) TextButton(onPressed: () => _push(context, SavingsPlanScreen(goal: widget.goal!)), child: Text(context.l10n.savingsPlanLink)),
  ]))));
}

class SavingsPlanScreen extends StatelessWidget {
  const SavingsPlanScreen({super.key, required this.goal});
  final SavingsGoal goal;
  @override
  Widget build(BuildContext context) {
    final months = _monthsLeft(goal.deadline).clamp(1, 120).toInt();
    final monthly = monthlyGoalContribution(targetTenge: goal.target, savedTenge: goal.saved, monthsRemaining: months);
    return Scaffold(appBar: EditorialHeader(title: Text(context.l10n.savingsPlan)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Text(goal.name, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      RecordGroup(child: Column(children: [LabeledValue(label: context.l10n.target, value: context.formatTenge(goal.target)), LabeledValue(label: context.l10n.deadline, value: context.formatShortDate(goal.deadline)), LabeledValue(label: context.l10n.saveEveryMonth, value: context.formatTenge(monthly))])),
      const SizedBox(height: 18),
      SectionHeading(context.l10n.projectedSavings),
      for (var step = 0; step <= months && step < 6; step++) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(step == 0 ? context.l10n.now : context.l10n.goalMonth(step)), trailing: Text(context.formatTenge((goal.saved + monthly * step).clamp(0, goal.target)))),
      RecordGroup(color: context.colors.noticeSurface, child: Text(context.l10n.goalEstimateExplainer, style: TextStyle(fontSize: 12))),
      const SizedBox(height: 20),
      PrimaryAction(label: context.l10n.saveGoal, onPressed: () => Navigator.pop(context)),
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.adjust)),
    ])));
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Column(children: [Icon(Icons.flag_outlined, size: 48, color: context.colors.muted), SizedBox(height: 12), Text(context.l10n.noGoals), Text(context.l10n.createGoalProgress, style: TextStyle(color: context.colors.muted))]));
}

int _monthsLeft(DateTime deadline) { final now = DateTime.now(); return ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(0, 120); }
void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
