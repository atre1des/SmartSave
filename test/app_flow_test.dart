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
import 'package:smart_save/shared/appearance.dart';
import 'package:smart_save/shared/widgets.dart';
import 'package:smart_save/l10n/app_locale.dart';
import 'package:smart_save/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Widget tests use fake time and cannot await replies from a real isolate.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'compact account journey covers onboarding, finances, and export in ${mode.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 700);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        SharedPreferences.setMockInitialValues({'appearance_theme': mode.name});
        final repository = await FinanceRepository.open(
          databasePath: inMemoryDatabasePath,
          accountUid: 'widget-test-account',
          currentUid: () => 'widget-test-account',
          seed: false,
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
        final appearance = AppearanceController(prefs);
        addTearDown(appearance.dispose);
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
                appLocaleProvider.overrideWith(
                  (_) => AppLocaleController(preferences: prefs, uid: uid),
                ),
                if (uid != null)
                  financeRepositoryProvider.overrideWithValue(repository),
              ],
              child: AppearanceScope(
                controller: appearance,
                child: Consumer(
                  builder: (context, ref, _) => MaterialApp(
                    theme: buildAppTheme(),
                    darkTheme: buildAppTheme(Brightness.dark),
                    themeMode: AppearanceScope.of(context)!.value,
                    locale: ref.watch(appLocaleProvider).locale,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    home: const AppEntry(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Get started'));
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'student@example.edu',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'demo-pass-123',
        );
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'demo-pass-123',
        );
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
        await tester.scrollUntilVisible(
          find.text('Continue to SmartSave'),
          250,
        );
        await tester.tap(find.text('Continue to SmartSave'));
        await tester.pumpAndSettle();

        expect(find.text('Your finances'), findsOneWidget);
        await tester.tap(find.byTooltip('Open My Account'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AppNavigationBar>(find.byType(AppNavigationBar))
              .selectedIndex,
          4,
        );
        expect(find.byType(BackButton), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Your finances'), findsOneWidget);

        final dashboardScroll = find
            .descendant(
              of: find.byType(DashboardScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        final myGoals = find.text('Create your first goal');
        await tester.scrollUntilVisible(
          find.text('Recent'),
          140,
          scrollable: dashboardScroll,
        );
        expect(find.text('Recent'), findsOneWidget);
        await tester.scrollUntilVisible(
          myGoals.hitTestable(),
          120,
          scrollable: dashboardScroll,
        );
        expect(find.text('No goals yet'), findsOneWidget);
        await tester.tap(myGoals);
        await tester.pumpAndSettle();
        await tester.tap(find.text('New goal'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Capstone laptop',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '350000');
        await tester.scrollUntilVisible(
          find.text('Save goal'),
          250,
          scrollable: verticalScroll,
        );
        await tester.tap(find.text('Save goal'));
        await tester.pumpAndSettle();
        expect(find.text('Capstone laptop'), findsOneWidget);
        await tester.tap(find.text('Capstone laptop'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Add money'), 200);
        await tester.tap(find.text('Add money'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '35000');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          (await repository.goals())
              .singleWhere((goal) => goal.name == 'Capstone laptop')
              .saved,
          35000,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();
        tester.state<ScrollableState>(dashboardScroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Goal Progress'),
          150,
          scrollable: dashboardScroll,
        );
        expect(find.text('No goals yet'), findsNothing);
        final recent = find
            .ancestor(of: find.text('Recent'), matching: find.byType(Row))
            .first;
        final recentLink = find.descendant(
          of: recent,
          matching: find.text('See all'),
        );
        await tester.scrollUntilVisible(
          recentLink.hitTestable(),
          -120,
          scrollable: dashboardScroll,
        );
        await tester.tap(recentLink);
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
        await tester.pageBack();
        await tester.pumpAndSettle();
        final spendingHeading = find
            .ancestor(
              of: find.text('Top spending this month'),
              matching: find.byType(Row),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Top spending this month'),
          100,
          scrollable: dashboardScroll,
        );
        await tester.tap(
          find.descendant(of: spendingHeading, matching: find.text('See all')),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Food budget'), 200);
        expect(find.text('Food budget'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Invest'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Investment Intelligence'),
          200,
        );
        expect(find.text('Investment Intelligence'), findsOneWidget);
        expect(find.text('Price change'), findsOneWidget);
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();
        expect(find.text('Thesis Autopsy'), findsOneWidget);
        expect(find.text('Price change'), findsNothing);
        await tester.tap(find.text('AI'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AppNavigationBar>(find.byType(AppNavigationBar))
              .selectedIndex,
          2,
        );

        await tester.tap(find.byTooltip('Conversation History'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('New Chat'), findsOneWidget);
        await tester.tap(find.text('New Chat'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);

        await tester.tap(find.text('My Account'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Privacy & data'), 200);
        await tester.tap(find.text('Privacy & data'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Export local data'), 200);
        await tester.tap(find.text('Export local data'));
        await tester.pumpAndSettle();
        expect(find.text('Local data export'), findsOneWidget);
        expect(
          find.textContaining('Test lunch', findRichText: true),
          findsWidgets,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Log out'), 200);
        await tester.tap(find.text('Log out'));
        await tester.pumpAndSettle();
        expect(find.byType(AppNavigationBar), findsNothing);

        await tester.ensureVisible(find.text('I already have an account'));
        await tester.tap(find.text('I already have an account'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'student@example.edu',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'demo-pass-123',
        );
        final signIn = find.widgetWithText(FilledButton, 'Sign in');
        await tester.ensureVisible(signIn);
        await tester.tap(signIn);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Test lunch'),
          200,
          scrollable: dashboardScroll,
        );
        expect(find.text('Test lunch'), findsOneWidget);
        await tester.tap(find.text('My Account'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Profile'), 180);
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        final languageMenu = find.byType(DropdownButtonFormField<Locale>);
        await tester.ensureVisible(languageMenu);
        await tester.tap(languageMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Қазақша').last);
        await tester.pumpAndSettle();
        expect(find.text('Тіл'), findsOneWidget);
        expect(find.text('Профиль'), findsOneWidget);
        expect(prefs.getString('profile_language_widget-test-account'), 'kk');
        final appearanceMenu = find.byType(DropdownButtonFormField<ThemeMode>);
        await tester.ensureVisible(appearanceMenu);
        await tester.tap(appearanceMenu);
        await tester.pumpAndSettle();
        final newMode = mode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
        await tester.tap(
          find.text(newMode == ThemeMode.dark ? 'Күңгірт' : 'Ашық').last,
        );
        await tester.pumpAndSettle();
        final profileContext = tester.element(find.text('Профиль'));
        expect(
          Theme.of(profileContext).brightness,
          newMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(prefs.getString('appearance_theme'), newMode.name);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Басты бет'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
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

  _TestUser? _registered;

  @override
  String? get currentUserEmail => _user == null ? null : 'student@example.edu';

  @override
  String? getProfilePreference(String key) => null;

  @override
  String? get currentUserId => _user?.uid;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    expect(email, 'student@example.edu');
    expect(password, 'demo-pass-123');
    _user = _registered;
    sessionUid.value = _user!.uid;
    _changes.add(_user);
    return AuthResult.ok();
  }

  @override
  Future<AuthResult> signOut() async {
    _registered = _user;
    _user = null;
    sessionUid.value = null;
    _changes.add(null);
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
