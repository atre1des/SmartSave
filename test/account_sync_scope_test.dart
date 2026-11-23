import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/app/account_sync_scope.dart';
import 'package:smart_save/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _user = StateProvider<User?>((_) => null);

void main() {
  testWidgets(
    'account scope starts, debounces, resumes, retries and unmounts sync',
    (tester) async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final local = await FinanceRepository.open(
        databasePath: inMemoryDatabasePath,
        currentUid: () => 'owner',
      );
      addTearDown(local.close);
      final service = _Sync();
      addTearDown(service.network.close);
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(ref.watch(_user)),
          ),
          financeRepositoryProvider.overrideWithValue(local),
          syncServiceProvider.overrideWith((_) => service),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AccountSyncScope(uid: 'owner', child: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      container.read(_user.notifier).state = _User('other', true);
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      container.read(_user.notifier).state = _User('owner', false);
      await tester.pumpAndSettle();
      expect(service.calls, 0);

      container.read(_user.notifier).state = _User('owner', true);
      await tester.pumpAndSettle();
      expect(service.calls, 1);

      const edits = Duration(milliseconds: 400);
      for (var index = 0; index < 2; index++) {
        await local.saveBudget('Fixture $index', 150);
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.calls, 1);
      await tester.pump(edits);
      expect(service.calls, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      service.network.add(true);
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.calls, 3);

      service.result = SyncResult.offline('fixture');
      container.read(syncRequestProvider.notifier).state++;
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.calls, 4);
      await tester.pump(const Duration(seconds: 5));
      expect(service.calls, 5);
      service.result = SyncResult.success();
      service.network.add(true);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.calls, 6);
      await tester.pump(const Duration(minutes: 2));
      expect(service.calls, 6);

      container.read(_user.notifier).state = null;
      await tester.pumpAndSettle();
      service.network.add(true);
      container.read(syncRequestProvider.notifier).state++;
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.calls, 6);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Sync extends ChangeNotifier implements SyncService {
  final network = StreamController<bool>.broadcast();
  int calls = 0;
  SyncResult result = SyncResult.success();

  @override
  Stream<bool> get connectionChanges => network.stream;

  @override
  Future<SyncResult> performFullSync() async {
    calls++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid, this.emailVerified);
  @override
  final String uid;
  @override
  final bool emailVerified;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
