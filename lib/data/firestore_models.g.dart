// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firestore_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirestoreTransaction _$FirestoreTransactionFromJson(
  Map<String, dynamic> json,
) => FirestoreTransaction(
  id: json['id'] as String,
  amount: (json['amount'] as num).toInt(),
  isIncome: json['isIncome'] as bool,
  category: json['category'] as String,
  merchant: json['merchant'] as String,
  occurredAt: DateTime.parse(json['occurredAt'] as String),
  note: json['note'] as String? ?? '',
  source: json['source'] as String? ?? 'Manual entry',
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreTransactionToJson(
  FirestoreTransaction instance,
) => <String, dynamic>{
  'id': instance.id,
  'amount': instance.amount,
  'isIncome': instance.isIncome,
  'category': instance.category,
  'merchant': instance.merchant,
  'occurredAt': instance.occurredAt.toIso8601String(),
  'note': instance.note,
  'source': instance.source,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

const _$SyncStatusEnumMap = {
  SyncStatus.pending: 'pending',
  SyncStatus.synced: 'synced',
  SyncStatus.conflict: 'conflict',
  SyncStatus.error: 'error',
  SyncStatus.deleted: 'deleted',
};

FirestoreSavingsGoal _$FirestoreSavingsGoalFromJson(
  Map<String, dynamic> json,
) => FirestoreSavingsGoal(
  id: json['id'] as String,
  name: json['name'] as String,
  target: (json['target'] as num).toInt(),
  saved: (json['saved'] as num).toInt(),
  deadline: DateTime.parse(json['deadline'] as String),
  purpose: json['purpose'] as String,
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreSavingsGoalToJson(
  FirestoreSavingsGoal instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'target': instance.target,
  'saved': instance.saved,
  'deadline': instance.deadline.toIso8601String(),
  'purpose': instance.purpose,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

FirestoreGoalContribution _$FirestoreGoalContributionFromJson(
  Map<String, dynamic> json,
) => FirestoreGoalContribution(
  id: json['id'] as String,
  goalId: json['goalId'] as String,
  amount: (json['amount'] as num).toInt(),
  contributedAt: DateTime.parse(json['contributedAt'] as String),
  note: json['note'] as String? ?? '',
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreGoalContributionToJson(
  FirestoreGoalContribution instance,
) => <String, dynamic>{
  'id': instance.id,
  'goalId': instance.goalId,
  'amount': instance.amount,
  'contributedAt': instance.contributedAt.toIso8601String(),
  'note': instance.note,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

FirestoreBudget _$FirestoreBudgetFromJson(Map<String, dynamic> json) =>
    FirestoreBudget(
      id: json['id'] as String,
      category: json['category'] as String,
      monthlyLimit: (json['monthlyLimit'] as num).toInt(),
      localId: json['localId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      syncStatus:
          $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
          SyncStatus.pending,
    );

Map<String, dynamic> _$FirestoreBudgetToJson(FirestoreBudget instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'monthlyLimit': instance.monthlyLimit,
      'localId': instance.localId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isSynced': instance.isSynced,
      'isDeleted': instance.isDeleted,
      'version': instance.version,
      'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
    };

FirestoreInvestmentThesis _$FirestoreInvestmentThesisFromJson(
  Map<String, dynamic> json,
) => FirestoreInvestmentThesis(
  id: json['id'] as String,
  securityName: json['securityName'] as String,
  ticker: json['ticker'] as String,
  exchange: json['exchange'] as String? ?? 'KASE',
  identifier: json['identifier'] as String? ?? '',
  rationale: json['rationale'] as String? ?? '',
  horizon: json['horizon'] as String? ?? '',
  assumptions: json['assumptions'] as String? ?? '',
  risks: json['risks'] as String? ?? '',
  invalidationConditions: json['invalidationConditions'] as String? ?? '',
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreInvestmentThesisToJson(
  FirestoreInvestmentThesis instance,
) => <String, dynamic>{
  'id': instance.id,
  'securityName': instance.securityName,
  'ticker': instance.ticker,
  'exchange': instance.exchange,
  'identifier': instance.identifier,
  'rationale': instance.rationale,
  'horizon': instance.horizon,
  'assumptions': instance.assumptions,
  'risks': instance.risks,
  'invalidationConditions': instance.invalidationConditions,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

FirestoreThesisCondition _$FirestoreThesisConditionFromJson(
  Map<String, dynamic> json,
) => FirestoreThesisCondition(
  id: json['id'] as String,
  thesisId: json['thesisId'] as String,
  description: json['description'] as String,
  metric: json['metric'] as String? ?? '',
  comparator: json['comparator'] as String? ?? 'atLeast',
  threshold: (json['threshold'] as num?)?.toDouble(),
  observedValue: (json['observedValue'] as num?)?.toDouble(),
  reportingPeriod: json['reportingPeriod'] as String? ?? '',
  source: json['source'] as String? ?? '',
  evidenceNote: json['evidenceNote'] as String? ?? '',
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreThesisConditionToJson(
  FirestoreThesisCondition instance,
) => <String, dynamic>{
  'id': instance.id,
  'thesisId': instance.thesisId,
  'description': instance.description,
  'metric': instance.metric,
  'comparator': instance.comparator,
  'threshold': instance.threshold,
  'observedValue': instance.observedValue,
  'reportingPeriod': instance.reportingPeriod,
  'source': instance.source,
  'evidenceNote': instance.evidenceNote,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

FirestoreThesisAssessment _$FirestoreThesisAssessmentFromJson(
  Map<String, dynamic> json,
) => FirestoreThesisAssessment(
  id: json['id'] as String,
  thesisId: json['thesisId'] as String,
  assessedAt: DateTime.parse(json['assessedAt'] as String),
  conditions: (json['conditions'] as List<dynamic>)
      .map(
        (e) => FirestoreConditionAssessment.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  supportingArguments: (json['supportingArguments'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  counterarguments: (json['counterarguments'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  unverifiedAssumptions: (json['unverifiedAssumptions'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  overlookedRisks: (json['overlookedRisks'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  reconsiderationTriggers: (json['reconsiderationTriggers'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  additionalInformation: (json['additionalInformation'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreThesisAssessmentToJson(
  FirestoreThesisAssessment instance,
) => <String, dynamic>{
  'id': instance.id,
  'thesisId': instance.thesisId,
  'assessedAt': instance.assessedAt.toIso8601String(),
  'conditions': instance.conditions,
  'supportingArguments': instance.supportingArguments,
  'counterarguments': instance.counterarguments,
  'unverifiedAssumptions': instance.unverifiedAssumptions,
  'overlookedRisks': instance.overlookedRisks,
  'reconsiderationTriggers': instance.reconsiderationTriggers,
  'additionalInformation': instance.additionalInformation,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

FirestoreConditionAssessment _$FirestoreConditionAssessmentFromJson(
  Map<String, dynamic> json,
) => FirestoreConditionAssessment(
  id: json['id'] as String,
  conditionId: (json['conditionId'] as num).toInt(),
  description: json['description'] as String,
  status: json['status'] as String,
  explanation: json['explanation'] as String,
  evidence: json['evidence'] as String,
  source: json['source'] as String,
  reportingPeriod: json['reportingPeriod'] as String,
  observedValue: (json['observedValue'] as num?)?.toDouble(),
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreConditionAssessmentToJson(
  FirestoreConditionAssessment instance,
) => <String, dynamic>{
  'id': instance.id,
  'conditionId': instance.conditionId,
  'description': instance.description,
  'status': instance.status,
  'explanation': instance.explanation,
  'evidence': instance.evidence,
  'source': instance.source,
  'reportingPeriod': instance.reportingPeriod,
  'observedValue': instance.observedValue,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

FirestorePortfolioHolding _$FirestorePortfolioHoldingFromJson(
  Map<String, dynamic> json,
) => FirestorePortfolioHolding(
  id: json['id'] as String,
  securityName: json['securityName'] as String,
  ticker: json['ticker'] as String,
  exchange: json['exchange'] as String? ?? 'KASE',
  identifier: json['identifier'] as String? ?? '',
  marketValueKzt: (json['marketValueKzt'] as num).toInt(),
  fxSensitivityPctPerPct: (json['fxSensitivityPctPerPct'] as num?)?.toDouble(),
  oilSensitivityPctPerPct: (json['oilSensitivityPctPerPct'] as num?)
      ?.toDouble(),
  rateSensitivityPctPerPoint: (json['rateSensitivityPctPerPoint'] as num?)
      ?.toDouble(),
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestorePortfolioHoldingToJson(
  FirestorePortfolioHolding instance,
) => <String, dynamic>{
  'id': instance.id,
  'securityName': instance.securityName,
  'ticker': instance.ticker,
  'exchange': instance.exchange,
  'identifier': instance.identifier,
  'marketValueKzt': instance.marketValueKzt,
  'fxSensitivityPctPerPct': instance.fxSensitivityPctPerPct,
  'oilSensitivityPctPerPct': instance.oilSensitivityPctPerPct,
  'rateSensitivityPctPerPoint': instance.rateSensitivityPctPerPoint,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

FirestoreInvestmentSetting _$FirestoreInvestmentSettingFromJson(
  Map<String, dynamic> json,
) => FirestoreInvestmentSetting(
  id: json['id'] as String,
  key: json['key'] as String,
  value: json['value'] as String,
  localId: json['localId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? false,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$FirestoreInvestmentSettingToJson(
  FirestoreInvestmentSetting instance,
) => <String, dynamic>{
  'id': instance.id,
  'key': instance.key,
  'value': instance.value,
  'localId': instance.localId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isSynced': instance.isSynced,
  'isDeleted': instance.isDeleted,
  'version': instance.version,
  'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
};

SyncMetadata _$SyncMetadataFromJson(Map<String, dynamic> json) => SyncMetadata(
  id: json['id'] as String,
  userId: json['userId'] as String,
  lastFullSync: DateTime.parse(json['lastFullSync'] as String),
  pendingUploadCount: (json['pendingUploadCount'] as num?)?.toInt() ?? 0,
  lastConflictAt: json['lastConflictAt'] == null
      ? null
      : DateTime.parse(json['lastConflictAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
  entityVersions: json['entityVersions'] as Map<String, dynamic>? ?? const {},
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isSynced: json['isSynced'] as bool? ?? true,
  isDeleted: json['isDeleted'] as bool? ?? false,
  version: (json['version'] as num?)?.toInt() ?? 1,
  syncStatus:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
      SyncStatus.synced,
);

Map<String, dynamic> _$SyncMetadataToJson(SyncMetadata instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'lastFullSync': instance.lastFullSync.toIso8601String(),
      'pendingUploadCount': instance.pendingUploadCount,
      'lastConflictAt': instance.lastConflictAt?.toIso8601String(),
      'schemaVersion': instance.schemaVersion,
      'entityVersions': instance.entityVersions,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isSynced': instance.isSynced,
      'isDeleted': instance.isDeleted,
      'version': instance.version,
      'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
    };

PendingWrite _$PendingWriteFromJson(Map<String, dynamic> json) => PendingWrite(
  id: json['id'] as String,
  entityType: json['entityType'] as String,
  entityId: json['entityId'] as String,
  localId: json['localId'] as String,
  operation: json['operation'] as String,
  payload: json['payload'] as Map<String, dynamic>,
  createdAt: DateTime.parse(json['createdAt'] as String),
  retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
  lastError: json['lastError'] as String?,
  status:
      $enumDecodeNullable(_$SyncStatusEnumMap, json['status']) ??
      SyncStatus.pending,
);

Map<String, dynamic> _$PendingWriteToJson(PendingWrite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entityType': instance.entityType,
      'entityId': instance.entityId,
      'localId': instance.localId,
      'operation': instance.operation,
      'payload': instance.payload,
      'createdAt': instance.createdAt.toIso8601String(),
      'retryCount': instance.retryCount,
      'lastError': instance.lastError,
      'status': _$SyncStatusEnumMap[instance.status]!,
    };
