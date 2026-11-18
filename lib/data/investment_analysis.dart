import 'investment_models.dart';

ConditionAssessment evaluateCondition(ThesisCondition condition) {
  final hasSource =
      condition.source.trim().isNotEmpty &&
      condition.reportingPeriod.trim().isNotEmpty;
  final hasObservedValue = condition.observedValue != null;
  if (!condition.isNumeric || !hasSource || !hasObservedValue) {
    return ConditionAssessment(
      conditionId: condition.id ?? 0,
      description: condition.description,
      status: EvidenceStatus.insufficient,
      explanation: condition.isNumeric
          ? 'A numeric observation, source and reporting period are required to evaluate this condition.'
          : 'Qualitative evidence requires review of an issuer disclosure; no verified disclosure is connected.',
      evidence: condition.evidenceNote.trim().isEmpty
          ? 'No usable evidence recorded.'
          : condition.evidenceNote.trim(),
      source: condition.source.trim(),
      reportingPeriod: condition.reportingPeriod.trim(),
      observedValue: condition.observedValue,
    );
  }

  final observed = condition.observedValue!;
  final threshold = condition.threshold!;
  final passed = condition.comparator == ConditionComparator.atLeast
      ? observed >= threshold
      : observed <= threshold;
  return ConditionAssessment(
    conditionId: condition.id ?? 0,
    description: condition.description,
    status: passed ? EvidenceStatus.supported : EvidenceStatus.contradicted,
    explanation: passed
        ? 'The user-entered value meets the stated threshold. This is a rule-based comparison, not independent verification.'
        : 'The user-entered value does not meet the stated threshold. This is a rule-based comparison, not independent verification.',
    evidence: condition.evidenceNote.trim().isEmpty
        ? 'Observed ${condition.metric}: $observed.'
        : condition.evidenceNote.trim(),
    source: condition.source.trim(),
    reportingPeriod: condition.reportingPeriod.trim(),
    observedValue: observed,
  );
}

ThesisAssessment analyzeThesis(
  InvestmentThesis thesis,
  List<ThesisCondition> conditions, {
  DateTime? now,
}) {
  final assessments = conditions.map(evaluateCondition).toList();
  final unsupported = assessments
      .where((item) => item.status == EvidenceStatus.insufficient)
      .length;
  final supported = assessments
      .where((item) => item.status == EvidenceStatus.supported)
      .length;
  final contradicted = assessments
      .where((item) => item.status == EvidenceStatus.contradicted)
      .length;
  final rationale = thesis.rationale.trim();
  final arguments = <String>[
    if (rationale.isNotEmpty) 'User-stated rationale: $rationale',
    if (supported > 0)
      '$supported user-defined numeric condition(s) currently meet their entered thresholds.',
    if (rationale.isEmpty && supported == 0)
      'No supporting thesis rationale or qualifying numeric evidence was provided.',
  ];
  final counterarguments = <String>[
    if (thesis.risks.trim().isNotEmpty)
      'User-identified risks: ${thesis.risks.trim()}',
    if (contradicted > 0)
      '$contradicted user-defined numeric condition(s) currently miss their entered thresholds.',
    if (thesis.risks.trim().isEmpty)
      'The user has not recorded principal risks; this is a research gap, not evidence that risks are absent.',
  ];
  return ThesisAssessment(
    thesisId: thesis.id ?? 0,
    assessedAt: now ?? DateTime.now(),
    conditions: assessments,
    supportingArguments: arguments,
    counterarguments: counterarguments,
    unverifiedAssumptions: thesis.assumptions.trim().isEmpty
        ? const ['No assumptions have been recorded.']
        : [thesis.assumptions.trim()],
    overlookedRisks: thesis.risks.trim().isEmpty
        ? const [
            'Review issuer-specific, market, currency and liquidity risks. These are prompts, not claims about this issuer.',
          ]
        : const [
            'Consider whether the recorded risks cover issuer, market, currency and liquidity exposures.',
          ],
    reconsiderationTriggers: thesis.invalidationConditions.trim().isEmpty
        ? const [
            'Define observable events that would weaken or invalidate the thesis.',
          ]
        : [thesis.invalidationConditions.trim()],
    additionalInformation: [
      if (unsupported > 0)
        'Obtain dated issuer disclosures or financial statements for $unsupported condition(s) with insufficient evidence.',
      'Review source documents and reporting periods directly before relying on any user-entered values.',
    ],
  );
}

