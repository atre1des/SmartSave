import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';
import '../../services/auth_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import '../app/app.dart';
import '../app/demo_flow_screens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.mintLight,
                  foregroundColor: AppColors.firefly,
                  child: Text('Y'),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your name', style: Theme.of(context).textTheme.titleLarge),
                    const Text(
                      'Moderate investor · Kazakhstan',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingRow(
              title: 'Profile',
              subtitle: 'Name, country, currency',
              icon: Icons.person_outline,
              onTap: () => _push(context, const ProfileDetailsScreen()),
            ),
            _SettingRow(
              title: 'Connected accounts',
              subtitle: 'Cards and banks · demo only',
              icon: Icons.credit_card_outlined,
              onTap: () => _push(context, const ConnectedAccountsScreen()),
            ),
            _SettingRow(
              title: 'Notifications',
              subtitle: 'Reminders and alerts',
              icon: Icons.notifications_none,
              onTap: () => _push(context, const NotificationsScreen()),
            ),
            _SettingRow(
              title: 'Advice history',
              subtitle: 'Past recommendations',
              icon: Icons.history,
              onTap: () => _push(context, const AdviceHistoryScreen()),
            ),
            _SettingRow(
              title: 'Privacy & data',
              subtitle: 'Consent, export, delete account',
              icon: Icons.lock_outline,
              onTap: () => _push(context, const PrivacyDataScreen()),
            ),
            _SettingRow(
              title: 'Subscription',
              subtitle: 'Free plan · demo',
              icon: Icons.workspace_premium_outlined,
              onTap: () => _push(context, const SubscriptionScreen()),
            ),
            _SettingRow(
              title: 'Help & support',
              subtitle: 'FAQ, contact',
              icon: Icons.help_outline,
              onTap: () => _push(context, const HelpScreen()),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final authService = ref.read(authServiceProvider);
                final result = await authService.signOut();
                if (context.mounted) {
                  if (result.success) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (_) => false,
                    );
                  } else {
                    showMessage(context, result.errorMessage ?? 'Sign out failed.');
                  }
                }
              },
              child: const Text('Log out'),
            ),
            const Divider(),
            TextButton.icon(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Reset sample data?'),
                    content: const Text(
                        'Replaces local demo records with the original fictional examples.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _reset(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset demo data'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(financeControllerProvider).resetDemoData();
    if (context.mounted) showMessage(context, 'Fictional demo data restored.');
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.subtitle, required this.icon, required this.onTap});
  final String title, subtitle; final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 3), leading: Icon(icon, color: AppColors.firefly), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11)), trailing: const Icon(Icons.chevron_right), onTap: onTap);
}

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});
  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}
class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _name = TextEditingController(text: 'Your name');
  final _contact = TextEditingController(text: 'name@example.com');
  String _country = 'Kazakhstan';
  String _currency = 'Tenge (KZT)';
  String _language = 'English';
  @override
  void dispose() { _name.dispose(); _contact.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Profile')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    const Center(child: CircleAvatar(radius: 34, backgroundColor: AppColors.mintLight, child: Text('Y', style: TextStyle(fontSize: 24)))),
    TextButton(onPressed: () => showMessage(context, 'Photo upload is not included in this local demo.'), child: const Text('Change photo')),
    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
    const SizedBox(height: 14), TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Email or phone')),
    const SizedBox(height: 14), _choice('Country', _country, ['Kazakhstan', 'Other'], (v) => setState(() => _country = v)),
    const SizedBox(height: 14), _choice('Currency', _currency, ['Tenge (KZT)', 'US dollar (USD)'], (v) => setState(() => _currency = v)),
    const SizedBox(height: 14), _choice('Language', _language, ['English', 'Русский', 'Қазақша'], (v) => setState(() => _language = v)),
    const SizedBox(height: 12), const Text('Country determines the local sample deposits and stocks shown.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
    const SizedBox(height: 20), PrimaryAction(label: 'Save', onPressed: () async {
      final authService = ref.read(authServiceProvider);
      final profileData = {
        'profile_name': _name.text.trim(),
        'profile_country': _country,
        'profile_currency': _currency,
        'profile_language': _language,
      };
      await authService.saveLocalProfile(profileData);
      if (context.mounted) {
        showMessage(context, 'Profile saved.');
        Navigator.pop(context);
      }
    }),
  ])));
}

