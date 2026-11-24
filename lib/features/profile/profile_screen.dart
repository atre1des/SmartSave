import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_locale.dart';

import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/appearance.dart';
import '../../shared/widgets.dart';
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
                CircleAvatar(
                  backgroundColor: context.colors.subtleSurface,
                  foregroundColor: context.colors.text,
                  child: Text('Y'),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.yourName, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      context.l10n.moderateInvestorKazakhstan,
                      style: TextStyle(color: context.colors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingRow(
              title: context.l10n.profile,
              subtitle: context.l10n.nameCountryCurrency,
              icon: Icons.person_outline,
              onTap: () => _push(context, const ProfileDetailsScreen()),
            ),
            _SettingRow(
              title: context.l10n.connectedAccounts,
              subtitle: context.l10n.demoCards,
              icon: Icons.credit_card_outlined,
              onTap: () => _push(context, const ConnectedAccountsScreen()),
            ),
            _SettingRow(
              title: context.l10n.notifications,
              subtitle: context.l10n.alerts,
              icon: Icons.notifications_none,
              onTap: () => _push(context, const NotificationsScreen()),
            ),
            _SettingRow(
              title: context.l10n.adviceHistory,
              subtitle: context.l10n.pastAdvice,
              icon: Icons.history,
              onTap: () => _push(context, const AdviceHistoryScreen()),
            ),
            _SettingRow(
              title: context.l10n.privacyData,
              subtitle: context.l10n.consentExportDelete,
              icon: Icons.lock_outline,
              onTap: () => _push(context, const PrivacyDataScreen()),
            ),
            _SettingRow(
              title: context.l10n.subscription,
              subtitle: context.l10n.freeDemoPlan,
              icon: Icons.workspace_premium_outlined,
              onTap: () => _push(context, const SubscriptionScreen()),
            ),
            _SettingRow(
              title: context.l10n.helpSupport,
              subtitle: context.l10n.supportFaq,
              icon: Icons.help_outline,
              onTap: () => _push(context, const HelpScreen()),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final result = await ref.read(authServiceProvider).signOut();
                if (context.mounted && !result.success) {
                  showMessage(context, result.errorMessage ?? 'Sign out failed.');
                }
              },
              child: Text(context.l10n.logOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.subtitle, required this.icon, required this.onTap});
  final String title, subtitle; final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 3), leading: Icon(icon, color: context.colors.text), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text(subtitle, style: TextStyle(color: context.colors.muted, fontSize: 11)), trailing: const Icon(Icons.chevron_right), onTap: onTap);
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
  @override
  void initState() {
    super.initState();
    final auth = ref.read(authServiceProvider);
    _name.text = auth.auth.currentUser?.displayName ?? '';
    _contact.text = auth.currentUserEmail ?? '';
    _country = auth.getProfilePreference('profile_country') ?? _country;
    _currency = auth.getProfilePreference('profile_currency') ?? _currency;
  }
  @override
  void dispose() { _name.dispose(); _contact.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.profile)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    Center(child: CircleAvatar(radius: 34, backgroundColor: context.colors.subtleSurface, child: Text('Y', style: TextStyle(fontSize: 24)))),
    TextButton(onPressed: () => showMessage(context, context.l10n.noPhotoUpload), child: Text(context.l10n.changePhoto)),
    TextField(controller: _name, decoration: InputDecoration(labelText: context.l10n.name)),
    const SizedBox(height: 14), TextField(controller: _contact, readOnly: true, decoration: InputDecoration(labelText: context.l10n.emailOrPhone)),
    const SizedBox(height: 14), _choice(context.l10n.country, _country, {'Kazakhstan': context.l10n.kazakhstan, 'Other': context.l10n.other}, (v) => setState(() => _country = v)),
    const SizedBox(height: 14), _choice(context.l10n.currency, _currency, {'Tenge (KZT)': context.l10n.tengeCurrency, 'US dollar (USD)': context.l10n.dollarCurrency}, (v) => setState(() => _currency = v)),
    const SizedBox(height: 14),
    DropdownButtonFormField<Locale>(
      initialValue: AppLocaleController.resolve(
        Localizations.maybeLocaleOf(context),
        const [Locale('en'), Locale('kk'), Locale('ru')],
      ),
      decoration: InputDecoration(labelText: context.l10n.language),
      items: const [
        DropdownMenuItem(value: Locale('en'), child: Text('English')),
        DropdownMenuItem(value: Locale('kk'), child: Text('Қазақша')),
        DropdownMenuItem(value: Locale('ru'), child: Text('Русский')),
      ],
      onChanged: (locale) async {
        if (locale == null) return;
        final success = await ref.read(appLocaleProvider).select(locale);
        if (!success && context.mounted) {
          showMessage(context, context.l10n.languageSaveFailed);
        }
      },
    ),
    if (AppearanceScope.of(context) case final appearance?) ...[
      const SizedBox(height: 14),
      DropdownButtonFormField<ThemeMode>(
        initialValue: appearance.value,
        decoration: InputDecoration(labelText: context.l10n.appearance),
        items: [
          DropdownMenuItem(value: ThemeMode.system, child: Text(context.l10n.themeSystem)),
          DropdownMenuItem(value: ThemeMode.light, child: Text(context.l10n.themeLight)),
          DropdownMenuItem(value: ThemeMode.dark, child: Text(context.l10n.themeDark)),
        ],
        onChanged: (mode) async {
          if (mode == null) return;
          if (!await appearance.select(mode) && context.mounted) {
            showMessage(context, context.l10n.themeSaveFailed);
          }
        },
      ),
    ],
    const SizedBox(height: 12), Text(context.l10n.countryDisclosure, style: TextStyle(color: context.colors.muted, fontSize: 11)),
    const SizedBox(height: 20), PrimaryAction(label: context.l10n.save, onPressed: () async {
      final authService = ref.read(authServiceProvider);
      final result = await authService.updateProfile(displayName: _name.text.trim());
      if (!result.success) {
        if (context.mounted) showMessage(context, result.errorMessage ?? 'Could not update profile.');
        return;
      }
      final profileData = {
        'profile_country': _country,
        'profile_currency': _currency,
      };
      await authService.saveLocalProfile(profileData);
      if (context.mounted) {
        showMessage(context, context.l10n.profileSaved);
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
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.connectedAccounts)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    if (_connected) SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(backgroundColor: context.colors.subtleSurface, child: Text('KA')), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.kaspiDemoCard, style: TextStyle(fontWeight: FontWeight.w600)), Text(context.l10n.readOnlyDemo, style: TextStyle(color: context.colors.muted, fontSize: 11))]))]), const SizedBox(height: 14), Text(context.l10n.sampleLastSync, style: TextStyle(fontSize: 12)), Row(children: [TextButton(onPressed: () => showMessage(context, context.l10n.bankSyncUnavailable), child: Text(context.l10n.syncNow)), const Spacer(), TextButton(onPressed: () => setState(() => _connected = false), child: Text(context.l10n.disconnect))])])) else SurfaceCard(child: Text(context.l10n.noDemoCard)),
    const SizedBox(height: 14), SurfaceCard(color: context.colors.subtleSurface, child: Text(context.l10n.noBankIntegration, style: TextStyle(fontSize: 12))),
    const SizedBox(height: 18), PrimaryAction(label: context.l10n.addCard, onPressed: () => _push(context, const ConnectCardScreen())),
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
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.notifications)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    for (final entry in _values.entries) SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(_descriptions[entry.key]!, style: TextStyle(fontSize: 12, color: context.colors.muted)), value: entry.value, onChanged: (value) => setState(() => _values[entry.key] = value)),
    const SizedBox(height: 10), Text(context.l10n.noDemoPush, style: TextStyle(color: context.colors.muted, fontSize: 11)),
  ])));
}

