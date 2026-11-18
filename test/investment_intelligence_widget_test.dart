import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/invest/investment_intelligence_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('creates a local thesis, evaluates evidence, and shows history', (
    tester,
  ) async {
    final repository = await FinanceRepository.open(
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: InvestmentIntelligenceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create your first thesis'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Example issuer');
    await tester.enterText(find.byType(TextFormField).at(1), 'EX');
    await tester.ensureVisible(find.text('Save thesis'));
    await tester.tap(find.text('Save thesis'));
    await tester.pumpAndSettle();

    expect(find.text('Example issuer'), findsWidgets);
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
    await tester.ensureVisible(find.text('Save condition'));
    await tester.tap(find.text('Save condition'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Assess available evidence'));
    await tester.tap(find.text('Assess available evidence'));
    await tester.pumpAndSettle();
    expect(find.text('Supported'), findsOneWidget);
    expect(find.text('Assessment history'), findsOneWidget);
  });
}
