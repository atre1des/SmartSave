import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../l10n/app_locale.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/appearance.dart';
import '../shared/glass.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import '../ai/models.dart';
import '../ai/openrouter_provider.dart';
import 'cloud_repository.dart';
import 'review_data.dart';

part 'live_session.dart';
part 'live_workspace.dart';
part 'live_chat.dart';

const _sidebarWidth = 224.0;
const _desktopBreakpoint = 1024.0;
const _columnsBreakpoint = 720.0;

Future<bool> runBrowserWorkspace({bool review = false}) async {
  SemanticsBinding.instance.ensureSemantics();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    AppearanceScope(
      controller: AppearanceController(preferences),
      child: _BrowserApp(review: review),
    ),
  );
  return true;
}

String _copy(BuildContext context, String en, String kk, String ru) =>
    switch (Localizations.localeOf(context).languageCode) {
      'kk' => kk,
      'ru' => ru,
      _ => en,
    };

String _reviewLabel(BuildContext context) => _copy(
  context,
  'Fictional preview',
  'Ойдан шығарылған деректер',
  'Демонстрационные данные',
);

class _BrowserApp extends StatefulWidget {
  const _BrowserApp({required this.review});
  final bool review;

  @override
  State<_BrowserApp> createState() => _BrowserAppState();
}

class _BrowserAppState extends State<_BrowserApp> {
  Locale? _locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SmartSave',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(Brightness.light, 'Noto Sans'),
    darkTheme: buildAppTheme(Brightness.dark, 'Noto Sans'),
    themeMode: AppearanceScope.of(context)?.value ?? ThemeMode.system,
    locale: _locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    localeResolutionCallback: AppLocaleController.resolve,
    home: widget.review
        ? _ReviewWorkspace(
            onLocale: (locale) => setState(() => _locale = locale),
          )
        : const _LiveSession(),
  );
}

