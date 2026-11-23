// Firestore Repository for SmartSave
// Handles all Cloud Firestore operations with proper error handling

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_models.dart';
import 'firestore_paths.dart';

/// Result wrapper for Firestore operations
class FirestoreResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final FirestoreErrorCode? errorCode;

  const FirestoreResult._({
    required this.success,
    this.data,
    this.errorMessage,
    this.errorCode,
  });

  factory FirestoreResult.success(T data) => FirestoreResult._(
        success: true,
        data: data,
        errorMessage: null,
        errorCode: null,
      );

  factory FirestoreResult.failure(String message, [FirestoreErrorCode? code]) =>
      FirestoreResult._(
        success: false,
        data: null,
        errorMessage: message,
        errorCode: code,
      );

  factory FirestoreResult.ok() => const FirestoreResult._(
        success: true,
        data: null,
        errorMessage: null,
        errorCode: null,
      );
}

/// Firestore-specific error codes
enum FirestoreErrorCode {
  permissionDenied,
  notFound,
  alreadyExists,
  unavailable,
  deadlineExceeded,
  invalidArgument,
  failedPrecondition,
  aborted,
  internal,
  unknown,
}

/// Maps Firestore exceptions to app-specific error codes
FirestoreErrorCode _mapFirestoreException(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return FirestoreErrorCode.permissionDenied;
    case 'not-found':
      return FirestoreErrorCode.notFound;
    case 'already-exists':
      return FirestoreErrorCode.alreadyExists;
    case 'unavailable':
      return FirestoreErrorCode.unavailable;
    case 'deadline-exceeded':
      return FirestoreErrorCode.deadlineExceeded;
    case 'invalid-argument':
      return FirestoreErrorCode.invalidArgument;
    case 'failed-precondition':
      return FirestoreErrorCode.failedPrecondition;
    case 'aborted':
      return FirestoreErrorCode.aborted;
    case 'internal':
      return FirestoreErrorCode.internal;
    default:
      return FirestoreErrorCode.unknown;
  }
}

/// User-friendly error messages for Firestore exceptions
String _getFirestoreErrorMessage(FirestoreErrorCode code) {
  switch (code) {
    case FirestoreErrorCode.permissionDenied:
      return 'Permission denied. You may not have access to this data.';
    case FirestoreErrorCode.notFound:
      return 'The requested data was not found.';
    case FirestoreErrorCode.alreadyExists:
      return 'This record already exists.';
    case FirestoreErrorCode.unavailable:
      return 'Firestore is temporarily unavailable. Please try again later.';
    case FirestoreErrorCode.deadlineExceeded:
      return 'The operation timed out. Please try again.';
    case FirestoreErrorCode.invalidArgument:
      return 'Invalid data provided.';
    case FirestoreErrorCode.failedPrecondition:
      return 'Operation cannot be completed in current state.';
    case FirestoreErrorCode.aborted:
      return 'Operation was aborted due to conflict. Please try again.';
    case FirestoreErrorCode.internal:
      return 'An internal error occurred. Please try again later.';
    case FirestoreErrorCode.unknown:
      return 'An unexpected error occurred. Please try again.';
  }
}

/// Firestore Repository for Cloud Firestore operations
class FirestoreRepository {
  FirestoreRepository(this._firestore, this._auth, {String? expectedUid})
      : _expectedUid = expectedUid;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final String? _expectedUid;

  String get _currentUid {
    final uid = _auth.currentUser?.uid;
    return _expectedUid == null || _expectedUid == uid ? uid ?? '' : '';
  }

  // ===== Transaction Operations =====

