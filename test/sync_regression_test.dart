import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/firestore_models.dart';
import 'package:smart_save/data/firestore_repository.dart';
import 'package:smart_save/data/investment_analysis.dart';
import 'package:smart_save/data/investment_models.dart';
import 'package:smart_save/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory directory;
  late FinanceRepository local;
  late _Cloud cloud;
  late _Auth auth;
  late SyncService sync;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('smartsave-sync-test');
    local = await FinanceRepository.open(
      databasePath: '${directory.path}/account.db',
      currentUid: () => 'owner',
    );
    cloud = _Cloud();
    auth = _Auth()..currentUser = _User('owner');
    sync = SyncService(localRepo: local, cloudRepo: cloud, auth: auth);
    await sync.initialize();
  });

  tearDown(() async {
    sync.dispose();
    await local.close();
    await directory.delete(recursive: true);
  });

  const holding = PortfolioHolding(
    securityName: 'Synthetic holding',
    ticker: 'FIX',
    marketValueKzt: 12000,
  );

  test('remote document IDs and server timestamps survive decoding', () {
    final date = DateTime.utc(2026, 1, 1);
    final payload = FirestoreTransaction.fromLocal(
      FinanceTransaction(
        amount: 25,
        isIncome: false,
        category: 'Food',
        merchant: 'Fixture',
        occurredAt: date,
      ),
      '1',
    ).toFirestore();
    payload['updatedAt'] = Timestamp.fromDate(date);
    final result = FirestoreTransaction.fromJson(
      firestoreDocumentFields('real-remote-id', payload),
    );
    expect(result.id, 'real-remote-id');
    expect(result.updatedAt, date);
    expect(result.amount, 25);
  });

  test('response loss and restart retry the same remote document', () async {
    final id = await local.savePortfolioHolding(holding);
    final original = (await local.getPendingSyncOperations()).single;
    cloud.loseResponse = true;
    expect((await sync.pushLocalChanges()).failed, 1);
    expect((await local.getPendingSyncOperations()).single.id, original.id);
    final cloudId = cloud.holdings.keys.single;
    expect(cloudId, isNotEmpty);
    expect(cloudId, isNot(id.toString()));

    sync.dispose();
    await local.close();
    local = await FinanceRepository.open(
      databasePath: '${directory.path}/account.db',
      currentUid: () => 'owner',
    );
    sync = SyncService(localRepo: local, cloudRepo: cloud, auth: auth);
    expect((await sync.pushLocalChanges()).uploaded, 1);
    expect(cloud.holdings.keys, [cloudId]);
    expect(await local.getPendingSyncOperations(), isEmpty);
    expect((await local.getPortfolioHoldingById(id))?.id, id);
  });

  test(
    'local and remote investment deletion preserve history and pending edits',
    () async {
      final id = await local.savePortfolioHolding(holding);
      final date = DateTime.utc(2026, 1, 1);
      final thesisId = await local.saveInvestmentThesis(
        InvestmentThesis(
          securityName: 'Synthetic thesis',
          ticker: 'FIX',
          createdAt: date,
          updatedAt: date,
        ),
      );
      final thesis = (await local.getInvestmentThesisById(thesisId))!;
      await local.saveThesisAssessment(analyzeThesis(thesis, []));
      expect((await sync.pushLocalChanges()).uploaded, 2);

      final cloudHolding = cloud.holdings.values.single;
      expect(
        await local.savePortfolioHolding(
          PortfolioHolding(
            id: id,
            securityName: holding.securityName,
            ticker: holding.ticker,
            marketValueKzt: 17000,
          ),
        ),
        id,
      );
      cloud.holdings[cloudHolding.id] = cloudHolding.copyWith(
        version: cloudHolding.version + 1,
        isDeleted: true,
      );
      expect((await sync.pullRemoteChanges()).conflicts, 1);
      expect((await local.getPortfolioHoldingById(id))?.marketValueKzt, 17000);

      await local.deletePortfolioHolding(id);
      await local.deleteInvestmentThesis(thesisId);
      final changes = await sync.pushLocalChanges();
      expect(changes.uploaded, 1);
      expect(changes.conflicts, 1);
      expect(cloud.deleted, [cloud.theses.keys.single]);
      expect(await local.portfolioHoldings(), isEmpty);
      expect(await local.investmentTheses(), isEmpty);
      expect(await local.thesisAssessments(thesisId), hasLength(1));
      expect(await local.getPendingSyncOperations(), hasLength(2));
      expect((await sync.pullRemoteChanges()).conflicts, 1);
      expect(await local.thesisAssessments(thesisId), hasLength(1));
    },
  );

  test(
    'a deletion seals a reserved document even if the first upload never arrived',
    () async {
      final id = await local.savePortfolioHolding(holding);
      await local.deletePortfolioHolding(id);
      expect(
        (await local.getPendingSyncOperations()).map((op) => op.operation),
        ['create', 'delete'],
      );
      expect((await sync.pushLocalChanges()).uploaded, 2);
      expect(cloud.holdings.values.single.isDeleted, isTrue);
      expect(await local.portfolioHoldings(), isEmpty);
    },
  );

  test(
    'two offline edits to one holding preserve the losing device edit',
    () async {
      final holdingId = await local.savePortfolioHolding(holding);
      await sync.pushLocalChanges();
      final second = await FinanceRepository.open(
        databasePath: '${directory.path}/second.db',
        currentUid: () => 'owner',
      );
      addTearDown(second.close);
      final secondSync = SyncService(
        localRepo: second,
        cloudRepo: cloud,
        auth: auth,
      );
      addTearDown(secondSync.dispose);
      expect((await secondSync.pullRemoteChanges()).downloaded, 1);
      final otherId = (await second.portfolioHoldings()).single.id;
      await local.savePortfolioHolding(
        PortfolioHolding(
          id: holdingId,
          securityName: 'Fixture',
          ticker: 'FIX',
          marketValueKzt: 21000,
        ),
      );
      await second.savePortfolioHolding(
        PortfolioHolding(
          id: otherId,
          securityName: 'Fixture',
          ticker: 'FIX',
          marketValueKzt: 32000,
        ),
      );
      expect((await sync.pushLocalChanges()).uploaded, 1);
      expect((await secondSync.pushLocalChanges()).conflicts, 1);
      expect((await secondSync.pullRemoteChanges()).conflicts, 1);
      expect(cloud.holdings.values.single.marketValueKzt, 21000);
      expect((await second.portfolioHoldings()).single.marketValueKzt, 32000);
      expect(await second.getPendingSyncOperations(), hasLength(1));
    },
  );

  test(
    'transaction and goal tombstones reconcile with another device without altering unrelated rows',
    () async {
      final id = await local.saveTransaction(
        FinanceTransaction(
          amount: 75,
          isIncome: true,
          category: 'Income',
          merchant: 'Remote fixture transaction',
          occurredAt: DateTime.utc(2026, 2, 1),
        ),
      );
      final goalId = await local.saveGoal(
        SavingsGoal(
          name: 'Remote fixture goal',
          target: 500,
          saved: 0,
          deadline: DateTime.utc(2027),
          purpose: 'Synthetic',
        ),
      );
      expect((await sync.pushLocalChanges()).uploaded, 2);
      final second = await FinanceRepository.open(
        databasePath: '${directory.path}/second.db',
        currentUid: () => 'owner',
      );
      addTearDown(second.close);
      final secondSync = SyncService(
        localRepo: second,
        cloudRepo: cloud,
        auth: auth,
      );
      addTearDown(secondSync.dispose);
      final originalBalance = await second.totalBalance();
      expect((await secondSync.pullRemoteChanges()).downloaded, 2);
      expect(await second.totalBalance(), originalBalance + 75);
      await local.deleteTransaction(id);
      await local.deleteGoal(goalId);
      expect((await sync.pushLocalChanges()).uploaded, 2);
      expect((await secondSync.pullRemoteChanges()).downloaded, 2);
      expect(await second.totalBalance(), originalBalance);
      expect(
        (await second.transactions()).any(
          (tx) => tx.merchant == 'Remote fixture transaction',
        ),
        isFalse,
      );
      expect(
        (await second.goals()).any(
          (goal) => goal.name == 'Remote fixture goal',
        ),
        isFalse,
      );
    },
  );

  test(
    'an ambiguous older acknowledgement does not discard a newer local edit',
    () async {
      final id = await local.savePortfolioHolding(holding);
      cloud.loseResponse = true;
      expect((await sync.pushLocalChanges()).failed, 1);
      await local.savePortfolioHolding(
        PortfolioHolding(
          id: id,
          securityName: 'Fixture',
          ticker: 'FIX',
          marketValueKzt: 26000,
        ),
      );
      expect(await local.getPendingSyncOperations(), hasLength(2));
      final retry = await sync.pushLocalChanges();
      expect(retry.uploaded, 2);
      expect(cloud.holdings.values.single.version, 2);
      expect(cloud.holdings.values.single.marketValueKzt, 26000);
      expect(await local.getPendingSyncOperations(), isEmpty);
    },
  );

  test('a later remote edit prevents acknowledging a stale replay', () async {
    await local.savePortfolioHolding(holding);
    cloud.loseResponse = true;
    expect((await sync.pushLocalChanges()).failed, 1);
    final priorCommit = cloud.holdings.values.single;
    // Another client advanced the revision while retaining the old marker.
    cloud.holdings[priorCommit.id] = priorCommit.copyWith(
      version: priorCommit.version + 1,
      marketValueKzt: 55000,
    );
    expect((await sync.pushLocalChanges()).conflicts, 1);
    expect(await local.getPendingSyncOperations(), hasLength(1));
    expect(cloud.holdings.values.single.marketValueKzt, 55000);
  });

  test(
    'a response that arrives after an account switch is never applied',
    () async {
      final request = Completer<FirestoreResult<List<FirestoreTransaction>>>();
      final started = Completer<void>();
      cloud.readTransactions = () {
        started.complete();
        return request.future;
      };
      final pull = sync.pullRemoteChanges();
      await started.future;
      auth.currentUser = _User('other');
      request.complete(
        FirestoreResult.success([
          FirestoreTransaction.fromLocal(
            FinanceTransaction(
              amount: 25,
              isIncome: false,
              category: 'Food',
              merchant: 'Do not import',
              occurredAt: DateTime.utc(2026),
            ),
            '1',
          ).copyWith(id: 'other-remote-id'),
        ]),
      );
      expect((await pull).isNoAuth, isTrue);
      expect(
        (await local.transactions()).any(
          (row) => row.merchant == 'Do not import',
        ),
        isFalse,
      );
      expect((await sync.performFullSync()).isNoAuth, isTrue);
    },
  );
}

