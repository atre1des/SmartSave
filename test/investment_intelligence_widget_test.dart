import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/invest/investment_intelligence_screen.dart';
import 'package:smart_save/shared/theme.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Widget tests use fake time and cannot await replies from a real isolate.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('creates a local thesis, evaluates evidence, and shows history', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final verticalScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    final repository = await FinanceRepository.open(
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const InvestmentIntelligenceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Thesis autopsy'));
    await tester.tap(find.text('Thesis autopsy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create your first thesis'));
    await tester.tap(find.text('Create your first thesis'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Example issuer');
    await tester.enterText(find.byType(TextFormField).at(1), 'EX');
    await tester.scrollUntilVisible(
      find.text('Save thesis'),
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.text('Save thesis'));
    await tester.pumpAndSettle();

    expect(find.text('Example issuer'), findsWidgets);
    await tester.tap(find.text('Example issuer').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add').last,
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Revenue growth stays above 5%',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Revenue growth (%)',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '5');
    await tester.enterText(find.byType(TextFormField).at(3), '7');
    await tester.enterText(find.byType(TextFormField).at(4), 'FY2025');
    await tester.enterText(
      find.byType(TextFormField).at(5),
      'User-provided report reference',
    );
    await tester.scrollUntilVisible(
      find.text('Save condition'),
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.text('Save condition'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Assess available evidence'),
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.text('Assess available evidence'));
    await tester.pumpAndSettle();
    expect(find.text('Supported'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Assessment history'),
      250,
      scrollable: verticalScroll,
    );
    expect(find.text('Assessment history'), findsOneWidget);
  });
}
