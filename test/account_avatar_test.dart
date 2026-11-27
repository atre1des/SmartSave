import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_save/data/avatar_preferences.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/dashboard/dashboard_screen.dart';
import 'package:smart_save/features/profile/account_avatar.dart';
import 'package:smart_save/features/profile/my_account_screen.dart';
import 'package:smart_save/features/profile/profile_screen.dart';
import 'package:smart_save/l10n/generated/app_localizations.dart';
import 'package:smart_save/services/auth_service.dart';
import 'package:smart_save/shared/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('avatar is saved, shared across screens, restored and isolated', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = await FinanceRepository.open(
      databasePath: inMemoryDatabasePath,
      seed: false,
    );
    final auth = _TestAuth('first');
    addTearDown(repository.close);
    addTearDown(auth.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    Future<void> render({Widget? home}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            sharedPreferencesProvider.overrideWithValue(preferences),
            financeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home:
                home ??
                Consumer(
                  builder: (context, ref, _) {
                    return ref.watch(selectedTabIndexProvider) == 4
                        ? const MyAccountScreen()
                        : const DashboardScreen();
                  },
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final strings = lookupAppLocalizations(const Locale('en'));
    await render();
    expect(_shownAnimal(), findsNothing);
    await tester.tap(find.byTooltip(strings.openAccount));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(strings.chooseAvatar));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNWidgets(10));
    await tester.tap(find.text(strings.avatarPanda));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();
    expect(_shownAnimal(), findsOneWidget);
    expect(preferences.getString(avatarPreferenceKey('first')), 'panda');

    await tester.scrollUntilVisible(find.text(strings.profile), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.profile).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(ProfileDetailsScreen), findsOneWidget);
    expect(_shownAnimal(), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await preferences.reload();
    await render();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(_shownAnimal(), findsOneWidget);

    auth.switchTo('second');
    await tester.pumpAndSettle();
    expect(_shownAnimal(), findsNothing);
    expect(preferences.getString(avatarPreferenceKey('second')), isNull);
    auth.switchTo(null);
    await tester.pumpAndSettle();
    expect(_shownAnimal(), findsNothing);
    auth.switchTo('first');
    await tester.pumpAndSettle();
    expect(_shownAnimal(), findsOneWidget);

    await tester.tap(find.byTooltip(strings.openAccount));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(strings.chooseAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.resetAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
    expect(preferences.getString(avatarPreferenceKey('first')), 'panda');

    await tester.tap(find.byTooltip(strings.chooseAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.resetAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();
    expect(_shownAnimal(), findsNothing);
    expect(preferences.get(avatarPreferenceKey('first')), isNull);
  });

  for (final (language, brightness) in [
    ('en', Brightness.light),
    ('kk', Brightness.dark),
    ('ru', Brightness.light),
  ]) {
    testWidgets('localized $language picker in $brightness at 320 px', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        avatarPreferenceKey('first'): 'cat',
      });
      final preferences = await SharedPreferences.getInstance();
      final auth = _TestAuth('first');
      addTearDown(auth.close);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 844);
      addTearDown(tester.view.reset);
      final locale = Locale(language);
      final labels = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.65)),
              child: child!,
            ),
            home: const Scaffold(body: AccountAvatar(editable: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(labels.chooseAvatar));
      await tester.pumpAndSettle();
      expect(find.text(labels.chooseAvatar), findsOneWidget);
      final choice = find.bySemanticsLabel(labels.avatarCat);
      expect(choice, findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.getSize(choice).shortestSide, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
      auth.switchTo('second');
      await tester.pumpAndSettle();
      expect(find.text(labels.chooseAvatar), findsNothing);
      expect(_shownAnimal(), findsNothing);
    });
  }
}

Finder _shownAnimal() => find.descendant(
  of: find.byType(AccountAvatar),
  matching: find.byType(SvgPicture),
);

class _TestAuth implements AuthService {
  _TestAuth(String uid) : _user = _TestUser(uid);

  final _changes = StreamController<User?>.broadcast();
  User? _user;

  void switchTo(String? uid) {
    _user = uid == null ? null : _TestUser(uid);
    _changes.add(_user);
  }

  Future<void> close() => _changes.close();

  @override
  Stream<User?> get authStateChanges => Stream.multi((controller) {
    controller.add(_user);
    final subscription = _changes.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  @override
  FirebaseAuth get auth => _FirebaseAuth(_user);

  @override
  String? get currentUserEmail => 'student@example.com';

  @override
  String? getProfilePreference(String key) => null;

  @override
  String? getRiskProfile() => 'moderate';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUser implements User {
  _TestUser(this.uid);
  @override
  final String uid;
  @override
  String get displayName => 'Aruzhan';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FirebaseAuth implements FirebaseAuth {
  _FirebaseAuth(this.currentUser);
  @override
  final User? currentUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
