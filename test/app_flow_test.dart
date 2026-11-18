import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/app/app.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('demo onboarding reaches goals and transaction creation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await FinanceRepository.open(databasePath: inMemoryDatabasePath);
    addTearDown(repository.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [financeRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: WelcomeScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'student@example.edu');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo-pass-123');
    await tester.enterText(find.byType(TextFormField).at(2), 'demo-pass-123');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip, add transactions manually'));
    await tester.pumpAndSettle();

    const answers = ['Sell everything to avoid more losses', 'Within a year', 'None yet', 'Very little', 'Protect what I have'];
    for (var index = 0; index < answers.length; index++) {
      await tester.tap(find.text(answers[index]));
      await tester.pump();
      await tester.tap(find.text(index == answers.length - 1 ? 'See risk profile' : 'Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Continue to SmartSave'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Capstone laptop');
    await tester.enterText(find.byType(TextFormField).at(1), '350000');
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(find.text('Capstone laptop'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '2500');
    await tester.enterText(find.byType(TextFormField).at(1), 'Test lunch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Test lunch'), findsOneWidget);
  });
}
