part of 'workspace.dart';

Future<FirebaseAuth> _initializeWebAuth() async {
  const emulator = bool.fromEnvironment('SMARTSAVE_WEB_EMULATORS');
  const project = String.fromEnvironment('SMARTSAVE_FIREBASE_PROJECT_ID');
  const appId = String.fromEnvironment('SMARTSAVE_FIREBASE_APP_ID');
  const key = String.fromEnvironment('SMARTSAVE_FIREBASE_API_KEY');
  const sender = String.fromEnvironment('SMARTSAVE_FIREBASE_SENDER_ID');
  const domain = String.fromEnvironment('SMARTSAVE_FIREBASE_AUTH_DOMAIN');

  if (emulator) {
    if (!const {'localhost', '127.0.0.1'}.contains(Uri.base.host)) {
      throw StateError('Emulators require a loopback web origin.');
    }
  } else if ([
        project,
        appId,
        key,
        sender,
        domain,
      ].any((field) => field.isEmpty) ||
      Uri.base.scheme != 'https') {
    throw StateError(
      'Explicit Firebase web configuration and HTTPS are required.',
    );
  }
  final app = await Firebase.initializeApp(
    options: emulator
        ? const FirebaseOptions(
            apiKey: 'emulator-only',
            appId: '1:123456789:web:123456789abc',
            messagingSenderId: '123456789',
            projectId: 'demo-smartsave-web',
          )
        : const FirebaseOptions(
            apiKey: key,
            appId: appId,
            messagingSenderId: sender,
            projectId: project,
            authDomain: domain,
          ),
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  final store = FirebaseFirestore.instanceFor(app: app);
  store.settings = const Settings(persistenceEnabled: false);
  if (emulator) {
    await auth.useAuthEmulator('127.0.0.1', 8610);
    store.useFirestoreEmulator('127.0.0.1', 8611, automaticHostMapping: false);
  }
  await auth.setPersistence(Persistence.SESSION);
  return auth;
}

Future<void> _requestPasswordReset(FirebaseAuth auth, String email) async {
  if (!const bool.fromEnvironment('SMARTSAVE_WEB_EMULATORS')) {
    await auth.sendPasswordResetEmail(email: email);
    return;
  }
  // Send only to the loopback Auth service in emulator mode.
  const endpoint =
      'http://127.0.0.1:8610/identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=emulator-only';
  final headers = web.Headers()..set('Content-Type', 'application/json');
  final response = await web.window
      .fetch(
        endpoint.toJS,
        web.RequestInit(
          method: 'POST',
          headers: headers,
          redirect: 'error',
          body: jsonEncode({
            'requestType': 'PASSWORD_RESET',
            'email': email,
          }).toJS,
        ),
      )
      .toDart
      .timeout(const Duration(seconds: 10));
  if (!response.ok) throw WebDataIssue.unavailable;
}

class _LiveSession extends StatefulWidget {
  const _LiveSession();
  @override
  State<_LiveSession> createState() => _LiveSessionState();
}

class _LiveSessionState extends State<_LiveSession> {
  late final _startup = _initializeWebAuth();
  FirebaseAuth? _auth;
  Stream<User?>? _users;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _startup,
    builder: (context, startup) {
      if (startup.hasError) return const _UnavailableWorkspace();
      if (!startup.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final auth = _auth ??= startup.data!;
      return StreamBuilder<User?>(
        stream: _users ??= auth.userChanges(),
        builder: (context, session) {
          if (session.hasError) return const _UnavailableWorkspace();
          if (session.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = session.data;
          if (user == null || !user.emailVerified) {
            return _WebSignIn(key: ValueKey(user?.uid), auth: auth, user: user);
          }
          final uid = user.uid;
          return Navigator(
            key: ValueKey(uid),
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => _LiveWorkspace(
                repository: WebFinanceRepository(
                  auth,
                  FirebaseFirestore.instanceFor(app: auth.app),
                  uid,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _WebSignIn extends StatefulWidget {
  const _WebSignIn({super.key, required this.auth, required this.user});
  final FirebaseAuth auth;
  final User? user;
  @override
  State<_WebSignIn> createState() => _WebSignInState();
}

class _WebSignInState extends State<_WebSignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final notice = await action();
      if (mounted) setState(() => _message = notice);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final strings = context.l10n;
      setState(
        () => _message = switch (error.code) {
          'email-already-in-use' => strings.emailTaken,
          'invalid-email' => strings.invalidEmail,
          'weak-password' => strings.passwordMin,
          'too-many-requests' => strings.authRateLimit,
          'invalid-credential' ||
          'wrong-password' => strings.invalidCredentials,
          _ => strings.authFailed,
        },
      );
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.authFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final auth = widget.auth;
    final user = widget.user;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('SmartSave', style: glassTitle(context)),
                  const SizedBox(height: 24),
                  if (user != null) ...[
                    _Heading(strings.verifyEmail),
                    Text(strings.emailVerificationNotice),
                    const SizedBox(height: 16),
                    _WebAction(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await user.reload();
                                return mounted &&
                                        auth.currentUser?.emailVerified != true
                                    ? strings.emailUnverified
                                    : null;
                              }),
                        child: Text(strings.verifiedEmail),
                      ),
                    ),
                    _WebActionGroup(
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await user.sendEmailVerification();
                                  return strings.verificationResent;
                                }),
                          child: Text(strings.resendEmail),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await auth.signOut();
                                  return null;
                                }),
                          child: Text(strings.signOut),
                        ),
                      ],
                    ),
                  ] else ...[
                    _Heading(_register ? strings.signUp : strings.signIn),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: strings.email),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(labelText: strings.password),
                    ),
                    const SizedBox(height: 16),
                    _WebAction(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                if (_register) {
                                  final result = await auth
                                      .createUserWithEmailAndPassword(
                                        email: _email.text.trim(),
                                        password: _password.text,
                                      );
                                  await result.user?.sendEmailVerification();
                                } else {
                                  await auth.signInWithEmailAndPassword(
                                    email: _email.text.trim(),
                                    password: _password.text,
                                  );
                                }
                                return null;
                              }),
                        child: Text(
                          _register ? strings.signUp : strings.signIn,
                        ),
                      ),
                    ),
                    _WebActionGroup(
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _message = null;
                                }),
                          child: Text(
                            _register ? strings.signIn : strings.signUp,
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  if (_email.text.trim().isEmpty) {
                                    return strings.enterEmailFirst;
                                  }
                                  await _requestPasswordReset(
                                    auth,
                                    _email.text.trim(),
                                  );
                                  return strings.passwordResetSent;
                                }),
                          child: Text(strings.forgotPassword),
                        ),
                      ],
                    ),
                  ],
                  if (_message != null)
                    Semantics(liveRegion: true, child: Text(_message!)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
