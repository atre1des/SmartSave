import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../shared/theme.dart';
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
    final authStatus = ref.watch(authStatusProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const WelcomeScreen();
        }
        // Check if email is verified
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }
        return const AppShell();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.firefly),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.wine, size: 48),
              const SizedBox(height: 16),
              const Text('Authentication error'),
              const SizedBox(height: 8),
              Text(
                'Please restart the app.',
                style: TextStyle(color: AppColors.muted),
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
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.email_outlined,
                size: 80,
                color: AppColors.firefly,
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your email',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We\'ve sent a verification link to your email address. '
                'Please check your inbox and click the link to verify your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
              const SizedBox(height: 24),
              PrimaryAction(
                label: 'I\'ve verified my email',
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.sendEmailVerification();
                  if (context.mounted) {
                    showMessage(context, 'Verification email sent again.');
                  }
                },
              ),
              const SizedBox(height: 12),
              SecondaryAction(
                label: 'Resend verification email',
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.sendEmailVerification();
                  if (context.mounted) {
                    showMessage(context, 'Verification email resent.');
                  }
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                },
                child: const Text('Sign out'),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.topLeft,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: SvgPicture.asset(
                      'assets/figma/splash-blob.svg',
                      width: 230,
                      height: 230,
                    ),
                  ),
                  Positioned(
                    left: 126,
                    top: 0,
                    child: SvgPicture.asset(
                      'assets/figma/splash-blob-mint.svg',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  Positioned(
                    left: -7,
                    top: 166,
                    child: SvgPicture.asset(
                      'assets/figma/splash-blob-lime.svg',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  Positioned(
                    left: 158,
                    top: 144,
                    child: SvgPicture.asset(
                      'assets/figma/splash-logo.svg',
                      width: 86,
                      height: 86,
                    ),
                  ),
                  Positioned(
                    left: 25,
                    top: 25,
                    child: SvgPicture.asset(
                      'assets/figma/splash-blob-dark.svg',
                      width: 180,
                      height: 180,
                    ),
                  ),
                  Positioned(
                    left: 39,
                    top: 58,
                    child: SvgPicture.asset(
                      'assets/figma/splash-logo-background.svg',
                      width: 152,
                      height: 114,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SmartSave',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 36, height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Know where your money goes. Know what to do next.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const Spacer(flex: 3),
            PrimaryAction(
              label: 'Get started',
              onPressed: () => _open(context, const AuthScreen(signUp: true)),
            ),
            const SizedBox(height: 12),
            SecondaryAction(
              label: 'I already have an account',
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
      showMessage(context, 'Accept the terms to continue.');
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
      result = await authService.signIn(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      if (widget.signUp) {
        // New user: go through onboarding
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (_) => false,
        );
      } else {
        // Existing user: check onboarding status
        final authService = ref.read(authServiceProvider);
        final onboardingComplete = await authService.isOnboardingComplete();
        if (!mounted) return;
        if (onboardingComplete) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppShell()),
            (_) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (_) => false,
          );
        }
      }
    } else {
      showMessage(context, result.errorMessage ?? 'Authentication failed. Please try again.');
    }
  }

  Future<void> _forgotPassword() async {
    final email = _contact.text.trim();
    if (email.isEmpty) {
      showMessage(context, 'Please enter your email address first.');
      return;
    }

    final authService = ref.read(authServiceProvider);
    setState(() => _busy = true);
    final result = await authService.sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      showMessage(context, 'Password reset email sent. Check your inbox.');
    } else {
      showMessage(context, result.errorMessage ?? 'Failed to send reset email.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Welcome'),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Sign up')),
                ButtonSegment(value: false, label: Text('Log in')),
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
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'name@example.com',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email address.';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'At least 8 characters',
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            if (widget.signUp) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match.' : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acceptedTerms,
                onChanged: (value) =>
                    setState(() => _acceptedTerms = value ?? false),
                title: const Text(
                  'I accept the Terms and Privacy policy',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            const SizedBox(height: 22),
            PrimaryAction(
              label: widget.signUp ? 'Create account' : 'Sign in',
              busy: _busy,
              onPressed: _continue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Your credentials are securely managed by Firebase Authentication.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
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
  static const _titles = [
    'Track every tenge',
    'Turn spending into a plan',
    'Grow savings at your pace',
  ];
  static const _descriptions = [
    'See your spending by category and spot what you can change.',
    'Set practical category limits and understand your monthly patterns.',
    'Create a goal, choose a deadline and track your progress over time.',
  ];

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            const SizedBox(height: 48),
            Container(
              height: 230,
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 112,
                  color: AppColors.firefly,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _titles[_step],
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            Text(
              _descriptions[_step],
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Track · Save · Grow',
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
                    color: index == _step ? AppColors.firefly : AppColors.mint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryAction(
              label: _step == 2 ? 'Continue' : 'Next',
              onPressed: () => _step == 2 ? _finish() : setState(() => _step++),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});
  final int initialIndex;
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
    ref.read(assistantConversationProvider.notifier).state = const [];
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
      isSelected ? AppColors.firefly : AppColors.muted,
      BlendMode.srcIn,
    ),
  );

  static const _tabs = [
    (label: 'Home', asset: 'assets/figma/tab-home.svg'),
    (label: 'Deposits', asset: 'assets/figma/tab-deposits.svg'),
    (label: 'AI', asset: 'assets/figma/tab-ai.svg'),
    (label: 'Invest', asset: 'assets/figma/tab-invest.svg'),
    (label: 'My Account', asset: 'assets/figma/tab-profile.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTabIndexProvider);
    return Scaffold(
      body: IndexedStack(index: selected, children: _pages),
      bottomNavigationBar: NavigationBar(
        height: 80,
        selectedIndex: selected,
        onDestinationSelected: (index) => ref.read(selectedTabIndexProvider.notifier).state = index,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: _buildTabIcon(_tabs[i].asset, i == selected),
              label: _tabs[i].label,
            ),
        ],
      ),
    );
  }
}

void _open(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
