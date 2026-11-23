import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/providers.dart';
import 'data/finance_repository.dart';
import 'features/app/app.dart';
import 'features/advice/assistant_session.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'shared/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!await firebaseService.initialize()) {
    runApp(
      const MaterialApp(home: _SessionStatus('Authentication is unavailable.')),
    );
    return;
  }

  // SQLite supplies offline storage. Avoid adding a second persistent cache.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthService(prefs);
  await auth.initialize();
  runApp(_AccountSessions(auth: auth, prefs: prefs));
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
        return const MaterialApp(
          home: _SessionStatus('Authentication is unavailable.'),
        );
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
        return const MaterialApp(
          home: _SessionStatus('Could not open local financial records.'),
        );
      }
      if (snapshot.connectionState != ConnectionState.done ||
          (widget.uid != null && !snapshot.hasData)) {
        return const MaterialApp(home: _SessionStatus());
      }
      final repository = snapshot.data;
      return ProviderScope(
        overrides: [
          if (repository != null)
            financeRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(widget.prefs),
          authServiceProvider.overrideWithValue(widget.auth),
        ],
        child: const SmartSaveApp(),
      );
    },
  );
}

class _SessionStatus extends StatelessWidget {
  const _SessionStatus([this.message]);

  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: message == null
          ? const CircularProgressIndicator()
          : Text(message!),
    ),
  );
}

class SmartSaveApp extends StatelessWidget {
  const SmartSaveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: appNavigatorKey,
    title: 'SmartSave',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const AppEntry(),
  );
}
