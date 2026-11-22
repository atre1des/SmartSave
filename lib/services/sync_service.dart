// Firestore Synchronization Service for SmartSave
// Coordinates local SQLite changes with Cloud Firestore.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/finance_repository.dart';
import '../data/firestore_repository.dart';
import '../data/firestore_models.dart';

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
       _auth = auth;

  final FinanceRepository _localRepo;
  final FirestoreRepository _cloudRepo;
  final FirebaseAuth _auth;

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
    return pending;
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
    if (_isSyncing) {
      return SyncResult.failure('A sync is already in progress');
    }
    _isSyncing = true;
    _setState(SyncState.syncing);

    try {
      final pushResult = await pushLocalChanges();
      final pullResult = await pullRemoteChanges();

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
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return SyncResult.noAuthenticatedUser();
    }

    int uploaded = 0;
    int failed = 0;
    int conflicts = 0;

    final pendingOps = await _localRepo.getPendingSyncOperations();

    for (final op in pendingOps) {
      if (op.status == 'pending' || op.status == 'error') {
        if (op.ownerUid == null || op.ownerUid != uid) {
          conflicts++;
          continue;
        }
        try {
          final success = await _uploadOperation(op, uid);
          if (success) {
            uploaded++;
            await _localRepo.removeSyncOperation(op.id);
          } else {
            conflicts++;
            // Don't mark as failed — it's a conflict, preserve the op
          }
        } catch (e) {
          failed++;
          await _localRepo.failSyncOperation(op.id, e.toString());
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
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return SyncResult.noAuthenticatedUser();
    }

    int downloaded = 0;
    int failed = 0;
    int conflicts = 0;

    // Download transactions
    final txResult = await _cloudRepo.getTransactions();
    if (txResult.success && txResult.data != null) {
      for (final tx in txResult.data!) {
        try {
          final applied = await _localRepo.applyCloudTransaction(
            tx.toLocal(),
            tx.id,
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
    final goalsResult = await _cloudRepo.getGoals();
    if (goalsResult.success && goalsResult.data != null) {
      for (final goal in goalsResult.data!) {
        try {
          final applied = await _localRepo.applyCloudGoal(
            goal.toLocal(),
            goal.id,
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
    final budgetsResult = await _cloudRepo.getBudgets();
    if (budgetsResult.success && budgetsResult.data != null) {
      for (final entry in budgetsResult.data!.entries) {
        try {
          if (await _localRepo.applyCloudBudget(entry.key, entry.value)) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
    }

    // Download portfolio holdings
    final holdingsResult = await _cloudRepo.getPortfolioHoldings();
    if (holdingsResult.success && holdingsResult.data != null) {
      for (final holding in holdingsResult.data!) {
        try {
          final applied = await _localRepo.applyCloudHolding(
            holding.toLocal(),
            holding.id,
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
    final thesesResult = await _cloudRepo.getInvestmentTheses();
    if (thesesResult.success && thesesResult.data != null) {
      for (final thesis in thesesResult.data!) {
        try {
          final applied = await _localRepo.applyCloudThesis(
            thesis.toLocal(),
            thesis.id,
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
    final settingsResult = await _cloudRepo.getInvestmentSettings();
    if (settingsResult.success && settingsResult.data != null) {
      for (final entry in settingsResult.data!.entries) {
        try {
          if (await _localRepo.applyCloudSetting(entry.key, entry.value)) {
            downloaded++;
          } else {
            conflicts++;
          }
        } catch (e) {
          failed++;
        }
      }
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

  /// Upload a single pending operation to Firestore.
  /// Returns true on success, false on conflict (local unsynced changes exist).
  Future<bool> _uploadOperation(SyncOperation op, String uid) async {
    if (_auth.currentUser?.uid != uid || op.ownerUid != uid) return false;
    if (op.operation == 'delete') {
      switch (op.entityType) {
        case 'transaction':
          final result = await _cloudRepo.deleteTransaction(
            (op.payload['cloud_id'] as String?) ?? op.entityId,
          );
          return result.success;
        case 'goal':
          final result = await _cloudRepo.deleteGoal(
            (op.payload['cloud_id'] as String?) ?? op.entityId,
          );
          return result.success;
        default:
          return false;
      }
    }
    switch (op.entityType) {
      case 'transaction':
        return _uploadTransaction(op);
      case 'goal':
        return _uploadGoal(op);
      case 'budget':
        return _uploadBudget(op);
      case 'investment_thesis':
        return _uploadThesis(op);
      case 'portfolio_holding':
        return _uploadHolding(op);
      case 'investment_setting':
        return _uploadSetting(op);
      default:
        debugPrint('[SyncService] Unsupported entity type: ${op.entityType}');
        return false;
    }
  }

  Future<bool> _uploadTransaction(SyncOperation op) async {
    final localId = int.tryParse(op.entityId);
    if (localId == null) return false;

    final tx = await _localRepo.getTransactionById(localId);
    if (tx == null) return false;

    final cloudModel = FirestoreTransaction.fromLocal(tx, op.entityId);
    final result = await _cloudRepo.saveTransaction(cloudModel);

    if (result.success && result.data != null) {
      await _localRepo.markTransactionSynced(localId, result.data!.id);
      return true;
    }
    return false;
  }

  Future<bool> _uploadGoal(SyncOperation op) async {
    final localId = int.tryParse(op.entityId);
    if (localId == null) return false;

    final goal = await _localRepo.getGoalById(localId);
    if (goal == null) return false;

    final cloudModel = FirestoreSavingsGoal.fromLocal(goal, op.entityId);
    final result = await _cloudRepo.saveGoal(cloudModel);

    if (result.success && result.data != null) {
      await _localRepo.markGoalSynced(localId, result.data!.id);
      return true;
    }
    return false;
  }

  Future<bool> _uploadBudget(SyncOperation op) async {
    final payload = op.payload;
    final category = payload['category'] as String? ?? '';
    final limit = (payload['monthly_limit'] as num?)?.toInt() ?? 0;

    final cloudModel = FirestoreBudget.fromLocal(category, limit, category);
    final result = await _cloudRepo.saveBudget(cloudModel);
    return result.success;
  }

  Future<bool> _uploadThesis(SyncOperation op) async {
    final localId = int.tryParse(op.entityId);
    if (localId == null) return false;

    final thesis = await _localRepo.getInvestmentThesisById(localId);
    if (thesis == null) return false;

    final cloudModel = FirestoreInvestmentThesis.fromLocal(thesis, op.entityId);
    final result = await _cloudRepo.saveInvestmentThesis(cloudModel);

    if (result.success && result.data != null) {
      await _localRepo.markInvestmentThesisSynced(localId, result.data!.id);
      return true;
    }
    return false;
  }

  Future<bool> _uploadHolding(SyncOperation op) async {
    final localId = int.tryParse(op.entityId);
    if (localId == null) return false;

    final holding = await _localRepo.getPortfolioHoldingById(localId);
    if (holding == null) return false;

    final cloudModel = FirestorePortfolioHolding.fromLocal(
      holding,
      op.entityId,
    );
    final result = await _cloudRepo.savePortfolioHolding(cloudModel);

    if (result.success && result.data != null) {
      await _localRepo.markHoldingSynced(localId, result.data!.id);
      return true;
    }
    return false;
  }

  Future<bool> _uploadSetting(SyncOperation op) async {
    final payload = op.payload;
    final key = payload['key'] as String? ?? '';
    final value = payload['value'] as String? ?? '';

    final cloudModel = FirestoreInvestmentSetting(
      id: key,
      key: key,
      value: value,
      localId: key,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final result = await _cloudRepo.saveInvestmentSetting(cloudModel);
    return result.success;
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
    notifyListeners();
  }
}
