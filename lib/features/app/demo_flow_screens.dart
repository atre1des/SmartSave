import '../../l10n/app_locale.dart';

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
        appBar: AppBar(title: Text(context.l10n.connectCard)),
        body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          Text(context.l10n.sampleCard, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(context.l10n.sampleCardDetails, style: TextStyle(color: context.colors.muted)),
          const SizedBox(height: 20),
          SurfaceCard(child: Row(children: [Icon(Icons.credit_card, color: context.colors.muted), SizedBox(width: 12), Flexible(child: Text('••••  ••••  ••••  ••••', style: TextStyle(letterSpacing: 1.2)))])),
          const SizedBox(height: 20),
          Text(context.l10n.chooseBank, style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [for (final bank in ['Kaspi', 'Halyk', 'Freedom', 'Other']) ChoiceChip(label: Text(bank), selected: _bank == bank, onSelected: (_) => setState(() => _bank = bank), selectedColor: context.colors.subtleSurface)]),
          const SizedBox(height: 18),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent, onChanged: (value) => setState(() => _consent = value ?? false), title: Text(context.l10n.demoConsent, style: TextStyle(fontSize: 12))),
          PrimaryAction(label: context.l10n.connectCard, onPressed: _continue),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiskQuizScreen())), child: Text(context.l10n.skipCard)),
          const SizedBox(height: 12),
          Text(context.l10n.sampleBankDisclaimer, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: context.colors.muted)),
        ])),
      );
}

class ConnectionFailedScreen extends StatelessWidget {
  const ConnectionFailedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.connectCard)),
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Spacer(),
          Icon(Icons.error_outline_rounded, size: 56, color: context.colors.error),
          const SizedBox(height: 18),
          Text(context.l10n.cardConnectionFailed, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(context.l10n.cardConnectionUnavailable, textAlign: TextAlign.center, style: TextStyle(color: context.colors.muted)),
          const SizedBox(height: 28),
          SurfaceCard(color: context.colors.noticeSurface, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.commonReasons, style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 8), Text(context.l10n.noBankProvider), Text(context.l10n.localDemoOnly), Text(context.l10n.noCredentialsRequested)])),
          const Spacer(),
          PrimaryAction(label: context.l10n.tryAgain, onPressed: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          SecondaryAction(label: context.l10n.skipForNow, onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiskQuizScreen()))),
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
  List<String> _questions(BuildContext context) => [
    context.l10n.quizQuestionOne,
    context.l10n.quizQuestionTwo,
    context.l10n.quizQuestionThree,
    context.l10n.quizQuestionFour,
    context.l10n.quizQuestionFive,
  ];
  List<List<String>> _options(BuildContext context) => [
    [context.l10n.quizSell, context.l10n.quizWait, context.l10n.quizBuy, context.l10n.quizUnknown],
    [context.l10n.quizYear, context.l10n.quizOneToThree, context.l10n.quizMoreThanThree, context.l10n.quizUnsure],
    [context.l10n.quizNone, context.l10n.quizLittle, context.l10n.quizSomeExperience, context.l10n.quizExperienced],
    [context.l10n.quizVeryLittle, context.l10n.quizSome, context.l10n.quizLots, context.l10n.quizUnknown],
    [context.l10n.quizProtect, context.l10n.quizBalance, context.l10n.quizLongTerm, context.l10n.quizUnsure],
  ];

  void _next() {
    if (_answer == null) {
      showMessage(context, context.l10n.quizRequired);
      return;
    }
    if (_question == _questions(context).length - 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiskProfileScreen()));
    } else {
      setState(() { _question++; _answer = null; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.riskQuiz)),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Question ${_question + 1} of 5', style: TextStyle(color: context.colors.muted)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: (_question + 1) / _questions(context).length, color: context.colors.progress, backgroundColor: context.colors.subtleSurface, minHeight: 8, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 28),
          Text(_questions(context)[_question], style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          for (final option in _options(context)[_question]) ...[
            InkWell(onTap: () => setState(() => _answer = option), borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15), decoration: BoxDecoration(color: _answer == option ? context.colors.subtleSurface : context.colors.surface, border: Border.all(color: _answer == option ? context.colors.text : context.colors.outline), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(_answer == option ? Icons.radio_button_checked : Icons.radio_button_off, color: context.colors.text), const SizedBox(width: 10), Expanded(child: Text(option))]))),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          SurfaceCard(color: context.colors.subtleSurface, child: Text(context.l10n.quizNotice, style: TextStyle(fontSize: 12))),
          const SizedBox(height: 20),
          PrimaryAction(label: _question == 4 ? context.l10n.seeRiskProfile : context.l10n.next, onPressed: _next),
        ])),
      );
}

class RiskProfileScreen extends StatelessWidget {
  const RiskProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.riskProfile)),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
          SurfaceCard(color: context.colors.subtleSurface, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.yourProfile), SizedBox(height: 4), Text(context.l10n.moderate, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text(context.l10n.moderateExplanation) ])),
          const SizedBox(height: 20),
          Text(context.l10n.whyResult, style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.profileWouldWait), SizedBox(height: 9), Text(context.l10n.profileHorizon), SizedBox(height: 9), Text(context.l10n.profileMix)])),
          const SizedBox(height: 20),
          Text(context.l10n.suggestedMix, style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SurfaceCard(child: Column(children: [LabeledValue(label: context.l10n.deposits, value: '60%'), Divider(), LabeledValue(label: context.l10n.bonds, value: '25%'), Divider(), LabeledValue(label: context.l10n.stocks, value: '15%')])),
          const SizedBox(height: 12),
          Text(context.l10n.sampleProfileDisclaimer, textAlign: TextAlign.center, style: TextStyle(color: context.colors.muted, fontSize: 11)),
          const SizedBox(height: 20),
          PrimaryAction(label: context.l10n.continueSmartSave, onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('demo_session', true); await prefs.setBool('risk_profile_complete', true); if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AppShell()), (_) => false); }),
          TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiskQuizScreen())), child: Text(context.l10n.retakeQuiz)),
        ])),
      );
}
