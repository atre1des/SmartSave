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
      appBar: AppBar(
        title: const Text('Investment Intelligence'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'AI Investing for Beginners'),
            Tab(text: 'Thesis autopsy'),
            Tab(text: 'Liquidity'),
            Tab(text: 'Economic ripple'),
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
      const Text(
        'Learn the basics of investing step by step.',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 5),
      const Text(
        'No live market data or AI provider is configured. This section uses local educational content.',
        style: TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      const SizedBox(height: 16),

      // Topic cards
      _TopicCard(
        icon: Icons.savings_outlined,
        title: 'Deposits vs Investments',
        description: 'Understand the difference between bank deposits and investing in shares.',
        onTap: () => _showLesson(context, 'deposits_vs_investments'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.flag_outlined,
        title: 'Setting Savings Goals',
        description: 'How to create realistic targets and track progress.',
        onTap: () => _showLesson(context, 'savings_goals'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.pie_chart_outline,
        title: 'Diversification Basics',
        description: 'Why spreading your money across different assets matters.',
        onTap: () => _showLesson(context, 'diversification'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.shield_outlined,
        title: 'Risk & Your Profile',
        description: 'Discover your risk tolerance and match investments to it.',
        onTap: () => _showLesson(context, 'risk_profile'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.trending_up,
        title: 'Compound Growth',
        description: 'How time and reinvested returns build wealth.',
        onTap: () => _showLesson(context, 'compound_growth'),
      ),
      const SizedBox(height: 10),
      _TopicCard(
        icon: Icons.lightbulb_outline,
        title: 'Common Beginner Mistakes',
        description: 'Learn what to avoid when starting your investing journey.',
        onTap: () => _showLesson(context, 'beginner_mistakes'),
      ),
      const SizedBox(height: 20),

      // Open AI Assistant
      SurfaceCard(
        color: AppColors.firefly,
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const _AIAssistantScreenRoute()),
          );
        },
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.mint, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask SmartSave AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Open the AI assistant for personalized guidance',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Educational content only — not financial advice. Investments can lose value.',
        style: TextStyle(color: AppColors.muted, fontSize: 11),
      ),
    ],
  );
}

