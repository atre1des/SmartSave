import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/app/app.dart';
import 'package:smart_save/services/auth_service.dart';
import 'package:smart_save/features/dashboard/dashboard_screen.dart';
import 'package:smart_save/shared/theme.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Widget tests use fake time and cannot await replies from a real isolate.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('demo onboarding reaches goals and transaction creation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final repository = await FinanceRepository.open(
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(repository.close);

    final verticalScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    final prefs = await SharedPreferences.getInstance();
    final auth = _TestAuthService(prefs);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<String?>(
        valueListenable: auth.sessionUid,
        builder: (context, uid, _) => ProviderScope(
          // Match the production session boundary that discards signed-out routes.
          key: ValueKey(uid),
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            sharedPreferencesProvider.overrideWithValue(prefs),
            if (uid != null)
              financeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(theme: buildAppTheme(), home: const AppEntry()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.edu',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'demo-pass-123');
    await tester.enterText(find.byType(TextFormField).at(2), 'demo-pass-123');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    await tester.tap(find.text("I've verified my email"));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Skip, add transactions manually'),
      250,
    );
    await tester.tap(find.text('Skip, add transactions manually'));
    await tester.pumpAndSettle();

    const answers = [
      'Sell everything to avoid more losses',
      'Within a year',
      'None yet',
      'Very little',
      'Protect what I have',
    ];
    for (var index = 0; index < answers.length; index++) {
      await tester.tap(find.text(answers[index]));
      await tester.pump();
      final next = find.text(
        index == answers.length - 1 ? 'See risk profile' : 'Next',
      );
      await tester.scrollUntilVisible(next, 250);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text('Continue to SmartSave'), 250);
    await tester.tap(find.text('Continue to SmartSave'));
    await tester.pumpAndSettle();

    final dashboardScroll = find
        .descendant(
          of: find.byType(DashboardScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final myGoals = find.text('My Goals');
    await tester.scrollUntilVisible(myGoals, 300, scrollable: dashboardScroll);
    await tester.tap(myGoals);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Capstone laptop');
    await tester.enterText(find.byType(TextFormField).at(1), '350000');
    await tester.scrollUntilVisible(
      find.text('Save goal'),
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(find.text('Capstone laptop'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final recent = find
        .ancestor(of: find.text('Recent'), matching: find.byType(Row))
        .first;
    await tester.scrollUntilVisible(
      find.text('Recent'),
      300,
      scrollable: dashboardScroll,
    );
    await tester.tap(
      find.descendant(of: recent, matching: find.text('See all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '2500');
    await tester.enterText(find.byType(TextFormField).at(1), 'Test lunch');
    await tester.scrollUntilVisible(
      find.text('Save'),
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Test lunch'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestAuthService implements AuthService {
  _TestAuthService(this._prefs);

  final SharedPreferences _prefs;
  final sessionUid = ValueNotifier<String?>(null);
  final _changes = StreamController<User?>.broadcast();
  _TestUser? _user;

  @override
  FirebaseAuth get auth => _TestFirebaseAuth(_user);

  @override
  String? getRiskProfile() => 'moderate';

  @override
  bool get isEmailVerified => _user?.emailVerified ?? false;

  @override
  Stream<User?> get authStateChanges => Stream.multi((controller) {
    controller.add(_user);
    final subscription = _changes.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    expect(email, 'student@example.edu');
    expect(password, 'demo-pass-123');
    _user = _TestUser(displayName, () => _changes.add(_user));
    sessionUid.value = _user!.uid;
    return AuthResult.ok();
  }

  @override
  Future<bool> isOnboardingComplete() async =>
      _prefs.getBool('onboarding_complete') ?? false;

  @override
  Future<void> setOnboardingComplete(bool complete) =>
      _prefs.setBool('onboarding_complete', complete);

  Future<void> dispose() async {
    sessionUid.dispose();
    await _changes.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestFirebaseAuth implements FirebaseAuth {
  _TestFirebaseAuth(this.currentUser);
  @override
  final User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUser implements User {
  _TestUser(this.displayName, this._onVerified);

  @override
  final String displayName;
  final VoidCallback _onVerified;
  @override
  String get uid => 'widget-test-account';
  @override
  bool emailVerified = false;

  @override
  Future<void> reload() async {
    emailVerified = true;
    _onVerified();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
