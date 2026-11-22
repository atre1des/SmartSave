// Firestore data models for SmartSave
// These models represent the Cloud Firestore document structure

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'investment_models.dart';
import 'finance_repository.dart';

part 'firestore_models.g.dart';

/// Base model for all Firestore documents
abstract class FirestoreModel {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  String get localId;
  bool get isSynced;
  bool get isDeleted;
  int get version;

  Map<String, dynamic> toFirestore();
}

/// Sync status for tracking synchronization state
enum SyncStatus {
  pending,
  synced,
  conflict,
  error,
  deleted,
}

/// Firestore Transaction model
@JsonSerializable()
class FirestoreTransaction implements FirestoreModel {
  @override
  final String id;
  final int amount;
  final bool isIncome;
  final String category;
  final String merchant;
  final DateTime occurredAt;
  final String note;
  final String source;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreTransaction({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.merchant,
    required this.occurredAt,
    this.note = '',
    this.source = 'Manual entry',
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreTransaction.fromJson(Map<String, dynamic> json) =>
      _$FirestoreTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreTransactionToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreTransaction fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreTransaction.fromJson({'id': doc.id, ...data});
  }

  // Convert from local SQLite model
  factory FirestoreTransaction.fromLocal(FinanceTransaction local, String localId) {
    final now = DateTime.now();
    return FirestoreTransaction(
      id: '', // Will be set by Firestore
      amount: local.amount,
      isIncome: local.isIncome,
      category: local.category,
      merchant: local.merchant,
      occurredAt: local.occurredAt,
      note: local.note,
      source: local.source,
      localId: localId,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      isDeleted: false,
      version: 1,
      syncStatus: SyncStatus.pending,
    );
  }

  // Convert to local SQLite model
  FinanceTransaction toLocal() {
    return FinanceTransaction(
      id: int.tryParse(localId),
      amount: amount,
      isIncome: isIncome,
      category: category,
      merchant: merchant,
      occurredAt: occurredAt,
      note: note,
      source: source,
    );
  }
}

/// Firestore SavingsGoal model
@JsonSerializable()
class FirestoreSavingsGoal implements FirestoreModel {
  @override
  final String id;
  final String name;
  final int target;
  final int saved;
  final DateTime deadline;
  final String purpose;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreSavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.deadline,
    required this.purpose,
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreSavingsGoal.fromJson(Map<String, dynamic> json) =>
      _$FirestoreSavingsGoalFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreSavingsGoalToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreSavingsGoal fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreSavingsGoal.fromJson({'id': doc.id, ...data});
  }

  factory FirestoreSavingsGoal.fromLocal(SavingsGoal local, String localId) {
    final now = DateTime.now();
    return FirestoreSavingsGoal(
      id: '',
      name: local.name,
      target: local.target,
      saved: local.saved,
      deadline: local.deadline,
      purpose: local.purpose,
      localId: localId,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      isDeleted: false,
      version: 1,
      syncStatus: SyncStatus.pending,
    );
  }

  SavingsGoal toLocal() {
    return SavingsGoal(
      id: int.tryParse(localId),
      name: name,
      target: target,
      saved: saved,
      deadline: deadline,
      purpose: purpose,
    );
  }
}

/// Firestore GoalContribution model
@JsonSerializable()
class FirestoreGoalContribution implements FirestoreModel {
  @override
  final String id;
  final String goalId;
  final int amount;
  final DateTime contributedAt;
  final String note;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreGoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.contributedAt,
    this.note = '',
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreGoalContribution.fromJson(Map<String, dynamic> json) =>
      _$FirestoreGoalContributionFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreGoalContributionToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreGoalContribution fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreGoalContribution.fromJson({'id': doc.id, ...data});
  }

  factory FirestoreGoalContribution.fromLocal(
    int goalLocalId,
    int amount,
    DateTime contributedAt,
    String note,
    String localId,
  ) {
    final now = DateTime.now();
    return FirestoreGoalContribution(
      id: '',
      goalId: goalLocalId.toString(),
      amount: amount,
      contributedAt: contributedAt,
      note: note,
      localId: localId,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      isDeleted: false,
      version: 1,
      syncStatus: SyncStatus.pending,
    );
  }
}

/// Firestore Budget model
@JsonSerializable()
class FirestoreBudget implements FirestoreModel {
  @override
  final String id;
  final String category;
  final int monthlyLimit;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreBudget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreBudget.fromJson(Map<String, dynamic> json) =>
      _$FirestoreBudgetFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreBudgetToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreBudget fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreBudget.fromJson({'id': doc.id, ...data});
  }

  factory FirestoreBudget.fromLocal(String category, int limit, String localId) {
    final now = DateTime.now();
    return FirestoreBudget(
      id: '',
      category: category,
      monthlyLimit: limit,
      localId: localId,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      isDeleted: false,
      version: 1,
      syncStatus: SyncStatus.pending,
    );
  }
}

