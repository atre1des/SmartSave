import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceController extends ValueNotifier<ThemeMode> {
  AppearanceController(this._preferences)
    : super(switch (_preferences.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      });

  static const _key = 'appearance_theme';
  final SharedPreferences _preferences;

  Future<bool> select(ThemeMode mode) async {
    if (!await _preferences.setString(_key, mode.name)) return false;
    value = mode;
    return true;
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppearanceController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
