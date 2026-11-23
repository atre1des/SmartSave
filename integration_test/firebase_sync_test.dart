import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/firestore_repository.dart';
import 'package:smart_save/data/investment_models.dart';
import 'package:smart_save/services/sync_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'syncs native account SQLite through Auth and Firestore emulators',
    (_) async {
      const project = 'demo-smartsave-stage6';
      const host = String.fromEnvironment(
        'SMARTSAVE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      if (!const {'10.0.2.2', '127.0.0.1', 'localhost'}.contains(host)) {
        throw StateError('Use a local Firebase emulator.');
      }
      final marker = DateTime.now().microsecondsSinceEpoch;
      final fixturePassword = ['synthetic', 'fixture', '$marker'].join('-');
      final app = await Firebase.initializeApp(
        name: 'stage6-emulator-$marker',
        options: const FirebaseOptions(
          apiKey: 'synthetic-emulator-key',
          appId: '1:1234567890:android:12345abcd',
          messagingSenderId: '1234567890',
          projectId: project,
        ),
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
      final cloud = FirebaseFirestore.instanceFor(app: app);
      cloud.settings = const Settings(persistenceEnabled: false);
      cloud.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-firebase',
      );
      addTearDown(() async {
        await auth.signOut();
        await app.delete();
        await directory.delete(recursive: true);
      });

      final owner = (await auth.createUserWithEmailAndPassword(
        email: 'owner-$marker@example.test',
        password: fixturePassword,
      )).user!;
      final keySuffix = base64Url.encode(utf8.encode(owner.uid));
      addTearDown(
        () => const FlutterSecureStorage().delete(
          key: 'smartsave.sqlite.v1.$keySuffix',
        ),
      );
      final ownerDb = await directory.createTemp('owner-');
      final repository = await FinanceRepository.openForAccount(
        owner.uid,
        directory: ownerDb.path,
      );
      final service = SyncService(
        localRepo: repository,
        cloudRepo: FirestoreRepository(cloud, auth, expectedUid: owner.uid),
        auth: auth,
      );
      await cloud.disableNetwork();
      final holdingId = await repository.savePortfolioHolding(
        const PortfolioHolding(
          securityName: 'Synthetic integration holding',
          ticker: 'FIX',
          marketValueKzt: 25000,
        ),
      );
      await repository.savePortfolioHolding(
        const PortfolioHolding(
          securityName: 'Retained fixture',
          ticker: 'KEEP',
          marketValueKzt: 50000,
        ),
      );
      expect(await repository.getPendingSyncCount(), 2);
      await cloud.enableNetwork();
      expect((await service.pushLocalChanges()).uploaded, 2);
      expect(await repository.getPendingSyncCount(), 0);
      await service.pushLocalChanges();

      final remote = cloud.collection('users/${owner.uid}/portfolioHoldings');
      final remoteRows = (await remote.get()).docs;
      expect(remoteRows, hasLength(2));
      final reference = remoteRows
          .singleWhere((row) => row.data()['ticker'] == 'FIX')
          .reference;
      await repository.deletePortfolioHolding(holdingId);
      expect((await service.pushLocalChanges()).uploaded, 1);
      expect((await reference.get()).data()?['isDeleted'], true);
      service.dispose();
      await repository.close();

      await auth.signOut();
      final restored = (await auth.signInWithEmailAndPassword(
        email: 'owner-$marker@example.test',
        password: fixturePassword,
      )).user!;
      expect(restored.uid, owner.uid);
      final secondDb = await directory.createTemp('restored-');
      final next = await FinanceRepository.openForAccount(
        owner.uid,
        directory: secondDb.path,
      );
      final nextSync = SyncService(
        localRepo: next,
        cloudRepo: FirestoreRepository(cloud, auth, expectedUid: owner.uid),
        auth: auth,
      );
      addTearDown(() async {
        nextSync.dispose();
        await next.close();
      });
      expect((await nextSync.pullRemoteChanges()).isSuccess, true);
      expect((await next.portfolioHoldings()).single.marketValueKzt, 50000);

      await auth.signOut();
      await auth.createUserWithEmailAndPassword(
        email: 'other-$marker@example.test',
        password: fixturePassword,
      );
      expect((await nextSync.pullRemoteChanges()).isNoAuth, true);
      await expectLater(
        reference.get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
    skip: !(Platform.isAndroid || Platform.isIOS),
  );
}
