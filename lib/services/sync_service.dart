// Firestore Synchronization Service for SmartSave
// Coordinates local SQLite changes with Cloud Firestore.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/finance_repository.dart';
import '../data/firestore_repository.dart';
import '../data/firestore_models.dart';
import '../data/investment_models.dart';

/// Outcome of a synchronization attempt.
enum SyncResultStatus {
  success,
  partialSuccess,
  failure,
  noPendingChanges,
  offline,
  noAuthenticatedUser,
  initializationFailed,
  conflict,
}

/// Result of a sync operation with detailed counts.
class SyncResult {
  final SyncResultStatus status;
  final String? errorMessage;
  final int uploaded;
  final int downloaded;
  final int failed;
  final int conflicts;

  const SyncResult._({
    required this.status,
    this.errorMessage,
    this.uploaded = 0,
    this.downloaded = 0,
    this.failed = 0,
    this.conflicts = 0,
  });

  factory SyncResult.success({int uploaded = 0, int downloaded = 0}) =>
      SyncResult._(
        status: SyncResultStatus.success,
        uploaded: uploaded,
        downloaded: downloaded,
      );

  factory SyncResult.partialSuccess({
    required int uploaded,
    required int downloaded,
    required int failed,
    required int conflicts,
  }) => SyncResult._(
    status: SyncResultStatus.partialSuccess,
    uploaded: uploaded,
    downloaded: downloaded,
    failed: failed,
    conflicts: conflicts,
  );

  factory SyncResult.failure(String message) =>
      SyncResult._(status: SyncResultStatus.failure, errorMessage: message);

  factory SyncResult.noPendingChanges() =>
      const SyncResult._(status: SyncResultStatus.noPendingChanges);

  factory SyncResult.offline(String message) =>
      SyncResult._(status: SyncResultStatus.offline, errorMessage: message);

  factory SyncResult.noAuthenticatedUser() =>
      const SyncResult._(status: SyncResultStatus.noAuthenticatedUser);

  factory SyncResult.initializationFailed(String message) => SyncResult._(
    status: SyncResultStatus.initializationFailed,
    errorMessage: message,
  );

  factory SyncResult.conflict({
    required int conflicts,
    int uploaded = 0,
    int downloaded = 0,
  }) => SyncResult._(
    status: SyncResultStatus.conflict,
    conflicts: conflicts,
    uploaded: uploaded,
    downloaded: downloaded,
  );

  bool get isSuccess => status == SyncResultStatus.success;
  bool get isPartialSuccess => status == SyncResultStatus.partialSuccess;
  bool get isFailure => status == SyncResultStatus.failure;
  bool get isOffline => status == SyncResultStatus.offline;
  bool get isNoPending => status == SyncResultStatus.noPendingChanges;
  bool get isNoAuth => status == SyncResultStatus.noAuthenticatedUser;
  bool get isConflict => status == SyncResultStatus.conflict;
}

/// Sync status for UI display.
enum SyncState { idle, syncing, success, error, conflict }

/// Firestore Synchronization Service.
///
/// Coordinates synchronization between local SQLite and Cloud Firestore.
/// - Firebase Authentication: authoritative user identity
/// - Cloud Firestore: authoritative persistent cloud data
/// - SQLite: local operational storage + pending sync queue
class SyncService extends ChangeNotifier {
  SyncService({
    required FinanceRepository localRepo,
    required FirestoreRepository cloudRepo,
    required FirebaseAuth auth,
  }) : _localRepo = localRepo,
       _cloudRepo = cloudRepo,
       _auth = auth,
       _sessionUid = auth.currentUser?.uid;

  final FinanceRepository _localRepo;
  final FirestoreRepository _cloudRepo;
  final FirebaseAuth _auth;
  final String? _sessionUid;
  bool _disposed = false;

  Stream<bool> get connectionChanges => _cloudRepo.watchSyncConnection();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String? get _activeUid {
    final uid = _sessionUid;
    return !_disposed &&
            uid != null &&
            _auth.currentUser?.uid == uid &&
            _localRepo.canSyncAccount(uid)
        ? uid
        : null;
  }

  SyncState _state = SyncState.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _initialized = false;
  Future<void>? _initialization;

  SyncState get state => _state;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;

  /// Initializes the sync service by ensuring the SQLite sync schema exists.
  /// Safe to call multiple times.
  Future<void> initialize() async {
    final existing = _initialization;
    if (existing != null) return existing;
    final pending = _initializeOnce();
    _initialization = pending;
    await pending;
    if (!_initialized && identical(_initialization, pending)) {
      _initialization = null;
    }
  }

  Future<void> _initializeOnce() async {
    try {
      await _localRepo.initializeSync();
      await _refreshPendingCount();
      _initialized = true;
      _setState(SyncState.idle);
    } catch (e) {
      _initialized = false;
      _setState(SyncState.error, 'Sync initialization failed');
    }
  }

