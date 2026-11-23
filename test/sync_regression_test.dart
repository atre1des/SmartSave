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
      cloud.holdings[cloudHolding.id] = cloudHolding.copyWith(isDeleted: true);
      expect((await sync.pullRemoteChanges()).conflicts, 1);
      expect((await local.getPortfolioHoldingById(id))?.marketValueKzt, 17000);

      await local.deletePortfolioHolding(id);
      await local.deleteInvestmentThesis(thesisId);
      expect((await sync.pushLocalChanges()).uploaded, 2);
      expect(
        cloud.deleted,
        containsAll([cloudHolding.id, cloud.theses.keys.single]),
      );
      expect(await local.portfolioHoldings(), isEmpty);
      expect(await local.investmentTheses(), isEmpty);
      expect(await local.thesisAssessments(thesisId), hasLength(1));
      expect(await local.getPendingSyncOperations(), isEmpty);
      expect((await sync.pullRemoteChanges()).isSuccess, isTrue);
      expect(await local.thesisAssessments(thesisId), hasLength(1));
    },
  );

  test(
    'a deletion seals a reserved document even if the first upload never arrived',
    () async {
      final id = await local.savePortfolioHolding(holding);
      await local.deletePortfolioHolding(id);
      expect(
        (await local.getPendingSyncOperations()).single.operation,
        'delete',
      );
      expect((await sync.pushLocalChanges()).uploaded, 1);
      expect(cloud.holdings.values.single.isDeleted, isTrue);
      expect(await local.portfolioHoldings(), isEmpty);
    },
  );

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
  }) async => readTransactions == null
      ? FirestoreResult.success([])
      : readTransactions!();

  @override
  Future<FirestoreResult<List<FirestoreSavingsGoal>>> getGoals() async =>
      FirestoreResult.success([]);

  @override
  Future<FirestoreResult<Map<String, int>>> getBudgets() async =>
      FirestoreResult.success({});

  @override
  Future<FirestoreResult<Map<String, String>>> getInvestmentSettings() async =>
      FirestoreResult.success({});

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

  @override
  Future<FirestoreResult<FirestorePortfolioHolding>> savePortfolioHolding(
    FirestorePortfolioHolding holding,
  ) async {
    holdings[holding.id] = holding;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Simulated lost acknowledgement');
    }
    return FirestoreResult.success(holding);
  }

  @override
  Future<FirestoreResult<FirestoreInvestmentThesis>> saveInvestmentThesis(
    FirestoreInvestmentThesis thesis,
  ) async {
    theses[thesis.id] = thesis;
    return FirestoreResult.success(thesis);
  }

  @override
  Future<FirestoreResult<void>> deletePortfolioHolding(
    FirestorePortfolioHolding snapshot,
  ) async {
    final id = snapshot.id;
    deleted.add(id);
    holdings[id] = (holdings[id] ?? snapshot).copyWith(isDeleted: true);
    return FirestoreResult.ok();
  }

  @override
  Future<FirestoreResult<void>> deleteInvestmentThesis(
    FirestoreInvestmentThesis snapshot,
  ) async {
    final id = snapshot.id;
    deleted.add(id);
    theses[id] = (theses[id] ?? snapshot).copyWith(isDeleted: true);
    return FirestoreResult.ok();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