  /// Get all transactions for current user
  Future<FirestoreResult<List<FirestoreTransaction>>> getTransactions({
    String? category,
    String? query,
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      Query queryRef = _firestore
          .collection(FirestorePaths.transactions(uid))
          .where('isDeleted', isEqualTo: false)
          .orderBy('occurredAt', descending: true);

      if (category != null && category != 'All') {
        queryRef = queryRef.where('category', isEqualTo: category);
      }

      if (query != null && query.trim().isNotEmpty) {
        // Firestore doesn't support full-text search natively
        // We'll filter in memory for now
        // For production, consider Algolia or similar
      }

      if (limit != null) {
        queryRef = queryRef.limit(limit);
      }

      if (startAfter != null) {
        queryRef = queryRef.startAfterDocument(startAfter);
      }

      final snapshot = await queryRef.get();
      final transactions = snapshot.docs
          .map(FirestoreTransaction.fromFirestore)
          .toList();

      // Apply text search filter if needed
      List<FirestoreTransaction> filtered = transactions;
      if (query != null && query.trim().isNotEmpty) {
        final searchLower = query.trim().toLowerCase();
        filtered = transactions.where((t) =>
            t.merchant.toLowerCase().contains(searchLower) ||
            t.note.toLowerCase().contains(searchLower)).toList();
      }

      return FirestoreResult.success(filtered);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load transactions: $e');
    }
  }

  /// Save a transaction (create or update)
  Future<FirestoreResult<FirestoreTransaction>> saveTransaction(
      FirestoreTransaction transaction) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final updatedTransaction = transaction.copyWith(
        updatedAt: now,
        version: transaction.version + 1,
      );

