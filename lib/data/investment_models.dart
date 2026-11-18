import 'dart:convert';

enum EvidenceStatus {
  supported,
  weakening,
  contradicted,
  insufficient,
  notEvaluated,
}

enum ConditionComparator { atLeast, atMost }

enum EconomicScenario {
  tengeDepreciation,
  oilPriceDecrease,
  interestRateIncrease,
}

class InvestmentThesis {
  const InvestmentThesis({
    this.id,
    required this.securityName,
    required this.ticker,
    this.exchange = 'KASE',
    this.identifier = '',
    this.rationale = '',
    this.horizon = '',
    this.assumptions = '',
    this.risks = '',
    this.invalidationConditions = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String securityName;
  final String ticker;
  final String exchange;
  final String identifier;
  final String rationale;
  final String horizon;
  final String assumptions;
  final String risks;
  final String invalidationConditions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory InvestmentThesis.fromMap(Map<String, Object?> map) =>
      InvestmentThesis(
        id: map['id'] as int,
        securityName: map['security_name'] as String,
        ticker: map['ticker'] as String,
        exchange: map['exchange'] as String,
        identifier: map['identifier'] as String,
        rationale: map['rationale'] as String,
        horizon: map['horizon'] as String,
        assumptions: map['assumptions'] as String,
        risks: map['risks'] as String,
        invalidationConditions: map['invalidation_conditions'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
    'security_name': securityName,
    'ticker': ticker,
    'exchange': exchange,
    'identifier': identifier,
    'rationale': rationale,
    'horizon': horizon,
    'assumptions': assumptions,
    'risks': risks,
    'invalidation_conditions': invalidationConditions,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class ThesisCondition {
  const ThesisCondition({
    this.id,
    required this.thesisId,
    required this.description,
    this.metric = '',
    this.comparator = ConditionComparator.atLeast,
    this.threshold,
    this.observedValue,
    this.reportingPeriod = '',
    this.source = '',
    this.evidenceNote = '',
  });

  final int? id;
  final int thesisId;
  final String description;
  final String metric;
  final ConditionComparator comparator;
  final double? threshold;
  final double? observedValue;
  final String reportingPeriod;
  final String source;
  final String evidenceNote;

  bool get isNumeric => threshold != null;

  factory ThesisCondition.fromMap(Map<String, Object?> map) => ThesisCondition(
    id: map['id'] as int,
    thesisId: map['thesis_id'] as int,
    description: map['description'] as String,
    metric: map['metric'] as String,
    comparator: map['comparator'] == 'atMost'
        ? ConditionComparator.atMost
        : ConditionComparator.atLeast,
    threshold: (map['threshold'] as num?)?.toDouble(),
    observedValue: (map['observed_value'] as num?)?.toDouble(),
    reportingPeriod: map['reporting_period'] as String,
    source: map['source'] as String,
    evidenceNote: map['evidence_note'] as String,
  );

  Map<String, Object?> toMap() => {
    'thesis_id': thesisId,
    'description': description,
    'metric': metric,
    'comparator': comparator.name,
    'threshold': threshold,
    'observed_value': observedValue,
    'reporting_period': reportingPeriod,
    'source': source,
    'evidence_note': evidenceNote,
  };
}

class ConditionAssessment {
  const ConditionAssessment({
    required this.conditionId,
    required this.description,
    required this.status,
    required this.explanation,
    required this.evidence,
    required this.source,
    required this.reportingPeriod,
    this.observedValue,
  });

  final int conditionId;
  final String description;
  final EvidenceStatus status;
  final String explanation;
  final String evidence;
  final String source;
  final String reportingPeriod;
  final double? observedValue;

  Map<String, Object?> toMap() => {
    'condition_id': conditionId,
    'description': description,
    'status': status.name,
    'explanation': explanation,
    'evidence': evidence,
    'source': source,
    'reporting_period': reportingPeriod,
    'observed_value': observedValue,
  };

  factory ConditionAssessment.fromMap(Map<String, Object?> map) =>
      ConditionAssessment(
        conditionId: map['condition_id'] as int,
        description: map['description'] as String,
        status: EvidenceStatus.values.firstWhere(
          (item) => item.name == map['status'],
          orElse: () => EvidenceStatus.insufficient,
        ),
        explanation: map['explanation'] as String,
        evidence: map['evidence'] as String,
        source: map['source'] as String,
        reportingPeriod: map['reporting_period'] as String,
        observedValue: (map['observed_value'] as num?)?.toDouble(),
      );
}

class ThesisAssessment {
  const ThesisAssessment({
    this.id,
    required this.thesisId,
    required this.assessedAt,
    required this.conditions,
    required this.supportingArguments,
    required this.counterarguments,
    required this.unverifiedAssumptions,
    required this.overlookedRisks,
    required this.reconsiderationTriggers,
    required this.additionalInformation,
  });

  final int? id;
  final int thesisId;
  final DateTime assessedAt;
  final List<ConditionAssessment> conditions;
  final List<String> supportingArguments;
  final List<String> counterarguments;
  final List<String> unverifiedAssumptions;
  final List<String> overlookedRisks;
  final List<String> reconsiderationTriggers;
  final List<String> additionalInformation;

  Map<String, Object?> toMap() => {
    'thesis_id': thesisId,
    'assessed_at': assessedAt.toIso8601String(),
    'payload_json': jsonEncode({
      'conditions': conditions.map((item) => item.toMap()).toList(),
      'supporting_arguments': supportingArguments,
      'counterarguments': counterarguments,
      'unverified_assumptions': unverifiedAssumptions,
      'overlooked_risks': overlookedRisks,
      'reconsideration_triggers': reconsiderationTriggers,
      'additional_information': additionalInformation,
    }),
  };

  factory ThesisAssessment.fromMap(Map<String, Object?> map) {
    final payload =
        jsonDecode(map['payload_json'] as String) as Map<String, dynamic>;
    List<String> strings(String key) =>
        (payload[key] as List<dynamic>).cast<String>();
    return ThesisAssessment(
      id: map['id'] as int,
      thesisId: map['thesis_id'] as int,
      assessedAt: DateTime.parse(map['assessed_at'] as String),
      conditions: (payload['conditions'] as List<dynamic>)
          .map(
            (item) => ConditionAssessment.fromMap(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
      supportingArguments: strings('supporting_arguments'),
      counterarguments: strings('counterarguments'),
      unverifiedAssumptions: strings('unverified_assumptions'),
      overlookedRisks: strings('overlooked_risks'),
      reconsiderationTriggers: strings('reconsideration_triggers'),
      additionalInformation: strings('additional_information'),
    );
  }
}

class PortfolioHolding {
  const PortfolioHolding({
    this.id,
    required this.securityName,
    required this.ticker,
    this.exchange = 'KASE',
    this.identifier = '',
    required this.marketValueKzt,
    this.fxSensitivityPctPerPct,
    this.oilSensitivityPctPerPct,
    this.rateSensitivityPctPerPoint,
  });

  final int? id;
  final String securityName;
  final String ticker;
  final String exchange;
  final String identifier;
  final int marketValueKzt;
  final double? fxSensitivityPctPerPct;
  final double? oilSensitivityPctPerPct;
  final double? rateSensitivityPctPerPoint;

  factory PortfolioHolding.fromMap(Map<String, Object?> map) =>
      PortfolioHolding(
        id: map['id'] as int,
        securityName: map['security_name'] as String,
        ticker: map['ticker'] as String,
        exchange: map['exchange'] as String,
        identifier: map['identifier'] as String,
        marketValueKzt: map['market_value_kzt'] as int,
        fxSensitivityPctPerPct: (map['fx_sensitivity'] as num?)?.toDouble(),
        oilSensitivityPctPerPct: (map['oil_sensitivity'] as num?)?.toDouble(),
        rateSensitivityPctPerPoint: (map['rate_sensitivity'] as num?)
            ?.toDouble(),
      );

  Map<String, Object?> toMap() => {
    'security_name': securityName,
    'ticker': ticker,
    'exchange': exchange,
    'identifier': identifier,
    'market_value_kzt': marketValueKzt,
    'fx_sensitivity': fxSensitivityPctPerPct,
    'oil_sensitivity': oilSensitivityPctPerPct,
    'rate_sensitivity': rateSensitivityPctPerPoint,
  };
}

class HoldingScenarioResult {
  const HoldingScenarioResult({
    required this.holding,
    required this.returnPercent,
    required this.changeKzt,
  });
  final PortfolioHolding holding;
  final double? returnPercent;
  final int? changeKzt;
}

class RippleResult {
  const RippleResult({
    required this.beforeKzt,
    required this.afterKzt,
    required this.holdings,
    required this.scenario,
    required this.magnitude,
  });
  final int beforeKzt;
  final int? afterKzt;
  final List<HoldingScenarioResult> holdings;
  final EconomicScenario scenario;
  final double magnitude;
  int? get changeKzt => afterKzt == null ? null : afterKzt! - beforeKzt;
}
