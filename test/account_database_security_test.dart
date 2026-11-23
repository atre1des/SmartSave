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
    'account files isolate private records and preserve the shared database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-account-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final legacy = await FinanceRepository.open(
        databasePath: path.join(directory.path, 'smartsave_demo.db'),
      );
      await legacy.saveInvestmentSetting('private_test', 'legacy');
      await legacy.close();

      var alice = await FinanceRepository.openForAccount(
        'alice',
        directory: directory.path,
      );
      await alice.saveInvestmentSetting('private_test', 'alice-only');
      await alice.saveAssistantConversationHistory('[]');
      await alice.recordSyncOperation(
        id: 'alice-test-operation',
        entityType: 'investment_setting',
        entityId: 'private_test',
        operation: 'upsert',
        payload: {'key': 'private_test', 'value': 'alice-only'},
        ownerUid: 'alice',
      );
      await expectLater(
        alice.recordSyncOperation(
          id: 'cross-account',
          entityType: 'investment_setting',
          entityId: 'private_test',
          operation: 'create',
          payload: {},
          ownerUid: 'bob',
        ),
        throwsStateError,
      );
      await expectLater(alice.resetDemoData(), throwsStateError);
      await alice.close();

      final bob = await FinanceRepository.openForAccount(
        'bob',
        directory: directory.path,
      );
      expect((await bob.investmentSettings())['private_test'], isNull);
      expect(await bob.getPendingSyncOperations(), isEmpty);
      expect(await bob.assistantConversationHistory(), isNull);
      await bob.close();

      alice = await FinanceRepository.openForAccount(
        'alice',
        directory: directory.path,
      );
      expect((await alice.investmentSettings())['private_test'], 'alice-only');
      expect(await alice.assistantConversationHistory(), '[]');
      final pending = await alice.getPendingSyncOperations();
      expect(pending, isNotEmpty);
      expect(
        pending.map((operation) => operation.ownerUid),
        everyElement('alice'),
      );
      await alice.close();

      final original = await FinanceRepository.open(
        databasePath: path.join(directory.path, 'smartsave_demo.db'),
      );
      expect((await original.investmentSettings())['private_test'], 'legacy');
      await original.close();
    },
  );
}
