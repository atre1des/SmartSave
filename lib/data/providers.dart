import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'finance_controller.dart';
import 'finance_repository.dart';
import 'firestore_repository.dart';
import '../../ai/ai_assistant_service.dart';
import '../../ai/openrouter_provider.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) => throw StateError('Repository not initialized'));
final financeControllerProvider = ChangeNotifierProvider<FinanceController>((ref) =>
    FinanceController(ref.watch(financeRepositoryProvider))..refresh());

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw StateError('SharedPreferences not initialized'));

final openRouterProviderProvider = Provider<OpenRouterProvider>((ref) => OpenRouterProvider());

final aiAssistantServiceProvider = Provider<SmartSaveAIAssistantService>((ref) =>
    SmartSaveAIAssistantService(ref.watch(financeRepositoryProvider)));

// AuthService provider is initialized in main.dart
final authServiceProvider = Provider<AuthService>((ref) => throw StateError('AuthService not initialized'));

// Firestore repository
final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  final auth = ref.watch(authServiceProvider).auth;
  return FirestoreRepository(firestore, auth);
});

// Sync service
final syncServiceProvider = ChangeNotifierProvider<SyncService>((ref) {
  final localRepo = ref.watch(financeRepositoryProvider);
  final cloudRepo = ref.watch(firestoreRepositoryProvider);
  final auth = FirebaseAuth.instance;
  return SyncService(
    localRepo: localRepo,
    cloudRepo: cloudRepo,
    auth: auth,
  )..initialize();
});

// Stream provider for auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Provider for current auth status
final authStatusProvider = Provider<AuthStatus>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentStatus;
});

/// Provider for the currently selected main tab (Home=0, Deposits=1, AI=2, Invest=3, My Account=4)
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);