import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';

import '../../shared/theme.dart';
import '../../shared/widgets.dart';

class RiskQuizScreen extends ConsumerStatefulWidget {
  const RiskQuizScreen({super.key});

  @override
  ConsumerState<RiskQuizScreen> createState() => _RiskQuizScreenState();
}

class _RiskQuizScreenState extends ConsumerState<RiskQuizScreen> {
  int _step = 0;
  final List<String?> _answers = List.filled(5, null);

  static const _questions = [
    _QuizQuestion(
      question: 'How long are you willing to invest without needing the money?',
      options: [
        ('wait', 'Less than 1 year'),
        ('1-3years', '1–3 years'),
        ('3-5years', '3–5 years'),
        ('5plus', 'More than 5 years'),
      ],
    ),
    _QuizQuestion(
      question: 'How would you describe your experience with investing?',
      options: [
        ('none', 'None – this is new to me'),
        ('some', 'Some – I understand the basics'),
        ('experienced', 'Experienced – I actively invest'),
      ],
    ),
    _QuizQuestion(
      question: 'If your investment dropped 15% in a month, what would you do?',
      options: [
        ('sell', 'Sell immediately to avoid more loss'),
        ('hold', 'Hold and wait for recovery'),
        ('buy', 'Buy more at a lower price'),
      ],
    ),
    _QuizQuestion(
      question: 'What portion of your savings are you comfortable putting at risk?',
      options: [
        ('small', 'A small amount (up to 10%)'),
        ('moderate', 'A moderate amount (10–30%)'),
        ('large', 'A significant amount (30%+)'),
      ],
    ),
    _QuizQuestion(
      question: 'What is your primary goal for this money?',
      options: [
        ('preserve', 'Preserve capital – I can\'t afford to lose it'),
        ('balance', 'Balance of growth and stability'),
        ('growth', 'Maximize growth – I accept higher risk'),
      ],
    ),
  ];

  Future<void> _finish() async {
    if (_answers.any((a) => a == null)) return;

    final profile = _calculateRiskProfile(_answers);
    await ref.read(authServiceProvider).setRiskQuizComplete(true, profile: profile);

    if (mounted) {
      showMessage(context, 'Risk profile updated: ${profile[0].toUpperCase()}${profile.substring(1)} investor');
      Navigator.pop(context);
    }
  }

  String _calculateRiskProfile(List<String?> answers) {
    int score = 0;
    // Time horizon
    score += switch (answers[0]) { 'wait' => 1, '1-3years' => 2, '3-5years' => 3, '5plus' => 4, _ => 1 };
    // Experience
    score += switch (answers[1]) { 'none' => 1, 'some' => 2, 'experienced' => 3, _ => 1 };
    // Reaction to loss
    score += switch (answers[2]) { 'sell' => 1, 'hold' => 2, 'buy' => 3, _ => 1 };
    // Risk allocation
    score += switch (answers[3]) { 'small' => 1, 'moderate' => 2, 'large' => 3, _ => 1 };
    // Goal
    score += switch (answers[4]) { 'preserve' => 1, 'balance' => 2, 'growth' => 3, _ => 1 };

    if (score <= 7) return 'conservative';
    if (score <= 11) return 'moderate';
    return 'growth';
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_step];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.riskAssessment),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(context.l10n.finish, style: TextStyle(color: AppColors.firefly)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_step + 1) / _questions.length,
                color: AppColors.firefly,
                backgroundColor: AppColors.mintLight,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(
                'Question ${_step + 1} of ${_questions.length}',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.mintLight,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 80,
                    color: AppColors.firefly,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                question.question,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  for (final option in question.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuizOption(
                        label: option.$2,
                        value: option.$1,
                        selected: _answers[_step] == option.$1,
                        onTap: () => setState(() => _answers[_step] = option.$1),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: Text(context.l10n.back),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryAction(
                      label: _step == _questions.length - 1 ? context.l10n.finish : context.l10n.next,
                      onPressed: _answers[_step] != null
                          ? (_step == _questions.length - 1 ? _finish : () => setState(() => _step++))
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({required this.question, required this.options});
  final String question;
  final List<(String, String)> options;
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({required this.label, required this.value, required this.selected, required this.onTap});
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.firefly : Colors.white,
        border: Border.all(
          color: selected ? AppColors.firefly : AppColors.border,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              border: Border.all(
                color: selected ? Colors.white : AppColors.border,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: selected
                ? const Icon(Icons.check, color: AppColors.firefly, size: 16)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.firefly,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}