LiquidityAnalysis analyzeLiquidity({
  required double orderSize,
  required double? averageDailyVolume,
  required String volumeUnit,
  required DateTime? observedAt,
  required int participationPercent,
  DateTime? now,
}) {
  if (orderSize <= 0 ||
      participationPercent <= 0 ||
      participationPercent > 100) {
    throw ArgumentError(
      'Order size and participation must be positive; participation cannot exceed 100%.',
    );
  }
  if (averageDailyVolume == null ||
      averageDailyVolume <= 0 ||
      observedAt == null) {
    return const LiquidityAnalysis(
      status: 'insufficient',
      volumeMultiple: null,
      scenarioDays: null,
      message:
          'Insufficient volume observations. Add a dated historical average volume to run this scenario.',
    );
  }
  final age = (now ?? DateTime.now()).difference(observedAt);
  if (age.isNegative || age > const Duration(days: 7)) {
    return LiquidityAnalysis(
      status: 'stale',
      volumeMultiple: null,
      scenarioDays: null,
      message:
          'The volume observation is more than 7 days old or dated in the future. Refresh it before interpreting the scenario.',
    );
  }
  final multiple = orderSize / averageDailyVolume;
  final days = orderSize / (averageDailyVolume * participationPercent / 100);
  final message = multiple >= 1
      ? 'The hypothetical order is ${multiple.toStringAsFixed(1)}× the entered average daily volume. At the selected participation assumption, the scenario spans about ${days.toStringAsFixed(1)} trading days. This is not a prediction of executable liquidity or price.'
      : 'The hypothetical order is ${(multiple * 100).toStringAsFixed(1)}% of the entered average daily volume. Historical volume is not current order-book depth or a promise of execution.';
  return LiquidityAnalysis(
    status: 'scenario',
    volumeMultiple: multiple,
    scenarioDays: days,
    message: message,
    volumeUnit: volumeUnit,
  );
}

class LiquidityAnalysis {
  const LiquidityAnalysis({
    required this.status,
    required this.volumeMultiple,
    required this.scenarioDays,
    required this.message,
    this.volumeUnit = '',
  });
  final String status;
  final double? volumeMultiple;
  final double? scenarioDays;
  final String message;
  final String volumeUnit;
}

RippleResult simulateRipple({
  required List<PortfolioHolding> holdings,
  required EconomicScenario scenario,
  required double magnitude,
}) {
  if (magnitude < 0) {
    throw ArgumentError('Scenario magnitude cannot be negative.');
  }
  final results = holdings.map((holding) {
    final sensitivity = switch (scenario) {
      EconomicScenario.tengeDepreciation => holding.fxSensitivityPctPerPct,
      EconomicScenario.oilPriceDecrease => holding.oilSensitivityPctPerPct,
      EconomicScenario.interestRateIncrease =>
        holding.rateSensitivityPctPerPoint,
    };
    if (sensitivity == null) {
      return HoldingScenarioResult(
        holding: holding,
        returnPercent: null,
        changeKzt: null,
      );
    }
    final direction = scenario == EconomicScenario.oilPriceDecrease ? -1 : 1;
    final estimatedReturnPercent = sensitivity * magnitude * direction;
    final changeKzt = (holding.marketValueKzt * estimatedReturnPercent / 100)
        .round();
    return HoldingScenarioResult(
      holding: holding,
      returnPercent: estimatedReturnPercent,
      changeKzt: changeKzt,
    );
  }).toList();
  final before = holdings.fold<int>(
    0,
    (total, holding) => total + holding.marketValueKzt,
  );
  final after = results.every((result) => result.changeKzt != null)
      ? before +
            results.fold<int>(
              0,
              (total, result) => total + (result.changeKzt ?? 0),
            )
      : null;
  return RippleResult(
    beforeKzt: before,
    afterKzt: after,
    holdings: results,
    scenario: scenario,
    magnitude: magnitude,
  );
}