class _UnavailableWorkspace extends StatelessWidget {
  const _UnavailableWorkspace();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SmartSave', style: glassTitle(context)),
                const SizedBox(height: 16),
                Text(
                  _copy(
                    context,
                    'Browser sign-in is unavailable. Check the Firebase web configuration and connection.',
                    'Браузердегі жұмыс кеңістігі тексеріліп жатыр. Мұнда есептік жазбаға кіру және қаржылық деректер қолжетімсіз.',
                    'Веб-версия проходит проверку. Вход в аккаунт и финансовые данные здесь недоступны.',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReviewWorkspace extends StatefulWidget {
  const _ReviewWorkspace({
    required this.onLocale,
    this.data,
    this.repository,
    this.stale = false,
    this.loading = false,
    this.refresh,
  });
  final ValueChanged<Locale> onLocale;
  final WebSnapshot? data;
  final WebFinanceRepository? repository;
  final bool stale;
  final bool loading;
  final Future<void> Function()? refresh;

  @override
  State<_ReviewWorkspace> createState() => _ReviewWorkspaceState();
}

class _ReviewWorkspaceState extends State<_ReviewWorkspace> {
  static const WorkspaceData _data = FictionalWorkspace();
  int _section = 0;

  void _select(int next) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _section = next);
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.data;
    final repository = widget.repository;
    final data = live ?? _data;
    final labels = [
      context.l10n.home,
      context.l10n.deposits,
      context.l10n.ai,
      context.l10n.invest,
      context.l10n.myAccount,
    ];
    const icons = [
      Icons.home_outlined,
      Icons.savings_outlined,
      Icons.chat_bubble_outline,
      Icons.show_chart,
      Icons.person_outline,
    ];
    return LayoutBuilder(
      builder: (context, viewport) {
        final desktop = viewport.maxWidth >= _desktopBreakpoint;
        final pages = [
          _Home(
            data: data,
            onNavigate: _select,
            actions: live == null || repository == null || widget.stale
                ? null
                : _financeActions(context, repository, live, widget.refresh!),
          ),
          _SectionPage(
            title: context.l10n.deposits,
            child: _Deferred(
              heading: context.l10n.depositCalculator,
              description: context.l10n.sampleDepositDisclaimer,
            ),
          ),
          _Chat(repository: repository),
          live == null
              ? _Investment(data: data, onAssistant: () => _select(2))
              : _liveInvestment(context, live, () => _select(2)),
          _SectionPage(
            title: context.l10n.myAccount,
            child: _Preferences(
              onLocale: widget.onLocale,
              account: repository == null
                  ? null
                  : _accountActions(
                      context,
                      repository,
                      live!,
                      widget.refresh!,
                      widget.stale,
                    ),
            ),
          ),
        ];
        final requestedPage = IndexedStack(
          index: _section,
          children: [
            for (final (index, page) in pages.indexed)
              ExcludeFocus(excluding: index != _section, child: page),
          ],
        );
        final body = Column(
          children: [
            _WorkspaceBar(
              compact: !desktop,
              status: repository == null
                  ? null
                  : widget.stale
                  ? _webUnavailable(context)
                  : repository.auth.currentUser?.email ??
                        context.l10n.myAccount,
            ),
            if (widget.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: requestedPage),
          ],
        );
        return Scaffold(
          body: SafeArea(
            bottom: desktop,
            child: Row(
              children: [
                if (desktop)
                  SizedBox(
                    width: _sidebarWidth,
                    child: _Sidebar(
                      labels: labels,
                      icons: icons,
                      selected: _section,
                      onSelect: _select,
                    ),
                  ),
                if (desktop)
                  VerticalDivider(
                    width: 1,
                    color: context.colors.outline.withValues(alpha: .44),
                  ),
                Expanded(key: const ValueKey('workspace'), child: body),
              ],
            ),
          ),
          bottomNavigationBar:
              desktop ||
                  (_section == 2 && MediaQuery.viewInsetsOf(context).bottom > 0)
              ? null
              : AppNavigationBar(
                  selectedIndex: _section,
                  onSelected: _select,
                  destinations: [
                    for (final (index, label) in labels.indexed)
                      (icon: Icon(icons[index], size: 22), label: label),
                  ],
                ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onSelect,
  });
  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 0, 36),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: context.colors.action,
              size: 23,
            ),
            const SizedBox(width: 10),
            Text(
              'SmartSave',
              style: glassTitle(
                context,
              ).copyWith(fontSize: 23, letterSpacing: -.8),
            ),
          ],
        ),
      ),
      for (final (index, label) in labels.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Semantics(
            selected: selected == index,
            child: TextButton(
              style: TextButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                backgroundColor: selected == index
                    ? context.colors.action.withValues(alpha: .12)
                    : null,
                foregroundColor: selected == index
                    ? context.colors.action
                    : context.colors.muted,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: () => onSelect(index),
              child: Row(
                children: [
                  Icon(icons[index], size: 21),
                  const SizedBox(width: 11),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _WorkspaceBar extends StatelessWidget {
  const _WorkspaceBar({required this.compact, this.status});
  final bool compact;
  final String? status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 18 : 32,
      vertical: compact ? 7 : 13,
    ),
    child: Row(
      children: [
        if (compact)
          const Text(
            'SmartSave',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        if (compact) const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: compact
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Text(
              status ?? _reviewLabel(context),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: compact ? TextAlign.end : TextAlign.start,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ThemeMenu(),
      ],
    ),
  );
}

class _ThemeMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PopupMenuButton<ThemeMode>(
    tooltip: context.l10n.appearance,
    icon: Icon(
      Theme.of(context).brightness == Brightness.dark
          ? Icons.dark_mode_outlined
          : Icons.light_mode_outlined,
    ),
    onSelected: (mode) async {
      await AppearanceScope.of(context)?.select(mode);
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: ThemeMode.system,
        child: Text(context.l10n.themeSystem),
      ),
      PopupMenuItem(
        value: ThemeMode.light,
        child: Text(context.l10n.themeLight),
      ),
      PopupMenuItem(value: ThemeMode.dark, child: Text(context.l10n.themeDark)),
    ],
  );
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({
    required this.title,
    this.description,
    required this.child,
  });
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final margin = constraints.maxWidth < 600 ? 20.0 : 40.0;
      return Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(margin, 10, margin, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: glassTitle(context)),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 26),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Columns extends StatelessWidget {
  const _Columns({required this.primary, required this.secondary});
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth >= _columnsBreakpoint
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: primary),
              const SizedBox(width: 32),
              Expanded(flex: 4, child: secondary),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 27), secondary],
          ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home({required this.data, required this.onNavigate, this.actions});
  final Widget? actions;
  final WorkspaceData data;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => _SectionPage(
    title: context.l10n.yourFinances,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Columns(
          primary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: FinancialFigure(
                  context.formatTenge(data.balance).replaceFirst('−', '-'),
                  label: data is WebSnapshot
                      ? _copy(
                          context,
                          'Net recorded balance',
                          'Жазбалар бойынша таза қалдық',
                          'Баланс по записям',
                        )
                      : context.l10n.totalBalance,
                  fontSize: 58,
                ),
              ),
              _Heading(context.l10n.recent),
              const SizedBox(height: 12),
              RecordGroup(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (final (index, transaction)
                        in data.transactions.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          foregroundColor: context.colors.action,
                          backgroundColor: context.colors.action.withValues(
                            alpha: .10,
                          ),
                          child: Icon(
                            transaction.amount >= 0
                                ? Icons.south_west
                                : Icons.north_east,
                            size: 17,
                          ),
                        ),
                        title: Text(transaction.merchant),
                        subtitle: Text(
                          context.transactionCategory(transaction.category),
                        ),
                        trailing: Text(
                          context
                              .formatSignedTenge(
                                transaction.amount.abs(),
                                income: transaction.amount >= 0,
                              )
                              .replaceFirst('−', '-'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => onNavigate(2),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(context.l10n.askSmartSaveShort),
              ),
            ],
          ),
          secondary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Heading(context.l10n.spentMonth),
              const SizedBox(height: 10),
              RecordGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FinancialFigure(context.formatTenge(data.monthlySpending)),
                    const SizedBox(height: 12),
                    ProgressTrack(
                      value: data.budget == 0
                          ? 0
                          : data.monthlySpending / data.budget,
                      height: 6,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      context.l10n.budgetSpent(
                        context.formatTenge(data.monthlySpending),
                        context.formatTenge(data.budget),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Heading(context.l10n.goalProgress),
              const SizedBox(height: 10),
              RecordGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, goal) in data.goals.indexed) ...[
                      if (index > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                      Text(
                        goal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.l10n.amountOf(
                          context.formatTenge(goal.saved),
                          context.formatTenge(goal.target),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ProgressTrack(value: goal.saved / goal.target, height: 5),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => onNavigate(3),
                icon: const Icon(Icons.arrow_outward, size: 16),
                label: Text(context.l10n.investmentIntelligence),
              ),
            ],
          ),
        ),
        if (actions != null) ...[const SizedBox(height: 30), actions!],
      ],
    ),
  );
}