class ConnectedAccountsScreen extends StatefulWidget {
  const ConnectedAccountsScreen({super.key});
  @override
  State<ConnectedAccountsScreen> createState() => _ConnectedAccountsScreenState();
}
class _ConnectedAccountsScreenState extends State<ConnectedAccountsScreen> {
  bool _connected = true;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Connected accounts')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    if (_connected) SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [CircleAvatar(backgroundColor: AppColors.mintLight, child: Text('KA')), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Kaspi · bank card', style: TextStyle(fontWeight: FontWeight.w600)), Text('Demo sample · read-only appearance', style: TextStyle(color: AppColors.muted, fontSize: 11))]))]), const SizedBox(height: 14), const Text('Last sync · Sample only', style: TextStyle(fontSize: 12)), Row(children: [TextButton(onPressed: () => showMessage(context, 'Bank sync is unavailable; local sample data was not changed.'), child: const Text('Sync now')), const Spacer(), TextButton(onPressed: () => setState(() => _connected = false), child: const Text('Disconnect'))])])) else const SurfaceCard(child: Text('No demo card connected.')),
    const SizedBox(height: 14), const SurfaceCard(color: AppColors.mintLight, child: Text('This app has no bank integration. Sample transactions are fictional; no balance or card data is read or moved.', style: TextStyle(fontSize: 12))),
    const SizedBox(height: 18), PrimaryAction(label: 'Add card', onPressed: () => _push(context, const ConnectCardScreen())),
  ])));
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  final _values = <String, bool>{'Goal reminders': true, 'Budget alerts': true, 'Advice of the day': false, 'Deposit rate changes': false, 'Market news': false};
  final _descriptions = {'Goal reminders': 'Monthly saving reminder', 'Budget alerts': 'When a category goes over budget', 'Advice of the day': 'One short tip each morning', 'Deposit rate changes': 'When sample rates change', 'Market news': 'Updates on your sample watchlist'};
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Notifications')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    for (final entry in _values.entries) SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(_descriptions[entry.key]!, style: const TextStyle(fontSize: 12, color: AppColors.muted)), value: entry.value, onChanged: (value) => setState(() => _values[entry.key] = value)),
    const SizedBox(height: 10), const Text('These controls save demo preferences only; scheduled push notifications are not configured.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
  ])));
}

class AdviceHistoryScreen extends StatelessWidget {
  const AdviceHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Advice history')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    for (final item in [
      ('Savings', 'Cut food delivery by 15 000 ₸', 'Applied'),
      ('Deposit', 'Freedom Bank · 19.50% ГЭСВ', 'Viewed'),
      ('Stock', 'Halyk Bank (HSBK) fits Moderate', 'Saved'),
      ('Savings', 'Save 23 000 ₸ per month for New laptop', 'Applied'),
    ]) SurfaceCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item.$1} · ${item.$3}', style: const TextStyle(color: AppColors.muted, fontSize: 11)), const SizedBox(height: 5), Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w600)), TextButton(onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('About this demo item'), content: const Text('This is sample advice history from the Figma prototype; it does not represent a personalized financial recommendation.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])), child: const Text('Why this?'))])),
  ])));
}

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});
  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}
