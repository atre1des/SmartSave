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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: _ScrollWhenNeeded(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _EntryMotif(icon: Icons.mark_email_unread_outlined),
              const SizedBox(height: 28),
              Text(
                context.l10n.verifyEmail,
                style: glassTitle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.emailVerificationNotice,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted, fontSize: 16),
              ),
              const SizedBox(height: 24),
              PrimaryAction(
                label: context.l10n.verifiedEmail,
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.auth.currentUser?.reload();
                  if (context.mounted && !authService.isEmailVerified) {
                    showMessage(context, context.l10n.emailUnverified);
                  }
                },
              ),
              const SizedBox(height: 12),
              SecondaryAction(
                label: context.l10n.resendEmail,
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.sendEmailVerification();
                  if (context.mounted) {
                    showMessage(context, context.l10n.verificationResent);
                  }
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                },
                child: Text(context.l10n.signOut),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: _ScrollWhenNeeded(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            const _EntryMotif(icon: Icons.account_balance_wallet_outlined),
            const SizedBox(height: 24),
            Text('SmartSave', style: glassTitle(context).copyWith(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              context.l10n.welcomeSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.colors.muted),
            ),
            const Spacer(flex: 3),
            PrimaryAction(
              label: context.l10n.getStarted,
              onPressed: () => _open(context, const AuthScreen(signUp: true)),
            ),
            const SizedBox(height: 12),
            SecondaryAction(
              label: context.l10n.haveAccount,
              onPressed: () => _open(context, const AuthScreen(signUp: false)),
            ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    ),
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
      showMessage(
        context,
        _authError(result.errorCode),
      );
    }
  }

  String _authError(AuthExceptionCode? code) {
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

  Future<void> _forgotPassword() async {
    final email = _contact.text.trim();
    if (email.isEmpty) {
      showMessage(context, context.l10n.enterEmailFirst);
      return;
    }

    final authService = ref.read(authServiceProvider);
    setState(() => _busy = true);
    final result = await authService.sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      showMessage(context, context.l10n.passwordResetSent);
    } else {
      showMessage(
        context,
        result.errorCode == null ? context.l10n.passwordResetFailed : _authError(result.errorCode),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EditorialHeader(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: Text(widget.signUp ? context.l10n.signUp : context.l10n.signIn),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(context.l10n.signUp)),
                ButtonSegment(value: false, label: Text(context.l10n.signIn)),
              ],
              selected: {widget.signUp},
              onSelectionChanged: (value) => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AuthScreen(signUp: value.first),
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _contact,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.l10n.email,
                hintText: 'name@example.com',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.enterEmail;
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return context.l10n.invalidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.password,
                hintText: context.l10n.passwordLength,
              ),
              validator: (value) => value == null || value.length < 8
                  ? context.l10n.passwordMin
                  : null,
            ),
            if (widget.signUp) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.confirmPassword,
                ),
                validator: (value) =>
                    value != _password.text ? context.l10n.passwordMismatch : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acceptedTerms,
                onChanged: (value) =>
                    setState(() => _acceptedTerms = value ?? false),
                title: Text(
                  context.l10n.acceptTerms,
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: Text(context.l10n.forgotPassword),
                ),
              ),
            const SizedBox(height: 22),
            PrimaryAction(
              label: widget.signUp ? context.l10n.createAccount : context.l10n.signIn,
              busy: _busy,
              onPressed: _continue,
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.firebaseCredentials,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
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

  Widget _buildTabIcon(String assetPath, bool isSelected) => SvgPicture.asset(
    assetPath,
    width: 24,
    height: 24,
    colorFilter: ColorFilter.mode(
      isSelected ? context.colors.action : context.colors.muted,
      BlendMode.srcIn,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final tabs = [
      (label: strings.home, asset: 'assets/figma/tab-home.svg'),
      (label: strings.deposits, asset: 'assets/figma/tab-deposits.svg'),
      (label: strings.ai, asset: 'assets/figma/tab-ai.svg'),
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