/// Firestore InvestmentThesis model
@JsonSerializable()
class FirestoreInvestmentThesis implements FirestoreModel {
  @override
  final String id;
  final String securityName;
  final String ticker;
  final String exchange;
  final String identifier;
  final String rationale;
  final String horizon;
  final String assumptions;
  final String risks;
  final String invalidationConditions;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreInvestmentThesis({
    required this.id,
    required this.securityName,
    required this.ticker,
    this.exchange = 'KASE',
    this.identifier = '',
    this.rationale = '',
    this.horizon = '',
    this.assumptions = '',
    this.risks = '',
    this.invalidationConditions = '',
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreInvestmentThesis.fromJson(Map<String, dynamic> json) =>
      _$FirestoreInvestmentThesisFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreInvestmentThesisToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreInvestmentThesis fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreInvestmentThesis.fromJson({'id': doc.id, ...data});
  }

  factory FirestoreInvestmentThesis.fromLocal(InvestmentThesis local, String localId) {
    final now = DateTime.now();
    return FirestoreInvestmentThesis(
      id: '',
      securityName: local.securityName,
      ticker: local.ticker,
      exchange: local.exchange,
      identifier: local.identifier,
      rationale: local.rationale,
      horizon: local.horizon,
      assumptions: local.assumptions,
      risks: local.risks,
      invalidationConditions: local.invalidationConditions,
      localId: localId,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
      isSynced: false,
      isDeleted: false,
      version: 1,
      syncStatus: SyncStatus.pending,
    );
  }

  InvestmentThesis toLocal() {
    return InvestmentThesis(
      id: int.tryParse(localId),
      securityName: securityName,
      ticker: ticker,
      exchange: exchange,
      identifier: identifier,
      rationale: rationale,
      horizon: horizon,
      assumptions: assumptions,
      risks: risks,
      invalidationConditions: invalidationConditions,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Firestore ThesisCondition model
@JsonSerializable()
class FirestoreThesisCondition implements FirestoreModel {
  @override
  final String id;
  final String thesisId;
  final String description;
  final String metric;
  final String comparator;
  final double? threshold;
  final double? observedValue;
  final String reportingPeriod;
  final String source;
  final String evidenceNote;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreThesisCondition({
    required this.id,
    required this.thesisId,
    required this.description,
    this.metric = '',
    this.comparator = 'atLeast',
    this.threshold,
    this.observedValue,
    this.reportingPeriod = '',
    this.source = '',
    this.evidenceNote = '',
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreThesisCondition.fromJson(Map<String, dynamic> json) =>
      _$FirestoreThesisConditionFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreThesisConditionToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreThesisCondition fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreThesisCondition.fromJson({'id': doc.id, ...data});
  }

  factory FirestoreThesisCondition.fromLocal(ThesisCondition local, String localId, String thesisLocalId) {
    final now = DateTime.now();
    return FirestoreThesisCondition(
      id: '',
      thesisId: thesisLocalId,
      description: local.description,
      metric: local.metric,
      comparator: local.comparator.name,
      threshold: local.threshold,
      observedValue: local.observedValue,
      reportingPeriod: local.reportingPeriod,
      source: local.source,
      evidenceNote: local.evidenceNote,
      localId: localId,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      isDeleted: false,
      version: 1,
      syncStatus: SyncStatus.pending,
    );
  }
}

/// Firestore ThesisAssessment model
@JsonSerializable()
class FirestoreThesisAssessment implements FirestoreModel {
  @override
  final String id;
  final String thesisId;
  final DateTime assessedAt;
  final List<FirestoreConditionAssessment> conditions;
  final List<String> supportingArguments;
  final List<String> counterarguments;
  final List<String> unverifiedAssumptions;
  final List<String> overlookedRisks;
  final List<String> reconsiderationTriggers;
  final List<String> additionalInformation;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreThesisAssessment({
    required this.id,
    required this.thesisId,
    required this.assessedAt,
    required this.conditions,
    required this.supportingArguments,
    required this.counterarguments,
    required this.unverifiedAssumptions,
    required this.overlookedRisks,
    required this.reconsiderationTriggers,
    required this.additionalInformation,
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreThesisAssessment.fromJson(Map<String, dynamic> json) =>
      _$FirestoreThesisAssessmentFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreThesisAssessmentToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreThesisAssessment fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreThesisAssessment.fromJson({'id': doc.id, ...data});
  }
}

/// Firestore ConditionAssessment model
@JsonSerializable()
class FirestoreConditionAssessment implements FirestoreModel {
  @override
  final String id;
  final int conditionId;
  final String description;
  final String status;
  final String explanation;
  final String evidence;
  final String source;
  final String reportingPeriod;
  final double? observedValue;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreConditionAssessment({
    required this.id,
    required this.conditionId,
    required this.description,
    required this.status,
    required this.explanation,
    required this.evidence,
    required this.source,
    required this.reportingPeriod,
    this.observedValue,
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreConditionAssessment.fromJson(Map<String, dynamic> json) =>
      _$FirestoreConditionAssessmentFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreConditionAssessmentToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();
}

/// Firestore PortfolioHolding model
@JsonSerializable()
class FirestorePortfolioHolding implements FirestoreModel {
  @override
  final String id;
  final String securityName;
  final String ticker;
  final String exchange;
  final String identifier;
  final int marketValueKzt;
  final double? fxSensitivityPctPerPct;
  final double? oilSensitivityPctPerPct;
  final double? rateSensitivityPctPerPoint;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestorePortfolioHolding({
    required this.id,
    required this.securityName,
    required this.ticker,
    this.exchange = 'KASE',
    this.identifier = '',
    required this.marketValueKzt,
    this.fxSensitivityPctPerPct,
    this.oilSensitivityPctPerPct,
    this.rateSensitivityPctPerPoint,
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestorePortfolioHolding.fromJson(Map<String, dynamic> json) =>
      _$FirestorePortfolioHoldingFromJson(json);

  Map<String, dynamic> toJson() => _$FirestorePortfolioHoldingToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestorePortfolioHolding fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestorePortfolioHolding.fromJson({'id': doc.id, ...data});
  }

  factory FirestorePortfolioHolding.fromLocal(PortfolioHolding local, String localId) {
    final now = DateTime.now();
    return FirestorePortfolioHolding(
      id: '',
      securityName: local.securityName,
      ticker: local.ticker,
      exchange: local.exchange,
      identifier: local.identifier,
      marketValueKzt: local.marketValueKzt,
      fxSensitivityPctPerPct: local.fxSensitivityPctPerPct,
      oilSensitivityPctPerPct: local.oilSensitivityPctPerPct,
      rateSensitivityPctPerPoint: local.rateSensitivityPctPerPoint,
      localId: localId,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      isDeleted: false,
      version: 1,
      syncStatus: SyncStatus.pending,
    );
  }

  PortfolioHolding toLocal() {
    return PortfolioHolding(
      id: int.tryParse(localId),
      securityName: securityName,
      ticker: ticker,
      exchange: exchange,
      identifier: identifier,
      marketValueKzt: marketValueKzt,
      fxSensitivityPctPerPct: fxSensitivityPctPerPct,
      oilSensitivityPctPerPct: oilSensitivityPctPerPct,
      rateSensitivityPctPerPoint: rateSensitivityPctPerPoint,
    );
  }
}

/// Firestore InvestmentSettings model
@JsonSerializable()
class FirestoreInvestmentSetting implements FirestoreModel {
  @override
  final String id;
  final String key;
  final String value;
  final String localId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  const FirestoreInvestmentSetting({
    required this.id,
    required this.key,
    required this.value,
    required this.localId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.pending,
  });

  factory FirestoreInvestmentSetting.fromJson(Map<String, dynamic> json) =>
      _$FirestoreInvestmentSettingFromJson(json);

  Map<String, dynamic> toJson() => _$FirestoreInvestmentSettingToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static FirestoreInvestmentSetting fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreInvestmentSetting.fromJson({'id': doc.id, ...data});
  }
}

/// Sync metadata for tracking synchronization state
@JsonSerializable()
class SyncMetadata implements FirestoreModel {
  @override
  final String id;
  final String userId;
  final DateTime lastFullSync;
  final int pendingUploadCount;
  final DateTime? lastConflictAt;
  final int schemaVersion;
  final Map<String, dynamic> entityVersions;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  final int version;
  @override
  final SyncStatus syncStatus;

  @override
  String get localId => 'metadata';

  const SyncMetadata({
    required this.id,
    required this.userId,
    required this.lastFullSync,
    this.pendingUploadCount = 0,
    this.lastConflictAt,
    this.schemaVersion = 1,
    this.entityVersions = const {},
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = true,
    this.isDeleted = false,
    this.version = 1,
    this.syncStatus = SyncStatus.synced,
  });

  factory SyncMetadata.fromJson(Map<String, dynamic> json) =>
      _$SyncMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$SyncMetadataToJson(this);

  @override
  Map<String, dynamic> toFirestore() => toJson();

  static SyncMetadata fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SyncMetadata.fromJson({'id': doc.id, ...data});
  }
}

/// Pending write operation for offline queue
@JsonSerializable()
class PendingWrite {
  final String id;
  final String entityType;
  final String entityId;
  final String localId;
  final String operation; // create, update, delete
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final SyncStatus status;

  const PendingWrite({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.status = SyncStatus.pending,
  });

  factory PendingWrite.fromJson(Map<String, dynamic> json) =>
      _$PendingWriteFromJson(json);

  Map<String, dynamic> toJson() => _$PendingWriteToJson(this);
}