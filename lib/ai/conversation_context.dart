import 'dart:convert';

import 'models.dart';

/// Bounds UTF-8 input separately from the provider's output-token allowance.
class ConversationContext {
  const ConversationContext({
    this.inputBytes = const int.fromEnvironment(
      'SMARTSAVE_AI_INPUT_BYTES',
      defaultValue: 14000,
    ),
  });

  final int inputBytes;

  List<AIMessage> build({
    required String systemPrompt,
    required String financialContext,
    required Iterable<AIMessage> history,
    required String prompt,
  }) {
    final budget = inputBytes.clamp(10000, 20000);
    final system = AIMessage.system(
      '$systemPrompt\n\nUser financial context:\n${_bounded(financialContext, 3000)}',
    );
    final available = budget - _cost(system);
    final latest = AIMessage.user(
      _bounded(prompt, (available - 32).clamp(0, 5000)),
    );
    var remaining = available - _cost(latest);
    final previous = history.toList(growable: false);
    final turns = <(AIMessage, AIMessage)>[];

    for (var i = previous.length - 1; i > 0; i--) {
      final assistant = previous[i];
      final user = previous[i - 1];
      if (assistant.role != 'assistant' ||
          assistant.isLocalFallback ||
          assistant.isStreaming ||
          assistant.error != null ||
          assistant.content.trim().isEmpty ||
          !user.isUser ||
          user.isStreaming ||
          user.error != null ||
          user.content.trim().isEmpty) {
        continue;
      }
      final cost = _cost(user) + _cost(assistant);
      if (cost > remaining) break;
      turns.add((user, assistant));
      remaining -= cost;
      i--;
    }
    return [
      system,
      for (final (user, reply) in turns.reversed) ...[user, reply],
      latest,
    ];
  }

  int _cost(AIMessage message) => utf8.encode(message.content).length + 32;

  String _bounded(String text, int maxBytes) {
    final bytes = utf8.encode(text);
    if (bytes.length <= maxBytes) return text;
    const marker = '\n[truncated]';
    var end = maxBytes - marker.length;
    if (end <= 0) return '';
    while ((bytes[end] & 0xc0) == 0x80) {
      end--;
    }
    return '${utf8.decode(bytes.sublist(0, end))}$marker';
  }
}