class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _personalAdvice = true;
  bool _analytics = false;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Privacy & data')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Use my data for personal advice'), subtitle: const Text('Needed for recommendations', style: TextStyle(fontSize: 12, color: AppColors.muted)), value: _personalAdvice, onChanged: (value) => setState(() => _personalAdvice = value)),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Share anonymous usage stats'), subtitle: const Text('Helps improve the app', style: TextStyle(fontSize: 12, color: AppColors.muted)), value: _analytics, onChanged: (value) => setState(() => _analytics = value)),
    const SizedBox(height: 12), const SurfaceCard(color: AppColors.mintLight, child: Text('The demo stores fictional records on this device only. No bank, market or analytics service receives your data.', style: TextStyle(fontSize: 12))),
    const SizedBox(height: 12), OutlinedButton(onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Demo data export'), content: const Text('Structured records remain local in SQLite. A downloadable export is not configured in this MVP.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])), child: const Text('Download my data')),
    const SizedBox(height: 8), TextButton(onPressed: () => _push(context, const DeleteAccountScreen()), child: const Text('Delete account', style: TextStyle(color: AppColors.wine))),
  ])));
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}
class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.length < 8) {
      showMessage(context, 'Enter your password (at least 8 characters) to confirm.');
      return;
    }

    setState(() => _busy = true);
    final authService = ref.read(authServiceProvider);
    final result = await authService.deleteAccount(password: _password.text);

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } else {
      showMessage(context, result.errorMessage ?? 'Account deletion failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delete account')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.wine),
      const SizedBox(height: 8),
      Text('Delete your account?', style: Theme.of(context).textTheme.headlineMedium),
      const Text('This action cannot be undone.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 16),
      const SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• Your account and all associated data will be permanently deleted'),
        SizedBox(height: 8),
        Text('• Your local goals and financial data will be removed'),
        SizedBox(height: 8),
        Text('• This action cannot be undone'),
      ])),
      const SizedBox(height: 16),
      TextField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm with your password'),
      ),
      const SizedBox(height: 20),
      PrimaryAction(
        label: 'Delete permanently',
        busy: _busy,
        onPressed: _delete,
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      const SizedBox(height: 10),
      const Text(
        'This will permanently delete your Firebase Authentication account and all associated data.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 11),
      ),
    ])));
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Subscription')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    const SurfaceCard(color: AppColors.mintLight, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Free · Current', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), SizedBox(height: 10), Text('✓ Expense tracking and categories'), Text('✓ Savings goals and monthly plan'), Text('✓ Deposit comparison')])),
    const SizedBox(height: 14), const SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text('Price to be set', style: TextStyle(color: AppColors.muted)), SizedBox(height: 10), Text('✓ Everything in Free'), Text('✓ Deeper stock and bond analysis'), Text('✓ Personal investment plan'), Text('✓ Full advice history')])),
    const SizedBox(height: 12), const Text('Subscription pricing and billing are not connected in this demo.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
    const SizedBox(height: 18), PrimaryAction(label: 'Try Premium (demo)', onPressed: () => showMessage(context, 'Premium is a non-billing demo preview.')),
  ])));
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}
class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  final _faqs = const [
    ('How does SmartSave get my data?', 'The prototype uses fictional local sample data. It does not connect to your bank.'),
    ('Why did I get this recommendation?', 'Each suggestion is a sample explanation and is not personalized financial advice.'),
    ('Is this financial advice?', 'No. The app provides educational/demo information only.'),
    ('How do I delete my account?', 'Open Profile → Privacy & data → Delete account. The demo clears local records.'),
  ];
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final filtered = _faqs.where((faq) => faq.$1.toLowerCase().contains(_search.text.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: const Text('Help & support')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search help')),
      const SizedBox(height: 12),
      for (final faq in filtered) Card(color: Colors.white, child: ExpansionTile(title: Text(faq.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), children: [Padding(padding: const EdgeInsets.all(16), child: Text(faq.$2, style: const TextStyle(fontSize: 12, color: AppColors.muted)))])),
      const SizedBox(height: 12), PrimaryAction(label: 'Chat with support', onPressed: () => showMessage(context, 'Live support is not configured for the capstone demo.')),
      TextButton(onPressed: () => showMessage(context, 'Privacy information is available in the Privacy & data screen.'), child: const Text('Privacy policy')),
    ])));
  }
}

Widget _choice(String label, String value, List<String> options, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label), items: options.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(), onChanged: (next) { if (next != null) onChanged(next); });
void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
