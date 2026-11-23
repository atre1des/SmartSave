import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/firestore_repository.dart';
import 'package:smart_save/services/sync_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'deletes a disposable Firebase account and its native encrypted cache',
    (_) async {
      const enabled = bool.fromEnvironment('SMARTSAVE_EMULATOR_DELETION');
      const host = String.fromEnvironment(
        'SMARTSAVE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      if (!enabled || !const {'10.0.2.2', '127.0.0.1'}.contains(host)) {
        throw StateError(
          'Use only the explicitly enabled local deletion emulator.',
        );
      }
      const project = 'demo-smartsave-stage6';
      final marker = DateTime.now().microsecondsSinceEpoch;
      final email = 'delete-$marker@example.test';
      final passwordFixture = ['fixture', 'synthetic', '$marker'].join('-');
      final app = await Firebase.initializeApp(
        name: 'deletion-$marker',
        options: const FirebaseOptions(
          apiKey: 'synthetic-emulator-key',
          appId: '1:1234567890:android:12345abcd',
          messagingSenderId: '1234567890',
          projectId: project,
        ),
      );
      addTearDown(app.delete);
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.settings = const Settings(persistenceEnabled: false);
      firestore.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
      final user = (await auth.createUserWithEmailAndPassword(
        email: email,
        password: passwordFixture,
      )).user!;
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-native-delete',
      );
      addTearDown(() => directory.delete(recursive: true));
      final suffix = base64Url.encode(utf8.encode(user.uid));
      final key = 'smartsave.sqlite.v1.$suffix';
      const storage = FlutterSecureStorage();
      addTearDown(() => storage.delete(key: key));
      final pref = 'onboarding_complete_${user.uid}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(pref, true);
      addTearDown(() => prefs.remove(pref));
      final repository = await FinanceRepository.openForAccount(
        user.uid,
        directory: directory.path,
      );
      addTearDown(repository.close);
      expect(await storage.containsKey(key: key), isTrue);
      expect(prefs.containsKey(key), isFalse);

      await repository.saveBudget('Fixture', 450);
      var called = false;
      await expectLater(
        repository.deleteAccountData(user.uid, () async {
          called = true;
        }),
        throwsStateError,
      );
      expect(called, isFalse);

      final cloudRepo = FirestoreRepository(
        firestore,
        auth,
        expectedUid: user.uid,
      );
      final sync = SyncService(
        localRepo: repository,
        cloudRepo: cloudRepo,
        auth: auth,
      );
      addTearDown(sync.dispose);
      expect((await sync.pushLocalChanges()).uploaded, 1);
      final remote = firestore.doc('users/${user.uid}/budgets/Fixture');
      expect(
        (await remote.get(const GetOptions(source: Source.server))).exists,
        isTrue,
      );

      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: passwordFixture),
      );
      final token = await user.getIdToken(true);
      expect(token != null, isTrue);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      addTearDown(() => client.close(force: true));
      await repository.deleteAccountData(
        user.uid,
        () async {
          final request = await client.postUrl(
            Uri.http('$host:3001', '/api/account/delete-data'),
          );
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          final response = await request.close().timeout(
            const Duration(seconds: 30),
          );
          await response.drain<void>();
          expect(response.statusCode, HttpStatus.noContent);
        },
        clearPreferences: (_) async {
          expect(await prefs.remove(pref), isTrue);
        },
      );

      expect(await storage.containsKey(key: key), isFalse);
      expect(prefs.containsKey(pref), isFalse);
      expect(
        await directory.list().any(
          (entry) => entry.path.contains('smartsave_account_$suffix'),
        ),
        isFalse,
      );
      await expectLater(
        remote.get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await user.delete();
      await expectLater(
        auth.signInWithEmailAndPassword(
          email: email,
          password: passwordFixture,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
    skip: !(Platform.isAndroid || Platform.isIOS),
  );
}
