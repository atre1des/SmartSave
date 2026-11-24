import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/models.dart';
import '../../ai/conversations.dart';
import '../../data/providers.dart';

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

final aiConversationsProvider = ChangeNotifierProvider<AIConversations>(
  (ref) => AIConversations(ref.watch(financeRepositoryProvider)),
);

/// Provider for the assistant conversation mode (beginner/experienced)
final assistantModeProvider = StateProvider<AssistantMode>((ref) => AssistantMode.beginner);
