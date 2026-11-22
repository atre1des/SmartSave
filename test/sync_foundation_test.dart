import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';

/// Focused tests for the SQLite-side sync foundation.
///
/// These tests exercise the persistence primitives that SyncService relies on:
/// schema initialization, the pending-operations queue, retry counters, and
/// conflict-aware cloud-to-local application.
///
/// They do NOT exercise real Firestore I/O. Firestore-dependent integration
/// tests require the Firebase Emulator Suite, which is not configured in this
/// project (documented separately). These tests verify the local persistence
/// layer only.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FinanceRepository repository;
  String? currentUid;
  setUp(() async {
    currentUid = 'user-a';
    repository = await FinanceRepository.open(
      databasePath: inMemoryDatabasePath,
      currentUid: () => currentUid,
    );
    await repository.initializeSync();
  });
  tearDown(() => repository.close());

  test(
    'initializeSync creates the sync_operations queue (idempotent)',
    () async {
      // Called again — must not throw or duplicate.
      await repository.initializeSync();
      await repository.initializeSync();
      expect(await repository.getPendingSyncCount(), 0);
    },
  );

  test('saveTransaction queues a pending sync operation', () async {
    final id = await repository.saveTransaction(
      FinanceTransaction(
        amount: 1234,
        isIncome: false,
        category: 'Food',
        merchant: 'Sync test',
        occurredAt: DateTime.now(),
      ),
    );
    final pending = await repository.getPendingSyncOperations();
    final op = pending.firstWhere((o) => o.entityId == id.toString());
    expect(op.entityType, 'transaction');
    expect(op.operation, 'create');
    expect(op.status, 'pending');
    expect(op.ownerUid, 'user-a');
  });

  test(
    'deleteTransaction queues its snapshot and original owner before removal',
    () async {
      final id = await repository.saveTransaction(
        FinanceTransaction(
          amount: 500,
          isIncome: false,
          category: 'Food',
          merchant: 'To delete',
          occurredAt: DateTime.now(),
        ),
      );
      await repository.deleteTransaction(id);
      final pending = await repository.getPendingSyncOperations();
      final deleteOps = pending.where((o) => o.operation == 'delete');
      expect(deleteOps, isNotEmpty);
      final deletion = deleteOps.first;
      expect(deletion.ownerUid, 'user-a');
      expect(deletion.payload['merchant'], 'To delete');
      expect(deletion.payload['amount'], 500);
      expect(
        (await repository.transactions()).any((tx) => tx.id == id),
        isFalse,
      );
      currentUid = 'user-b';
      expect(deletion.ownerUid, isNot(currentUid));
    },
  );

  test(
    'cloud budget and setting do not overwrite unsynced local values',
    () async {
      await repository.saveBudget('Food', 12000);
      await repository.saveInvestmentSetting('risk_profile', 'local');

      expect(await repository.applyCloudBudget('Food', 99000), isFalse);
      expect(
        await repository.applyCloudSetting('risk_profile', 'remote'),
        isFalse,
      );
      expect((await repository.budgets())['Food'], 12000);
      expect((await repository.investmentSettings())['risk_profile'], 'local');
    },
  );

  test(
    'failed sync operation retains queue entry and increments retry_count',
    () async {
      await repository.saveTransaction(
        FinanceTransaction(
          amount: 999,
          isIncome: false,
          category: 'Bills',
          merchant: 'Retry test',
          occurredAt: DateTime.now(),
        ),
      );
      final pending = await repository.getPendingSyncOperations();
      final op = pending.first;
      await repository.failSyncOperation(op.id, 'simulated failure');

      final afterFail = await repository.getPendingSyncOperations();
      final failedOp = afterFail.firstWhere((o) => o.id == op.id);
      expect(failedOp.status, 'error');

      final retryRow = (await repository.getPendingOpsWithRetry()).firstWhere(
        (row) => row['id'] == op.id,
      );
      expect(retryRow['retry_count'], 1);
    },
  );

  test(
    'applyCloudTransaction inserts a remote record once, not twice on repeat',
    () async {
      final cloud = FinanceTransaction(
        amount: 4242,
        isIncome: true,
        category: 'Income',
        merchant: 'Cloud salary',
        occurredAt: DateTime.now(),
      );

      final first = await repository.applyCloudTransaction(cloud, 'cloud-tx-1');
      final second = await repository.applyCloudTransaction(
        cloud,
        'cloud-tx-1',
      );
      expect(first, isTrue);
      expect(second, isTrue); // update path, not duplicate insert

      final all = await repository.transactions();
      expect(all.where((t) => t.merchant == 'Cloud salary'), hasLength(1));
    },
  );

  test(
    'applyCloudTransaction does not overwrite an unsynced local record (conflict)',
    () async {
      // Create a local transaction and mark it as synced with a cloud id.
      final id = await repository.saveTransaction(
        FinanceTransaction(
          amount: 1000,
          isIncome: false,
          category: 'Food',
          merchant: 'Local edit',
          occurredAt: DateTime.now(),
        ),
      );
      await repository.markTransactionSynced(id, 'cloud-tx-2');

      // Locally re-edit the record after it was synced. saveTransaction clears
      // sync metadata on update, so the local change needs re-upload.
      final updatedTx = FinanceTransaction(
        id: id,
        amount: 1000,
        isIncome: false,
        category: 'Food',
        merchant: 'Local edit v2',
        occurredAt: DateTime.now(),
      );
      await repository.saveTransaction(updatedTx);

      // Now apply cloud data for the same cloud id — conflict because local
      // has unsynced changes (is_synced was reset to 0 by saveTransaction).
      final cloud = FinanceTransaction(
        amount: 9999,
        isIncome: false,
        category: 'Food',
        merchant: 'Remote change',
        occurredAt: DateTime.now(),
      );
      final applied = await repository.applyCloudTransaction(
        cloud,
        'cloud-tx-2',
      );
      expect(applied, isFalse); // conflict — local unsynced change preserved

      final all = await repository.transactions();
      final local = all.firstWhere((t) => t.id == id);
      expect(local.merchant, 'Local edit v2'); // local value NOT overwritten
    },
  );

  test(
    'applyCloudGoal inserts remote goal once on repeated application',
    () async {
      final cloud = SavingsGoal(
        name: 'Cloud goal',
        target: 100000,
        saved: 25000,
        deadline: DateTime(2027, 1, 1),
        purpose: 'Test',
      );
      await repository.applyCloudGoal(cloud, 'cloud-goal-1');
      await repository.applyCloudGoal(cloud, 'cloud-goal-1');

      final goals = await repository.goals();
      expect(goals.where((g) => g.name == 'Cloud goal'), hasLength(1));
    },
  );

  test('removeSyncOperation clears a completed queue entry', () async {
    await repository.saveTransaction(
      FinanceTransaction(
        amount: 70,
        isIncome: false,
        category: 'Food',
        merchant: 'Clear me',
        occurredAt: DateTime.now(),
      ),
    );
    final pending = await repository.getPendingSyncOperations();
    expect(pending, isNotEmpty);
    await repository.removeSyncOperation(pending.first.id);
    final after = await repository.getPendingSyncOperations();
    expect(after.any((o) => o.id == pending.first.id), isFalse);
  });
}
