// Canonical Firestore collection paths for SmartSave
// This is the single source of truth for all Firestore document paths.

/// Provides static methods for building Firestore collection and document paths.
/// All paths are scoped under the user's UID for data isolation.
class FirestorePaths {
  /// Root user document path
  static String userRoot(String uid) => 'users/$uid';

  /// Transactions collection for a user
  static String transactions(String uid) => 'users/$uid/transactions';

  /// Savings goals collection for a user
  static String goals(String uid) => 'users/$uid/goals';

  /// Goal contributions subcollection
  static String goalContributions(String uid, String goalId) =>
      'users/$uid/goals/$goalId/contributions';

  /// Budgets collection for a user
  static String budgets(String uid) => 'users/$uid/budgets';

  /// Investment theses collection for a user
  static String investmentTheses(String uid) => 'users/$uid/investmentTheses';

  /// Thesis conditions subcollection
  static String thesisConditions(String uid, String thesisId) =>
      'users/$uid/investmentTheses/$thesisId/conditions';

  /// Thesis assessments subcollection
  static String thesisAssessments(String uid, String thesisId) =>
      'users/$uid/investmentTheses/$thesisId/assessments';

  /// Portfolio holdings collection for a user
  static String portfolioHoldings(String uid) => 'users/$uid/portfolioHoldings';

  /// Investment settings collection for a user
  static String investmentSettings(String uid) => 'users/$uid/investmentSettings';

  /// Sync metadata document for a user
  static String syncMetadata(String uid) => 'users/$uid/syncMetadata';

  /// Pending writes collection for offline queue
  static String pendingWrites(String uid) => 'users/$uid/pendingWrites';

  /// AI messages collection for a user
  static String aiMessages(String uid) => 'users/$uid/aiMessages';
}