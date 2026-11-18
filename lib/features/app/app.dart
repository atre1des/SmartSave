import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/theme.dart';
import '../../data/providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../advice/assistant_session.dart';
import '../advice/ai_assistant_screen.dart';
import '../invest/invest_hub_screen.dart';
import '../invest/invest_screen.dart';
import '../profile/my_account_screen.dart';
import '../../shared/widgets.dart';
import 'demo_flow_screens.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();

  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: _preferences,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.firefly),
          ),
        );
      }
      return snapshot.data!.getBool('demo_session') == true
          ? const AppShell()
          : const WelcomeScreen();
    },
  );
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

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.signUp});
  final bool signUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
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
      showMessage(context, 'Accept the demo terms to continue.');
      return;
    }
    setState(() => _busy = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('demo_contact', _contact.text.trim());

    if (widget.signUp) {
      // New user: go through onboarding
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } else {
      // Existing user: skip quiz and onboarding, seed fake quiz data
      await prefs.setBool('demo_session', true);
      await prefs.setBool('risk_profile_complete', true);
      await prefs.setBool('onboarding_complete', true);
      await prefs.setBool('quiz_completed', true);
      await prefs.setString('risk_profile', 'moderate');
      await prefs.setString('quiz_answers', 'wait;1-3years;some;some;balance');
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
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
                labelText: 'Email or phone',
                hintText: 'name@example.com',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your email or phone.'
                  : null,
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
                  onPressed: () => showMessage(
                    context,
                    'Password reset is unavailable in this local demo.',
                  ),
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
              'Demo authentication only. Credentials are not verified or stored as secure production credentials.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
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