class _Investment extends StatelessWidget {
  const _Investment({required this.data, required this.onAssistant});
  final WorkspaceData data;
  final VoidCallback onAssistant;

  @override
  Widget build(BuildContext context) => _SectionPage(
    title: context.l10n.investmentIntelligence,
    description: context.l10n.sampleStockNotice,
    child: _Columns(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(context.l10n.stockPriceChange),
          const SizedBox(height: 16),
          RecordGroup(
            child: Column(
              children: [
                for (final quote in data.quotes)
                  _MarketBar(symbol: quote.symbol, change: quote.change),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Heading(context.l10n.availableStocks),
          const SizedBox(height: 10),
          RecordGroup(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final (index, quote) in data.quotes.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(quote.name),
                    subtitle: Text(quote.symbol),
                    trailing: Text(context.formatTenge(quote.price)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      secondary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(context.l10n.explore),
          const SizedBox(height: 10),
          RecordGroup(
            child: Column(
              children: [
                for (final (index, row) in [
                  (context.l10n.aiBeginners, context.l10n.investBasicsIntro),
                  (context.l10n.thesisReview, context.l10n.thesisTrackingIntro),
                  (
                    context.l10n.liquidityAnalysis,
                    context.l10n.liquidityExecutionIntro,
                  ),
                  (context.l10n.economicRipple, context.l10n.macroImpactIntro),
                ].indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.$1),
                    subtitle: Text(row.$2),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _copy(
              context,
              'Research tools are read-only in this preview.',
              'Бұл нұсқада зерттеу құралдары тек қарауға арналған.',
              'В этой версии инструменты доступны только для просмотра.',
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAssistant,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(context.l10n.askSmartSaveShort),
          ),
        ],
      ),
    ),
  );
}

class _MarketBar extends StatelessWidget {
  const _MarketBar({required this.symbol, required this.change});
  final String symbol;
  final double change;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        SizedBox(width: 52, child: Text(symbol)),
        Expanded(
          child: ExcludeSemantics(
            child: SizedBox(
              height: 24,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final midpoint = constraints.maxWidth / 2;
                  final width = midpoint * (change.abs() / 2.5).clamp(0, 1);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Divider(height: 1, color: context.colors.outline),
                      VerticalDivider(width: 1, color: context.colors.muted),
                      Positioned(
                        left: change >= 0 ? midpoint : midpoint - width,
                        width: width,
                        height: 11,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: change >= 0
                                ? context.colors.action
                                : context.colors.warning,
                            borderRadius: BorderRadius.circular(4),
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
          child: Text(
            '${change >= 0 ? '+' : '-'}${change.abs()}%',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

class _Deferred extends StatelessWidget {
  const _Deferred({required this.heading, required this.description});
  final String heading;
  final String description;

  @override
  Widget build(BuildContext context) => RecordGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(heading),
        const SizedBox(height: 8),
        Text(description),
        const SizedBox(height: 10),
        Text(
          _copy(
            context,
            'Available in the mobile app. Browser support is pending.',
            'Мобильді қолданбада қолжетімді. Браузер нұсқасы дайындалуда.',
            'Доступно в мобильном приложении. Поддержка в браузере готовится.',
          ),
        ),
      ],
    ),
  );
}

class _Preferences extends StatelessWidget {
  const _Preferences({required this.onLocale, this.account});
  final Widget? account;
  final ValueChanged<Locale> onLocale;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Heading(context.l10n.language),
      const SizedBox(height: 10),
      Wrap(
        spacing: 9,
        runSpacing: 8,
        children: [
          for (final (code, label) in [
            ('en', 'English'),
            ('kk', 'Қазақша'),
            ('ru', 'Русский'),
          ])
            Pill(
              label: label,
              selected: Localizations.localeOf(context).languageCode == code,
              onTap: () => onLocale(Locale(code)),
            ),
        ],
      ),
      const SizedBox(height: 26),
      account ??
          _Deferred(
            heading: context.l10n.privacyData,
            description: _reviewLabel(context),
          ),
    ],
  );
}