class _Auth implements FirebaseAuth {
  @override
  User? currentUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cloud implements FirestoreRepository {
  final transactions = <String, FirestoreTransaction>{};
  final goals = <String, FirestoreSavingsGoal>{};
  final holdings = <String, FirestorePortfolioHolding>{};
  final theses = <String, FirestoreInvestmentThesis>{};
  final deleted = <String>[];
  bool loseResponse = false;
  Future<FirestoreResult<List<FirestoreTransaction>>> Function()?
  readTransactions;

  @override
  Future<FirestoreResult<List<FirestoreTransaction>>> getTransactions({
    String? category,
    String? query,
    int? limit,
    Object? startAfter,
    bool includeDeleted = false,
  }) async => readTransactions == null
      ? FirestoreResult.success(
          transactions.values
              .where((row) => includeDeleted || !row.isDeleted)
              .toList(),
        )
      : readTransactions!();

  @override
  Future<FirestoreResult<List<FirestoreSavingsGoal>>> getGoals({
    bool includeDeleted = false,
  }) async => FirestoreResult.success(
    goals.values.where((row) => includeDeleted || !row.isDeleted).toList(),
  );

  @override
  Future<FirestoreResult<List<FirestoreBudget>>> getVersionedBudgets() async =>
      FirestoreResult.success([]);

  @override
  Future<FirestoreResult<List<FirestoreInvestmentSetting>>>
  getVersionedSettings() async => FirestoreResult.success([]);

  @override
  Future<FirestoreResult<List<FirestorePortfolioHolding>>>
  getPortfolioHoldings({bool includeDeleted = false}) async =>
      FirestoreResult.success(
        holdings.values
            .where((row) => includeDeleted || !row.isDeleted)
            .toList(),
      );

  @override
  Future<FirestoreResult<List<FirestoreInvestmentThesis>>> getInvestmentTheses({
    bool includeDeleted = false,
  }) async => FirestoreResult.success(
    theses.values.where((row) => includeDeleted || !row.isDeleted).toList(),
  );

  final mutations = <String, String>{};

  @override
  Future<FirestoreResult<int>> commitSyncMutation({
    required String entity,
    required FirestoreModel record,
    required int expectedRevision,
    required String mutationId,
    required bool deleted,
  }) async {
    final previous =
        holdings[record.id] ??
        theses[record.id] ??
        transactions[record.id] ??
        goals[record.id];
    if (mutations[record.id] == mutationId &&
        previous?.version == expectedRevision + 1) {
      return FirestoreResult.success(expectedRevision + 1);
    }
    if ((previous?.version ?? 0) != expectedRevision ||
        (previous?.isDeleted == true && !deleted)) {
      return FirestoreResult.failure(
        'Conflict',
        FirestoreErrorCode.failedPrecondition,
      );
    }
    final version = expectedRevision + 1;
    if (record is FirestoreTransaction) {
      transactions[record.id] = record.copyWith(
        version: version,
        isDeleted: deleted,
      );
    } else if (record is FirestoreSavingsGoal) {
      goals[record.id] = record.copyWith(version: version, isDeleted: deleted);
    } else if (record is FirestorePortfolioHolding) {
      holdings[record.id] = record.copyWith(
        version: version,
        isDeleted: deleted,
      );
    } else if (record is FirestoreInvestmentThesis) {
      theses[record.id] = record.copyWith(version: version, isDeleted: deleted);
    }
    mutations[record.id] = mutationId;
    if (deleted) this.deleted.add(record.id);
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Simulated lost acknowledgement');
    }
    return FirestoreResult.success(version);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
