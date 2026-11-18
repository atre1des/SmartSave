import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import 'app.dart';

class ConnectCardScreen extends StatefulWidget {
  const ConnectCardScreen({super.key});
  @override
  State<ConnectCardScreen> createState() => _ConnectCardScreenState();
}

class _ConnectCardScreenState extends State<ConnectCardScreen> {
  String? _bank;
  bool _consent = false;

  void _continue() {
    if (_bank == null || !_consent) {
      showMessage(context, 'Choose a bank and accept the demo data notice, or skip card setup.');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionFailedScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Connect card')),
        body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          Text('Link your card to see where your money goes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Read-only access. SmartSave cannot move or spend your money.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          const SurfaceCard(child: Row(children: [Icon(Icons.credit_card, color: AppColors.muted), SizedBox(width: 12), Text('••••  ••••  ••••  ••••', style: TextStyle(letterSpacing: 1.2))])),
          const SizedBox(height: 20),
          const Text('Choose your bank', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [for (final bank in ['Kaspi', 'Halyk', 'Freedom', 'Other']) ChoiceChip(label: Text(bank), selected: _bank == bank, onSelected: (_) => setState(() => _bank = bank), selectedColor: AppColors.mintLight)]),
          const SizedBox(height: 18),
          const SurfaceCard(color: AppColors.mintLight, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('✓  Read-only access to balance and transactions'), SizedBox(height: 8), Text('✓  Data is encrypted and never sold'), SizedBox(height: 8), Text('✓  Disconnect and delete data anytime')])),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent, onChanged: (value) => setState(() => _consent = value ?? false), title: const Text('I agree to the processing of demo financial data. Privacy policy', style: TextStyle(fontSize: 12))),
          PrimaryAction(label: 'Connect card', onPressed: _continue),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiskQuizScreen())), child: const Text('Skip, add transactions manually')),
          const SizedBox(height: 12),
          const Text('This prototype does not connect to any bank. Sample transactions are fictional.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ])),
      );
}

class ConnectionFailedScreen extends StatelessWidget {
  const ConnectionFailedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Connect card')),
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Spacer(),
          const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.wine),
          const SizedBox(height: 18),
          Text('We could not connect your card', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text('The bank connection is not available in this demo. Nothing was changed on your account.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          const SurfaceCard(color: AppColors.paleRose, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Common reasons', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 8), Text('• Bank connection provider is not configured'), Text('• This is a local-only demonstration'), Text('• No account credentials are requested')])),
          const Spacer(),
          PrimaryAction(label: 'Try again', onPressed: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          SecondaryAction(label: 'Skip for now', onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiskQuizScreen()))),
        ]))),
      );
}

class RiskQuizScreen extends StatefulWidget {
  const RiskQuizScreen({super.key});
  @override
  State<RiskQuizScreen> createState() => _RiskQuizScreenState();
}

class _RiskQuizScreenState extends State<RiskQuizScreen> {
  int _question = 0;
  String? _answer;
  static const _questions = [
    'If your investment fell 10% in one month, what would you do?',
    'When might you need the money you are setting aside?',
    'How would you describe your investing experience?',
    'How much short-term change in value feels manageable?',
    'Which statement best describes your preference?',
  ];
  static const _options = [
    ['Sell everything to avoid more losses', 'Wait and see before deciding', 'Buy more while prices are lower', 'I do not know'],
    ['Within a year', 'In 1 to 3 years', 'In more than 3 years', 'I am not sure'],
    ['None yet', 'A little', 'Some experience', 'Experienced'],
    ['Very little', 'Some', 'A lot', 'I do not know'],
    ['Protect what I have', 'Balance safety and growth', 'Focus on long-term growth', 'I am not sure'],
  ];

  void _next() {
    if (_answer == null) {
      showMessage(context, 'Choose an answer to continue.');
      return;
    }
    if (_question == _questions.length - 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiskProfileScreen()));
    } else {
      setState(() { _question++; _answer = null; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Risk quiz')),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Question ${_question + 1} of 5', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: (_question + 1) / _questions.length, color: AppColors.mint, backgroundColor: AppColors.mintLight, minHeight: 8, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 28),
          Text(_questions[_question], style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          for (final option in _options[_question]) ...[
            InkWell(onTap: () => setState(() => _answer = option), borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15), decoration: BoxDecoration(color: _answer == option ? AppColors.mintLight : Colors.white, border: Border.all(color: _answer == option ? AppColors.firefly : AppColors.border), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(_answer == option ? Icons.radio_button_checked : Icons.radio_button_off, color: AppColors.firefly), const SizedBox(width: 10), Expanded(child: Text(option))]))),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          const SurfaceCard(color: AppColors.mintLight, child: Text('Your answers set an illustrative demo risk profile. This is not investment advice.', style: TextStyle(fontSize: 12))),
          const SizedBox(height: 20),
          PrimaryAction(label: _question == 4 ? 'See risk profile' : 'Next', onPressed: _next),
        ])),
      );
}

class RiskProfileScreen extends StatelessWidget {
  const RiskProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Risk profile')),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
          const SurfaceCard(color: AppColors.mintLight, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your profile'), SizedBox(height: 4), Text('Moderate', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('You accept small short-term losses in exchange for steadier growth.') ])),
          const SizedBox(height: 20),
          const Text('Why this result', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('✓  You would wait if prices fall 10%'), SizedBox(height: 9), Text('✓  Your goal horizon is 1 to 3 years'), SizedBox(height: 9), Text('✓  You prefer a mix of deposits and bonds')])),
          const SizedBox(height: 20),
          const Text('Suggested mix (illustrative)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const SurfaceCard(child: Column(children: [LabeledValue(label: 'Deposits', value: '60%'), Divider(), LabeledValue(label: 'Bonds', value: '25%'), Divider(), LabeledValue(label: 'Stocks', value: '15%')])),
          const SizedBox(height: 12),
          const Text('Sample profile only. Not investment advice.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 20),
          PrimaryAction(label: 'Continue to SmartSave', onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('demo_session', true); await prefs.setBool('risk_profile_complete', true); if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AppShell()), (_) => false); }),
          TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiskQuizScreen())), child: const Text('Retake quiz')),
        ])),
      );
}
