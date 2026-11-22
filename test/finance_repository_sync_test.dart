import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('markSyncOperationFailed increments retry_count from 0 to 1', () async {
    final dir = await Directory.systemTemp.createTemp('smartsave_sync_test');
    final dbPath = '${dir.path}/test.db';
    final repo = await FinanceRepository.open(databasePath: dbPath);
    final probe = await databaseFactoryFfi.openDatabase(dbPath);

    addTearDown(() async {
      await repo.close();
      await probe.close();
      await dir.delete(recursive: true);
    });

    await repo.initializeSync();

    await repo.recordSyncOperation(
      id: 'op-1',
      entityType: 'transaction',
      entityId: '1',
      operation: 'create',
      payload: <String, dynamic>{'amount': 100},
    );

    var rows = await probe.query(
      'sync_operations',
      where: 'id = ?',
      whereArgs: ['op-1'],
    );
    expect(rows.single['retry_count'], 0);
    expect(rows.single['status'], 'pending');

    await repo.markSyncOperationFailed('op-1', 'boom');

    rows = await probe.query(
      'sync_operations',
      where: 'id = ?',
      whereArgs: ['op-1'],
    );
    expect(rows.single['retry_count'], 1);
    expect(rows.single['status'], 'error');
    expect(rows.single['error_message'], 'boom');
  });
}
