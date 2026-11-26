import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/finance_repository.dart';
import '../../data/investment_analysis.dart';
import '../../data/investment_models.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';

class InvestmentIntelligenceScreen extends StatelessWidget {
  const InvestmentIntelligenceScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    initialIndex: initialTab,
    length: 4,
    child: Scaffold(
      appBar: EditorialHeader(
        title: Text(context.l10n.investmentIntelligence),
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: context.l10n.aiBeginners),
            Tab(text: context.l10n.thesisAutopsyTab),
            Tab(text: context.l10n.liquidity),
            Tab(text: context.l10n.economicRippleTab),
          ],
        ),
      ),
      body: const SafeArea(
        child: TabBarView(
          children: [_AIBeginnerTab(), _ThesisTab(), _LiquidityTab(), _RippleTab()],
        ),
      ),
    ),
  );
}

class _AIBeginnerTab extends ConsumerWidget {
  const _AIBeginnerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Text(
        context.l10n.learnInvest,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 5),
      Text(
        context.l10n.noLiveEducation,
        style: TextStyle(color: context.colors.muted, fontSize: 11),
      ),
      const SizedBox(height: 16),

      // Topic cards
      _TopicCard(
        icon: Icons.savings_outlined,
        title: context.l10n.depositVsInvest,
        description: context.l10n.depositLessonDescription,
        onTap: () => _showLesson(context, 'deposits_vs_investments'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.flag_outlined,
        title: context.l10n.settingGoals,
        description: context.l10n.goalLessonDescription,
        onTap: () => _showLesson(context, 'savings_goals'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.pie_chart_outline,
        title: context.l10n.diversification,
        description: context.l10n.diversificationDescription,
        onTap: () => _showLesson(context, 'diversification'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.shield_outlined,
        title: context.l10n.riskAndProfile,
        description: context.l10n.riskLessonDescription,
        onTap: () => _showLesson(context, 'risk_profile'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.trending_up,
        title: context.l10n.compoundGrowth,
        description: context.l10n.growthLessonDescription,
        onTap: () => _showLesson(context, 'compound_growth'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.lightbulb_outline,
        title: context.l10n.beginnerMistakes,
        description: context.l10n.mistakesLessonDescription,
        onTap: () => _showLesson(context, 'beginner_mistakes'),
      ),
      const SizedBox(height: 20),

      // Open AI Assistant
      RecordGroup(
        color: context.colors.emphasis,
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const _AIAssistantScreenRoute()),
          );
        },
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: context.colors.progress, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.askAi,
                    style: TextStyle(
                      color: context.colors.onEmphasis,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    context.l10n.openAiForGuidance,
                    style: TextStyle(color: context.colors.onEmphasis, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.onEmphasis),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.educationRisk,
        style: TextStyle(color: context.colors.muted, fontSize: 11),
      ),
    ],
  );
}

void _showLesson(BuildContext context, String lessonId) {
  final strings = context.l10n;
  final lesson = switch (lessonId) {
    'deposits_vs_investments' => (strings.depositVsInvest, strings.lessonDepositsBody),
    'savings_goals' => (strings.settingGoals, strings.lessonGoalsBody),
    'diversification' => (strings.diversification, strings.lessonDiversificationBody),
    'risk_profile' => (strings.riskAndProfile, strings.lessonRiskBody),
    'compound_growth' => (strings.compoundGrowth, strings.lessonGrowthBody),
    'beginner_mistakes' => (strings.beginnerMistakes, strings.lessonMistakesBody),
    _ => null,
  };
  if (lesson == null) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.$1, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(lesson.$2, style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            PrimaryAction(
              label: context.l10n.gotIt,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RecordGroup(
    onTap: onTap,
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.subtleSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.colors.text, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: context.colors.muted, fontSize: 12)),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: context.colors.muted),
      ],
    ),
  );
}

class _AIAssistantScreenRoute extends StatelessWidget {
  const _AIAssistantScreenRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('AI Assistant - to be implemented')),
    );
  }
}

class _ThesisOverview {
  const _ThesisOverview({
    required this.theses,
    required this.attentionCount,
    required this.changedCount,
    required this.latestAssessment,
  });
  final List<InvestmentThesis> theses;
  final int attentionCount;
  final int changedCount;
  final DateTime? latestAssessment;
}

class _ThesisTab extends ConsumerStatefulWidget {
  const _ThesisTab();
  @override
  ConsumerState<_ThesisTab> createState() => _ThesisTabState();
}