class AdviceHistoryScreen extends StatelessWidget {
  const AdviceHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.adviceHistory)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    for (final item in [
      ('Savings', 'Cut food delivery by 15 000 ₸', 'Applied'),
      ('Deposit', 'Freedom Bank · 19.50% ГЭСВ', 'Viewed'),
      ('Stock', 'Halyk Bank (HSBK) fits Moderate', 'Saved'),
      ('Savings', 'Save 23 000 ₸ per month for New laptop', 'Applied'),
    ]) SurfaceCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item.$1} · ${item.$3}', style: TextStyle(color: context.colors.muted, fontSize: 11)), const SizedBox(height: 5), Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w600)), TextButton(onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text(context.l10n.aboutDemoItem), content: Text(context.l10n.adviceHistoryNotice), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.close))])), child: Text(context.l10n.whyThis))])),
  ])));
}

class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({super.key});
  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}
class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool _personalAdvice = true;
  bool _analytics = false;
  bool _working = false;

  Future<void> _export() async {
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUserId;
    if (uid == null) return;
    final repository = ref.read(financeRepositoryProvider);
    setState(() => _working = true);
    try {
      final data = await repository.exportAccountData(uid);
      if (!mounted || auth.currentUserId != uid) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(dialog.l10n.localDataExport),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(child: SelectableText(data)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!mounted || auth.currentUserId != uid) return;
                await Clipboard.setData(ClipboardData(text: data));
                if (dialog.mounted) Navigator.pop(dialog);
              },
              child: Text(dialog.l10n.copyJson),
            ),
            TextButton(onPressed: () => Navigator.pop(dialog), child: Text(dialog.l10n.close)),
          ],
        ),
      );
    } catch (_) {
      if (mounted) showMessage(context, context.l10n.exportFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showLegacyRecovery() => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(dialog.l10n.legacyRecovery),
      content: Text(dialog.l10n.legacyRecoveryWarning),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: Text(dialog.l10n.close)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.privacyData)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.personalAdviceConsent), subtitle: Text(context.l10n.neededForAdvice, style: TextStyle(fontSize: 12, color: context.colors.muted)), value: _personalAdvice, onChanged: (value) => setState(() => _personalAdvice = value)),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.l10n.shareStats), subtitle: Text(context.l10n.improvesApp, style: TextStyle(fontSize: 12, color: context.colors.muted)), value: _analytics, onChanged: (value) => setState(() => _analytics = value)),
    const SizedBox(height: 12), SurfaceCard(color: context.colors.subtleSurface, child: Text(context.l10n.privacyDisclosure, style: TextStyle(fontSize: 12))),
    const SizedBox(height: 12),
    OutlinedButton(onPressed: _working ? null : _export, child: Text(context.l10n.exportData)),
    OutlinedButton(
      onPressed: _working ? null : () => ref.read(syncRequestProvider.notifier).state++,
      child: Text(context.l10n.syncRecords),
    ),
    Consumer(builder: (context, ref, _) {
      final status = ref.watch(syncStatusMessageProvider);
      final strings = context.l10n;
      return switch (status) {
        SyncNotice.syncing => Text(strings.syncInProgress),
        SyncNotice.conflicts => Text(strings.syncConflicts),
        SyncNotice.unavailable => Text(strings.syncUnavailable),
        SyncNotice.complete => Text(strings.syncDone),
        null => const SizedBox.shrink(),
      };
    }),
    OutlinedButton(onPressed: _working ? null : _showLegacyRecovery, child: Text(context.l10n.recoverLegacy)),
    const SizedBox(height: 8), TextButton(onPressed: () => _push(context, const DeleteAccountScreen()), child: Text(context.l10n.deleteAccount, style: TextStyle(color: context.colors.error))),
  ])));
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() { _busy = true; _error = null; });
    final password = _password.text;
    _password.clear();
    final result = await ref.read(authServiceProvider).deleteAccount(
      password: password,
      repository: ref.read(financeRepositoryProvider),
    );
    if (!mounted) return;
    setState(() { _busy = false; _error = result.errorMessage; });
    if (result.success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.deleteAccount)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.l10n.deleteAccountWarning),
          CheckboxListTile(
            title: Text(context.l10n.deleteAccountConfirmation),
            value: _confirmed,
            onChanged: _busy ? null : (value) => setState(() => _confirmed = value == true),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            enabled: !_busy,
            decoration: InputDecoration(labelText: context.l10n.confirmWithPassword),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) Text(_error!),
          FilledButton(
            onPressed: _confirmed && !_busy && _password.text.isNotEmpty ? _delete : null,
            child: Text(_busy ? context.l10n.deleting : context.l10n.deletePermanently),
          ),
        ],
      ),
    ),
  );
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.subscription)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    SurfaceCard(color: context.colors.subtleSurface, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.freeCurrent, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), SizedBox(height: 10), Text(context.l10n.featureExpenses), Text(context.l10n.featureGoals), Text(context.l10n.featureDeposits)])),
    const SizedBox(height: 14), SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text(context.l10n.pricePending, style: TextStyle(color: context.colors.muted)), SizedBox(height: 10), Text(context.l10n.featureFree), Text(context.l10n.featureStocksBonds), Text(context.l10n.featurePersonalPlan), Text(context.l10n.featureAdviceHistory)])),
    const SizedBox(height: 12), Text(context.l10n.noSubscriptionBilling, style: TextStyle(color: context.colors.muted, fontSize: 11)),
    const SizedBox(height: 18), PrimaryAction(label: context.l10n.tryPremium, onPressed: () => showMessage(context, context.l10n.premiumPreview)),
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
    ('How do I delete my account?', 'Open Profile → Privacy & data → Delete account. Deletion requires your password and blocks when local changes have not synchronized.'),
  ];
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final filtered = _faqs.where((faq) => faq.$1.toLowerCase().contains(_search.text.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: Text(context.l10n.helpSupport)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: context.l10n.showHelp)),
      const SizedBox(height: 12),
      for (final faq in filtered) Card(color: context.colors.surface, child: ExpansionTile(title: Text(faq.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), children: [Padding(padding: const EdgeInsets.all(16), child: Text(faq.$2, style: TextStyle(fontSize: 12, color: context.colors.muted)))])),
      const SizedBox(height: 12), PrimaryAction(label: context.l10n.supportChat, onPressed: () => showMessage(context, context.l10n.noLiveSupport)),
      TextButton(onPressed: () => showMessage(context, context.l10n.privacyHelp), child: Text(context.l10n.privacyPolicy)),
    ])));
  }
}

Widget _choice(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label), items: options.entries.map((option) => DropdownMenuItem(value: option.key, child: Text(option.value))).toList(), onChanged: (next) { if (next != null) onChanged(next); });
void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
