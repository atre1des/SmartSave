// Minimal SyncService stub for Stage 4A compilation.
// DOES NOT IMPLEMENT ACTUAL SYNCHRONIZATION.
// This stub exists solely to resolve the dependency graph.
// Full synchronization engine will be implemented in Stage 4B+.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/finance_repository.dart';
import '../data/firestore_repository.dart';

/// Result of a sync operation.
class SyncResult {
  final bool success;
  final String? errorMessage;

  const SyncResult._({required this.success, this.errorMessage});

  factory SyncResult.success() => const SyncResult._(success: true);
  factory SyncResult.failure(String message) =>
      SyncResult._(success: false, errorMessage: message);
}

/// Sync status for UI display.
enum SyncState {
  idle,
  syncing,
  success,
  error,
}

/// Minimal SyncService stub.
///
/// WARNING: This is a compilation stub only. It does NOT perform any actual
/// synchronization between local SQLite and Cloud Firestore. All mutating
/// operations return an explicit "not implemented" failure. Read operations
/// return empty/initial state.
///
/// DO NOT USE THIS FOR PRODUCTION SYNCHRONIZATION.
class SyncService extends ChangeNotifier {
  SyncService({
    required FinanceRepository localRepo,
    required FirestoreRepository cloudRepo,
    required FirebaseAuth auth,
  })  : _localRepo = localRepo,
        _cloudRepo = cloudRepo,
        _auth = auth;

  final FinanceRepository _localRepo;
  final FirestoreRepository _cloudRepo;
  final FirebaseAuth _auth;

  SyncState _state = SyncState.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  int _pendingCount = 0;

  SyncState get state => _state;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;

  /// Initializes the sync service (no-op in stub).
  Future<void> initialize() async {
    _state = SyncState.idle;
    notifyListeners();
  }

  /// Performs a full synchronization (NOT IMPLEMENTED).
  ///
  /// Returns a failure result indicating this operation is not implemented.
  /// Does NOT upload or download any data.
  Future<SyncResult> performFullSync() async {
    _setState(SyncState.error, 'Full sync not implemented in Stage 4A');
    return SyncResult.failure('Full sync not implemented in Stage 4A');
  }

  /// Pushes local changes to Firestore (NOT IMPLEMENTED).
  ///
  /// Returns a failure result indicating this operation is not implemented.
  /// Does NOT upload any data.
  Future<SyncResult> pushLocalChanges() async {
    _setState(SyncState.error, 'Push not implemented in Stage 4A');
    return SyncResult.failure('Push not implemented in Stage 4A');
  }

  /// Pulls remote changes from Firestore (NOT IMPLEMENTED).
  ///
  /// Returns a failure result indicating this operation is not implemented.
  /// Does NOT download any data.
  Future<SyncResult> pullRemoteChanges() async {
    _setState(SyncState.error, 'Pull not implemented in Stage 4A');
    return SyncResult.failure('Pull not implemented in Stage 4A');
  }

  /// Resolves a sync conflict (NOT IMPLEMENTED).
  ///
  /// Returns a failure result indicating this operation is not implemented.
  Future<SyncResult> resolveConflict(
      String entityType, String entityId, bool useLocal) async {
    return SyncResult.failure('Conflict resolution not implemented in Stage 4A');
  }

  /// Gets the count of pending local operations (stub returns 0).
  Future<int> getPendingOperationsCount() async {
    return 0;
  }

  /// Checks if a sync is currently in progress.
  bool get isSyncing => _state == SyncState.syncing;

  void _setState(SyncState newState, [String? error]) {
    _state = newState;
    _lastError = error;
    if (newState == SyncState.success) {
      _lastSyncTime = DateTime.now();
    }
    notifyListeners();
  }
}