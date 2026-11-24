import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_save/l10n/app_locale.dart';
import 'package:smart_save/l10n/generated/app_localizations.dart';

void main() {
  test(
    'language preference survives restart and stays scoped to the account',
    () async {
      SharedPreferences.setMockInitialValues({
        'profile_language_legacy': 'Қазақша',
      });
      final preferences = await SharedPreferences.getInstance();
      final controller = AppLocaleController(
        preferences: preferences,
        uid: 'alice',
      );
      addTearDown(controller.dispose);
      expect(controller.locale, isNull);
      expect(await controller.select(const Locale('kk')), isTrue);
      expect(await controller.select(const Locale('ru')), isTrue);
      final restored = AppLocaleController(
        preferences: preferences,
        uid: 'alice',
      );
      final other = AppLocaleController(preferences: preferences, uid: 'bob');
      final signedOut = AppLocaleController(preferences: preferences);
      final legacy = AppLocaleController(
        preferences: preferences,
        uid: 'legacy',
      );
      addTearDown(restored.dispose);
      addTearDown(other.dispose);
      addTearDown(signedOut.dispose);
      addTearDown(legacy.dispose);
      expect(restored.locale, const Locale('ru'));
      expect(other.locale, isNull);
      expect(signedOut.locale, isNull);
      expect(legacy.locale, const Locale('kk'));
      expect(
        AppLocaleController.resolve(
          const Locale('fr'),
          AppLocalizations.supportedLocales,
        ),
        const Locale('en'),
      );
    },
  );

  testWidgets('locale changes translate navigation, money, dates and plurals', (
    tester,
  ) async {
    final controller = AppLocaleController();
    addTearDown(controller.dispose);
    final userText = TextEditingController(text: 'Әлия · KZAP · Елена');
    addTearDown(userText.dispose);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: controller,
        builder: (_, _) => MaterialApp(
          locale: controller.locale ?? const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              bottomNavigationBar: NavigationBar(
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home),
                    label: context.l10n.home,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person),
                    label: context.l10n.myAccount,
                  ),
                ],
              ),
              body: Column(
                children: [
                  Text(context.l10n.goals),
                  Text(context.l10n.amountSaved(context.formatTenge(12500))),
                  Text(context.formatShortDate(DateTime(2026, 1, 3))),
                  Text(context.l10n.monthsLeft(22)),
                  TextField(controller: userText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('12 500 ₸ saved'), findsOneWidget);
    expect(find.text('3 Jan 2026'), findsOneWidget);
    await controller.select(const Locale('kk'));
    await tester.pumpAndSettle();
    expect(find.text('Басты бет'), findsOneWidget);
    expect(find.text('Мақсаттар'), findsOneWidget);
    expect(find.text('22 ай қалды'), findsOneWidget);
    expect(find.textContaining('қаң'), findsOneWidget);
    await controller.select(const Locale('ru'));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Цели'), findsOneWidget);
    expect(find.text('Осталось 22 месяца'), findsOneWidget);
    expect(find.textContaining('янв'), findsOneWidget);
    expect(find.text('Әлия · KZAP · Елена'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
