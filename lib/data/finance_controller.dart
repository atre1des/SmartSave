import 'package:flutter/foundation.dart';

import 'finance_repository.dart';

class FinanceController extends ChangeNotifier {
  FinanceController(this.repository);

  final FinanceRepository repository;
  List<FinanceTransaction> transactions = const [];
  List<SavingsGoal> goals = const [];
  Map<String, int> spending = const {};
  Map<String, int> budgetLimits = const {};
  List<DepositProduct> products = const [];
  int balance = 0;
  int monthlySpend = 0;
  bool isLoading = true;
  String? loadError;
  bool _disposed = false;
  int _refreshGeneration = 0;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_refreshGeneration;
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        repository.transactions(),
        repository.goals(),
        repository.spendingByCategory(),
        repository.budgets(),
        repository.deposits(),
        repository.totalBalance(),
        repository.spentThisMonth(),
      ]);
      if (_disposed || generation != _refreshGeneration) return;
      transactions = values[0] as List<FinanceTransaction>;
      goals = values[1] as List<SavingsGoal>;
      spending = values[2] as Map<String, int>;
      budgetLimits = values[3] as Map<String, int>;
      products = values[4] as List<DepositProduct>;
      balance = values[5] as int;
      monthlySpend = values[6] as int;
    } catch (error) {
      if (!_disposed && generation == _refreshGeneration) {
        loadError = 'Could not load local financial records.';
      }
    } finally {
      if (!_disposed && generation == _refreshGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveTransaction(FinanceTransaction transaction) async {
    await repository.saveTransaction(transaction);
    await refresh();
  }

  Future<void> deleteTransaction(int id) async {
    await repository.deleteTransaction(id);
    await refresh();
  }

  Future<int> saveGoal(SavingsGoal goal) async {
    final id = await repository.saveGoal(goal);
    await refresh();
    return id;
  }

  Future<void> deleteGoal(int id) async {
    await repository.deleteGoal(id);
    await refresh();
  }

  Future<void> addContribution(int goalId, int amount) async {
    await repository.addContribution(goalId, amount);
    await refresh();
  }

  Future<void> saveBudget(String category, int amount) async {
    await repository.saveBudget(category, amount);
    await refresh();
  }

  Future<List<FinanceTransaction>> searchTransactions({String? category, String? query}) =>
      repository.transactions(category: category, query: query);

  Future<List<DepositProduct>> filterDeposits({int? term, bool? topUp, bool? withdrawal, bool? capitalization}) =>
      repository.deposits(term: term, topUp: topUp, withdrawal: withdrawal, capitalization: capitalization);

  Future<void> resetDemoData() async {
    await repository.resetDemoData();
    await refresh();
  }
}
