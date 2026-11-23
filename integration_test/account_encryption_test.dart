import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:smart_save/data/finance_repository.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SQLCipher migrates, reopens and rejects an incorrect key',
    (_) async {
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-encrypted',
      );
      final uid = 'encryption-fixture-${DateTime.now().microsecondsSinceEpoch}';
      final encoded = base64Url.encode(utf8.encode(uid));
      final prefix = path.join(directory.path, 'smartsave_account_$encoded');
      final original = '$prefix.db';
      final protected = '$prefix.encrypted.db';
      addTearDown(() async {
        await const FlutterSecureStorage(
          mOptions: MacOsOptions(usesDataProtectionKeychain: false),
        ).delete(key: 'smartsave.sqlite.v1.$encoded');
        await directory.delete(recursive: true);
      });

      final sample = await cipher.openDatabase(original);
      await sample.execute(
        'CREATE TABLE investment_settings (key TEXT PRIMARY KEY, value TEXT)',
      );
      await sample.insert('investment_settings', {
        'key': 'fixture',
        'value': 'migration',
      });
      await sample.close();

      var account = await FinanceRepository.openForAccount(
        uid,
        directory: directory.path,
      );
      expect((await account.investmentSettings())['fixture'], 'migration');
      await account.saveInvestmentSetting('after-migration', 'reopen');
      await account.close();
      expect(await File(original).exists(), isTrue);

      final file = await File(protected).open();
      final header = await file.read(16);
      await file.close();
      expect(
        header,
        isNot(orderedEquals(utf8.encode('SQLite format 3\u0000'))),
      );

      await expectLater(() async {
        final wrong = await cipher.openDatabase(
          protected,
          password: 'intentionally-incorrect-test-password',
          readOnly: true,
          singleInstance: false,
        );
        try {
          await wrong.rawQuery('SELECT count(*) FROM sqlite_master');
        } finally {
          await wrong.close();
        }
      }, throwsA(anything));

      account = await FinanceRepository.openForAccount(
        uid,
        directory: directory.path,
      );
      expect((await account.investmentSettings())['after-migration'], 'reopen');
      await account.close();
    },
    skip: !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS),
  );
  testWidgets(
    'an interrupted import can retry using the original and a separate account key',
    (_) async {
      const storage = FlutterSecureStorage(
        mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      );
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-encryption-retry',
      );
      final marker = DateTime.now().microsecondsSinceEpoch;
      final uid = 'migration-$marker';
      final otherUid = 'other-$marker';
      final encoded = base64Url.encode(utf8.encode(uid));
      final otherEncoded = base64Url.encode(utf8.encode(otherUid));
      final primaryKeyName = 'smartsave.sqlite.v1.$encoded';
      final otherKeyName = 'smartsave.sqlite.v1.$otherEncoded';
      final original = path.join(
        directory.path,
        'smartsave_account_$encoded.db',
      );
      addTearDown(() async {
        await storage.delete(key: primaryKeyName);
        await storage.delete(key: otherKeyName);
        await directory.delete(recursive: true);
      });

      var source = await cipher.openDatabase(original);
      await source.execute(
        'CREATE TABLE investment_settings (key TEXT PRIMARY KEY, value TEXT)',
      );
      await source.insert('investment_settings', {
        'key': 'fixture',
        'value': 'retained',
      });
      await source.execute(
        'CREATE TABLE unexpected_fixture (id INTEGER PRIMARY KEY)',
      );
      await source.close();
      await expectLater(
        FinanceRepository.openForAccount(uid, directory: directory.path),
        throwsStateError,
      );

      // Only the synthetic obstruction is removed. The retained row must
      // survive the unsuccessful attempt and still be available to import.
      source = await cipher.openDatabase(original);
      expect(
        (await source.query('investment_settings')).single['value'],
        'retained',
      );
      await source.execute('DROP TABLE unexpected_fixture');
      await source.close();
      final account = await FinanceRepository.openForAccount(
        uid,
        directory: directory.path,
      );
      final other = await FinanceRepository.openForAccount(
        otherUid,
        directory: directory.path,
      );
      addTearDown(account.close);
      addTearDown(other.close);
      expect((await account.investmentSettings())['fixture'], 'retained');
      expect((await other.investmentSettings())['fixture'], isNull);
      final firstKey = await storage.read(key: primaryKeyName);
      final otherKey = await storage.read(key: otherKeyName);
      expect(
        firstKey != null && otherKey != null && firstKey != otherKey,
        isTrue,
      );
      expect(await File(original).exists(), isTrue);
    },
    skip: !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS),
  );
}
