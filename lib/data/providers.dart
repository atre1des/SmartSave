import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'finance_controller.dart';
import 'finance_repository.dart';
import '../../ai/ai_assistant_service.dart';
import '../../ai/openrouter_provider.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) => throw StateError('Repository not initialized'));
final financeControllerProvider = ChangeNotifierProvider<FinanceController>((ref) =>
    FinanceController(ref.watch(financeRepositoryProvider))..refresh());

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw StateError('SharedPreferences not initialized'));

final openRouterProviderProvider = Provider<OpenRouterProvider>((ref) => OpenRouterProvider());

final aiAssistantServiceProvider = Provider<SmartSaveAIAssistantService>((ref) =>
    SmartSaveAIAssistantService(ref.watch(financeRepositoryProvider)));

/// Provider for the currently selected main tab (Home=0, Deposits=1, AI=2, Invest=3, My Account=4)
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);