import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/finance_controller.dart';
import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import '../app/app.dart';
import '../app/demo_flow_screens.dart';
import '../goals/goals_screen.dart';
import '../transactions/transactions_screen.dart';
import '../invest/investment_intelligence_screen.dart';
import '../invest/invest_screen.dart';
import 'profile_screen.dart';

class MyAccountScreen extends ConsumerWidget {
  const MyAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: Text('My Account'),
      ),
      body: SafeArea(
        child: finance.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.firefly))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  // User identity section
                  _UserIdentitySection(
                    finance: finance,
                    prefs: prefs,
                  ),
                  const SizedBox(height: 24),

                  // Risk Profile / Investor Level
                  _RiskProfileCard(finance: finance),
                  const SizedBox(height: 24),

                  // Goals section
                  _GoalsSection(finance: finance),
                  const SizedBox(height: 24),

                  // Connected Accounts
                  _SettingRow(
                    title: 'Connected accounts',
                    subtitle: 'Cards and banks · demo only',
                    icon: Icons.credit_card_outlined,
                    onTap: () => _push(context, const ConnectedAccountsScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Advice History
                  _SettingRow(
                    title: 'Advice history',
                    subtitle: 'Past recommendations',
                    icon: Icons.history,
                    onTap: () => _push(context, const AdviceHistoryScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Settings section
                  const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.firefly)),
                  const SizedBox(height: 12),
                  _SettingRow(
                    title: 'Profile',
                    subtitle: 'Name, country, currency',
                    icon: Icons.person_outline,
                    onTap: () => _push(context, const ProfileDetailsScreen()),
                  ),
                  _SettingRow(
                    title: 'Notifications',
                    subtitle: 'Reminders and alerts',
                    icon: Icons.notifications_none,
                    onTap: () => _push(context, const NotificationsScreen()),
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
                  const SizedBox(height: 20),

                  // Log out
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                          (_) => false,
                        );
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
                          content: const Text('Replaces local demo records with the original fictional examples.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                await _reset(context, ref);
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

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    await ref.read(financeControllerProvider).resetDemoData();
    if (context.mounted) showMessage(context, 'Fictional demo data restored.');
  }
}

class _UserIdentitySection extends ConsumerWidget {
  const _UserIdentitySection({required this.finance, required this.prefs});
  final FinanceController finance;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = prefs.getString('profile_name') ?? 'Your name';

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.mintLight,
          foregroundColor: AppColors.firefly,
          radius: 28,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'Y',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Kazakhstan',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RiskProfileCard extends ConsumerWidget {
  const _RiskProfileCard({required this.finance});
  final FinanceController finance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final riskProfile = prefs.getString('risk_profile') ?? 'moderate';
    final riskLabel = riskProfile[0].toUpperCase() + riskProfile.substring(1);

    return SurfaceCard(
      onTap: () => _push(context, const RiskQuizScreen()),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.firefly, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Risk Profile / Investor Level',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '$riskLabel investor · Tap to retake quiz',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _GoalsSection extends ConsumerWidget {
  const _GoalsSection({required this.finance});
  final FinanceController finance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('My Goals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.firefly)),
            TextButton(
              onPressed: () => _push(context, const GoalsScreen()),
              child: const Text('View all', style: TextStyle(color: AppColors.prussianBlue, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (finance.goals.isEmpty)
          SurfaceCard(
            color: AppColors.mintLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No goals yet', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Create a goal to start tracking progress toward your savings targets.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 12),
                PrimaryAction(
                  label: 'Create your first goal',
                  onPressed: () => _push(context, const GoalsScreen()),
                ),
              ],
            ),
          )
        else ...[
          for (final goal in finance.goals.take(2)) ...[
            _GoalCard(goal: goal),
            const SizedBox(height: 12),
          ],
          if (finance.goals.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => _push(context, const GoalsScreen()),
                child: Text('View ${finance.goals.length - 2} more goal${finance.goals.length > 3 ? 's' : ''}'),
              ),
            ),
          const SizedBox(height: 16),
          // AI suggestion card
          if (finance.goals.isNotEmpty) _AISuggestionCard(goal: finance.goals.first),
        ],
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: () => _push(context, GoalProgressScreen(goal: goal)),
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('${goal.progressPercent}%', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 9),
        ProgressTrack(value: goal.target == 0 ? 0 : goal.saved / goal.target),
        const SizedBox(height: 8),
        Text('${formatTenge(goal.saved)} / ${formatTenge(goal.target)} · ${_monthsLeft(goal.deadline)} months left', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        const Text('On track', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    ),
  );
  }

  int _monthsLeft(DateTime deadline) {
    final now = DateTime.now();
    return ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(0, 120);
  }

class _AISuggestionCard extends ConsumerWidget {
  const _AISuggestionCard({required this.goal});
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = _monthsLeft(goal.deadline).clamp(1, 120).toInt();
    final monthly = monthlyGoalContribution(targetTenge: goal.target, savedTenge: goal.saved, monthsRemaining: months);

    return SurfaceCard(
      color: AppColors.paleGold,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text('SmartSave suggestion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Want to reach "${goal.name}" faster? You need ${formatTenge(monthly)}/month. Explore adding money to a deposit or an investment scenario.',
            style: TextStyle(fontSize: 12, color: AppColors.firefly),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _push(context, const DepositRatesScreen()),
                  child: const Text('Explore deposits'),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _push(context, const InvestmentIntelligenceScreen()),
                  child: const Text('Investment scenarios'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Investments can lose value. This is educational information, not a guaranteed outcome.',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  int _monthsLeft(DateTime deadline) {
    final now = DateTime.now();
    return ((deadline.year - now.year) * 12 + deadline.month - now.month).clamp(0, 120);
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.subtitle, required this.icon, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 3),
    leading: Icon(icon, color: AppColors.firefly),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));