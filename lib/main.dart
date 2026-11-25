import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/providers.dart';
import 'platform_web/workspace_stub.dart'
    if (dart.library.js_interop) 'platform_web/workspace.dart';
import 'data/finance_repository.dart';
import 'features/app/app.dart';
import 'features/app/account_sync_scope.dart';
import 'features/advice/assistant_session.dart';
import 'l10n/app_locale.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'shared/theme.dart';
import 'shared/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (await runBrowserWorkspace()) return;

  final prefs = await SharedPreferences.getInstance();
  final appearance = AppearanceController(prefs);

  if (!await firebaseService.initialize()) {
    runApp(
      AppearanceScope(
        controller: appearance,
        child: const _SessionApp(_SessionProblem.authentication),
      ),
    );
    return;
  }

  // SQLite supplies offline storage. Avoid adding a second persistent cache.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  final auth = AuthService(prefs);
  await auth.initialize();
  runApp(
    AppearanceScope(
      controller: appearance,
      child: _AccountSessions(auth: auth, prefs: prefs),
    ),
  );
}

class _AccountSessions extends StatefulWidget {
  const _AccountSessions({required this.auth, required this.prefs});

  final AuthService auth;
  final SharedPreferences prefs;

  @override
  State<_AccountSessions> createState() => _AccountSessionsState();
}

class _AccountSessionsState extends State<_AccountSessions> {
  late final _uids = widget.auth.authStateChanges
      .map((user) => user?.uid)
      .distinct();

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
    stream: _uids,
    initialData: widget.auth.currentUserId,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _SessionApp(_SessionProblem.authentication);
      }
      return _AccountSession(
        key: ValueKey(snapshot.data),
        uid: snapshot.data,
        auth: widget.auth,
        prefs: widget.prefs,
      );
    },
  );
}

class _AccountSession extends StatefulWidget {
  const _AccountSession({
    super.key,
    required this.uid,
    required this.auth,
    required this.prefs,
  });

  final String? uid;
  final AuthService auth;
  final SharedPreferences prefs;

  @override
  State<_AccountSession> createState() => _AccountSessionState();
}

class _AccountSessionState extends State<_AccountSession> {
  FinanceRepository? _repository;

  late final Future<FinanceRepository?> _opening = _open();

  Future<FinanceRepository?> _open() async {
    final uid = widget.uid;
    if (uid == null) return null;
    final repository = await FinanceRepository.openForAccount(uid);
    if (!mounted || widget.auth.currentUserId != uid) {
      await repository.close();
      return null;
    }
    _repository = repository;
    return repository;
  }

  @override
  void dispose() {
    final repository = _repository;
    if (repository != null) unawaited(repository.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FinanceRepository?>(
    future: _opening,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _SessionApp(_SessionProblem.storage);
      }
      if (snapshot.connectionState != ConnectionState.done ||
          (widget.uid != null && !snapshot.hasData)) {
        return const _SessionApp();
      }
      final repository = snapshot.data;
      return ProviderScope(
        overrides: [
          if (repository != null)
            financeRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(widget.prefs),
          appLocaleProvider.overrideWith(
            (_) =>
                AppLocaleController(preferences: widget.prefs, uid: widget.uid),
          ),
          authServiceProvider.overrideWithValue(widget.auth),
        ],
        child: AccountSyncScope(uid: widget.uid, child: const SmartSaveApp()),
      );
    },
  );
}

enum _SessionProblem { authentication, storage }

class _SessionApp extends StatelessWidget {
  const _SessionApp([this.problem]);

  final _SessionProblem? problem;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(Brightness.dark),
    themeMode: AppearanceScope.of(context)?.value ?? ThemeMode.system,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: AppLocaleController.resolve,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: switch (problem) {
            _SessionProblem.authentication => Text(
              context.l10n.authUnavailable,
            ),
            _SessionProblem.storage => Text(context.l10n.localRecordsError),
            null => const CircularProgressIndicator(),
          },
        ),
      ),
    ),
  );
}

class SmartSaveApp extends ConsumerWidget {
  const SmartSaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: ref.watch(appLocaleProvider).locale,
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(Brightness.dark),
    themeMode: AppearanceScope.of(context)?.value ?? ThemeMode.system,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: AppLocaleController.resolve,
    navigatorKey: appNavigatorKey,
    title: 'SmartSave',
    debugShowCheckedModeBanner: false,
    home: const AppEntry(),
  );
}
