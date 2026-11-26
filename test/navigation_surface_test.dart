import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/shared/theme.dart';
import 'package:smart_save/shared/widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'grouped navigation and section actions at 320 px in $brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        var rowTaps = 0;
        var sectionTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SectionHeading(
                      'Recent transactions',
                      trailing: 'View all',
                      onTrailing: () => sectionTaps++,
                    ),
                    RecordGroup(
                      padding: EdgeInsets.zero,
                      child: NavigationCell(
                        title: 'Инвестиционная аналитика',
                        detail: 'Акции и облигации',
                        icon: Icons.show_chart,
                        onTap: () => rowTaps++,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final cell = find.byType(NavigationCell);
        final chevron = find.byIcon(Icons.chevron_right_rounded);
        expect(chevron, findsOneWidget);
        expect(tester.getSize(cell).height, greaterThanOrEqualTo(44));
        expect(
          tester.getSize(find.byType(CompactAction)).height,
          greaterThanOrEqualTo(44),
        );
        expect(
          tester.getTopRight(find.byType(CompactAction)).dx,
          closeTo(tester.getTopRight(find.byType(SectionHeading)).dx, .01),
        );
        await tester.tap(chevron);
        await tester.pumpAndSettle();
        expect(rowTaps, 1);
        await tester.tap(find.text('View all'));
        await tester.pumpAndSettle();
        expect(sectionTaps, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(rowTaps + sectionTaps, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
