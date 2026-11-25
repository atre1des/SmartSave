// Separate loopback integration target. This code is absent from the app entry.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smart_save/platform_web/cloud_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var result = 'FAIL';
  try {
    if (Uri.base.host != '127.0.0.1') throw StateError('Loopback required.');
    final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'emulator-only',
        appId: '1:123456789:web:123456789abc',
        messagingSenderId: '123456789',
        projectId: 'demo-smartsave-web',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 8610);
    await auth.setPersistence(Persistence.SESSION);
    final user = await auth.authStateChanges().first;
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator('127.0.0.1', 8611);
    final repo = WebFinanceRepository(auth, firestore, user!.uid);
    final operation = repo.operationId();
    final transaction = {
      'amount': 50,
      'isIncome': false,
      'merchant': 'Replay probe',
      'category': 'Food',
      'occurredAt': DateTime.now().toIso8601String(),
      'note': '',
      'source': 'Emulator fixture',
    };
    await repo.save('transactions', operation, null, transaction);
    await repo.save('transactions', operation, null, transaction);
    final rows = await repo.list('transactions');
    if (rows
            .where((row) => row.id == operation && row.data['version'] == 1)
            .length !=
        1) {
      throw StateError('Transaction replay changed the record.');
    }
    try {
      await repo.save('transactions', operation, null, {
        ...transaction,
        'amount': 51,
      });
      throw StateError('Changed replay was accepted.');
    } on WebDataIssue catch (issue) {
      if (issue != WebDataIssue.conflict) rethrow;
    }
    final originalTransaction = rows.singleWhere((row) => row.id == operation);
    await repo.save('transactions', repo.operationId(), originalTransaction, {
      'amount': 60,
    });
    final editedTransaction = (await repo.list(
      'transactions',
    )).singleWhere((row) => row.id == operation);
    if (editedTransaction.data['amount'] != 60 ||
        editedTransaction.data['version'] != 2) {
      throw StateError('Transaction edit was not recorded.');
    }
    await repo.save('transactions', repo.operationId(), editedTransaction, {
      'isDeleted': true,
    });
    if ((await repo.list('transactions')).any((row) => row.id == operation)) {
      throw StateError('Deleted transaction is still visible.');
    }

    final goalId = repo.operationId();
    await repo.save('goals', goalId, null, {
      'name': 'Replay probe goal',
      'saved': 0,
      'target': 1000,
      'deadline': DateTime.now().toIso8601String(),
      'purpose': '',
    });
    final goal = (await repo.list(
      'goals',
    )).singleWhere((row) => row.id == goalId);
    final contribution = repo.operationId();
    await repo.contribute(contribution, goal, 70);
    await repo.contribute(contribution, goal, 70);
    final updated = (await repo.list(
      'goals',
    )).singleWhere((row) => row.id == goalId);
    if (updated.data['saved'] != 70) {
      throw StateError('Contribution replay was counted twice.');
    }
    await repo.save('goals', repo.operationId(), updated, {'target': 1500});
    final editedGoal = (await repo.list(
      'goals',
    )).singleWhere((row) => row.id == goalId);
    if (editedGoal.data['target'] != 1500 || editedGoal.data['saved'] != 70) {
      throw StateError('Goal edit replaced the contribution.');
    }
    await repo.save('goals', repo.operationId(), editedGoal, {
      'isDeleted': true,
    });
    if ((await repo.list('goals')).any((row) => row.id == goalId)) {
      throw StateError('Deleted goal is still visible.');
    }
    const budgetName = 'Emulator probe budget';
    await repo.save('budgets', repo.operationId(), null, {
      'category': budgetName,
      'monthlyLimit': 200,
    });
    final budget = (await repo.list(
      'budgets',
    )).singleWhere((row) => row.data['category'] == budgetName);
    await repo.save('budgets', repo.operationId(), budget, {
      'monthlyLimit': 350,
    });
    final editedBudget = (await repo.list(
      'budgets',
    )).singleWhere((row) => row.id == budget.id);
    if (editedBudget.data['monthlyLimit'] != 350 ||
        editedBudget.data['version'] != 2) {
      throw StateError('Budget revision was not recorded.');
    }
    repo.close();
    result =
        'PASS transaction and contribution replay, revisions and tombstones';
  } catch (error) {
    // A fixed result avoids leaking disposable account data into the page.
    result = 'FAIL ${error.runtimeType}';
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Semantics(label: result, child: Text(result)),
        ),
      ),
    ),
  );
}