  /// Performs a full synchronization: upload pending changes then download remote.
  Future<SyncResult> performFullSync() async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        return SyncResult.initializationFailed('Sync initialization failed');
      }
    }
    if (_activeUid == null) return SyncResult.noAuthenticatedUser();
    if (_isSyncing) {
      return SyncResult.failure('A sync is already in progress');
    }
    _isSyncing = true;
    _setState(SyncState.syncing);

    try {
      final pushResult = await pushLocalChanges();
      if (pushResult.isNoAuth) return pushResult;
      final pullResult = await pullRemoteChanges();
      if (pullResult.isNoAuth) return pullResult;

      final totalUploaded = pushResult.uploaded;
      final totalDownloaded = pullResult.downloaded;
      final totalFailed = pushResult.failed + pullResult.failed;
      final totalConflicts = pushResult.conflicts + pullResult.conflicts;

      await _refreshPendingCount();

      if (totalConflicts > 0) {
        _setState(
          SyncState.conflict,
          '$totalConflicts conflict(s) require resolution',
        );
        return SyncResult.partialSuccess(
          uploaded: totalUploaded,
          downloaded: totalDownloaded,
          failed: totalFailed,
          conflicts: totalConflicts,
        );
      }
      if (totalFailed > 0) {
        _setState(SyncState.error, '$totalFailed operation(s) failed');
        return SyncResult.partialSuccess(
          uploaded: totalUploaded,
          downloaded: totalDownloaded,
          failed: totalFailed,
          conflicts: 0,
        );
      }
      _setState(SyncState.success);
      return SyncResult.success(
        uploaded: totalUploaded,
        downloaded: totalDownloaded,
      );
    } catch (e) {
      _setState(SyncState.error, 'Sync failed: $e');
      return SyncResult.failure('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Pushes local changes to Firestore.
  /// Uploads only records belonging to the currently authenticated user.
  Future<SyncResult> pushLocalChanges() async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        return SyncResult.initializationFailed('Sync initialization failed');
      }
    }
    final uid = _activeUid;
    if (uid == null || uid.isEmpty) {
      return SyncResult.noAuthenticatedUser();
    }

    int uploaded = 0;
    int failed = 0;
    int conflicts = 0;

    final pendingOps = await _localRepo.getPendingSyncOperations();

    final blockedRecords = <(String, String)>{};
    for (final op in pendingOps) {
      final record = (op.entityType, op.entityId);
      if (blockedRecords.contains(record)) continue;
      if (op.status == 'pending' || op.status == 'error') {
        if (op.ownerUid == null || op.ownerUid != uid) {
          conflicts++;
          blockedRecords.add(record);
          continue;
        }
        try {
          final success = await _uploadOperation(op, uid);
          if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
          if (success) {
            uploaded++;
          } else {
            conflicts++;
            blockedRecords.add(record);
            // Don't mark as failed — it's a conflict, preserve the op
          }
        } catch (e) {
          if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
          failed++;
          blockedRecords.add(record);
          await _localRepo.failSyncOperation(
            op.id,
            'Cloud write could not be confirmed',
          );
        }
      }
    }

    if (uploaded == 0 && failed == 0 && conflicts == 0) {
      return SyncResult.noPendingChanges();
    }
    if (failed > 0 || conflicts > 0) {
      return SyncResult.partialSuccess(
        uploaded: uploaded,
        downloaded: 0,
        failed: failed,
        conflicts: conflicts,
      );
    }
    return SyncResult.success(uploaded: uploaded);
  }

  /// Downloads remote data from Firestore and applies it to local SQLite.
  /// Never deletes local records based on remote absence.
  Future<SyncResult> pullRemoteChanges() async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        return SyncResult.initializationFailed('Sync initialization failed');
      }
    }
    final uid = _activeUid;
    if (uid == null || uid.isEmpty) {
      return SyncResult.noAuthenticatedUser();
    }

    int downloaded = 0;
    int failed = 0;
    int conflicts = 0;

    // Download transactions
    final txResult = await _cloudRepo.getTransactions(includeDeleted: true);
    if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
    if (txResult.success && txResult.data != null) {
      for (final tx in txResult.data!) {
        if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
        try {
          final applied = tx.isDeleted
              ? await _localRepo.applyTombstone(
                  'transaction',
                  tx.id,
                  tx.version,
                )
              : await _localRepo.applyCloudTransaction(
                  tx.toLocal(),
                  tx.id,
                  revision: tx.version,
                );
          if (applied) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
    } else if (!txResult.success) {
      failed++;
    }

    // Download goals
    final goalsResult = await _cloudRepo.getGoals(includeDeleted: true);
    if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
    if (goalsResult.success && goalsResult.data != null) {
      for (final goal in goalsResult.data!) {
        if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
        try {
          final applied = goal.isDeleted
              ? await _localRepo.applyTombstone('goal', goal.id, goal.version)
              : await _localRepo.applyCloudGoal(
                  goal.toLocal(),
                  goal.id,
                  revision: goal.version,
                );
          if (applied) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
    } else if (!goalsResult.success) {
      failed++;
    }

    // Download budgets (remote-wins)
    final budgetsResult = await _cloudRepo.getVersionedBudgets();
    if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
    if (budgetsResult.success && budgetsResult.data != null) {
      for (final entry in budgetsResult.data!) {
        if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
        try {
          if (await _localRepo.applyCloudBudget(
            entry.category,
            entry.monthlyLimit,
            revision: entry.version,
          )) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
    } else if (!budgetsResult.success) {
      failed++;
    }

    // Download portfolio holdings
    final holdingsResult = await _cloudRepo.getPortfolioHoldings(
      includeDeleted: true,
    );
    if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
    if (holdingsResult.success && holdingsResult.data != null) {
      for (final holding in holdingsResult.data!) {
        try {
          if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
          final applied = holding.isDeleted
              ? await _localRepo.applyTombstone(
                  'portfolio_holding',
                  holding.id,
                  holding.version,
                )
              : await _localRepo.applyCloudHolding(
                  holding.toLocal(),
                  holding.id,
                  revision: holding.version,
                );
          if (applied) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
    } else if (!holdingsResult.success) {
      failed++;
    }

    // Download investment theses
    final thesesResult = await _cloudRepo.getInvestmentTheses(
      includeDeleted: true,
    );
    if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
    if (thesesResult.success && thesesResult.data != null) {
      for (final thesis in thesesResult.data!) {
        try {
          if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
          final applied = thesis.isDeleted
              ? await _localRepo.applyTombstone(
                  'investment_thesis',
                  thesis.id,
                  thesis.version,
                )
              : await _localRepo.applyCloudThesis(
                  thesis.toLocal(),
                  thesis.id,
                  revision: thesis.version,
                );
          if (applied) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
    } else if (!thesesResult.success) {
      failed++;
    }

    // Download investment settings (remote-wins)
    final settingsResult = await _cloudRepo.getVersionedSettings();
    if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
    if (settingsResult.success && settingsResult.data != null) {
      for (final entry in settingsResult.data!) {
        if (_activeUid != uid) return SyncResult.noAuthenticatedUser();
        try {
          if (await _localRepo.applyCloudSetting(
            entry.key,
            entry.value,
            revision: entry.version,
          )) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
    } else if (!settingsResult.success) {
      failed++;
    }

    if (downloaded == 0 && failed == 0 && conflicts == 0) {
      return SyncResult.noPendingChanges();
    }
    if (failed > 0 || conflicts > 0) {
      return SyncResult.partialSuccess(
        uploaded: 0,
        downloaded: downloaded,
        failed: failed,
        conflicts: conflicts,
      );
    }
    return SyncResult.success(downloaded: downloaded);
  }

  Future<bool> _uploadOperation(SyncOperation op, String uid) async {
    if (_activeUid != uid || op.ownerUid != uid) return false;
    final target = await _localRepo.prepareUpload(op);
    if (target == null || _activeUid != uid) return false;
    final fields = {...op.payload, 'id': int.tryParse(op.entityId)};
    final record = switch (op.entityType) {
      'transaction' => FirestoreTransaction.fromLocal(
        FinanceTransaction.fromMap(fields),
        op.entityId,
      ).copyWith(id: target.id),
      'goal' => FirestoreSavingsGoal.fromLocal(
        SavingsGoal.fromMap(fields),
        op.entityId,
      ).copyWith(id: target.id),
      'investment_thesis' => FirestoreInvestmentThesis.fromLocal(
        InvestmentThesis.fromMap(fields),
        op.entityId,
      ).copyWith(id: target.id),
      'portfolio_holding' => FirestorePortfolioHolding.fromLocal(
        PortfolioHolding.fromMap(fields),
        op.entityId,
      ).copyWith(id: target.id),
      'budget' => FirestoreBudget.fromLocal(
        fields['category'] as String,
        fields['monthly_limit'] as int,
        op.entityId,
      ).copyWith(id: target.id),
      'investment_setting' => FirestoreInvestmentSetting(
        id: target.id,
        key: fields['key'] as String,
        value: fields['value'] as String,
        localId: op.entityId,
        createdAt: op.createdAt,
        updatedAt: op.createdAt,
      ),
      _ => throw StateError('Unsupported queue entity'),
    };
    final result = await _cloudRepo.commitSyncMutation(
      entity: op.entityType,
      record: record,
      expectedRevision: target.revision,
      mutationId: op.id,
      deleted: op.operation == 'delete',
    );
    if (_activeUid != uid) return false;
    if (result.success && result.data != null) {
      await _localRepo.acknowledgeRecordUpload(op, target.id, result.data!);
      return true;
    }
    if (result.errorCode == FirestoreErrorCode.unavailable ||
        result.errorCode == FirestoreErrorCode.deadlineExceeded ||
        result.errorCode == FirestoreErrorCode.aborted) {
      throw StateError('Cloud temporarily unavailable');
    }
    return false;
  }

  Future<void> _refreshPendingCount() async {
    _pendingCount = await _localRepo.getPendingSyncCount();
  }

  void _setState(SyncState newState, [String? error]) {
    _state = newState;
    _lastError = error;
    if (newState == SyncState.success) {
      _lastSyncTime = DateTime.now();
    }
    if (!_disposed) notifyListeners();
  }
}