class _ThesisTabState extends ConsumerState<_ThesisTab> {
  late Future<_ThesisOverview> _theses;
  FinanceRepository get _repository => ref.read(financeRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _theses = _loadOverview();
  }

  Future<_ThesisOverview> _loadOverview() async {
    final theses = await _repository.investmentTheses();
    var attentionCount = 0;
    var changedCount = 0;
    DateTime? latestAssessment;
    for (final thesis in theses) {
      final conditions = await _repository.thesisConditions(thesis.id!);
      final history = await _repository.thesisAssessments(thesis.id!);
      if (history.isNotEmpty &&
          (latestAssessment == null ||
              history.first.assessedAt.isAfter(latestAssessment))) {
        latestAssessment = history.first.assessedAt;
      }
      final latest = history.isEmpty ? null : history.first;
      if (latest == null) {
        attentionCount += conditions.length;
      } else {
        attentionCount += latest.conditions
            .where((item) => item.status != EvidenceStatus.supported)
            .length;
        if (history.length > 1) {
          final previous = {
            for (final item in history[1].conditions)
              item.conditionId: item.status,
          };
          changedCount += latest.conditions
              .where(
                (item) =>
                    previous.containsKey(item.conditionId) &&
                    previous[item.conditionId] != item.status,
              )
              .length;
        }
      }
      attentionCount += conditions
          .where(
            (condition) =>
                condition.source.isEmpty ||
                condition.reportingPeriod.isEmpty ||
                (condition.isNumeric && condition.observedValue == null),
          )
          .length;
    }
    return _ThesisOverview(
      theses: theses,
      attentionCount: attentionCount,
      changedCount: changedCount,
      latestAssessment: latestAssessment,
    );
  }

  void _refresh() {
    final next = _loadOverview();
    setState(() {
      _theses = next;
    });
  }

  Future<void> _createThesis() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const _ThesisFormScreen()),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ThesisOverview>(
    future: _theses,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _errorState(context, 'Could not load saved theses.');
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final overview = snapshot.data!;
      final theses = overview.theses;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const _SourceBanner(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: context.l10n.activeTheses,
                  value: '${theses.length}',
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: context.l10n.conditionsAttention,
                  value: '${overview.attentionCount}',
                  icon: Icons.fact_check_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            overview.latestAssessment == null
                ? context.l10n.latestAssessmentNone
                : 'Latest assessment: ${overview.latestAssessment!.toLocal()} · ${overview.changedCount} recent condition change(s)',
            style: TextStyle(color: context.colors.muted, fontSize: 10),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              SectionHeading(context.l10n.yourTheses),
              TextButton.icon(
                onPressed: _createThesis,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.newThesis),
              ),
            ],
          ),
          if (theses.isEmpty)
            RecordGroup(
              color: context.colors.subtleSurface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.thesisIntro,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.thesisEvidence,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  PrimaryAction(
                    label: context.l10n.createFirstThesis,
                    onPressed: _createThesis,
                  ),
                ],
              ),
            )
          else
            for (final thesis in theses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RecordGroup(
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ThesisDetailScreen(thesis: thesis),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: context.colors.subtleSurface,
                        child: Text(
                          thesis.ticker.substring(
                            0,
                            thesis.ticker.length > 3 ? 3 : thesis.ticker.length,
                          ),
                          style: TextStyle(
                            color: context.colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              thesis.securityName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${thesis.ticker} · ${thesis.exchange} · ${thesis.horizon.isEmpty ? 'Horizon not set' : thesis.horizon}',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              thesis.rationale.isEmpty
                                  ? context.l10n.noThesisRationale
                                  : thesis.rationale,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: context.colors.muted),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            context.l10n.thesisLocalOnly,
            style: TextStyle(color: context.colors.muted, fontSize: 11),
          ),
        ],
      );
    },
  );
}

