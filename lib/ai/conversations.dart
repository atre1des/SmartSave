import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/finance_repository.dart';
import '../l10n/generated/app_localizations.dart';
import 'models.dart';

class ConversationRequest {
  ConversationRequest(this.id, this.prompt, Iterable<AIMessage> history)
    : history = List.unmodifiable(history);

  final String id;
  final String prompt;
  final List<AIMessage> history;
}

/// One transcript store and one active request per account's ProviderScope.
class AIConversations extends ChangeNotifier {
  AIConversations(this._repository) {
    unawaited(_load());
  }

  final FinanceRepository _repository;
  final Map<String, List<AIMessage>> _entries = {};
  String? _selected;
  ConversationRequest? _request;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool _writable = true;
  bool _ready = false;

  bool get ready => _ready;
  bool get busy => _request != null;
  String? get activeId => _selected;
  Iterable<MapEntry<String, List<AIMessage>>> get entries => _entries.entries;
  List<AIMessage> get messages => _entries[_selected] ?? const [];

  Future<void> _load() async {
    try {
      final raw = await _repository.assistantConversationHistory();
      if (_disposed) return;
      if (raw != null) {
        final decoded = jsonDecode(raw);
        final list = decoded is List
            ? decoded
            : (decoded as Map)['conversations'] as List;
        final restored = <String, List<AIMessage>>{};
        for (final row in list.whereType<Map<String, dynamic>>()) {
          final id = row['id'];
          final items = row['messages'];
          if (id is! String || items is! List) continue;
          restored[id] = List.unmodifiable(
            items
                .whereType<Map<String, dynamic>>()
                .map(_readMessage)
                .where(
                  (message) =>
                      (message.isUser || message.role == 'assistant') &&
                      !message.isStreaming &&
                      message.content.trim().isNotEmpty,
                ),
          );
        }
        _entries.addAll(restored);
        final active = decoded is Map
            ? decoded['activeId']
            : _entries.keys.lastOrNull;
        if (active is String && _entries.containsKey(active)) {
          _selected = active;
        }
      }
    } catch (_) {
      // An unreadable snapshot must not be overwritten.
      _writable = false;
    } finally {
      _ready = true;
      if (!_disposed) notifyListeners();
    }
  }

  AIMessage _readMessage(Map<String, dynamic> row) {
    final message = AIMessage.fromJson(row);
    if (message.role != 'assistant' || row.containsKey('isLocalFallback')) {
      return message;
    }
    final fallback =
        message.content.startsWith(
          "I'm currently unable to connect to the AI service",
        ) ||
        AppLocalizations.supportedLocales.any(
          (locale) => message.content.startsWith(
            lookupAppLocalizations(locale).aiOfflineReply,
          ),
        );
    return message.copyWith(isLocalFallback: fallback);
  }

  bool get _canEdit => ready && !busy && !_disposed;

  Future<void> select(String id) async {
    if (!_canEdit || !_entries.containsKey(id)) return;
    _selected = id;
    _changed();
    await _writes;
  }

  void startNew() {
    if (!_canEdit) return;
    _selected = null;
    _changed();
  }

  void clear() {
    if (!_canEdit || _selected == null) return;
    _entries[_selected!] = const [];
    _changed();
  }

  void delete(String id) {
    if (!_canEdit) return;
    _entries.remove(id);
    if (_selected == id) _selected = null;
    _changed();
  }

  ConversationRequest? begin(String prompt, {bool retry = false}) {
    if (!_canEdit || prompt.trim().isEmpty) return null;
    final prior = messages;
    if (retry &&
        (prior.isEmpty || !prior.last.isUser || prior.last.content != prompt)) {
      return null;
    }

    final id = _selected ?? 'conv_${DateTime.now().microsecondsSinceEpoch}';
    final history = retry ? prior.take(prior.length - 1) : prior;
    final request = ConversationRequest(id, prompt, history);
    _request = request;
    _selected = id;
    if (!retry) {
      _entries[id] = List.unmodifiable([...prior, AIMessage.user(prompt)]);
    }
    _changed();
    return request;
  }

  Future<void> finish(ConversationRequest request, {AIMessage? reply}) async {
    if (_disposed || !identical(_request, request)) return;
    if (reply != null) {
      _entries[request.id] = List.unmodifiable([
        ..._entries[request.id]!,
        reply,
      ]);
      _save();
    }
    await _writes;
    if (_disposed || !identical(_request, request)) return;
    _request = null;
    notifyListeners();
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  void _save() {
    if (_writable) {
      final snapshot = jsonEncode({
        'activeId': _selected,
        'conversations': [
          for (final entry in _entries.entries)
            {
              'id': entry.key,
              'messages': entry.value
                  .map((message) => message.toJson())
                  .toList(),
            },
        ],
      });
      _writes = _writes.then((_) async {
        try {
          if (!_disposed) {
            await _repository.saveAssistantConversationHistory(snapshot);
          }
        } catch (_) {
          debugPrint('[AIConversations] Could not save conversation history');
        }
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
