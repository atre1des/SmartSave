import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/widgets.dart' as english;
import 'generated/app_localizations.dart';

extension AppLocaleContext on BuildContext {
  // Standalone widget tests and previews can use the English catalog.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));

  String formatTenge(int amount) => localizedTenge(amount, l10n.localeName);
  String formatSignedTenge(int amount, {required bool income}) =>
      '${income ? '+' : '−'}${formatTenge(amount).replaceAll('−', '')}';
  String formatShortDate(DateTime date) => l10n.localeName == 'en'
      ? english.formatShortDate(date)
      : DateFormat('d MMM y', l10n.localeName).format(date);

  String formatPercent(int percentagePoints) =>
      NumberFormat.decimalPercentPattern(
        locale: l10n.localeName,
        decimalDigits: 0,
      ).format(percentagePoints / 100);

  String transactionCategory(String category) => l10n.categoryName(category);
}

extension AppCatalogCategories on AppLocalizations {
  String categoryName(String category) => switch (category) {
    'All' => all,
    'Food' => food,
    'Transport' => transport,
    'Shopping' => shopping,
    'Bills' => bills,
    'Health' => health,
    'Other' => other,
    'Income' => income,
    _ => category,
  };
}

AppLocalizations assistantStrings(String prompt, String languageCode) {
  final code = RegExp(r'[ӘҒҚҢӨҰҮҺІәғқңөұүһі]').hasMatch(prompt)
      ? 'kk'
      : RegExp(
          r'(^|[^а-яё])(как|что|почему|мой|можно|нужно|составить|пожалуйста)([^а-яё]|$)',
          caseSensitive: false,
        ).hasMatch(prompt)
      ? 'ru'
      : RegExp(r'[А-Яа-яЁё]').hasMatch(prompt)
      ? (languageCode == 'kk' ? 'kk' : 'ru')
      : RegExp(r'[A-Za-z]').hasMatch(prompt)
      ? 'en'
      : languageCode;
  return lookupAppLocalizations(
    AppLocaleController.resolve(
      Locale(code),
      AppLocalizations.supportedLocales,
    ),
  );
}

String localizedTenge(int amount, String languageCode) {
  final separator = languageCode == 'en'
      ? ' '
      : NumberFormat.decimalPattern(languageCode).symbols.GROUP_SEP;
  final digits = amount.toString().replaceFirst('-', '');
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => separator,
  );
  return '${amount < 0 ? '−' : ''}$grouped ₸';
}

final appLocaleProvider = ChangeNotifierProvider<AppLocaleController>(
  (ref) => AppLocaleController(),
);

class AppLocaleController extends ChangeNotifier {
  AppLocaleController({SharedPreferences? preferences, String? uid})
    : _preferences = preferences,
      _key = uid == null ? null : 'profile_language_$uid' {
    final key = _key;
    if (key != null) {
      _locale = switch (_preferences?.getString(key)) {
        'en' || 'English' => const Locale('en'),
        'kk' || 'Қазақша' => const Locale('kk'),
        'ru' || 'Русский' => const Locale('ru'),
        _ => null,
      };
    }
  }

  final SharedPreferences? _preferences;
  final String? _key;
  Locale? _locale;

  Locale? get locale => _locale;

  Future<bool> select(Locale locale) async {
    if (!AppLocalizations.supportedLocales.contains(locale)) return false;
    final key = _key;
    if (key != null &&
        !(await _preferences!.setString(key, locale.languageCode))) {
      return false;
    }
    if (_locale != locale) {
      _locale = locale;
      if (hasListeners) notifyListeners();
    }
    return true;
  }

  static Locale resolve(Locale? preferred, Iterable<Locale> supported) {
    for (final locale in supported) {
      if (locale.languageCode == preferred?.languageCode) return locale;
    }
    return const Locale('en');
  }
}