void _showLesson(BuildContext context, String lessonId) {
  final lessons = {
    'deposits_vs_investments': (
      'Deposits vs Investments',
      'Bank deposits offer fixed returns with capital protection (up to KDIF limits). '
      'Investing in shares offers variable returns with potential for higher growth '
      'but also risk of loss. Your money is not guaranteed when investing.',
    ),
    'savings_goals': (
      'Setting Savings Goals',
      'A good goal is Specific, Measurable, Achievable, Relevant, and Time-bound (SMART). '
      'Example: "Save ₸500,000 for a laptop in 12 months" → ₸41,667/month. '
      'Track progress monthly and adjust as needed.',
    ),
    'diversification': (
      'Diversification Basics',
      'Don\'t put all your eggs in one basket. Spread investments across:\n'
      '• Different asset types (deposits, shares, bonds)\n'
      '• Different sectors (banking, energy, tech)\n'
      '• Different geographies (Kazakhstan, global)\n'
      'This reduces the impact of any single investment performing poorly.',
    ),
    'risk_profile': (
      'Risk & Your Profile',
      'Risk tolerance depends on your:\n'
      '• Time horizon (how long until you need the money)\n'
      '• Financial cushion (emergency fund size)\n'
      '• Comfort with volatility\n\n'
      'Conservative: Capital preservation, short horizon\n'
      'Moderate: Balanced growth, medium horizon\n'
      'Aggressive: Maximum growth, long horizon',
    ),
    'compound_growth': (
      'Compound Growth',
      'When you earn returns on your returns, growth accelerates over time.\n'
      'Example: ₸100,000 at 15%/year → ₸404,556 in 10 years (simple) vs ₸1,030,925 (compounded).\n'
      'Start early, reinvest returns, stay invested.',
    ),
    'beginner_mistakes': (
      'Common Beginner Mistakes',
      '1. Investing money you can\'t afford to lose\n'
      '2. Trying to time the market\n'
      '3. Following hype without research\n'
      '4. Not diversifying\n'
      '5. Panic selling during downturns\n'
      '6. Ignoring fees and taxes\n'
      '7. Expecting quick riches',
    ),
  };

  final (String, String) lesson = lessons[lessonId] ?? ('Lesson', 'Content coming soon.');
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
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
            label: 'Got it',
            onPressed: () => Navigator.pop(context),
          ),
        ],
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
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.mintLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.firefly, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.muted),
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

  void _refresh() => setState(() => _theses = _loadOverview());

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
      if (snapshot.hasError) return _errorState('Could not load saved theses.');
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
                  label: 'Active theses',
                  value: '${theses.length}',
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Conditions needing attention',
                  value: '${overview.attentionCount}',
                  icon: Icons.fact_check_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            overview.latestAssessment == null
                ? 'Latest assessment: none yet'
                : 'Latest assessment: ${overview.latestAssessment!.toLocal()} · ${overview.changedCount} recent condition change(s)',
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeading('Your investment theses'),
              TextButton.icon(
                onPressed: _createThesis,
                icon: const Icon(Icons.add),
                label: const Text('New thesis'),
              ),
            ],
          ),
          if (theses.isEmpty)
            SurfaceCard(
              color: AppColors.mintLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start with your reasoning, not a stock tip.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Record what you believe, what could prove it wrong, and which evidence would change your mind.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  PrimaryAction(
                    label: 'Create your first thesis',
                    onPressed: _createThesis,
                  ),
                ],
              ),
            )
          else
            for (final thesis in theses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
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
                        backgroundColor: AppColors.mintLight,
                        child: Text(
                          thesis.ticker.substring(
                            0,
                            thesis.ticker.length > 3 ? 3 : thesis.ticker.length,
                          ),
                          style: const TextStyle(
                            color: AppColors.firefly,
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
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              thesis.rationale.isEmpty
                                  ? 'No thesis rationale added yet'
                                  : thesis.rationale,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          const Text(
            'Structured local review · No AI provider or market feed is configured.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      );
    },
  );
}

class _SourceBanner extends StatelessWidget {
  const _SourceBanner();
  @override
  Widget build(BuildContext context) => SurfaceCard(
    color: AppColors.firefly,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppColors.mint, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kazakhstan market data · Not connected',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'No live KASE/AIX prices or issuer disclosures are imported. Evidence you add is identified as user-provided.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
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
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(icon, color: AppColors.firefly, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
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
    appBar: AppBar(
      title: Text(
        widget.thesis == null ? 'New investment thesis' : 'Edit thesis',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Capture your own investment case. Optional fields can be completed later.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Security name'),
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
                    decoration: const InputDecoration(labelText: 'Ticker'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required.'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _exchange,
                    decoration: const InputDecoration(labelText: 'Exchange'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _identifier,
              decoration: const InputDecoration(
                labelText: 'ISIN / identifier (optional)',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _rationale,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Why are you interested?',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _horizon,
              decoration: const InputDecoration(
                labelText: 'Investment horizon (optional)',
                hintText: 'e.g. 3–5 years',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _assumptions,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Supporting evidence or assumptions',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _risks,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Principal risks you recognize',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _invalidation,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What would weaken or invalidate the thesis?',
              ),
            ),
            const SizedBox(height: 18),
            PrimaryAction(
              label: widget.thesis == null ? 'Save thesis' : 'Update thesis',
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

  void _refresh() => setState(() => _detail = _load());

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
    appBar: AppBar(
      title: Text(widget.thesis.ticker),
      actions: [
        IconButton(
          tooltip: 'Edit thesis',
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
            return _errorState('Could not load this thesis.');
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
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _textCard('Your rationale', widget.thesis.rationale),
              _textCard('Horizon', widget.thesis.horizon),
              _textCard('Assumptions', widget.thesis.assumptions),
              _textCard('Recognized risks', widget.thesis.risks),
              _textCard('Reconsider if', widget.thesis.invalidationConditions),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionHeading('Testable conditions'),
                  TextButton.icon(
                    onPressed: _addCondition,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (conditions.isEmpty)
                const SurfaceCard(
                  child: Text(
                    'No conditions yet. Add measurable thresholds or qualitative disclosure checks.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                label: 'Assess available evidence',
                onPressed: () => _assess(conditions),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Local rules compare only values you enter. No external source or AI model verifies them.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeading('Bear case & research gaps'),
              if (latest == null)
                const SurfaceCard(
                  child: Text(
                    'Run an assessment to create a dated review snapshot.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                )
              else
                _AssessmentCard(assessment: latest),
              const SizedBox(height: 16),
              const SectionHeading('Assessment history'),
              if (history.isEmpty)
                const Text(
                  'No saved assessments yet.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                label: const Text('Delete thesis'),
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
    appBar: AppBar(
      title: Text(
        widget.condition == null ? 'Add condition' : 'Edit condition',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Condition',
              hintText: 'Operating cash flow remains positive',
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Describe the condition.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _metric,
            decoration: const InputDecoration(
              labelText: 'Metric (optional)',
              hintText: 'Operating cash flow, KZT',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ConditionComparator>(
                  initialValue: _comparator,
                  decoration: const InputDecoration(
                    labelText: 'Expected condition',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ConditionComparator.atLeast,
                      child: Text('At least'),
                    ),
                    DropdownMenuItem(
                      value: ConditionComparator.atMost,
                      child: Text('At most'),
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
                  decoration: const InputDecoration(
                    labelText: 'Threshold',
                    hintText: 'Blank = qualitative',
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
            decoration: const InputDecoration(
              labelText: 'Observed value (optional)',
              helperText: 'Numeric comparison requires source and period.',
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
            decoration: const InputDecoration(
              labelText: 'Reporting period / observation date',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _source,
            decoration: const InputDecoration(
              labelText: 'Evidence source / reference',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Evidence note'),
          ),
          const SizedBox(height: 10),
          const Text(
            'No source is automatically fetched. Qualitative conditions remain insufficient until reviewed against a disclosure.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          PrimaryAction(
            label: widget.condition == null
                ? 'Save condition'
                : 'Update condition',
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
    child: SurfaceCard(
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
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          if (assessment != null) ...[
            const SizedBox(height: 6),
            Text(assessment!.explanation, style: const TextStyle(fontSize: 11)),
            if (assessment!.source.isNotEmpty)
              Text(
                'Source: ${assessment!.source} · ${assessment!.reportingPeriod}',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            Text(
              'Evidence: ${assessment!.evidence}',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
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
        AppColors.mintLight,
      ),
      _listCard(
        'Strongest counterarguments',
        assessment.counterarguments,
        AppColors.paleRose,
      ),
      _listCard(
        'Unverified assumptions',
        assessment.unverifiedAssumptions,
        Colors.white,
      ),
      _listCard(
        'Risks to investigate',
        assessment.overlookedRisks,
        Colors.white,
      ),
      _listCard(
        'Reconsideration triggers',
        assessment.reconsiderationTriggers,
        Colors.white,
      ),
      _listCard(
        'Information needed',
        assessment.additionalInformation,
        Colors.white,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Assessed ${assessment.assessedAt.toLocal()}',
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
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
      child: SurfaceCard(
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
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
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
      EvidenceStatus.supported => 'Supported',
      EvidenceStatus.weakening => 'Weakening',
      EvidenceStatus.contradicted => 'Contradicted',
      EvidenceStatus.insufficient => 'Insufficient',
      EvidenceStatus.notEvaluated => 'Not evaluated',
    };
    final color = status == EvidenceStatus.supported
        ? AppColors.success
        : status == EvidenceStatus.contradicted
        ? AppColors.wine
        : AppColors.muted;
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
        const Text(
          'Test a hypothetical position against historical trading activity.',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        const Text(
          'No live KASE/AIX volume, bid–ask spread, or order-book depth is connected.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
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
              decoration: const InputDecoration(
                labelText: 'Security / saved thesis (optional)',
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
          decoration: const InputDecoration(
            labelText: 'Observation date (YYYY-MM-DD)',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _source,
          decoration: const InputDecoration(
            labelText: 'Volume source / reference',
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
          const SurfaceCard(
            child: Text(
              'Enter an order size to see the historical-volume scenario.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          )
        else
          _LiquidityResult(
            analysis: analysis,
            source: _source.text,
            date: _date.text,
          ),
        const SizedBox(height: 12),
        const Text(
          'This compares an order with the supplied historical volume only. It does not predict an execution price, current liquidity, or available depth. A displayed market price is not a promise that the whole position can be sold at that price.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
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
  Widget build(BuildContext context) => SurfaceCard(
    color: analysis.status == 'scenario'
        ? AppColors.mintLight
        : AppColors.paleGold,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          analysis.status == 'scenario'
              ? 'Historical-volume scenario'
              : analysis.status == 'stale'
              ? 'Stale observation'
              : 'Insufficient evidence',
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
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
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
        return _errorState('Could not load portfolio assumptions.');
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
          const Text(
            'Explore a macro shock through your own portfolio assumptions.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            'No company sensitivities or economic data are imported. Portfolio values and sensitivities are user-provided assumptions.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeading('Portfolio holdings (KZT)'),
              TextButton.icon(
                onPressed: _addHolding,
                icon: const Icon(Icons.add),
                label: const Text('Add holding'),
              ),
            ],
          ),
          if (holdings.isEmpty)
            const SurfaceCard(
              child: Text(
                'Add a holding to start. Enter a KZT market value and only sensitivities you can justify; leave unknown assumptions blank.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          else
            for (final holding in holdings)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: SurfaceCard(
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
                              '${formatTenge(holding.marketValueKzt)} · user-entered value',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove holding',
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
            initialValue: _scenario,
            decoration: const InputDecoration(labelText: 'Scenario'),
            items: const [
              DropdownMenuItem(
                value: EconomicScenario.tengeDepreciation,
                child: Text('Tenge depreciation vs foreign currency'),
              ),
              DropdownMenuItem(
                value: EconomicScenario.oilPriceDecrease,
                child: Text('Oil price decrease'),
              ),
              DropdownMenuItem(
                value: EconomicScenario.interestRateIncrease,
                child: Text('Interest rate increase'),
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
          const Text(
            'Calculation: estimated holding return (%) = user-entered sensitivity × scenario magnitude. FX and oil sensitivities are return-% per 1% macro move; interest sensitivity is return-% per 1 percentage-point rate increase. Values are rounded to whole KZT and are not forecasts.',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
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
      SurfaceCard(
        color: AppColors.firefly,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scenario comparison',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Before  ${formatTenge(result.beforeKzt)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              result.afterKzt == null
                  ? 'After  Not estimated · add all selected sensitivities'
                  : 'After  ${formatTenge(result.afterKzt!)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              result.changeKzt == null
                  ? 'Total change unavailable because one or more holding sensitivities are unknown.'
                  : 'Change  ${formatTenge(result.changeKzt!)}',
              style: const TextStyle(
                color: AppColors.mint,
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
          child: SurfaceCard(
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
                            ? 'Insufficient data: sensitivity not entered for this scenario.'
                            : 'Assumed impact ${item.returnPercent!.toStringAsFixed(2)}% · ${formatTenge(item.changeKzt!)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.tune, size: 18, color: AppColors.muted),
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
        Text('Add holding', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Security name'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _ticker,
          decoration: const InputDecoration(labelText: 'Ticker'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _value,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Market value in KZT'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _fx,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'FX return-% per 1% tenge depreciation (optional)',
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _oil,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Return-% per 1% oil price change (optional)',
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Return-% per 1 pp rate increase (optional)',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sensitivities are your assumptions, not issuer data. Leave unknown values blank.',
          style: TextStyle(color: AppColors.muted, fontSize: 10),
        ),
        const SizedBox(height: 12),
        PrimaryAction(label: 'Save holding', onPressed: _save),
      ],
    ),
  );
}

Widget _textCard(String title, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: SurfaceCard(
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
            color: text.isEmpty ? AppColors.muted : AppColors.firefly,
            fontSize: 12,
          ),
        ),
      ],
    ),
  ),
);

Widget _listCard(String title, List<String> lines, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: SurfaceCard(
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

Widget _errorState(String message) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.wine),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 8),
        const Text(
          'Try leaving and reopening this section.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  ),
);
