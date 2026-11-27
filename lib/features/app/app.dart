import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_locale.dart';

import '../../shared/theme.dart';
import '../../shared/glass.dart';
import '../../data/providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../advice/assistant_session.dart';
import '../advice/ai_assistant_screen.dart';
import '../invest/invest_hub_screen.dart';
import '../invest/invest_screen.dart';
import '../profile/my_account_screen.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets.dart';
import 'demo_flow_screens.dart';
import 'auth_presentation.dart';

class AppEntry extends ConsumerWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const WelcomeScreen();
        }
        // Check if email is verified
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }
        return FutureBuilder<bool>(
          future: ref.read(authServiceProvider).isOnboardingComplete(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return snapshot.data! ? const AppShell() : const OnboardingScreen();
          },
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.colors.text),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: context.colors.error, size: 48),
              const SizedBox(height: 16),
              Text(context.l10n.authError),
              const SizedBox(height: 8),
              Text(
                context.l10n.restartApp,
                style: TextStyle(color: context.colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends ConsumerWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthPage(
    centered: true,
    children: [
      AuthHeading(
        title: context.l10n.verifyEmail,
        subtitle: context.l10n.emailVerificationNotice,
      ),
      const SizedBox(height: 26),
      AuthButton(
        label: context.l10n.verifiedEmail,
        onPressed: () async {
          final authService = ref.read(authServiceProvider);
          await authService.auth.currentUser?.reload();
          if (context.mounted && !authService.isEmailVerified) {
            showMessage(context, context.l10n.emailUnverified);
          }
        },
      ),
      const SizedBox(height: 10),
      AuthButton(
        secondary: true,
        label: context.l10n.resendEmail,
        onPressed: () async {
          final authService = ref.read(authServiceProvider);
          await authService.sendEmailVerification();
          if (context.mounted) {
            showMessage(context, context.l10n.verificationResent);
          }
        },
      ),
      TextButton(
        onPressed: () async {
          await ref.read(authServiceProvider).signOut();
        },
        child: Text(context.l10n.signOut),
      ),
    ],
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthPage(
    centered: true,
    footer: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthButton(
          label: context.l10n.getStarted,
          onPressed: () => _open(context, const AuthScreen(signUp: true)),
        ),
        const SizedBox(height: 10),
        AuthButton(
          secondary: true,
          label: context.l10n.haveAccount,
          onPressed: () => _open(context, const AuthScreen(signUp: false)),
        ),
      ],
    ),
    children: [
      AuthHeading(
        title: 'SmartSave',
        subtitle: context.l10n.welcomeSubtitle,
        hero: true,
      ),
    ],
  );
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.signUp});
  final bool signUp;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acceptedTerms = false;
  bool _busy = false;

  @override
  void dispose() {
    _contact.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.signUp && !_acceptedTerms) {
      showMessage(context, context.l10n.termsRequired);
      return;
    }
    setState(() => _busy = true);

    final authService = ref.read(authServiceProvider);
    final email = _contact.text.trim();
    final password = _password.text;

    AuthResult result;
    if (widget.signUp) {
      // Extract display name from email (before @) or use a default
      final displayName = email.split('@').first;
      result = await authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
    } else {
      result = await authService.signIn(email: email, password: password);
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      showMessage(context, _authError(context, result.errorCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return AuthPage(
      back: true,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            widget.signUp ? strings.authExistingAccount : strings.authNoAccount,
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AuthScreen(signUp: !widget.signUp),
                    ),
                  ),
            child: Text(widget.signUp ? strings.signIn : strings.signUp),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 4),
        AuthHeading(
          title: widget.signUp ? strings.signUp : strings.authWelcomeBack,
          subtitle: widget.signUp
              ? strings.authSignUpSubtitle
              : strings.authSignInSubtitle,
        ),
        const SizedBox(height: 25),
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthInput(
                  label: strings.email,
                  hint: 'name@example.com',
                  controller: _contact,
                  email: true,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) => _validateAuthEmail(context, value),
                ),
                const SizedBox(height: 14),
                AuthInput(
                  label: strings.password,
                  hint: strings.passwordLength,
                  controller: _password,
                  secret: true,
                  last: !widget.signUp,
                  autofillHints: [
                    widget.signUp
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  validator: (value) => value == null || value.length < 8
                      ? strings.passwordMin
                      : null,
                ),
                if (widget.signUp) ...[
                  const SizedBox(height: 14),
                  AuthInput(
                    label: strings.confirmPassword,
                    controller: _confirm,
                    secret: true,
                    last: true,
                    validator: (value) => value != _password.text
                        ? strings.passwordMismatch
                        : null,
                  ),
                  const SizedBox(height: 5),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _acceptedTerms,
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value ?? false),
                    title: Text(strings.acceptTerms),
                  ),
                ] else
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _open(
                              context,
                              _PasswordResetScreen(email: _contact.text.trim()),
                            ),
                      child: Text(strings.forgotPassword),
                    ),
                  ),
                const SizedBox(height: 12),
                AuthButton(
                  label: widget.signUp ? strings.createAccount : strings.signIn,
                  busy: _busy,
                  onPressed: _continue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordResetScreen extends ConsumerStatefulWidget {
  const _PasswordResetScreen({required this.email});

  final String email;

  @override
  ConsumerState<_PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<_PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final result = await ref
        .read(authServiceProvider)
        .sendPasswordResetEmail(_email.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.success) {
      final messenger = ScaffoldMessenger.of(context);
      final message = context.l10n.passwordResetSent;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } else {
      showMessage(
        context,
        result.errorCode == null
            ? context.l10n.passwordResetFailed
            : _authError(context, result.errorCode),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    back: true,
    children: [
      const SizedBox(height: 22),
      AuthHeading(
        title: context.l10n.forgotPassword,
        subtitle: context.l10n.authResetSubtitle,
      ),
      const SizedBox(height: 27),
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthInput(
              label: context.l10n.email,
              hint: 'name@example.com',
              controller: _email,
              email: true,
              last: true,
              autofillHints: const [AutofillHints.email],
              validator: (value) => _validateAuthEmail(context, value),
            ),
            const SizedBox(height: 20),
            AuthButton(
              label: context.l10n.authSendReset,
              onPressed: _send,
              busy: _busy,
            ),
          ],
        ),
      ),
    ],
  );
}

