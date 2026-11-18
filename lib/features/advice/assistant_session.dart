import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/models.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appSessionActive = ValueNotifier<bool>(false);
final assistantRouteActive = ValueNotifier<bool>(false);

class AssistantMessage {
  const AssistantMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

final assistantConversationProvider = StateProvider<List<AssistantMessage>>(
  (ref) => const [],
);

/// Provider for the AI-powered assistant conversation (uses AIMessage with role, content, etc.)
final assistantAIConversationProvider = StateProvider<List<AIMessage>>(
  (ref) => const [],
);

/// Provider for the assistant conversation mode (beginner/experienced)
final assistantModeProvider = StateProvider<AssistantMode>((ref) => AssistantMode.beginner);
