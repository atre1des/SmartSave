import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';

import '../../shared/theme.dart';
import '../../shared/glass.dart';
import 'assistant_session.dart';
import 'financial_assistant_screen.dart';

class AssistantAccessOverlay extends StatelessWidget {
  const AssistantAccessOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([appSessionActive, assistantRouteActive]),
    builder: (context, _) {
      final media = MediaQuery.of(context);
      final keyboardOpen = media.viewInsets.bottom > 0;
      final isActive = appSessionActive.value && !assistantRouteActive.value;
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (isActive && !keyboardOpen)
            Positioned(
              right: 16,
              bottom: 96 + media.padding.bottom,
              child: SafeArea(
                child: Semantics(
                  label: context.l10n.openFinanceAssistant,
                  button: true,
                  child: GlassSurface(
                    radius: 28,
                    child: FloatingActionButton.extended(
                      key: const ValueKey('assistantBubble'),
                      heroTag: 'smartSaveAssistantBubble',
                      onPressed: () {
                        assistantRouteActive.value = true;
                        appNavigatorKey.currentState
                            ?.push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const FinancialAssistantScreen(),
                              ),
                            )
                            .whenComplete(() {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                assistantRouteActive.value = false;
                              });
                            });
                      },
                      backgroundColor: Colors.transparent,
                      foregroundColor: context.colors.action,
                      elevation: 0,
                      highlightElevation: 0,
                      shape: const StadiumBorder(),
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(context.l10n.askSmartSaveShort),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
