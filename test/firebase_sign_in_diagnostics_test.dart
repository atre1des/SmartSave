import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/app/app.dart';
import 'package:smart_save/l10n/generated/app_localizations.dart';
import 'package:smart_save/services/auth_service.dart';

void main() {
  testWidgets('sign-in screen displays a safe SDK code in debug', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final auth = AuthService(
      preferences,
      auth: _Auth(_User(), code: 'keychain-error'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuthScreen(signUp: false),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'student@example.test');
    await tester.enterText(fields.last, 'private-password');
    final submit = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final notice = find.descendant(
      of: find.byType(SnackBar),
      matching: find.textContaining(
        'signInWithEmailAndPassword / keychain-error',
      ),
    );
    expect(notice, findsOneWidget);
    expect(
      tester.widget<Text>(notice).data,
      isNot(contains('private-response')),
    );
  });

  group('password sign-in service', () {
    late SharedPreferences preferences;
    late List<String> logs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      logs = [];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = original);
    });

    test('iOS credential rejection never attempts a user reload', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final user = _User();
      final auth = _Auth(user, code: 'invalid-credential');
      final result = await AuthService(
        preferences,
        auth: auth,
      ).signIn(email: ' student@example.test ', password: 'private-password');

      expect(auth.inputEmail, 'student@example.test');
      expect(result.success, isFalse);
      expect(result.errorCode, AuthExceptionCode.invalidCredential);
      expect(
        result.debugDiagnostic,
        'signInWithEmailAndPassword / invalid-credential',
      );
      expect(user.reloadCalls, 0);
      expect(
        logs.single,
        contains('iOS signInWithEmailAndPassword / invalid-credential'),
      );
      expect(logs.join(), isNot(contains('student@example.test')));
      expect(logs.join(), isNot(contains('private-password')));
    });

    test(
      'reload errors report the later phase after accepted credentials',
      () async {
        final user = _User(code: 'network-request-failed');
        final result = await AuthService(
          preferences,
          auth: _Auth(user),
        ).signIn(email: 'student@example.test', password: 'private-password');

        expect(user.reloadCalls, 1);
        expect(result.success, isFalse);
        expect(result.errorCode, AuthExceptionCode.networkError);
        expect(
          result.debugDiagnostic,
          'reloadAfterSignIn / network-request-failed',
        );
        expect(logs.first, contains('signInWithEmailAndPassword succeeded'));
        expect(
          logs.last,
          contains('reloadAfterSignIn / network-request-failed'),
        );
        expect(logs.join(), isNot(contains('private-response')));
      },
    );

    test('unexpected SDK codes and exception messages stay private', () async {
      final result = await AuthService(
        preferences,
        auth: _Auth(_User(), code: 'private-response'),
      ).signIn(email: 'student@example.test', password: 'private-password');

      expect(result.errorCode, AuthExceptionCode.unknown);
      expect(
        result.debugDiagnostic,
        'signInWithEmailAndPassword / unrecognized-firebase-code',
      );
      expect(logs.join(), isNot(contains('private-response')));
    });

    test(
      'successful credentials and reload preserve the credential result',
      () async {
        final user = _User();
        final result = await AuthService(
          preferences,
          auth: _Auth(user),
        ).signIn(email: 'student@example.test', password: 'private-password');

        expect(result.success, isTrue);
        expect(result.credential?.user, same(user));
        expect(user.reloadCalls, 1);
        expect(result.debugDiagnostic, isNull);
        expect(logs.last, contains('reloadAfterSignIn succeeded'));
      },
    );
  });
}

class _Auth implements FirebaseAuth {
  _Auth(this.currentUser, {this.code});

  @override
  final User currentUser;
  final String? code;
  String? inputEmail;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    inputEmail = email;
    if (code case final error?) {
      throw FirebaseAuthException(
        code: error,
        message: '$email $password private-response',
      );
    }
    return _Credential(currentUser);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(this.user);
  @override
  final User user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User({this.code});
  final String? code;
  int reloadCalls = 0;

  @override
  Future<void> reload() async {
    reloadCalls++;
    if (code case final error?) {
      throw FirebaseAuthException(code: error, message: 'private-response');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
