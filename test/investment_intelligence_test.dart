import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/investment_analysis.dart';
import 'package:smart_save/data/investment_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FinanceRepository repository;
  setUp(() async {
    repository = await FinanceRepository.open(
      databasePath: inMemoryDatabasePath,
    );
  });
  tearDown(() => repository.close());

  test('thesis, conditions and immutable dated assessments persist', () async {
    final now = DateTime(2026, 10, 28);
    final thesisId = await repository.saveInvestmentThesis(
      InvestmentThesis(
        securityName: 'Example issuer',
        ticker: 'EXAMPLE',
        rationale: 'User-entered thesis',
        assumptions: 'Assumption A',
        risks: 'Risk B',
        invalidationConditions: 'Cash flow turns negative',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveInvestmentThesis(
      InvestmentThesis(
        id: thesisId,
        securityName: 'Example issuer renamed',
        ticker: 'EXAMPLE',
        rationale: 'Updated user-entered thesis',
        createdAt: now,
        updatedAt: DateTime(2026, 10, 29),
      ),
    );
    expect(
      (await repository.investmentTheses()).single.securityName,
      'Example issuer renamed',
    );
    expect(
      (await repository.investmentTheses()).single.rationale,
      'Updated user-entered thesis',
    );

    final conditionId = await repository.saveThesisCondition(
      ThesisCondition(
        thesisId: thesisId,
        description: 'Cash flow stays positive',
        metric: 'Cash flow, KZT',
        comparator: ConditionComparator.atLeast,
        threshold: 0,
        observedValue: 25,
        reportingPeriod: 'FY2025',
        source: 'User-provided report reference',
      ),
    );
    final thesis = (await repository.investmentTheses()).single;
    final conditions = await repository.thesisConditions(thesisId);
    final first = analyzeThesis(thesis, conditions, now: now);
    expect(first.conditions.single.conditionId, conditionId);
    expect(first.conditions.single.status, EvidenceStatus.supported);
    await repository.saveThesisAssessment(first);

    final updatedCondition = ThesisCondition(
      id: conditionId,
      thesisId: thesisId,
      description: 'Cash flow stays positive',
      metric: 'Cash flow, KZT',
      comparator: ConditionComparator.atLeast,
      threshold: 0,
      observedValue: -8,
      reportingPeriod: 'FY2026',
      source: 'User-provided newer report reference',
    );
    await repository.saveThesisCondition(updatedCondition);
    final second = analyzeThesis(
      thesis,
      await repository.thesisConditions(thesisId),
      now: DateTime(2026, 10, 29),
    );
    expect(second.conditions.single.status, EvidenceStatus.contradicted);
    await repository.saveThesisAssessment(second);

    final history = await repository.thesisAssessments(thesisId);
    expect(history, hasLength(2));
    expect(history.first.conditions.single.status, EvidenceStatus.contradicted);
    expect(history.last.conditions.single.status, EvidenceStatus.supported);
  });

  test('qualitative and incomplete numeric evidence remain insufficient', () {
    final qualitative = ThesisCondition(
      thesisId: 1,
      description: 'Dividend remains supported by reported earnings',
    );
    expect(evaluateCondition(qualitative).status, EvidenceStatus.insufficient);

    final noSource = ThesisCondition(
      thesisId: 1,
      description: 'Revenue growth stays above threshold',
      threshold: 5,
      observedValue: 8,
      reportingPeriod: 'FY2025',
    );
    expect(evaluateCondition(noSource).status, EvidenceStatus.insufficient);

    final noObservation = ThesisCondition(
      thesisId: 1,
      description: 'Debt remains below limit',
      threshold: 100,
      source: 'Report',
      reportingPeriod: 'FY2025',
    );
    expect(
      evaluateCondition(noObservation).status,
      EvidenceStatus.insufficient,
    );
  });

  test(
    'liquidity compares order with dated historical volume and refuses stale or missing data',
    () {
      final date = DateTime(2026, 10, 27);
      final analysis = analyzeLiquidity(
        orderSize: 1000,
        averageDailyVolume: 500,
        volumeUnit: 'shares',
        observedAt: date,
        participationPercent: 10,
        now: DateTime(2026, 10, 28),
      );
      expect(analysis.volumeMultiple, 2);
      expect(analysis.scenarioDays, 20);
      expect(analysis.message, contains('not a prediction'));

      final stale = analyzeLiquidity(
        orderSize: 10,
        averageDailyVolume: 100,
        volumeUnit: 'shares',
        observedAt: DateTime(2026, 10, 1),
        participationPercent: 10,
        now: DateTime(2026, 10, 28),
      );
      expect(stale.status, 'stale');
      final missing = analyzeLiquidity(
        orderSize: 10,
        averageDailyVolume: 0,
        volumeUnit: 'shares',
        observedAt: date,
        participationPercent: 10,
        now: date,
      );
      expect(missing.status, 'insufficient');
      expect(missing.scenarioDays, isNull);
    },
  );

  test(
    'economic scenarios use only entered sensitivities and flag unknown exposures',
    () async {
      final holdings = [
        PortfolioHolding(
          securityName: 'Issuer A',
          ticker: 'AAA',
          marketValueKzt: 100000,
          fxSensitivityPctPerPct: 0.5,
          oilSensitivityPctPerPct: 0.2,
          rateSensitivityPctPerPoint: -1,
        ),
        PortfolioHolding(
          securityName: 'Issuer B',
          ticker: 'BBB',
          marketValueKzt: 50000,
        ),
      ];
      final fx = simulateRipple(
        holdings: holdings,
        scenario: EconomicScenario.tengeDepreciation,
        magnitude: 10,
      );
      expect(fx.holdings.first.changeKzt, 5000);
      expect(fx.holdings.last.changeKzt, isNull);
      expect(fx.afterKzt, isNull);

      final oil = simulateRipple(
        holdings: [holdings.first],
        scenario: EconomicScenario.oilPriceDecrease,
        magnitude: 20,
      );
      expect(oil.holdings.single.changeKzt, -4000);
      final rates = simulateRipple(
        holdings: [holdings.first],
        scenario: EconomicScenario.interestRateIncrease,
        magnitude: 2,
      );
      expect(rates.holdings.single.changeKzt, -2000);
    },
  );

  test('holdings and scenario assumptions survive retrieval', () async {
    await repository.savePortfolioHolding(
      const PortfolioHolding(
        securityName: 'Example',
        ticker: 'EX',
        marketValueKzt: 12345,
        fxSensitivityPctPerPct: 0.4,
      ),
    );
    await repository.saveInvestmentSetting(
      'scenario_type',
      EconomicScenario.oilPriceDecrease.name,
    );
    expect(
      (await repository.portfolioHoldings()).single.fxSensitivityPctPerPct,
      0.4,
    );
    expect(
      (await repository.portfolioHoldings()).single.oilSensitivityPctPerPct,
      isNull,
    );
    expect(
      (await repository.investmentSettings())['scenario_type'],
      EconomicScenario.oilPriceDecrease.name,
    );
  });
}
