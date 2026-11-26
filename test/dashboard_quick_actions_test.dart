import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/dashboard/dashboard_screen.dart';
import 'package:smart_save/features/invest/investment_intelligence_screen.dart';
import 'package:smart_save/l10n/generated/app_localizations.dart';
import 'package:smart_save/shared/theme.dart';
import 'package:smart_save/shared/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  for (final (width, locale, brightness, scale) in [
    (320.0, const Locale('ru'), Brightness.dark, 1.8),
    (390.0, const Locale('kk'), Brightness.light, 1.0),
    (430.0, const Locale('en'), Brightness.dark, 1.0),
  ]) {
    testWidgets('Home quick action order and layout at $width in $locale', (
      tester,
    ) async {
      final repository = await FinanceRepository.open(
        databasePath: inMemoryDatabasePath,
        seed: false,
      );
      addTearDown(repository.close);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 840);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [financeRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final strings = lookupAppLocalizations(locale);
      final list = tester.widget<ListView>(find.byType(ListView));
      final children =
          (list.childrenDelegate as SliverChildListDelegate).children;
      final recentIndex = children.indexWhere(
        (widget) => widget is SectionHeading && widget.title == strings.recent,
      );
      expect(recentIndex, greaterThanOrEqualTo(4));
      final quickActions = children[recentIndex - 2];
      final balance = children[recentIndex - 4];
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text(strings.quickActions),
        100,
        scrollable: scrollable,
      );
      expect(
        find.descendant(
          of: find.byWidget(quickActions),
          matching: find.text(strings.quickActions),
        ),
        findsOneWidget,
      );
      Scrollable.of(
        tester.element(find.text(strings.quickActions)),
      ).position.jumpTo(0);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byWidget(balance),
          matching: find.text(strings.totalBalance),
        ),
        findsOneWidget,
      );

      final tabs = [
        (strings.beginInvesting, 2),
        (strings.deposit, 1),
        (strings.opportunities, 3),
      ];
      final tools = [
        (strings.thesisReview, 1),
        (strings.liquidityAnalysis, 2),
        (strings.economicRipple, 3),
      ];
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      for (final (label, index) in [...tabs, ...tools]) {
        final tile = find.text(label);
        await tester.scrollUntilVisible(tile, 100, scrollable: scrollable);
        if (locale.languageCode != 'en') continue;
        await tester.tap(tile);
        await tester.pumpAndSettle();
        if (tabs.contains((label, index))) {
          expect(container.read(selectedTabIndexProvider), index);
        } else {
          final screen = find.byType(InvestmentIntelligenceScreen);
          expect(
            tester.widget<InvestmentIntelligenceScreen>(screen).initialTab,
            index,
          );
          Navigator.of(tester.element(screen)).pop();
          await tester.pumpAndSettle();
        }
      }
    });
  }

  testWidgets('progress respects reduced motion', (tester) async {
    Widget build(double value) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: ProgressTrack(value: value)),
      ),
    );
    await tester.pumpWidget(build(.25));
    await tester.pumpWidget(build(.75));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .75,
    );
  });
}
