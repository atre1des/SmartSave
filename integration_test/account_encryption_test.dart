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
}
