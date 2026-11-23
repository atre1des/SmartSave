// Auth Service for SmartSave
// Handles Firebase Authentication with proper error handling and state management

import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import '../data/finance_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication state enum
enum AuthStatus {
  /// User is not authenticated
  unauthenticated,
  /// User is authenticated but email not verified
  emailNotVerified,
  /// User is fully authenticated
  authenticated,
  /// Authentication in progress
  authenticating,
  /// Error occurred
  error,
}

/// Result of authentication operations
class AuthResult {
  final bool success;
  final UserCredential? credential;
  final String? errorMessage;
  final AuthExceptionCode? errorCode;

  const AuthResult._({
    required this.success,
    this.credential,
    this.errorMessage,
    this.errorCode,
  });

  factory AuthResult.success(UserCredential credential) => AuthResult._(
        success: true,
        credential: credential,
        errorMessage: null,
        errorCode: null,
      );

  factory AuthResult.failure(String message, [AuthExceptionCode? code]) => AuthResult._(
        success: false,
        credential: null,
        errorMessage: message,
        errorCode: code,
      );

  factory AuthResult.ok() => const AuthResult._(
        success: true,
        credential: null,
        errorMessage: null,
        errorCode: null,
      );
}

/// Firebase Auth error codes mapped to app-specific codes
enum AuthExceptionCode {
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  userNotFound,
  wrongPassword,
  invalidCredential,
  tooManyRequests,
  networkError,
  emailNotVerified,
  requiresRecentLogin,
  userDisabled,
  operationNotAllowed,
  unknown,
}

/// Maps Firebase Auth exceptions to app-specific error codes
AuthExceptionCode _mapFirebaseAuthException(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return AuthExceptionCode.emailAlreadyInUse;
    case 'invalid-email':
      return AuthExceptionCode.invalidEmail;
    case 'weak-password':
      return AuthExceptionCode.weakPassword;
    case 'user-not-found':
      return AuthExceptionCode.userNotFound;
    case 'wrong-password':
      return AuthExceptionCode.wrongPassword;
    case 'invalid-credential':
      return AuthExceptionCode.invalidCredential;
    case 'too-many-requests':
      return AuthExceptionCode.tooManyRequests;
    case 'network-request-failed':
      return AuthExceptionCode.networkError;
    case 'user-disabled':
      return AuthExceptionCode.userDisabled;
    case 'operation-not-allowed':
      return AuthExceptionCode.operationNotAllowed;
    case 'requires-recent-login':
      return AuthExceptionCode.requiresRecentLogin;
    default:
      return AuthExceptionCode.unknown;
  }
}

/// User-friendly error messages for auth exceptions
String _getAuthErrorMessage(AuthExceptionCode code) {
  switch (code) {
    case AuthExceptionCode.emailAlreadyInUse:
      return 'An account with this email already exists.';
    case AuthExceptionCode.invalidEmail:
      return 'Please enter a valid email address.';
    case AuthExceptionCode.weakPassword:
      return 'Password is too weak. Use at least 8 characters with letters and numbers.';
    case AuthExceptionCode.userNotFound:
      return 'No account found with this email address.';
    case AuthExceptionCode.wrongPassword:
      return 'Incorrect password. Please try again.';
    case AuthExceptionCode.invalidCredential:
      return 'Invalid credentials. Please check your email and password.';
    case AuthExceptionCode.tooManyRequests:
      return 'Too many attempts. Please try again later.';
    case AuthExceptionCode.networkError:
      return 'Network error. Please check your connection and try again.';
    case AuthExceptionCode.emailNotVerified:
      return 'Please verify your email address before signing in.';
    case AuthExceptionCode.requiresRecentLogin:
      return 'This action requires recent login. Please sign in again.';
    case AuthExceptionCode.userDisabled:
      return 'This account has been disabled. Contact support.';
    case AuthExceptionCode.operationNotAllowed:
      return 'This operation is not allowed. Contact support.';
    case AuthExceptionCode.unknown:
    default:
      return 'An unexpected error occurred. Please try again.';
  }
}