class _SourceBanner extends StatelessWidget {
  const _SourceBanner();
  @override
  Widget build(BuildContext context) => RecordGroup(
    color: context.colors.emphasis,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: context.colors.progress, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.kzMarketUnconnected,
                style: TextStyle(
                  color: context.colors.onEmphasis,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                context.l10n.evidenceUserProvided,
                style: TextStyle(color: context.colors.onEmphasis, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => RecordGroup(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(icon, color: context.colors.text, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                label,
                style: TextStyle(color: context.colors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ThesisFormScreen extends ConsumerStatefulWidget {
  const _ThesisFormScreen({this.thesis});
  final InvestmentThesis? thesis;
  @override
  ConsumerState<_ThesisFormScreen> createState() => _ThesisFormScreenState();
}

class _ThesisFormScreenState extends ConsumerState<_ThesisFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.thesis?.securityName);
  late final _ticker = TextEditingController(text: widget.thesis?.ticker);
  late final _exchange = TextEditingController(
    text: widget.thesis?.exchange ?? 'KASE',
  );
  late final _identifier = TextEditingController(
    text: widget.thesis?.identifier,
  );
  late final _rationale = TextEditingController(text: widget.thesis?.rationale);
  late final _horizon = TextEditingController(text: widget.thesis?.horizon);
  late final _assumptions = TextEditingController(
    text: widget.thesis?.assumptions,
  );
  late final _risks = TextEditingController(text: widget.thesis?.risks);
  late final _invalidation = TextEditingController(
    text: widget.thesis?.invalidationConditions,
  );
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _ticker,
      _exchange,
      _identifier,
      _rationale,
      _horizon,
      _assumptions,
      _risks,
      _invalidation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    await ref
        .read(financeRepositoryProvider)
        .saveInvestmentThesis(
          InvestmentThesis(
            id: widget.thesis?.id,
            securityName: _name.text.trim(),
            ticker: _ticker.text.trim().toUpperCase(),
            exchange: _exchange.text.trim().isEmpty
                ? 'KASE'
                : _exchange.text.trim().toUpperCase(),
            identifier: _identifier.text.trim(),
            rationale: _rationale.text.trim(),
            horizon: _horizon.text.trim(),
            assumptions: _assumptions.text.trim(),
            risks: _risks.text.trim(),
            invalidationConditions: _invalidation.text.trim(),
            createdAt: widget.thesis?.createdAt ?? now,
            updatedAt: now,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EditorialHeader(
      title: Text(
        widget.thesis == null ? context.l10n.newInvestmentThesis : context.l10n.editThesis,
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.l10n.captureThesis,
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: context.l10n.securityName),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Add a security name.'
                  : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ticker,
                    decoration: InputDecoration(labelText: context.l10n.ticker),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required.'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _exchange,
                    decoration: InputDecoration(labelText: context.l10n.exchange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _identifier,
              decoration: InputDecoration(
                labelText: context.l10n.isinOptional,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _rationale,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.whyInterested,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _horizon,
              decoration: InputDecoration(
                labelText: context.l10n.horizonOptional,
                hintText: context.l10n.horizonExample,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _assumptions,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.supportingEvidence,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _risks,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.principalRisks,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _invalidation,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.invalidateThesis,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryAction(
              label: widget.thesis == null ? context.l10n.saveThesis : context.l10n.updateThesis,
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThesisDetailScreen extends ConsumerStatefulWidget {
  const _ThesisDetailScreen({required this.thesis});
  final InvestmentThesis thesis;
  @override
  ConsumerState<_ThesisDetailScreen> createState() =>
      _ThesisDetailScreenState();
}

class _ThesisDetailScreenState extends ConsumerState<_ThesisDetailScreen> {
  late Future<(List<ThesisCondition>, List<ThesisAssessment>)> _detail;
  FinanceRepository get _repository => ref.read(financeRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _detail = _load();
  }

  Future<(List<ThesisCondition>, List<ThesisAssessment>)> _load() async => (
    await _repository.thesisConditions(widget.thesis.id!),
    await _repository.thesisAssessments(widget.thesis.id!),
  );

  void _refresh() {
    final next = _load();
    setState(() {
      _detail = next;
    });
  }

  Future<void> _addCondition() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ConditionFormScreen(thesisId: widget.thesis.id!),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _editCondition(ThesisCondition condition) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ConditionFormScreen(
          thesisId: widget.thesis.id!,
          condition: condition,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _assess(List<ThesisCondition> conditions) async {
    final assessment = analyzeThesis(widget.thesis, conditions);
    await _repository.saveThesisAssessment(assessment);
    if (mounted) {
      _refresh();
      showMessage(context, 'Assessment saved to history.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EditorialHeader(
      title: Text(widget.thesis.ticker),
      actions: [
        IconButton(
          tooltip: context.l10n.editThesis,
          onPressed: () async {
            final navigator = Navigator.of(context);
            await navigator.push<void>(
              MaterialPageRoute(
                builder: (_) => _ThesisFormScreen(thesis: widget.thesis),
              ),
            );
            if (mounted) navigator.pop();
          },
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<(List<ThesisCondition>, List<ThesisAssessment>)>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _errorState(context, 'Could not load this thesis.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conditions = snapshot.data!.$1;
          final history = snapshot.data!.$2;
          final latest = history.isEmpty ? null : history.first;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                widget.thesis.securityName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${widget.thesis.ticker} · ${widget.thesis.exchange}${widget.thesis.identifier.isEmpty ? '' : ' · ${widget.thesis.identifier}'}',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _textCard(context, 'Your rationale', widget.thesis.rationale),
              _textCard(context, 'Horizon', widget.thesis.horizon),
              _textCard(context, 'Assumptions', widget.thesis.assumptions),
              _textCard(context, 'Recognized risks', widget.thesis.risks),
              _textCard(context, 'Reconsider if', widget.thesis.invalidationConditions),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionHeading(context.l10n.testableConditions),
                  TextButton.icon(
                    onPressed: _addCondition,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.add),
                  ),
                ],
              ),
              if (conditions.isEmpty)
                RecordGroup(
                  child: Text(
                    context.l10n.noConditions,
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                )
              else
                for (final condition in conditions)
                  _ConditionCard(
                    condition: condition,
                    onTap: () => _editCondition(condition),
                    assessment: latest?.conditions
                        .where((item) => item.conditionId == condition.id)
                        .firstOrNull,
                  ),
              const SizedBox(height: 12),
              PrimaryAction(
                label: context.l10n.assessEvidence,
                onPressed: () => _assess(conditions),
              ),
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.evidenceLocalRules,
                  style: TextStyle(color: context.colors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 18),
              SectionHeading(context.l10n.bearCase),
              if (latest == null)
                RecordGroup(
                  child: Text(
                    context.l10n.runAssessment,
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                )
              else
                _AssessmentCard(assessment: latest),
              const SizedBox(height: 16),
              SectionHeading(context.l10n.assessmentHistory),
              if (history.isEmpty)
                Text(
                  context.l10n.noAssessments,
                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                )
              else
                for (final assessment in history)
                  _HistoryCard(
                    assessment: assessment,
                    previous: history.length > history.indexOf(assessment) + 1
                        ? history[history.indexOf(assessment) + 1]
                        : null,
                  ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await _repository.deleteInvestmentThesis(widget.thesis.id!);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.deleteThesis),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ConditionFormScreen extends ConsumerStatefulWidget {
  const _ConditionFormScreen({required this.thesisId, this.condition});
  final int thesisId;
  final ThesisCondition? condition;
  @override
  ConsumerState<_ConditionFormScreen> createState() =>
      _ConditionFormScreenState();
}

class _ConditionFormScreenState extends ConsumerState<_ConditionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(
    text: widget.condition?.description,
  );
  late final _metric = TextEditingController(text: widget.condition?.metric);
  late final _threshold = TextEditingController(
    text: widget.condition?.threshold?.toString(),
  );
  late final _observed = TextEditingController(
    text: widget.condition?.observedValue?.toString(),
  );
  late final _period = TextEditingController(
    text: widget.condition?.reportingPeriod,
  );
  late final _source = TextEditingController(text: widget.condition?.source);
  late final _note = TextEditingController(
    text: widget.condition?.evidenceNote,
  );
  late ConditionComparator _comparator =
      widget.condition?.comparator ?? ConditionComparator.atLeast;

  @override
  void dispose() {
    for (final c in [
      _description,
      _metric,
      _threshold,
      _observed,
      _period,
      _source,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(financeRepositoryProvider)
        .saveThesisCondition(
          ThesisCondition(
            id: widget.condition?.id,
            thesisId: widget.thesisId,
            description: _description.text.trim(),
            metric: _metric.text.trim(),
            comparator: _comparator,
            threshold: double.tryParse(_threshold.text.trim()),
            observedValue: double.tryParse(_observed.text.trim()),
            reportingPeriod: _period.text.trim(),
            source: _source.text.trim(),
            evidenceNote: _note.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EditorialHeader(
      title: Text(
        widget.condition == null ? context.l10n.addCondition : context.l10n.editCondition,
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _description,
            decoration: InputDecoration(
              labelText: context.l10n.condition,
              hintText: context.l10n.positiveCashFlow,
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Describe the condition.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _metric,
            decoration: InputDecoration(
              labelText: context.l10n.metric,
              hintText: context.l10n.operatingCashFlow,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ConditionComparator>(
                  initialValue: _comparator,
                  decoration: InputDecoration(
                    labelText: context.l10n.expectedCondition,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ConditionComparator.atLeast,
                      child: Text(context.l10n.atLeast),
                    ),
                    DropdownMenuItem(
                      value: ConditionComparator.atMost,
                      child: Text(context.l10n.atMost),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _comparator = value ?? ConditionComparator.atLeast,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _threshold,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.threshold,
                    hintText: context.l10n.qualitativeIfBlank,
                  ),
                  validator: (v) =>
                      v != null &&
                          v.trim().isNotEmpty &&
                          double.tryParse(v.trim()) == null
                      ? 'Enter a number.'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _observed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.observedValue,
              helperText: context.l10n.numericEvidenceRequirement,
            ),
            validator: (v) =>
                v != null &&
                    v.trim().isNotEmpty &&
                    double.tryParse(v.trim()) == null
                ? 'Enter a number.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _period,
            decoration: InputDecoration(
              labelText: context.l10n.observationPeriod,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _source,
            decoration: InputDecoration(
              labelText: context.l10n.evidenceSource,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: context.l10n.evidenceNote),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.qualitativeDisclaimer,
            style: TextStyle(color: context.colors.muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          PrimaryAction(
            label: widget.condition == null
                ? context.l10n.saveCondition
                : context.l10n.updateCondition,
            onPressed: _save,
          ),
        ],
      ),
    ),
  );
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    required this.condition,
    this.assessment,
    required this.onTap,
  });
  final ThesisCondition condition;
  final ConditionAssessment? assessment;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RecordGroup(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  condition.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _StatusChip(
                status: assessment?.status ?? EvidenceStatus.notEvaluated,
              ),
            ],
          ),
          if (condition.isNumeric)
            Text(
              '${condition.metric.isEmpty ? 'Metric' : condition.metric}: ${condition.comparator == ConditionComparator.atLeast ? '≥' : '≤'} ${condition.threshold}',
              style: TextStyle(fontSize: 11, color: context.colors.muted),
            ),
          if (assessment != null) ...[
            const SizedBox(height: 6),
            Text(assessment!.explanation, style: const TextStyle(fontSize: 11)),
            if (assessment!.source.isNotEmpty)
              Text(
                'Source: ${assessment!.source} · ${assessment!.reportingPeriod}',
                style: TextStyle(fontSize: 10, color: context.colors.muted),
              ),
            Text(
              'Evidence: ${assessment!.evidence}',
              style: TextStyle(fontSize: 10, color: context.colors.muted),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment});
  final ThesisAssessment assessment;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _listCard(
        'Arguments in support',
        assessment.supportingArguments,
        context.colors.subtleSurface,
      ),
      _listCard(
        'Strongest counterarguments',
        assessment.counterarguments,
        context.colors.noticeSurface,
      ),
      _listCard(
        'Unverified assumptions',
        assessment.unverifiedAssumptions,
        context.colors.surface,
      ),
      _listCard(
        'Risks to investigate',
        assessment.overlookedRisks,
        context.colors.surface,
      ),
      _listCard(
        'Reconsideration triggers',
        assessment.reconsiderationTriggers,
        context.colors.surface,
      ),
      _listCard(
        'Information needed',
        assessment.additionalInformation,
        context.colors.surface,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Assessed ${assessment.assessedAt.toLocal()}',
          style: TextStyle(color: context.colors.muted, fontSize: 10),
        ),
      ),
    ],
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.assessment, this.previous});
  final ThesisAssessment assessment;
  final ThesisAssessment? previous;
  @override
  Widget build(BuildContext context) {
    final changes = <String>[];
    if (previous != null) {
      for (final current in assessment.conditions) {
        final before = previous!.conditions
            .where((item) => item.conditionId == current.conditionId)
            .firstOrNull;
        if (before != null && before.status != current.status) {
          changes.add(
            '${current.description}: ${before.status.name} → ${current.status.name}',
          );
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RecordGroup(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assessment.assessedAt.toLocal().toString(),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text(
              '${assessment.conditions.length} conditions · ${assessment.conditions.where((item) => item.status == EvidenceStatus.insufficient).length} insufficient evidence',
              style: TextStyle(color: context.colors.muted, fontSize: 10),
            ),
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final change in changes)
                Text('Changed: $change', style: const TextStyle(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final EvidenceStatus status;
  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      EvidenceStatus.supported => context.l10n.evidenceSupported,
      EvidenceStatus.weakening => context.l10n.evidenceWeakening,
      EvidenceStatus.contradicted => context.l10n.evidenceContradicted,
      EvidenceStatus.insufficient => context.l10n.evidenceInsufficient,
      EvidenceStatus.notEvaluated => context.l10n.evidenceNotEvaluated,
    };
    final color = status == EvidenceStatus.supported
        ? context.colors.positive
        : status == EvidenceStatus.contradicted
        ? context.colors.error
        : context.colors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LiquidityTab extends ConsumerStatefulWidget {
  const _LiquidityTab();
  @override
  ConsumerState<_LiquidityTab> createState() => _LiquidityTabState();
}

class _LiquidityTabState extends ConsumerState<_LiquidityTab> {
  late final Future<List<InvestmentThesis>> _theses = ref
      .read(financeRepositoryProvider)
      .investmentTheses();
  final _order = TextEditingController();
  int? _selectedThesisId;
  final _volume = TextEditingController();
  final _date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _source = TextEditingController(text: 'User-entered historical volume');
  int _participation = 10;

  @override
  void dispose() {
    _order.dispose();
    _volume.dispose();
    _date.dispose();
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = double.tryParse(_order.text.trim()) ?? 0;
    final volume = double.tryParse(_volume.text.trim());
    final date = DateTime.tryParse(_date.text.trim());
    final analysis = order <= 0
        ? null
        : analyzeLiquidity(
            orderSize: order,
            averageDailyVolume: volume,
            volumeUnit: 'shares',
            observedAt: date,
            participationPercent: _participation,
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          context.l10n.testLiquidity,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.noLiveLiquidity,
          style: TextStyle(color: context.colors.muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<InvestmentThesis>>(
          future: _theses,
          builder: (context, snapshot) {
            final theses = snapshot.data ?? const <InvestmentThesis>[];
            if (theses.isEmpty) return const SizedBox.shrink();
            return DropdownButtonFormField<int>(
              initialValue: theses.any((item) => item.id == _selectedThesisId)
                  ? _selectedThesisId
                  : null,
              decoration: InputDecoration(
                labelText: context.l10n.optionalSecurity,
              ),
              items: [
                for (final thesis in theses)
                  DropdownMenuItem(
                    value: thesis.id,
                    child: Text('${thesis.ticker} · ${thesis.securityName}'),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedThesisId = value),
            );
          },
        ),
        const SizedBox(height: 10),
        _numberField(
          _order,
          'Hypothetical order size (shares)',
          () => setState(() {}),
        ),
        const SizedBox(height: 10),
        _numberField(
          _volume,
          'Average daily historical volume (shares)',
          () => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _date,
          decoration: InputDecoration(
            labelText: context.l10n.observationDate,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _source,
          decoration: InputDecoration(
            labelText: context.l10n.volumeSource,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text(
          'Assumed participation in daily volume: $_participation%',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        Slider(
          value: _participation.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          label: '$_participation%',
          onChanged: (value) => setState(() => _participation = value.round()),
        ),
        const SizedBox(height: 8),
        if (analysis == null)
          RecordGroup(
            child: Text(
              context.l10n.enterHistoricalOrder,
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
          )
        else
          _LiquidityResult(
            analysis: analysis,
            source: _source.text,
            date: _date.text,
          ),
        const SizedBox(height: 12),
        Text(
          context.l10n.liquidityDisclaimer,
          style: TextStyle(color: context.colors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _LiquidityResult extends StatelessWidget {
  const _LiquidityResult({
    required this.analysis,
    required this.source,
    required this.date,
  });
  final LiquidityAnalysis analysis;
  final String source;
  final String date;
  @override
  Widget build(BuildContext context) => RecordGroup(
    color: analysis.status == 'scenario'
        ? context.colors.subtleSurface
        : context.colors.noticeSurface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          analysis.status == 'scenario'
              ? context.l10n.historicalScenario
              : analysis.status == 'stale'
              ? context.l10n.staleObservation
              : context.l10n.insufficientEvidence,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Text(analysis.message, style: const TextStyle(fontSize: 12)),
        if (analysis.volumeMultiple != null) ...[
          const SizedBox(height: 9),
          Text(
            'Order / average volume: ${analysis.volumeMultiple!.toStringAsFixed(2)}×',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            'Observation: $date · $source',
            style: TextStyle(fontSize: 10, color: context.colors.muted),
          ),
        ],
      ],
    ),
  );
}

class _RippleTab extends ConsumerStatefulWidget {
  const _RippleTab();
  @override
  ConsumerState<_RippleTab> createState() => _RippleTabState();
}

class _RippleTabState extends ConsumerState<_RippleTab> {
  late Future<(List<PortfolioHolding>, Map<String, String>)> _data;
  EconomicScenario _scenario = EconomicScenario.tengeDepreciation;
  double _magnitude = 10;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<(List<PortfolioHolding>, Map<String, String>)> _load() async => (
    await ref.read(financeRepositoryProvider).portfolioHoldings(),
    await ref.read(financeRepositoryProvider).investmentSettings(),
  );
  void _refresh() => setState(() => _data = _load());

  Future<void> _saveSetting(String key, String value) =>
      ref.read(financeRepositoryProvider).saveInvestmentSetting(key, value);

  Future<void> _addHolding() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HoldingForm(),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(List<PortfolioHolding>, Map<String, String>)>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _errorState(context, 'Could not load portfolio assumptions.');
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final holdings = snapshot.data!.$1;
      final settings = snapshot.data!.$2;
      if (!_settingsLoaded) {
        _settingsLoaded = true;
        final storedScenario = settings['scenario_type'];
        _scenario =
            EconomicScenario.values
                .where((item) => item.name == storedScenario)
                .firstOrNull ??
            EconomicScenario.tengeDepreciation;
        _magnitude =
            double.tryParse(settings['scenario_magnitude'] ?? '') ?? 10;
      }
      final limits = _scenario == EconomicScenario.tengeDepreciation
          ? 50.0
          : _scenario == EconomicScenario.oilPriceDecrease
          ? 80.0
          : 10.0;
      final result = simulateRipple(
        holdings: holdings,
        scenario: _scenario,
        magnitude: _magnitude,
      );
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            context.l10n.macroIntro,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            context.l10n.macroDisclaimer,
            style: TextStyle(color: context.colors.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              SectionHeading(context.l10n.portfolioHoldings),
              TextButton.icon(
                onPressed: _addHolding,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.addHolding),
              ),
            ],
          ),
          if (holdings.isEmpty)
            RecordGroup(
              child: Text(
                context.l10n.holdingStart,
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
            )
          else
            for (final holding in holdings)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: RecordGroup(
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${holding.securityName} · ${holding.ticker}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${context.formatTenge(holding.marketValueKzt)} · user-entered value',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.removeHolding,
                        onPressed: () async {
                          await ref
                              .read(financeRepositoryProvider)
                              .deletePortfolioHolding(holding.id!);
                          if (mounted) _refresh();
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 10),
          DropdownButtonFormField<EconomicScenario>(
            isExpanded: true,
            initialValue: _scenario,
            decoration: InputDecoration(labelText: context.l10n.scenario),
            items: [
              DropdownMenuItem(
                value: EconomicScenario.tengeDepreciation,
                child: Text(
                  context.l10n.tengeDepreciation,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: EconomicScenario.oilPriceDecrease,
                child: Text(
                  context.l10n.oilPriceDrop,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: EconomicScenario.interestRateIncrease,
                child: Text(
                  context.l10n.interestIncrease,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _scenario = value;
                  _magnitude = _magnitude.clamp(
                    0,
                    value == EconomicScenario.tengeDepreciation
                        ? 50
                        : value == EconomicScenario.oilPriceDecrease
                        ? 80
                        : 10,
                  );
                });
                _saveSetting('scenario_type', value.name);
                _saveSetting('scenario_magnitude', _magnitude.toString());
              }
            },
          ),
          const SizedBox(height: 14),
          Text(
            '${_scenario == EconomicScenario.interestRateIncrease
                ? 'Rate increase'
                : _scenario == EconomicScenario.oilPriceDecrease
                ? 'Oil price decrease'
                : 'Tenge depreciation'}: ${_magnitude.toStringAsFixed(1)}${_scenario == EconomicScenario.interestRateIncrease ? ' pp' : '%'}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Slider(
            value: _magnitude.clamp(0, limits),
            min: 0,
            max: limits,
            divisions: limits.toInt(),
            label: _magnitude.toStringAsFixed(1),
            onChanged: (value) {
              setState(() => _magnitude = value);
              _saveSetting('scenario_magnitude', value.toString());
            },
          ),
          if (holdings.isNotEmpty) _RippleResults(result: result),
          const SizedBox(height: 12),
          Text(
            context.l10n.macroFormula,
            style: TextStyle(color: context.colors.muted, fontSize: 10),
          ),
        ],
      );
    },
  );
}

class _RippleResults extends StatelessWidget {
  const _RippleResults({required this.result});
  final RippleResult result;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RecordGroup(
        color: context.colors.emphasis,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.scenarioComparison,
              style: TextStyle(
                color: context.colors.onEmphasis,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Before  ${context.formatTenge(result.beforeKzt)}',
              style: TextStyle(color: context.colors.onEmphasis, fontSize: 12),
            ),
            Text(
              result.afterKzt == null
                  ? context.l10n.notEstimatedAfter
                  : 'After  ${context.formatTenge(result.afterKzt!)}',
              style: TextStyle(color: context.colors.onEmphasis, fontSize: 12),
            ),
            Text(
              result.changeKzt == null
                  ? context.l10n.portfolioUnknownNotice
                  : 'Change  ${context.formatTenge(result.changeKzt!)}',
              style: TextStyle(
                color: context.colors.progress,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final item in result.holdings)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: RecordGroup(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.holding.securityName} · ${item.holding.ticker}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        item.returnPercent == null
                            ? context.l10n.sensitivityMissing
                            : 'Assumed impact ${item.returnPercent!.toStringAsFixed(2)}% · ${context.formatTenge(item.changeKzt!)}',
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.tune, size: 18, color: context.colors.muted),
              ],
            ),
          ),
        ),
    ],
  );
}

class _HoldingForm extends ConsumerStatefulWidget {
  const _HoldingForm();
  @override
  ConsumerState<_HoldingForm> createState() => _HoldingFormState();
}

class _HoldingFormState extends ConsumerState<_HoldingForm> {
  final _name = TextEditingController();
  final _ticker = TextEditingController();
  final _value = TextEditingController();
  final _fx = TextEditingController();
  final _oil = TextEditingController();
  final _rate = TextEditingController();
  @override
  void dispose() {
    for (final c in [_name, _ticker, _value, _fx, _oil, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_value.text.replaceAll(' ', ''));
    if (_name.text.trim().isEmpty ||
        _ticker.text.trim().isEmpty ||
        value == null ||
        value < 0) {
      showMessage(
        context,
        'Enter a security, ticker and non-negative KZT value.',
      );
      return;
    }
    double? sensitivity(TextEditingController controller) =>
        controller.text.trim().isEmpty
        ? null
        : double.tryParse(controller.text.trim());
    if ([_fx, _oil, _rate].any(
      (controller) =>
          controller.text.trim().isNotEmpty && sensitivity(controller) == null,
    )) {
      showMessage(
        context,
        'Sensitivities must be valid numbers, or left blank when unknown.',
      );
      return;
    }
    await ref
        .read(financeRepositoryProvider)
        .savePortfolioHolding(
          PortfolioHolding(
            securityName: _name.text.trim(),
            ticker: _ticker.text.trim().toUpperCase(),
            marketValueKzt: value,
            fxSensitivityPctPerPct: sensitivity(_fx),
            oilSensitivityPctPerPct: sensitivity(_oil),
            rateSensitivityPctPerPoint: sensitivity(_rate),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      18,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(context.l10n.addHolding, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: context.l10n.securityName),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _ticker,
          decoration: InputDecoration(labelText: context.l10n.ticker),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _value,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.l10n.marketValue),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _fx,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: context.l10n.fxSensitivity,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _oil,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: context.l10n.oilSensitivity,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: context.l10n.rateSensitivity,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.sensitivityNotice,
          style: TextStyle(color: context.colors.muted, fontSize: 10),
        ),
        const SizedBox(height: 12),
        PrimaryAction(label: context.l10n.saveHolding, onPressed: _save),
      ],
    ),
  );
}

Widget _textCard(BuildContext context, String title, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: RecordGroup(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          text.isEmpty ? 'Not recorded.' : text,
          style: TextStyle(
            color: text.isEmpty ? context.colors.muted : context.colors.text,
            fontSize: 12,
          ),
        ),
      ],
    ),
  ),
);

Widget _listCard(String title, List<String> lines, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: RecordGroup(
    color: color,
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        ),
        const SizedBox(height: 5),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $line', style: const TextStyle(fontSize: 11)),
          ),
      ],
    ),
  ),
);

Widget _numberField(
  TextEditingController controller,
  String label,
  VoidCallback onChanged,
) => TextField(
  controller: controller,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: InputDecoration(labelText: label),
  onChanged: (_) => onChanged(),
);

Widget _errorState(BuildContext context, String message) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: context.colors.error),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 8),
        Text(
          'Try leaving and reopening this section.',
          style: TextStyle(color: context.colors.muted, fontSize: 12),
        ),
      ],
    ),
  ),
);
