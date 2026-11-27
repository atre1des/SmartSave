import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/app/app.dart';
import 'package:smart_save/l10n/generated/app_localizations.dart';
import 'package:smart_save/services/auth_service.dart';
import 'package:smart_save/shared/theme.dart';

void main() {
  for (final locale in [
    const Locale('en'),
    const Locale('kk'),
    const Locale('ru'),
  ]) {
    testWidgets('Reset validates and uses the existing service in $locale', (
      tester,
    ) async {
      final auth = _ResetAuth();
      final strings = lookupAppLocalizations(locale);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 650);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(auth)],
          child: MaterialApp(
            theme: buildAppTheme(
              locale.languageCode == 'ru' ? Brightness.dark : Brightness.light,
            ),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!,
            ),
            home: const WelcomeScreen(),
          ),
        ),
      );
      await tester.tap(find.text(strings.haveAccount));
      await tester.pumpAndSettle();
      expect(find.text(strings.authWelcomeBack), findsOneWidget);
      final toggle = find.byTooltip(strings.authShowPassword);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      final forgot = find.text(strings.forgotPassword);
      await tester.ensureVisible(forgot);
      await tester.tap(forgot);
      await tester.pumpAndSettle();

      final send = find.text(strings.authSendReset);
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text(strings.enterEmail), findsOneWidget);
      expect(auth.email, isNull);

      await tester.enterText(find.byType(TextFormField), 'student@example.com');
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(auth.email, 'student@example.com');
      expect(find.text(strings.passwordResetSent), findsOneWidget);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ResetAuth implements AuthService {
  String? email;

  @override
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    this.email = email;
    return AuthResult.ok();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
