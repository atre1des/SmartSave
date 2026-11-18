import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FinanceRepository repository;
  setUp(() async {
    repository = await FinanceRepository.open(databasePath: inMemoryDatabasePath);
  });
  tearDown(() => repository.close());

  test('seeded dashboard totals reconcile with the sample transactions', () async {
    expect(await repository.spentThisMonth(), 312400);
    expect(await repository.totalBalance(), 1248500);
    expect(await repository.spendingByCategory(), containsPair('Food', 106000));
    expect(await repository.spendingChangePercent(), containsPair('Food', 12));
    expect(await repository.spendingChangePercent(), containsPair('Shopping', 3));
    expect(await repository.spendingChangePercent(), containsPair('Transport', -4));
    expect(await repository.budgets(), containsPair('Food', 95000));
  });

  test('transaction create, update, filter and delete update summaries', () async {
    final now = DateTime.now();
    final id = await repository.saveTransaction(FinanceTransaction(amount: 5000, isIncome: false, category: 'Food', merchant: 'Test cafe', occurredAt: now));
    expect(await repository.spentThisMonth(), 317400);
    expect((await repository.transactions(query: 'Test cafe')).single.id, id);

    await repository.saveTransaction(FinanceTransaction(id: id, amount: 7000, isIncome: false, category: 'Food', merchant: 'Test cafe', occurredAt: now));
    expect(await repository.spentThisMonth(), 319400);

    await repository.deleteTransaction(id);
    expect(await repository.spentThisMonth(), 312400);
    expect(await repository.transactions(query: 'Test cafe'), isEmpty);
  });

  test('goal contributions and edits remain persisted in the repository', () async {
    final goal = (await repository.goals()).firstWhere((item) => item.name == 'New laptop');
    await repository.addContribution(goal.id!, 12000);
    final updated = (await repository.goals()).firstWhere((item) => item.id == goal.id);
    expect(updated.saved, 160000);
    expect(updated.remaining, 80000);
    expect(updated.progressPercent, 67);
  });

  test('deposit filters and demo reset are deterministic', () async {
    expect(await repository.deposits(term: 3), hasLength(4));
    expect(await repository.deposits(term: 3, topUp: true), hasLength(3));
    await repository.saveBudget('Food', 100000);
    await repository.resetDemoData();
    expect(await repository.spentThisMonth(), 312400);
    expect((await repository.budgets())['Food'], 95000);
  });
}