      if (transaction.id.isEmpty) {
        // Create new
        final docRef = await _firestore
            .collection(FirestorePaths.transactions(uid))
            .add(updatedTransaction.toFirestore());

        final created = updatedTransaction.copyWith(id: docRef.id);
        return FirestoreResult.success(created);
      } else {
        // Update existing
        await _firestore
            .collection(FirestorePaths.transactions(uid))
            .doc(transaction.id)
            .set(updatedTransaction.toFirestore(), SetOptions(merge: true));

        return FirestoreResult.success(updatedTransaction);
      }
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to save transaction: $e');
    }
  }

  /// Delete a transaction (soft delete)
  Future<FirestoreResult<void>> deleteTransaction(String id) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      await _firestore
          .collection(FirestorePaths.transactions(uid))
          .doc(id)
          .update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      });

      return FirestoreResult.ok();
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to delete transaction: $e');
    }
  }

  // ===== Savings Goal Operations =====

  /// Get all savings goals for current user
  Future<FirestoreResult<List<FirestoreSavingsGoal>>> getGoals() async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(FirestorePaths.goals(uid))
          .where('isDeleted', isEqualTo: false)
          .orderBy('deadline')
          .get();

      final goals = snapshot.docs
          .map(FirestoreSavingsGoal.fromFirestore)
          .toList();

      return FirestoreResult.success(goals);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load goals: $e');
    }
  }

  /// Save a savings goal (create or update)
  Future<FirestoreResult<FirestoreSavingsGoal>> saveGoal(
      FirestoreSavingsGoal goal) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final updatedGoal = goal.copyWith(
        updatedAt: now,
        version: goal.version + 1,
      );

      if (goal.id.isEmpty) {
        final docRef = await _firestore
            .collection(FirestorePaths.goals(uid))
            .add(updatedGoal.toFirestore());

        final created = updatedGoal.copyWith(id: docRef.id);
        return FirestoreResult.success(created);
      } else {
        await _firestore
            .collection(FirestorePaths.goals(uid))
            .doc(goal.id)
            .set(updatedGoal.toFirestore(), SetOptions(merge: true));

        return FirestoreResult.success(updatedGoal);
      }
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to save goal: $e');
    }
  }

  /// Delete a goal (and its contributions)
  Future<FirestoreResult<void>> deleteGoal(String id) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      // Delete contributions subcollection first
      final contributionsRef = _firestore
          .collection(FirestorePaths.goalContributions(uid, id));
      final contributionsSnapshot = await contributionsRef.get();

      final batch = _firestore.batch();
      for (final doc in contributionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore
          .collection(FirestorePaths.goals(uid))
          .doc(id));

      await batch.commit();

      return FirestoreResult.ok();
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to delete goal: $e');
    }
  }

  /// Add a contribution to a goal
  Future<FirestoreResult<FirestoreGoalContribution>> addContribution(
      String goalId, int amount, String note) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final contribution = FirestoreGoalContribution(
        id: '',
        goalId: goalId,
        amount: amount,
        contributedAt: now,
        note: note,
        localId: now.millisecondsSinceEpoch.toString(),
        createdAt: now,
        updatedAt: now,
        isSynced: true,
        isDeleted: false,
        version: 1,
        syncStatus: SyncStatus.synced,
      );

      final docRef = await _firestore
          .collection(FirestorePaths.goalContributions(uid, goalId))
          .add(contribution.toFirestore());

      final created = contribution.copyWith(id: docRef.id);

      // Update goal's saved amount
      await _firestore
          .collection(FirestorePaths.goals(uid))
          .doc(goalId)
          .update({
        'saved': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      });

      return FirestoreResult.success(created);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to add contribution: $e');
    }
  }

  // ===== Budget Operations =====

  /// Get all budgets for current user
  Future<FirestoreResult<Map<String, int>>> getBudgets() async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(FirestorePaths.budgets(uid))
          .where('isDeleted', isEqualTo: false)
          .get();

      final budgets = <String, int>{};
      for (final doc in snapshot.docs) {
        final budget = FirestoreBudget.fromFirestore(doc);
        budgets[budget.category] = budget.monthlyLimit;
      }

      return FirestoreResult.success(budgets);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load budgets: $e');
    }
  }

  /// Save a budget (create or update)
  Future<FirestoreResult<FirestoreBudget>> saveBudget(
      FirestoreBudget budget) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final updatedBudget = budget.copyWith(
        updatedAt: now,
        version: budget.version + 1,
      );

      if (budget.id.isEmpty) {
        // Use category as document ID
        await _firestore
            .collection(FirestorePaths.budgets(uid))
            .doc(budget.category)
            .set(updatedBudget.toFirestore());

        final created = updatedBudget.copyWith(id: budget.category);
        return FirestoreResult.success(created);
      } else {
        await _firestore
            .collection(FirestorePaths.budgets(uid))
            .doc(budget.id)
            .set(updatedBudget.toFirestore(), SetOptions(merge: true));

        return FirestoreResult.success(updatedBudget);
      }
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to save budget: $e');
    }
  }

  // ===== Investment Thesis Operations =====

  /// Get all investment theses for current user
  Future<FirestoreResult<List<FirestoreInvestmentThesis>>> getInvestmentTheses({bool includeDeleted = false})
      async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(FirestorePaths.investmentTheses(uid))
          .orderBy('updatedAt', descending: true)
          .get();

      final theses = snapshot.docs
          .map(FirestoreInvestmentThesis.fromFirestore)
          .where((record) => includeDeleted || !record.isDeleted)
          .toList();

      return FirestoreResult.success(theses);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load investment theses: $e');
    }
  }

  /// Save an investment thesis (create or update)
  Future<FirestoreResult<FirestoreInvestmentThesis>> saveInvestmentThesis(
      FirestoreInvestmentThesis thesis) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final updatedThesis = thesis.copyWith(
        updatedAt: now,
        version: thesis.version + 1,
      );

      if (thesis.id.isEmpty) {
        final docRef = await _firestore
            .collection(FirestorePaths.investmentTheses(uid))
            .add(updatedThesis.toFirestore());

        final created = updatedThesis.copyWith(id: docRef.id);
        return FirestoreResult.success(created);
      } else {
        await _firestore
            .collection(FirestorePaths.investmentTheses(uid))
            .doc(thesis.id)
            .set(updatedThesis.toFirestore(), SetOptions(merge: true));

        return FirestoreResult.success(updatedThesis);
      }
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to save investment thesis: $e');
    }
  }

  // ===== Portfolio Holdings Operations =====

  /// Get all portfolio holdings for current user
  Future<FirestoreResult<List<FirestorePortfolioHolding>>> getPortfolioHoldings({bool includeDeleted = false})
      async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(FirestorePaths.portfolioHoldings(uid))
          .orderBy('createdAt')
          .get();

      final holdings = snapshot.docs
          .map(FirestorePortfolioHolding.fromFirestore)
          .where((record) => includeDeleted || !record.isDeleted)
          .toList();

      return FirestoreResult.success(holdings);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load portfolio holdings: $e');
    }
  }

  /// Save a portfolio holding (create or update)
  Future<FirestoreResult<FirestorePortfolioHolding>> savePortfolioHolding(
      FirestorePortfolioHolding holding) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final updatedHolding = holding.copyWith(
        updatedAt: now,
        version: holding.version + 1,
      );

      if (holding.id.isEmpty) {
        final docRef = await _firestore
            .collection(FirestorePaths.portfolioHoldings(uid))
            .add(updatedHolding.toFirestore());

        final created = updatedHolding.copyWith(id: docRef.id);
        return FirestoreResult.success(created);
      } else {
        await _firestore
            .collection(FirestorePaths.portfolioHoldings(uid))
            .doc(holding.id)
            .set(updatedHolding.toFirestore(), SetOptions(merge: true));

        return FirestoreResult.success(updatedHolding);
      }
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to save portfolio holding: $e');
    }
  }

  Future<FirestoreResult<void>> deleteInvestmentThesis(FirestoreInvestmentThesis snapshot) =>
      _deleteInvestmentRecord(snapshot, FirestorePaths.investmentTheses);

  Future<FirestoreResult<void>> deletePortfolioHolding(FirestorePortfolioHolding snapshot) =>
      _deleteInvestmentRecord(snapshot, FirestorePaths.portfolioHoldings);

  Future<FirestoreResult<void>> _deleteInvestmentRecord(
    FirestoreModel record, String Function(String uid) collectionPath,
  ) async {
    final uid = _currentUid;
    if (uid.isEmpty) return FirestoreResult.failure('User not authenticated');
    try {
      final ref = _firestore.collection(collectionPath(uid)).doc(record.id);
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(ref);
        final changes = {
          'isDeleted': true,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        };
        if (!snapshot.exists) {
          // A write with an ambiguous response may arrive later. Seal this
          // reserved document ID even if it doesn't yet exist.
          txn.set(ref, {...record.toFirestore(), ...changes});
        } else if (snapshot.data()?['isDeleted'] != true) {
          txn.update(ref, {...changes, 'version': FieldValue.increment(1)});
        }
      });
      return FirestoreResult.ok();
    } on FirebaseException catch (error) {
      final code = _mapFirestoreException(error);
      return FirestoreResult.failure(_getFirestoreErrorMessage(code), code);
    }
  }

  // ===== Investment Settings =====

  /// Get investment settings
  Future<FirestoreResult<Map<String, String>>> getInvestmentSettings() async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(FirestorePaths.investmentSettings(uid))
          .get();

      final settings = <String, String>{};
      for (final doc in snapshot.docs) {
        final setting = FirestoreInvestmentSetting.fromFirestore(doc);
        settings[setting.key] = setting.value;
      }

      return FirestoreResult.success(settings);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load investment settings: $e');
    }
  }

  /// Save investment setting
  Future<FirestoreResult<FirestoreInvestmentSetting>> saveInvestmentSetting(
      FirestoreInvestmentSetting setting) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final updatedSetting = setting.copyWith(
        updatedAt: now,
        version: setting.version + 1,
      );

      await _firestore
          .collection(FirestorePaths.investmentSettings(uid))
          .doc(setting.key)
          .set(updatedSetting.toFirestore(), SetOptions(merge: true));

      return FirestoreResult.success(updatedSetting);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to save investment setting: $e');
    }
  }

  // ===== Sync Metadata =====

  /// Get sync metadata for current user
  Future<FirestoreResult<SyncMetadata?>> getSyncMetadata() async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final doc = await _firestore
          .collection(FirestorePaths.syncMetadata(uid))
          .doc('metadata')
          .get();

      if (!doc.exists) {
        return FirestoreResult.success(null);
      }

      return FirestoreResult.success(SyncMetadata.fromFirestore(doc));
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load sync metadata: $e');
    }
  }

  /// Save sync metadata
  Future<FirestoreResult<SyncMetadata>> saveSyncMetadata(
      SyncMetadata metadata) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final now = DateTime.now();
      final updatedMetadata = metadata.copyWith(
        updatedAt: now,
        version: metadata.version + 1,
      );

      await _firestore
          .collection(FirestorePaths.syncMetadata(uid))
          .doc('metadata')
          .set(updatedMetadata.toFirestore(), SetOptions(merge: true));

      return FirestoreResult.success(updatedMetadata);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to save sync metadata: $e');
    }
  }

  // ===== Pending Writes (Offline Queue) =====

  /// Add a pending write operation
  Future<FirestoreResult<void>> addPendingWrite(PendingWrite write) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      await _firestore
          .collection(FirestorePaths.pendingWrites(uid))
          .doc(write.id)
          .set(write.toJson());

      return FirestoreResult.ok();
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to add pending write: $e');
    }
  }

  /// Get pending writes
  Future<FirestoreResult<List<PendingWrite>>> getPendingWrites() async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(FirestorePaths.pendingWrites(uid))
          .where('status', whereIn: [SyncStatus.pending, SyncStatus.error])
          .orderBy('createdAt')
          .get();

      final writes = snapshot.docs
          .map((doc) => PendingWrite.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      return FirestoreResult.success(writes);
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to load pending writes: $e');
    }
  }

  /// Update pending write status
  Future<FirestoreResult<void>> updatePendingWrite(
      String id, SyncStatus status, {String? error}) async {
    try {
      final uid = _currentUid;
      if (uid.isEmpty) {
        return FirestoreResult.failure('User not authenticated');
      }

      final updates = {
        'status': status.name,
        'retryCount': FieldValue.increment(1),
      };
      if (error != null) {
        updates['lastError'] = error;
      }

      await _firestore
          .collection(FirestorePaths.pendingWrites(uid))
          .doc(id)
          .update(updates);

      return FirestoreResult.ok();
    } on FirebaseException catch (e) {
      return FirestoreResult.failure(
        _getFirestoreErrorMessage(_mapFirestoreException(e)),
        _mapFirestoreException(e),
      );
    } catch (e) {
      return FirestoreResult.failure('Failed to update pending write: $e');
    }
  }

  // ===== Real-time Listeners =====

  /// Listen to transaction changes
  Stream<List<FirestoreTransaction>> watchTransactions(
      {String? category, String? query}) {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    Query queryRef = _firestore
        .collection(FirestorePaths.transactions(uid))
        .where('isDeleted', isEqualTo: false)
        .orderBy('occurredAt', descending: true);

    if (category != null && category != 'All') {
      queryRef = queryRef.where('category', isEqualTo: category);
    }

    return queryRef.snapshots().map((snapshot) {
      final transactions = snapshot.docs
          .map(FirestoreTransaction.fromFirestore)
          .toList();

      List<FirestoreTransaction> filtered = transactions;
      if (query != null && query.trim().isNotEmpty) {
        final searchLower = query.trim().toLowerCase();
        filtered = transactions.where((t) =>
            t.merchant.toLowerCase().contains(searchLower) ||
            t.note.toLowerCase().contains(searchLower)).toList();
      }

      return filtered;
    });
  }

  /// Watch goals
  Stream<List<FirestoreSavingsGoal>> watchGoals() {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection(FirestorePaths.goals(uid))
        .where('isDeleted', isEqualTo: false)
        .orderBy('deadline')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(FirestoreSavingsGoal.fromFirestore).toList());
  }

  /// Watch budgets
  Stream<Map<String, int>> watchBudgets() {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection(FirestorePaths.budgets(uid))
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final budgets = <String, int>{};
      for (final doc in snapshot.docs) {
        final budget = FirestoreBudget.fromFirestore(doc);
        budgets[budget.category] = budget.monthlyLimit;
      }
      return budgets;
    });
  }

  /// Watch investment theses
  Stream<List<FirestoreInvestmentThesis>> watchInvestmentTheses() {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection(FirestorePaths.investmentTheses(uid))
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(FirestoreInvestmentThesis.fromFirestore).toList());
  }

  /// Watch portfolio holdings
  Stream<List<FirestorePortfolioHolding>> watchPortfolioHoldings() {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection(FirestorePaths.portfolioHoldings(uid))
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(FirestorePortfolioHolding.fromFirestore).toList());
  }
}

