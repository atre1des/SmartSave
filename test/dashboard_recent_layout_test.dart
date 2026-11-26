import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/dashboard/dashboard_screen.dart';
import 'package:smart_save/features/transactions/transactions_screen.dart';
import 'package:smart_save/l10n/app_locale.dart';
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
    (360.0, const Locale('kk'), Brightness.light, 1.4),
    (390.0, const Locale('en'), Brightness.dark, 1.0),
    (430.0, const Locale('en'), Brightness.light, 1.0),
  ]) {
    testWidgets('Recent spacing and trailing amounts at $width in $locale', (
      tester,
    ) async {
      final repository = await FinanceRepository.open(
        databasePath: inMemoryDatabasePath,
        seed: false,
      );
      addTearDown(repository.close);
      final transactions = [
        FinanceTransaction(
          merchant: 'Orchard Market and Neighborhood Produce Cooperative',
          category: 'Food',
          amount: 110,
          occurredAt: DateTime(2026, 11, 25, 12, 25),
          isIncome: false,
        ),
        FinanceTransaction(
          merchant: 'Payroll adjustment',
          category: 'Salary',
          amount: 987654321,
          occurredAt: DateTime(2026, 11, 25, 10),
          isIncome: true,
        ),
      ];
      for (final transaction in transactions) {
        await repository.saveTransaction(transaction);
      }
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
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
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final strings = lookupAppLocalizations(locale);
      final heading = find.byWidgetPredicate(
        (widget) => widget is SectionHeading && widget.title == strings.recent,
      );
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(heading, 130, scrollable: scrollable);
      await Scrollable.ensureVisible(tester.element(heading), alignment: .3);
      await tester.pumpAndSettle();

      for (final (index, transaction) in transactions.indexed) {
        final merchant = find.text(transaction.merchant);

        final card = find
            .ancestor(of: merchant, matching: find.byType(RecordGroup))
            .first;
        if (index == 0) {
          expect(
            tester.getTopLeft(card).dy - tester.getBottomLeft(heading).dy,
            inInclusiveRange(12, 16),
          );
        }
        final row = find
            .ancestor(of: merchant, matching: find.byType(InkWell))
            .first;
        final context = tester.element(merchant);
        final formatted = context.formatSignedTenge(
          transaction.amount,
          income: transaction.isIncome,
        );
        final amount = find.descendant(of: row, matching: find.text(formatted));
        final chevron = find.descendant(
          of: row,
          matching: find.byIcon(Icons.chevron_right_rounded),
        );
        expect(tester.widget<Text>(amount).textAlign, TextAlign.end);
        expect(
          tester.getTopRight(amount).dx + 4,
          closeTo(tester.getTopLeft(chevron).dx, .01),
        );
        expect(
          tester.getTopRight(chevron).dx,
          closeTo(tester.getTopRight(card).dx - 16, .01),
        );
      }
      expect(tester.takeException(), isNull);

      if (width == 430) {
        await tester.tap(find.text(transactions.last.merchant).hitTestable());
        await tester.pumpAndSettle();
        final detail = tester.widget<TransactionDetailsScreen>(
          find.byType(TransactionDetailsScreen),
        );
        expect(detail.transaction.amount, transactions.last.amount);
      }
    });
  }
}