String? _validateAuthEmail(BuildContext context, String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return context.l10n.enterEmail;
  if (!email.contains('@') || !email.contains('.')) {
    return context.l10n.invalidEmail;
  }
  return null;
}

String _authError(BuildContext context, AuthExceptionCode? code) {
  final strings = context.l10n;
  return switch (code) {
    AuthExceptionCode.emailAlreadyInUse => strings.emailTaken,
    AuthExceptionCode.invalidEmail => strings.invalidEmail,
    AuthExceptionCode.weakPassword => strings.passwordMin,
    AuthExceptionCode.userNotFound ||
    AuthExceptionCode.wrongPassword ||
    AuthExceptionCode.invalidCredential => strings.invalidCredentials,
    AuthExceptionCode.tooManyRequests => strings.authRateLimit,
    AuthExceptionCode.networkError => strings.authNetwork,
    AuthExceptionCode.emailNotVerified => strings.emailUnverified,
    AuthExceptionCode.requiresRecentLogin => strings.signInAgain,
    AuthExceptionCode.userDisabled => strings.disabledAccount,
    AuthExceptionCode.operationNotAllowed => strings.authUnavailable,
    _ => strings.authFailed,
  };
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  (String, String) _copy(BuildContext context) {
    final strings = context.l10n;
    return switch (_step) {
      0 => (strings.trackTenge, strings.trackTengeDetails),
      1 => (strings.spendingPlan, strings.spendingPlanDetails),
      _ => (strings.growSavings, strings.growSavingsDetails),
    };
  }

  Future<void> _finish() async {
    final authService = ref.read(authServiceProvider);
    await authService.setOnboardingComplete(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConnectCardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: _ScrollWhenNeeded(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: Text(context.l10n.skip)),
            ),
            const Spacer(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _EntryMotif(
                icon: [
                  Icons.pie_chart_outline_rounded,
                  Icons.savings_outlined,
                  Icons.show_chart_rounded,
                ][_step],
              ),
            ),
            const SizedBox(height: 28),
            Text(_copy(context).$1, style: glassTitle(context)),
            const SizedBox(height: 10),
            Text(
              _copy(context).$2,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.colors.muted),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                context.l10n.trackSaveGrow,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _step ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _step ? context.colors.emphasis : context.colors.progress,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryAction(
              label: _step == 2 ? context.l10n.continueLabel : context.l10n.next,
              onPressed: () => _step == 2 ? _finish() : setState(() => _step++),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EntryMotif extends StatelessWidget {
  const _EntryMotif({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: context.colors.action.withValues(alpha: .11),
    ),
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Icon(icon, size: 46, color: context.colors.action),
    ),
  );
}

class _ScrollWhenNeeded extends StatelessWidget {
  const _ScrollWhenNeeded({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: padding,
          child: IntrinsicHeight(child: child),
        ),
      ),
    ),
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) appSessionActive.value = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appSessionActive.value = false;
    });
    super.dispose();
  }

  late final List<Widget> _pages = [
    const DashboardScreen(),
    const DepositRatesScreen(),
    const AIAssistantScreen(),
    const InvestHubScreen(),
    const MyAccountScreen(),
  ];

  Widget _buildTabIcon(String? assetPath, bool isSelected) {
    final color = isSelected ? context.colors.action : context.colors.muted;
    if (assetPath == null) {
      return Icon(Icons.auto_awesome, size: 24, color: color);
    }
    return SvgPicture.asset(
      assetPath,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final tabs = [
      (label: strings.home, asset: 'assets/figma/tab-home.svg'),
      (label: strings.deposits, asset: 'assets/figma/tab-deposits.svg'),
      (label: strings.ai, asset: null),
      (label: strings.invest, asset: 'assets/figma/tab-invest.svg'),
      (label: strings.myAccount, asset: 'assets/figma/tab-profile.svg'),
    ];
    final selected = ref.watch(selectedTabIndexProvider);
    return PopScope(
      canPop: selected == 0 || Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selected != 0) {
          ref.read(selectedTabIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        extendBody: selected == 0 || selected == 3,
        body: IndexedStack(index: selected, children: _pages),
        bottomNavigationBar:
            selected == 2 && MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : AppNavigationBar(
                selectedIndex: selected,
                onSelected: (index) =>
                    ref.read(selectedTabIndexProvider.notifier).state = index,
                destinations: [
                  for (var i = 0; i < tabs.length; i++)
                    (
                      icon: _buildTabIcon(tabs[i].asset, i == selected),
                      label: tabs[i].label,
                    ),
                ],
              ),
      ),
    );
  }
}

void _open(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
