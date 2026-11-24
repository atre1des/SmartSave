import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/finance_controller.dart';
import '../../data/finance_repository.dart';
import '../../data/financial_math.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import '../app/demo_flow_screens.dart';
import '../goals/goals_screen.dart';
import '../invest/investment_intelligence_screen.dart';
import '../invest/invest_screen.dart';
import 'profile_screen.dart';

class MyAccountScreen extends ConsumerWidget {
  const MyAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.myAccount)),
      body: SafeArea(
        child: finance.isLoading
            ? Center(child: CircularProgressIndicator(color: context.colors.text))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  // User identity section
                  const _UserIdentitySection(),
                  const SizedBox(height: 24),

                  // Risk Profile / Investor Level
                  _RiskProfileCard(finance: finance),
                  const SizedBox(height: 24),

                  // Goals section
                  _GoalsSection(finance: finance),
                  const SizedBox(height: 24),

                  // Connected Accounts
                  _SettingRow(
                    title: context.l10n.connectedAccounts,
                    subtitle: context.l10n.demoCards,
                    icon: Icons.credit_card_outlined,
                    onTap: () => _push(context, const ConnectedAccountsScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Advice History
                  _SettingRow(
                    title: context.l10n.adviceHistory,
                    subtitle: context.l10n.pastAdvice,
                    icon: Icons.history,
                    onTap: () => _push(context, const AdviceHistoryScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Settings section
                  Text(context.l10n.settings, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.colors.text)),
                  const SizedBox(height: 12),
                  _SettingRow(
                    title: context.l10n.profile,
                    subtitle: context.l10n.nameCountryCurrency,
                    icon: Icons.person_outline,
                    onTap: () => _push(context, const ProfileDetailsScreen()),
                  ),
                  _SettingRow(
                    title: context.l10n.notifications,
                    subtitle: context.l10n.alerts,
                    icon: Icons.notifications_none,
                    onTap: () => _push(context, const NotificationsScreen()),
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
                  const SizedBox(height: 20),

                  // Log out
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

class _UserIdentitySection extends ConsumerWidget {
  const _UserIdentitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authStateProvider).valueOrNull?.displayName ?? 'Your name';

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: context.colors.subtleSurface,
          foregroundColor: context.colors.text,
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
                context.l10n.kazakhstan,
                style: TextStyle(color: context.colors.muted, fontSize: 12),
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
    final riskProfile = ref.watch(authServiceProvider).getRiskProfile() ?? 'moderate';
    final riskLabel = riskProfile[0].toUpperCase() + riskProfile.substring(1);

    return SurfaceCard(
      onTap: () => _push(context, const RiskQuizScreen()),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.subtleSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shield_outlined, color: context.colors.text, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.investorLevel,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '$riskLabel investor · Tap to retake quiz',
                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.muted),
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
            Text(context.l10n.myGoals, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.colors.text)),
            TextButton(
              onPressed: () => _push(context, const GoalsScreen()),
              child: Text(context.l10n.viewAll, style: TextStyle(color: context.colors.action, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (finance.goals.isEmpty)
          SurfaceCard(
            color: context.colors.subtleSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.noGoals, style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(context.l10n.createGoalHint, style: TextStyle(fontSize: 12, color: context.colors.muted)),
                const SizedBox(height: 12),
                PrimaryAction(
                  label: context.l10n.createFirstGoal,
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
                child: Text(context.l10n.monthsMoreGoals(finance.goals.length - 2)),
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
            Text(context.formatPercent(goal.progressPercent), style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 9),
        ProgressTrack(value: goal.target == 0 ? 0 : goal.saved / goal.target),
        const SizedBox(height: 8),
        Text('${context.formatTenge(goal.saved)} / ${context.formatTenge(goal.target)} · ${context.l10n.monthsLeft(_monthsLeft(goal.deadline))}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(context.l10n.onTrack, style: TextStyle(color: context.colors.positive, fontSize: 11, fontWeight: FontWeight.w600)),
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
      color: context.colors.noticeSurface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: context.colors.premium,
                foregroundColor: context.colors.onPremium,
                child: const Icon(Icons.lightbulb_outline, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(context.l10n.recommendationSmartSave, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.goalSuggestion(goal.name, context.formatTenge(monthly)),
            style: TextStyle(fontSize: 12, color: context.colors.text),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => _push(context, const DepositRatesScreen()),
                child: Text(context.l10n.exploreDeposits),
              ),
              OutlinedButton(
                onPressed: () => _push(context, const InvestmentIntelligenceScreen()),
                child: Text(context.l10n.investScenarios),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.accountInvestmentDisclaimer,
            style: TextStyle(color: context.colors.muted, fontSize: 10),
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
    leading: Icon(icon, color: context.colors.text),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    subtitle: Text(subtitle, style: TextStyle(color: context.colors.muted, fontSize: 11)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));