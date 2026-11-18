import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'data/providers.dart';
import 'data/finance_repository.dart';
import 'features/app/app.dart';
import 'features/advice/assistant_session.dart';
import 'features/advice/ai_assistant_screen.dart';
import 'features/invest/invest_hub_screen.dart';
import 'features/invest/invest_screen.dart';
import 'features/profile/my_account_screen.dart';
import 'shared/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Opens the local SQLite database. On failure this no longer blocks app startup:
  /// we retry once (common transient SQFLITE lock error) and, if it persists,
  /// fall back to a fresh demo database path so the app reaches its Home screen.
  FinanceRepository? _repository;
  try {
    _repository = await FinanceRepository.open();
  } catch (e, st) {
    print('[main] SQLite open failed first attempt: $e\n$st');
    try {
      _repository = await FinanceRepository.open();
    } catch (e2, st2) {
      print('[main] SQLite still unavailable; launching with demo fallback: $e2\n$st2');
      _repository = await FinanceRepository.open(databasePath: p.join(Directory.systemTemp.path, 'smartsave_demo.db'));
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(_repository!),
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      ],
      child: const SmartSaveApp(),
    ),
  );
}

class SmartSaveApp extends StatelessWidget {
  const SmartSaveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: appNavigatorKey,
    title: 'SmartSave',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const AppEntry(),
  );
}