/// Extension for copyWith on Firestore models
extension FirestoreTransactionCopy on FirestoreTransaction {
  FirestoreTransaction copyWith({
    String? id,
    int? amount,
    bool? isIncome,
    String? category,
    String? merchant,
    DateTime? occurredAt,
    String? note,
    String? source,
    String? localId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return FirestoreTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      source: source ?? this.source,
      localId: localId ?? this.localId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

extension FirestoreSavingsGoalCopy on FirestoreSavingsGoal {
  FirestoreSavingsGoal copyWith({
    String? id,
    String? name,
    int? target,
    int? saved,
    DateTime? deadline,
    String? purpose,
    String? localId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return FirestoreSavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      target: target ?? this.target,
      saved: saved ?? this.saved,
      deadline: deadline ?? this.deadline,
      purpose: purpose ?? this.purpose,
      localId: localId ?? this.localId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

extension FirestoreGoalContributionCopy on FirestoreGoalContribution {
  FirestoreGoalContribution copyWith({
    String? id,
    String? goalId,
    int? amount,
    DateTime? contributedAt,
    String? note,
    String? localId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return FirestoreGoalContribution(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      contributedAt: contributedAt ?? this.contributedAt,
      note: note ?? this.note,
      localId: localId ?? this.localId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

extension FirestoreBudgetCopy on FirestoreBudget {
  FirestoreBudget copyWith({
    String? id,
    String? category,
    int? monthlyLimit,
    String? localId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return FirestoreBudget(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      localId: localId ?? this.localId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

extension FirestoreInvestmentThesisCopy on FirestoreInvestmentThesis {
  FirestoreInvestmentThesis copyWith({
    String? id,
    String? securityName,
    String? ticker,
    String? exchange,
    String? identifier,
    String? rationale,
    String? horizon,
    String? assumptions,
    String? risks,
    String? invalidationConditions,
    String? localId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return FirestoreInvestmentThesis(
      id: id ?? this.id,
      securityName: securityName ?? this.securityName,
      ticker: ticker ?? this.ticker,
      exchange: exchange ?? this.exchange,
      identifier: identifier ?? this.identifier,
      rationale: rationale ?? this.rationale,
      horizon: horizon ?? this.horizon,
      assumptions: assumptions ?? this.assumptions,
      risks: risks ?? this.risks,
      invalidationConditions: invalidationConditions ?? this.invalidationConditions,
      localId: localId ?? this.localId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

extension FirestorePortfolioHoldingCopy on FirestorePortfolioHolding {
  FirestorePortfolioHolding copyWith({
    String? id,
    String? securityName,
    String? ticker,
    String? exchange,
    String? identifier,
    int? marketValueKzt,
    double? fxSensitivityPctPerPct,
    double? oilSensitivityPctPerPct,
    double? rateSensitivityPctPerPoint,
    String? localId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return FirestorePortfolioHolding(
      id: id ?? this.id,
      securityName: securityName ?? this.securityName,
      ticker: ticker ?? this.ticker,
      exchange: exchange ?? this.exchange,
      identifier: identifier ?? this.identifier,
      marketValueKzt: marketValueKzt ?? this.marketValueKzt,
      fxSensitivityPctPerPct: fxSensitivityPctPerPct ?? this.fxSensitivityPctPerPct,
      oilSensitivityPctPerPct: oilSensitivityPctPerPct ?? this.oilSensitivityPctPerPct,
      rateSensitivityPctPerPoint:
          rateSensitivityPctPerPoint ?? this.rateSensitivityPctPerPoint,
      localId: localId ?? this.localId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

extension FirestoreInvestmentSettingCopy on FirestoreInvestmentSetting {
  FirestoreInvestmentSetting copyWith({
    String? id,
    String? key,
    String? value,
    String? localId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return FirestoreInvestmentSetting(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      localId: localId ?? this.localId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

extension SyncMetadataCopy on SyncMetadata {
  SyncMetadata copyWith({
    String? id,
    String? userId,
    DateTime? lastFullSync,
    int? pendingUploadCount,
    DateTime? lastConflictAt,
    int? schemaVersion,
    Map<String, dynamic>? entityVersions,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    int? version,
    SyncStatus? syncStatus,
  }) {
    return SyncMetadata(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lastFullSync: lastFullSync ?? this.lastFullSync,
      pendingUploadCount: pendingUploadCount ?? this.pendingUploadCount,
      lastConflictAt: lastConflictAt ?? this.lastConflictAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      entityVersions: entityVersions ?? this.entityVersions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}