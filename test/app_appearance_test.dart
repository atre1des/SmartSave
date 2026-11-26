import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_save/shared/appearance.dart';
import 'package:smart_save/shared/theme.dart';
import 'package:smart_save/shared/glass.dart';
import 'package:smart_save/shared/widgets.dart';

double contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

void main() {
  test('core text, actions and status pairs meet normal text contrast', () {
    for (final brightness in Brightness.values) {
      final colors = AppColors(brightness);
      for (final (text, surface) in [
        (colors.text, colors.canvas),
        (colors.muted, colors.canvas),
        (colors.action, colors.canvas),
        (colors.text, colors.surface),
        (colors.muted, colors.surface),
        (colors.onPrimary, colors.primary),
        (colors.onSelection, colors.selection),
        (colors.onEmphasis, colors.emphasis),
        (colors.error, colors.noticeSurface),
        (colors.warning, colors.noticeSurface),
        (colors.onPremium, colors.premium),
        (colors.onWarmSurface, colors.warmSurface),
        (colors.onWarmSurface, colors.warmAccent),
        (colors.onPremium, colors.warmAccent),
      ]) {
        expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test(
    'appearance persists device-wide, including the System option',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = AppearanceController(prefs);
      addTearDown(controller.dispose);
      expect(controller.value, ThemeMode.system);
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        expect(await controller.select(mode), isTrue);
        final restored = AppearanceController(prefs);
        expect(restored.value, mode);
        restored.dispose();
      }
    },
  );

  testWidgets(
    'System mode follows platform and selected navigation stays legible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final dispatcher = tester.binding.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(Brightness.dark),
          home: Scaffold(
            bottomNavigationBar: AppNavigationBar(
              destinations: const [
                (label: 'Басты бет', icon: Icon(Icons.home)),
                (label: 'Инвестиции', icon: Icon(Icons.show_chart)),
              ],
              selectedIndex: 0,
              onSelected: (index) => selected = index,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final home = tester.widget<Text>(find.text('Басты бет'));
      expect(home.style?.color, const Color(0xFF8FD1B1));
      expect(
        Theme.of(
          tester.element(find.text('Басты бет')),
        ).scaffoldBackgroundColor.toARGB32(),
        0xFF1B1C1C,
      );
      await tester.tap(find.text('Инвестиции'));
      expect(selected, 1);
    },
  );

  testWidgets(
    'editor sheet remains scrollable on a compact keyboard viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            appBar: const EditorialHeader(title: Text('Настройки')),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEditorSheet<void>(
                  context: context,
                  builder: (context) => EditorSheet(
                    title: const Text('Ай сайынғы бюджет'),
                    content: const TextField(),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Сақтау'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5000');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final save = find.text('Сақтау');
      await tester.ensureVisible(save);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(360));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(EditorSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark glass omits the colored rim in standard contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: const Scaffold(body: GlassSurface(child: Text('Glass'))),
      ),
    );
    final box = find.descendant(
      of: find.byType(GlassSurface),
      matching: find.byType(DecoratedBox),
    );
    expect(
      (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).border,
      isNull,
    );
  });

  testWidgets('high contrast disables the glass blur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const Scaffold(body: GlassSurface(child: Text('Control'))),
        ),
      ),
    );
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
  });
}
