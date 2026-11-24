import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../data/providers.dart';
import 'investment_intelligence_screen.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';

class DepositRatesScreen extends ConsumerStatefulWidget {
  const DepositRatesScreen({super.key});
  @override
  ConsumerState<DepositRatesScreen> createState() => _DepositRatesScreenState();
}

class _DepositRatesScreenState extends ConsumerState<DepositRatesScreen> {
  int _term = 3;
  bool _topUp = false;
  bool _withdrawal = false;
  bool _compare = false;
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeControllerProvider);
    final products = finance.products
        .where(
          (product) =>
              product.termMonths == _term || product.termMonths < _term,
        )
        .where((product) => !_topUp || product.topUp)
        .where((product) => !_withdrawal || product.withdrawal)
        .toList();
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? BackButton() : null,
        title: Text(context.l10n.deposits),
      ),
      body: SafeArea(
        child: finance.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.firefly),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.deposits,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.sampleDepositHeading,
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      for (final term in [3, 6, 12])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Pill(
                            label: '$term months',
                            selected: _term == term,
                            onTap: () => setState(() => _term = term),
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      FilterChip(
                        label: Text(context.l10n.topUp),
                        selected: _topUp,
                        onSelected: (value) => setState(() => _topUp = value),
                      ),
                      FilterChip(
                        label: Text(context.l10n.withdrawal),
                        selected: _withdrawal,
                        onSelected: (value) =>
                            setState(() => _withdrawal = value),
                      ),
                      ActionChip(
                        label: Text(context.l10n.compare),
                        onPressed: () => setState(() => _compare = !_compare),
                      ),
                    ],
                  ),
                  if (_compare) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.compareLimit,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (products.isEmpty)
                    _NoDeposits(
                      onReset: () => setState(() {
                        _topUp = false;
                        _withdrawal = false;
                        _term = 3;
                      }),
                    )
                  else
                    ...products.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DepositRow(
                          product: product,
                          compareMode: _compare,
                          selected: _selected.contains(product.id),
                          onTap: () {
                            if (_compare) {
                              setState(() {
                                if (_selected.contains(product.id)) {
                                  _selected.remove(product.id);
                                } else if (_selected.length < 3) {
                                  _selected.add(product.id);
                                }
                              });
                            } else {
                              _push(
                                context,
                                DepositDetailsScreen(product: product),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  if (_compare && _selected.isNotEmpty)
                    PrimaryAction(
                      label: 'Compare (${_selected.length})',
                      onPressed: () => _push(
                        context,
                        DepositComparisonScreen(
                          products: products
                              .where((p) => _selected.contains(p.id))
                              .toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.sampleDepositDisclaimer,
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DepositRow extends StatelessWidget {
  const _DepositRow({
    required this.product,
    required this.compareMode,
    required this.selected,
    required this.onTap,
  });
  final DepositProduct product;
  final bool compareMode;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        if (compareMode)
          Checkbox(value: selected, onChanged: (_) => onTap())
        else
          CircleAvatar(
            backgroundColor: AppColors.mintLight,
            child: Text(
              product.bank.substring(0, 2).toUpperCase(),
              style: const TextStyle(
                color: AppColors.firefly,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.bank,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '${product.product} · ${product.termMonths} mo',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              Text(
                'Nominal ${(product.nominalRateBps / 100).toStringAsFixed(2)}%',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(product.effectiveRateBps / 100).toStringAsFixed(2)}%',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              context.l10n.effectiveRate,
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

class DepositDetailsScreen extends StatelessWidget {
  const DepositDetailsScreen({super.key, required this.product});
  final DepositProduct product;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.depositDetails)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SurfaceCard(
            color: AppColors.firefly,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product.bank} · ${product.product}',
                  style: const TextStyle(color: AppColors.mintLight),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(product.effectiveRateBps / 100).toStringAsFixed(2)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  context.l10n.effectiveIndicative,
                  style: TextStyle(color: AppColors.mint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            child: Column(
              children: [
                LabeledValue(
                  label: context.l10n.nominalRate,
                  value:
                      '${(product.nominalRateBps / 100).toStringAsFixed(2)}%',
                ),
                const Divider(),
                LabeledValue(
                  label: context.l10n.term,
                  value: '${product.termMonths} months',
                ),
                const Divider(),
                LabeledValue(label: context.l10n.currency, value: 'Tenge (KZT)'),
                const Divider(),
                LabeledValue(
                  label: context.l10n.guarantee,
                  value: 'KDIF, limits apply',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.estimateIncome,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'On 1 000 000 ₸ · about ${context.formatTenge(estimateSimpleInterest(principalTenge: 1000000, nominalRateBps: product.nominalRateBps, months: product.termMonths))} in ${product.termMonths} months (simple estimate).',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () =>
                      _push(context, DepositCalculatorScreen(product: product)),
                  child: Text(context.l10n.openCalculator),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            color: AppColors.paleGold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.whyDeposit,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.depositTermsNotice,
                  style: TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: () =>
                      _push(context, WhyDepositScreen(product: product)),
                  child: Text(context.l10n.whyThis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryAction(
            label: context.l10n.linkGoal,
            onPressed: () => _push(context, const GoalPickerScreen()),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => showMessage(
              context,
              context.l10n.noBankHandoff,
            ),
            child: Text(context.l10n.openAtBank),
          ),
          TextButton(
            onPressed: () =>
                _push(context, DepositComparisonScreen(products: [product])),
            child: Text(context.l10n.addCompare),
          ),
        ],
      ),
    ),
  );
}

class DepositCalculatorScreen extends StatefulWidget {
  const DepositCalculatorScreen({super.key, this.product});
  final DepositProduct? product;
  @override
  State<DepositCalculatorScreen> createState() =>
      _DepositCalculatorScreenState();
}

class _DepositCalculatorScreenState extends State<DepositCalculatorScreen> {
  final _amount = TextEditingController(text: '1000000');
  late int _term = widget.product?.termMonths ?? 3;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final amount =
        int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final income = product == null
        ? 0
        : estimateSimpleInterest(
            principalTenge: amount,
            nominalRateBps: product.nominalRateBps,
            months: _term,
          );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.depositCalculator)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.amount,
                suffixText: '₸',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final t in [3, 6, 12])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pill(
                      label: '$t mo',
                      selected: _term == t,
                      onTap: () => setState(() => _term = t),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              color: AppColors.mintLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.estimatedIncome),
                  const SizedBox(height: 4),
                  Text(
                    '≈ ${context.formatTenge(income)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'in $_term months · nominal rate, no top-ups',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.depositCalculationNotice,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            PrimaryAction(
              label: context.l10n.linkGoal,
              onPressed: () => _push(context, const GoalPickerScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class DepositComparisonScreen extends StatelessWidget {
  const DepositComparisonScreen({super.key, required this.products});
  final List<DepositProduct> products;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.filtersComparison)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.l10n.compareSamples,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const _NoDeposits(onReset: null)
          else ...[
            for (final product in products)
              SurfaceCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.bank,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ГЭСВ  ${(product.effectiveRateBps / 100).toStringAsFixed(2)}%',
                    ),
                    Text(
                      'Nominal  ${(product.nominalRateBps / 100).toStringAsFixed(2)}%',
                    ),
                    Text('Term  ${product.termMonths} mo'),
                    Text(
                      'Top-up  ${product.topUp ? 'Yes' : 'No'} · Withdrawal  ${product.withdrawal ? 'Yes' : 'No'}',
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            context.l10n.compareSampleRates,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class WhyDepositScreen extends StatelessWidget {
  const WhyDepositScreen({super.key, required this.product});
  final DepositProduct product;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.whyDeposit)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SurfaceCard(
            color: AppColors.mintLight,
            child: Text(
              '${product.bank} · ${(product.effectiveRateBps / 100).toStringAsFixed(2)}% ГЭСВ · ${product.termMonths} months',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          SectionHeading(context.l10n.recommendedBecause),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.depositHighSample),
                SizedBox(height: 10),
                Text(context.l10n.depositTermMatch),
                SizedBox(height: 10),
                Text(context.l10n.depositCompareOnly),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeading(context.l10n.checkBeforeOpening),
          SurfaceCard(
            child: Text(
              context.l10n.depositTermsVary,
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 18),
          SectionHeading(context.l10n.dataSources),
          Text(
            context.l10n.sampleRateDateNotice,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          PrimaryAction(
            label: context.l10n.backDeposit,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class InvestScreen extends StatelessWidget {
  const InvestScreen({super.key});
  static const _stocks = [
    ('Halyk Bank', 'HSBK', 'Medium', '245,00 ₸', '+1,8%', true),
    ('Kaspi.kz', 'KSPI', 'Medium', '42 300 ₸', '+0,6%', true),
    ('KEGOC', 'KEGC', 'Low', '1 480 ₸', '−0,4%', true),
    ('Kazatomprom', 'KAP', 'High', '21 900 ₸', '+2,3%', false),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            context.l10n.stocksForYouLower,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            color: AppColors.firefly,
            onTap: () => _push(context, const InvestmentIntelligenceScreen()),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.mint,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.investmentIntelligence,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        context.l10n.challengeThesis,
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            color: AppColors.mintLight,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.moderateRiskKazakhstan,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionHeading(context.l10n.picks),
          for (final stock in _stocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _StockTile(
                stock: stock,
                onTap: () => _push(context, StockDetailsScreen(stock: stock)),
              ),
            ),
          const SizedBox(height: 8),
          SurfaceCard(
            color: AppColors.mintLight,
            onTap: () => _push(context, const BondsLaterScreen()),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.bondsAndAuto,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        context.l10n.comingLater,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.fictionalStocks,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
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
            style: const TextStyle(
              color: AppColors.firefly,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stock.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '${stock.$2} · ${stock.$3} risk',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              Text(
                stock.$6 ? context.l10n.fitsProfile : context.l10n.aboveProfile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: stock.$6 ? AppColors.success : AppColors.wine,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stock.$4,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                stock.$5,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: stock.$5.startsWith('+')
                      ? AppColors.success
                      : AppColors.wine,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class StockDetailsScreen extends ConsumerStatefulWidget {
  const StockDetailsScreen({super.key, required this.stock});
  final (String, String, String, String, String, bool) stock;
  @override
  ConsumerState<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends ConsumerState<StockDetailsScreen> {
  String _range = '1D';
  late Future<bool> _watchFuture;

  @override
  void initState() {
    super.initState();
    _watchFuture = ref
        .read(financeRepositoryProvider)
        .isWatched(widget.stock.$2);
  }

  Future<void> _toggleWatch() async {
    await ref.read(financeRepositoryProvider).toggleWatch(widget.stock.$2);
    if (mounted) {
      setState(
        () => _watchFuture = ref
            .read(financeRepositoryProvider)
            .isWatched(widget.stock.$2),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.stock.$1} · ${widget.stock.$2}')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.stock.$4,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          Text(
            '${widget.stock.$5} today',
            style: const TextStyle(color: AppColors.success),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['1D', '1W', '1M', '1Y']
                .map(
                  (range) => Pill(
                    label: range,
                    selected: _range == range,
                    onTap: () => setState(() => _range = range),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                context.l10n.sampleTrend,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk: ${widget.stock.$3}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.stock.$6
                      ? context.l10n.fitsModerate
                      : context.l10n.aboveModerate,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.whyThis,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.companySampleWarning,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.sampleAdviceSource,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          FutureBuilder<bool>(
            future: _watchFuture,
            builder: (context, snapshot) => PrimaryAction(
              label: snapshot.data == true
                  ? context.l10n.removeWatchlist
                  : context.l10n.addWatchlist,
              onPressed: snapshot.hasData ? _toggleWatch : null,
            ),
          ),
        ],
      ),
    ),
  );
}

class BondsLaterScreen extends StatelessWidget {
  const BondsLaterScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.bondsAuto)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SurfaceCard(
            color: AppColors.mintLight,
            child: Text(
              context.l10n.comingLater,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          SectionHeading(context.l10n.whatPlanned),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.bondsByRisk),
                SizedBox(height: 12),
                Text(context.l10n.autoAllocation),
                SizedBox(height: 12),
                Text(
                  context.l10n.licensedBrokerApproval,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.licensedBrokerNotice,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          PrimaryAction(
            label: context.l10n.notifyMe,
            onPressed: () => showMessage(
              context,
              context.l10n.notificationSaved,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NoDeposits extends StatelessWidget {
  const _NoDeposits({this.onReset});
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      children: [
        const Icon(Icons.search_off, size: 38, color: AppColors.muted),
        const SizedBox(height: 10),
        Text(
          context.l10n.noMatchingDeposits,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.fewerFilters,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (onReset != null)
          TextButton(onPressed: onReset, child: Text(context.l10n.resetFilters)),
      ],
    ),
  );
}

class GoalPickerScreen extends StatelessWidget {
  const GoalPickerScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.linkGoal)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.l10n.depositGoalNotice,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          for (final name in ['New laptop', 'Emergency fund', 'Trip'])
            ListTile(
              title: Text(name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showMessage(context, '$name linked for this estimate only.');
                Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  );
}

void _push(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