/// Auth Service for managing Firebase Authentication
class AuthService {
  AuthService(this._prefs);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  /// Expose FirebaseAuth instance for Firestore initialization
  FirebaseAuth get auth => _auth;

  /// Current user stream
  Stream<User?> get authStateChanges => _auth.userChanges();

  /// Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Current user email
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Check if current user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Current authentication status
  AuthStatus get currentStatus {
    final user = _auth.currentUser;
    if (user == null) return AuthStatus.unauthenticated;
    if (!user.emailVerified) return AuthStatus.emailNotVerified;
    return AuthStatus.authenticated;
  }

  /// Initialize auth service
  Future<void> initialize() async {
    // Native Firebase manages its own authenticated session persistence.
    if (kIsWeb) await _auth.setPersistence(Persistence.SESSION);
  }

  /// Register a new user with email and password
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name
      if (credential.user != null && displayName.isNotEmpty) {
        await credential.user!.updateDisplayName(displayName.trim());
        await credential.user!.reload();
      }

      // Send email verification
      await _sendEmailVerification(credential.user!);

      // Store onboarding state locally (per user)
      await setOnboardingComplete(false);

      return AuthResult.success(credential);
    } on FirebaseAuthException catch (e) {
      final code = _mapFirebaseAuthException(e);
      return AuthResult.failure(_getAuthErrorMessage(code), code);
    } catch (e) {
      return AuthResult.failure('Registration failed. Please try again.', AuthExceptionCode.unknown);
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Reload user to get latest email verification status
      await credential.user!.reload();

      return AuthResult.success(credential);
    } on FirebaseAuthException catch (e) {
      final code = _mapFirebaseAuthException(e);
      return AuthResult.failure(_getAuthErrorMessage(code), code);
    } catch (e) {
      return AuthResult.failure('Sign in failed. Please try again.', AuthExceptionCode.unknown);
    }
  }

  /// Sign out
  Future<AuthResult> signOut() async {
    try {
      await _auth.signOut();
      // Clear local session data
      await _clearLocalSession();
      return AuthResult.ok();
    } catch (e) {
      return AuthResult.failure('Sign out failed. Please try again.', AuthExceptionCode.unknown);
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      final code = _mapFirebaseAuthException(e);
      return AuthResult.failure(_getAuthErrorMessage(code), code);
    } catch (e) {
      return AuthResult.failure('Failed to send reset email. Please try again.', AuthExceptionCode.unknown);
    }
  }

  /// Send email verification
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user signed in.', AuthExceptionCode.unknown);
      }
      await _sendEmailVerification(user);
      return AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      final code = _mapFirebaseAuthException(e);
      return AuthResult.failure(_getAuthErrorMessage(code), code);
    } catch (e) {
      return AuthResult.failure('Failed to send verification email.', AuthExceptionCode.unknown);
    }
  }

  /// Internal method to send email verification
  Future<void> _sendEmailVerification(User user) async {
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Re-authenticate user (required for sensitive operations)
  Future<AuthResult> reauthenticate(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return AuthResult.failure('No user signed in.', AuthExceptionCode.unknown);
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      final code = _mapFirebaseAuthException(e);
      return AuthResult.failure(_getAuthErrorMessage(code), code);
    } catch (e) {
      return AuthResult.failure('Re-authentication failed.', AuthExceptionCode.unknown);
    }
  }

  Future<AuthResult> deleteAccount({
    required String password,
    required FinanceRepository repository,
  }) async {
    const endpoint = String.fromEnvironment('SMARTSAVE_BACKEND_URL');
    final base = Uri.tryParse(endpoint);
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty) {
      return AuthResult.failure('A configured HTTPS backend is required.', AuthExceptionCode.operationNotAllowed);
    }
    final user = _auth.currentUser;
    if (user == null) return AuthResult.failure('Sign in to delete this account.', AuthExceptionCode.unknown);
    final signedIn = await reauthenticate(password);
    if (!signedIn.success) return signedIn;
    final client = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      followRedirects: false,
    ));
    try {
      final token = await user.getIdToken(true);
      if (token == null || currentUserId != user.uid) {
        throw StateError('Your account session changed.');
      }
      await repository.deleteAccountData(user.uid, () async {
        if (currentUserId != user.uid) throw StateError('Your account session changed.');
        final response = await client.postUri<void>(
          base.resolve('/api/account/delete-data'),
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (response.statusCode != 204) throw StateError('Cloud deletion could not be confirmed.');
      }, clearPreferences: (removeLegacy) async {
        for (final name in [..._profilePreferences, 'onboarding_complete', 'risk_profile_complete', 'risk_profile', 'quiz_answers']) {
          if (!await _prefs.remove('${name}_${user.uid}')) {
            throw StateError('Local account preferences could not be removed.');
          }
        }
        if (removeLegacy && !await _prefs.remove('ai_conversations')) {
          throw StateError('Legacy assistant history could not be removed.');
        }
      });
      if (currentUserId != user.uid) throw StateError('Your account session changed.');
      await user.delete();
      return AuthResult.ok();
    } on StateError catch (error) {
      return AuthResult.failure(error.message, AuthExceptionCode.operationNotAllowed);
    } catch (_) {
      return AuthResult.failure(
        'Deletion could not be confirmed. Some cleanup may have completed. Restart SmartSave and retry while the account still exists.',
        AuthExceptionCode.unknown,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Update user profile (display name, photo)
  Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user signed in.', AuthExceptionCode.unknown);
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName.trim());
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();
      return AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      final code = _mapFirebaseAuthException(e);
      return AuthResult.failure(_getAuthErrorMessage(code), code);
    } catch (e) {
      return AuthResult.failure('Failed to update profile.', AuthExceptionCode.unknown);
    }
  }

  static const _profilePreferences = [
    'profile_country',
    'profile_currency',
    'profile_language',
  ];

  String? getProfilePreference(String key) {
    final uid = currentUserId;
    return uid == null || !_profilePreferences.contains(key)
        ? null
        : _prefs.getString('${key}_$uid');
  }

  Future<void> saveLocalProfile(Map<String, String> data) async {
    final uid = currentUserId;
    if (uid == null) return;
    for (final key in _profilePreferences) {
      final value = data[key];
      if (value != null) await _prefs.setString('${key}_$uid', value);
    }
  }

  /// Check if onboarding is complete for current user
  Future<bool> isOnboardingComplete() async {
    return _prefs.getBool('onboarding_complete_${currentUserId}') ?? false;
  }

  /// Set onboarding complete state
  Future<void> setOnboardingComplete(bool complete) async {
    if (currentUserId != null) {
      await _prefs.setBool('onboarding_complete_${currentUserId}', complete);
    }
  }

  /// Check if risk quiz is complete
  Future<bool> isRiskQuizComplete() async {
    return _prefs.getBool('risk_profile_complete_${currentUserId}') ?? false;
  }

  /// Set risk quiz complete
  Future<void> setRiskQuizComplete(bool complete, {String? profile}) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _prefs.setBool('risk_profile_complete_$uid', complete);
    if (profile != null) await _prefs.setString('risk_profile_$uid', profile);
  }

  /// Get risk profile
  String? getRiskProfile() {
    if (currentUserId != null) {
      return _prefs.getString('risk_profile_${currentUserId}');
    }
    return null;
  }

  /// Clear local session data
  Future<void> _clearLocalSession() async {
    final keys = [
      'demo_session',
      'demo_contact',
      'profile_name',
      'profile_country',
      'profile_currency',
      'profile_language',
      'risk_profile',
      'quiz_answers',
      'onboarding_complete',
      'risk_profile_complete',
      'quiz_completed',
    ];

    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}