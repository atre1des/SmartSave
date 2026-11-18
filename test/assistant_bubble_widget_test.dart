import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/features/advice/assistant_access_overlay.dart';
import 'package:smart_save/features/advice/assistant_session.dart';
import 'package:smart_save/features/advice/financial_assistant_screen.dart';

void main() {
  testWidgets(
    'bubble opens assistant, hides there, and retains conversation',
    (tester) async {
      appSessionActive.value = true;
      assistantRouteActive.value = false;
      final container = ProviderContainer();
      addTearDown(() {
        appSessionActive.value = false;
        assistantRouteActive.value = false;
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: appNavigatorKey,
            builder: (context, child) =>
                AssistantAccessOverlay(child: child ?? const SizedBox.shrink()),
            home: Scaffold(
              body: const Center(child: Text('Home screen')),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 0,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.flag_outlined),
                    label: 'Goals',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const ValueKey('assistantBubble')), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      expect(find.byKey(const ValueKey('assistantBubble')), findsNothing);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump();
      expect(find.byKey(const ValueKey('assistantBubble')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('assistantBubble')));
      expect(assistantRouteActive.value, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(FinancialAssistantScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('SmartSave Assistant', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assistantBubble')), findsNothing);

      container.read(assistantConversationProvider.notifier).state = const [
        AssistantMessage(text: 'How is my spending?', isUser: true),
        AssistantMessage(text: 'Local demo spending summary.', isUser: false),
      ];
      await tester.pump();
      expect(
        find.text('Local demo spending summary.', skipOffstage: false),
        findsOneWidget,
      );

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Home screen'), findsOneWidget);
      expect(appSessionActive.value, isTrue);
      expect(assistantRouteActive.value, isFalse);
      expect(
        find.byKey(const ValueKey('assistantBubble'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assistantBubble')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('assistantBubble')));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('How is my spending?', skipOffstage: false),
        findsWidgets,
      );
      expect(
        find.text('Local demo spending summary.', skipOffstage: false),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
