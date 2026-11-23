import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:smart_save/data/finance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'confirmed recovery retains stable IDs and queues, is idempotent, and preserves the source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-recovery',
      );
      addTearDown(() => directory.delete(recursive: true));
      final originalPath = path.join(directory.path, 'smartsave_demo.db');
      final legacy = await databaseFactory.openDatabase(originalPath);
      await legacy.execute(
        'CREATE TABLE investment_settings (key TEXT PRIMARY KEY, value TEXT)',
      );
      await legacy.insert('investment_settings', {
        'key': 'legacy-key',
        'value': 'legacy-value',
      });
      await legacy.execute(
        'CREATE TABLE sync_operations (id TEXT PRIMARY KEY, entity_type TEXT, entity_id TEXT, operation TEXT, payload TEXT, created_at TEXT, status TEXT, owner_uid TEXT)',
      );
      await legacy.insert('sync_operations', {
        'id': 'legacy-operation',
        'entity_type': 'investment_setting',
        'entity_id': 'legacy-key',
        'operation': 'create',
        'payload': '{}',
        'created_at': '2026-01-01T00:00:00Z',
        'status': 'pending',
        'owner_uid': 'alice',
      });
      await legacy.close();
      final alice = await FinanceRepository.openForAccount(
        'alice',
        directory: directory.path,
      );
      addTearDown(alice.close);
      await expectLater(
        alice.importLegacyAccountData('alice', ownershipConfirmed: false),
        throwsStateError,
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await alice.importLegacyAccountData(
          'alice',
          ownershipConfirmed: true,
          assistantHistory: '[]',
        );
      }
      expect((await alice.investmentSettings())['legacy-key'], 'legacy-value');
      expect(
        (await alice.getPendingSyncOperations()).single.id,
        'legacy-operation',
      );
      expect(await alice.assistantConversationHistory(), '[]');
      final source = await databaseFactory.openDatabase(originalPath);
      expect(
        (await source.query('investment_settings')).single['key'],
        'legacy-key',
      );
      await source.close();
      final bob = await FinanceRepository.openForAccount(
        'bob',
        directory: directory.path,
      );
      addTearDown(bob.close);
      await expectLater(
        bob.importLegacyAccountData('bob', ownershipConfirmed: true),
        throwsStateError,
      );
    },
  );

  test('legacy rows replace only untouched sample records', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartsave-sample-recovery',
    );
    addTearDown(() => directory.delete(recursive: true));
    final legacy = await FinanceRepository.open(
      databasePath: path.join(directory.path, 'smartsave_demo.db'),
    );
    final legacyId = await legacy.saveTransaction(
      FinanceTransaction(
        amount: 777,
        isIncome: false,
        category: 'Recovery',
        merchant: 'Fixture',
        occurredAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await legacy.close();

    final account = await FinanceRepository.openForAccount(
      'alice',
      directory: directory.path,
    );
    addTearDown(account.close);
    expect(await account.getTransactionById(legacyId), isNull);
    await account.importLegacyAccountData('alice', ownershipConfirmed: true);
    expect((await account.getTransactionById(legacyId))?.amount, 777);
    final retained = await account.getPendingSyncOperations();
    expect(retained.single.ownerUid, isNull);
  });

  test(
    'export is account-bound and excludes internal tables and another account',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-export',
      );
      addTearDown(() => directory.delete(recursive: true));
      final alice = await FinanceRepository.openForAccount(
        'alice',
        directory: directory.path,
      );
      addTearDown(alice.close);
      final bob = await FinanceRepository.openForAccount(
        'bob',
        directory: directory.path,
      );
      addTearDown(bob.close);
      await alice.saveInvestmentSetting('alice-export', 'local-value');
      await bob.saveInvestmentSetting('bob-only', 'private-value');
      await alice.saveAssistantConversationHistory(
        '[{"id":"private-history"}]',
      );
      final raw = await alice.exportAccountData('alice');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['source'], 'local_account_cache');
      expect(decoded['records'], contains('transactions'));
      expect(decoded['records'], contains('goals'));
      expect(decoded['records'], contains('budgets'));
      expect(decoded['records'], isNot(contains('preferences')));
      expect(decoded['records'], isNot(contains('sync_operations')));
      expect(raw, contains('alice-export'));
      expect(raw, isNot(contains('bob-only')));
      expect(raw, isNot(contains('private-history')));
      await expectLater(alice.exportAccountData('bob'), throwsStateError);
    },
  );
  test(
    'deletion preserves local records on pending writes or remote failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-deletion',
      );
      addTearDown(() => directory.delete(recursive: true));
      final alice = await FinanceRepository.openForAccount(
        'alice',
        directory: directory.path,
      );
      final bob = await FinanceRepository.openForAccount(
        'bob',
        directory: directory.path,
      );
      addTearDown(bob.close);
      await bob.saveInvestmentSetting('private', 'bob');
      await alice.saveAssistantConversationHistory('[]');
      await alice.recordSyncOperation(
        id: 'pending',
        entityType: 'transaction',
        entityId: '1',
        operation: 'create',
        payload: {},
        ownerUid: 'alice',
      );
      var calls = 0;
      Future<void> failCloud() async {
        calls++;
        throw StateError('Remote failure');
      }

      await expectLater(
        alice.deleteAccountData('alice', failCloud),
        throwsStateError,
      );
      expect(calls, 0);
      await alice.removeSyncOperation('pending');
      await expectLater(
        alice.deleteAccountData('alice', failCloud),
        throwsStateError,
      );
      expect(calls, 1);
      expect(await alice.assistantConversationHistory(), '[]');
      await alice.deleteAccountData('alice', () async {
        calls++;
      });
      expect(calls, 2);
      expect(
        await databaseFactory.databaseExists(
          path.join(directory.path, 'smartsave_account_YWxpY2U=.db'),
        ),
        isFalse,
      );
      expect((await bob.investmentSettings())['private'], 'bob');
    },
  );
}
