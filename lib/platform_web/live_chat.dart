part of 'workspace.dart';

class _Chat extends StatefulWidget {
  const _Chat({this.repository});
  final WebFinanceRepository? repository;

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _drafts = <int, List<String>>{};
  int _thread = 0;
  bool _beginner = true;

  final _historyRows = <CloudRow>[];
  final _messages = <AIMessage>[];
  CloudRow? _selected;
  OpenRouterProvider? _provider;
  StreamIterator<AIStreamChunk>? _stream;
  bool _busy = false;
  bool _ready = false;
  bool? _reachable;
  String? _error;
  Future<void> Function()? _pendingSave;

  bool get _live => widget.repository != null;
  bool get _active => mounted && (widget.repository?.active ?? false);

  @override
  void initState() {
    super.initState();
    final repository = widget.repository;
    if (repository == null) return;
    _provider = OpenRouterProvider(
      baseUrl: const bool.fromEnvironment('SMARTSAVE_WEB_EMULATORS')
          ? 'http://127.0.0.1:8612'
          : null,
      currentUser: () => repository.active ? repository.auth.currentUser : null,
    );
    unawaited(_loadHistory());
    unawaited(
      _provider!.checkBackendHealth().then((reachable) {
        if (_active) setState(() => _reachable = reachable);
      }),
    );
  }

  Future<bool> _loadHistory() async {
    try {
      final rows = await widget.repository!.list('webConversations');
      if (!_active) return false;
      rows.sort(
        (a, b) => (b.data['updatedAt']?.toString() ?? '').compareTo(
          a.data['updatedAt']?.toString() ?? '',
        ),
      );
      setState(() {
        if (!_ready) _error = null;
        _ready = true;
        _historyRows
          ..clear()
          ..addAll(rows);
      });
      return true;
    } catch (_) {
      if (_active) setState(() => _error = _webUnavailable(context));
      return false;
    }
  }

  Future<void> _send() async {
    if (!_live) {
      _saveDraft();
      return;
    }
    final text = _input.text.trim();
    if (!_active ||
        !_ready ||
        _busy ||
        _pendingSave != null ||
        text.isEmpty ||
        text.length > 8000) {
      return;
    }
    final repository = widget.repository!;
    final previous = List<AIMessage>.of(_messages);
    final history = previous.length > 20
        ? previous.sublist(previous.length - 20)
        : previous;
    final userMessage = AIMessage(role: 'user', content: text);
    final selected = _selected;
    final language = Localizations.localeOf(context).languageCode;
    final rateNotice = context.l10n.aiRateLimit;
    final instructions = AIMessage(
      role: 'system',
      content:
          'You are SmartSave, an educational financial assistant. Do not claim access to live markets or account data. Reply in language code $language. Explain at ${_beginner ? 'beginner' : 'experienced'} level.',
    );
    setState(() {
      _busy = true;
      _error = null;
      _messages.add(userMessage);
    });
    _input.clear();
    _scrollToBottom();
    final stream = StreamIterator(
      _provider!.sendMessageStream(
        messages: [instructions, ...history, userMessage],
      ),
    );
    _stream = stream;
    final reply = StringBuffer();
    try {
      var completed = false;
      while (await stream.moveNext()) {
        if (!_active) return;
        final chunk = stream.current;
        if (chunk.error != null) {
          final error = chunk.isRateLimitError
              ? '$rateNotice${chunk.retryAfterSeconds == null ? '' : ' (${chunk.retryAfterSeconds}s)'}'
              : chunk.error!;
          throw StateError(error);
        }
        if (chunk.content.isNotEmpty) {
          reply.write(chunk.content);
          if (reply.length > 20000) throw WebDataIssue.invalid;
          final partial = AIMessage(
            role: 'assistant',
            content: reply.toString(),
          );
          setState(() {
            if (_messages.length > previous.length + 1) _messages.removeLast();
            _messages.add(partial);
          });
          _scrollToBottom();
        }
        completed = chunk.isDone;
      }
      if (!completed || reply.isEmpty) throw WebDataIssue.unavailable;
      final transcript = jsonEncode(
        _messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      );
      if (transcript.length > 95000) throw WebDataIssue.invalid;
      final operation = repository.operationId();
      final title =
          selected?.data['title'] as String? ??
          String.fromCharCodes(text.runes.take(60));
      _pendingSave = () async {
        await repository.save('webConversations', operation, selected, {
          'title': title,
          'transcript': transcript,
        });
        if (!_active) return;
        final id = selected?.id ?? operation;
        if (!await _loadHistory()) throw WebDataIssue.unavailable;
        if (!_active) return;
        final current = _historyRows.where((row) => row.id == id).firstOrNull;
        if (current == null) throw WebDataIssue.unavailable;
        setState(() {
          _selected = current;
          _pendingSave = null;
          _error = null;
        });
      };
      await _pendingSave!();
    } catch (error) {
      if (!_active) return;
      setState(() {
        if (_pendingSave == null) {
          _messages
            ..clear()
            ..addAll(previous);
          _input.text = text;
        }
        _error = error is StateError
            ? error.message.toString()
            : _writeNotice(context, error);
      });
    } finally {
      await stream.cancel();
      if (_active) {
        setState(() {
          _busy = false;
          _stream = null;
        });
      }
    }
  }

  Future<void> _retrySave() async {
    final save = _pendingSave;
    if (_busy || save == null || !_active) return;
    setState(() => _busy = true);
    try {
      await save();
    } catch (error) {
      if (_active) setState(() => _error = _writeNotice(context, error));
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  @override
  void dispose() {
    _provider?.dispose();
    unawaited(_stream?.cancel());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _saveDraft() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => (_drafts[_thread] ??= []).add(text));
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        !{
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
        }.contains(event.logicalKey) ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        (_input.value.isComposingRangeValid &&
            !_input.value.composing.isCollapsed)) {
      return KeyEventResult.ignored;
    }
    unawaited(_send());
    return KeyEventResult.handled;
  }

  void _selectThread(int thread) {
    if (_live) {
      if (_busy || _pendingSave != null) return;
      final selected = thread < 0 ? null : _historyRows[thread];
      try {
        final messages = selected == null
            ? <AIMessage>[]
            : (jsonDecode(selected.data['transcript'] as String) as List).map((
                record,
              ) {
                final role = record['role'] as String;
                if (role != 'user' && role != 'assistant') {
                  throw const FormatException();
                }
                return AIMessage(
                  role: role,
                  content: record['content'] as String,
                );
              }).toList();
        setState(() {
          _selected = selected;
          _messages
            ..clear()
            ..addAll(messages);
          _error = null;
          _input.clear();
        });
        _scrollToBottom();
      } catch (_) {
        setState(() => _error = _webUnavailable(context));
      }
      return;
    }
    setState(() {
      _thread = thread;
      _input.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  List<String> _subjects(BuildContext context) => [
    _copy(context, 'Emergency fund', 'Төтенше жағдай қоры', 'Резервный фонд'),
    _copy(context, 'Monthly spending', 'Айлық шығындар', 'Ежемесячные расходы'),
  ];

  Widget _history(BuildContext context, ValueChanged<int> onSelect) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
    children: [
      _Heading(context.l10n.conversationHistory),
      const SizedBox(height: 16),
      if (_live)
        _WebAction(
          child: TextButton.icon(
            onPressed: _busy || _pendingSave != null
                ? null
                : () => onSelect(-1),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.newChat),
          ),
        ),
      for (final (index, label)
          in (_live
                  ? _historyRows
                        .map((row) => row.data['title'] as String)
                        .toList()
                  : _subjects(context))
              .indexed)
        TextButton.icon(
          onPressed: _busy || _pendingSave != null
              ? null
              : () => onSelect(index),
          icon: Icon(
            (_live ? _historyRows[index].id == _selected?.id : index == _thread)
                ? Icons.chat_bubble
                : Icons.chat_bubble_outline,
            size: 17,
          ),
          label: Text(label),
          style: TextButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            backgroundColor:
                (_live
                    ? _historyRows[index].id == _selected?.id
                    : index == _thread)
                ? context.colors.action.withValues(alpha: .10)
                : null,
          ),
        ),
    ],
  );

  Future<void> _openHistory(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _history(sheetContext, (index) {
      Navigator.of(sheetContext).pop();
      _selectThread(index);
    }),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 790;
      final title = _live ? null : _subjects(context)[_thread];
      final response = _thread == 0
          ? _copy(
              context,
              '### Your emergency fund is 70% funded\n\nYou’ve set aside **₸420,000** toward your **₸600,000** goal. With six months remaining, the monthly estimate is **₸30,000**.',
              '### Қордың 70%-ы жиналды\n\n**₸600 000** мақсатқа **₸420 000** жиналды. Алты ай қалса, ай сайын **₸30 000** жинау қажет.',
              '### Резервный фонд пополнен на 70%\n\nВы отложили **₸420 000** из **₸600 000**. Если осталось шесть месяцев, ежемесячная сумма составит **₸30 000**.',
            )
          : _copy(
              context,
              '### Spending is within the example budget\n\nRecorded expenses are **₸74,800** against a fictional budget of **₸95,000**.',
              '### Шығындар үлгі бюджеттен аспады\n\nТіркелген шығын **₸74 800**, үлгі бюджет **₸95 000**.',
              '### Расходы в пределах примерного бюджета\n\nУчтённые расходы — **₸74 800** при условном бюджете **₸95 000**.',
            );
      return Row(
        children: [
          if (wide)
            SizedBox(width: 218, child: _history(context, _selectThread)),
          if (wide) const VerticalDivider(width: 1),
          Expanded(
            key: const ValueKey('transcript'),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.assistant,
                              style: glassTitle(
                                context,
                              ).copyWith(fontSize: wide ? 38 : 27),
                              maxLines: 2,
                            ),
                          ),
                          if (!wide)
                            IconButton(
                              tooltip: context.l10n.conversationHistory,
                              onPressed: () => _openHistory(context),
                              icon: const Icon(Icons.history),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _live
                            ? (_reachable == null
                                  ? context.l10n.waiting
                                  : _reachable!
                                  ? context.l10n.proxyReachable
                                  : context.l10n.offlineMode)
                            : _copy(
                                context,
                                'Preview · AI connection disabled',
                                'Алдын ала қарау · AI байланысы өшірулі',
                                'Предпросмотр · ИИ отключён',
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          children: [
                            if (_live) ...[
                              for (final message in _messages) ...[
                                if (message.role == 'user')
                                  _ChatBubble(message.content)
                                else
                                  SelectionArea(
                                    child: MarkdownBody(
                                      data: message.content,
                                      sizedImageBuilder: (image) =>
                                          Text(image.alt ?? ''),
                                      styleSheet: MarkdownStyleSheet.fromTheme(
                                        Theme.of(context),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 18),
                              ],
                            ] else ...[
                              _ChatBubble(title!),
                              const SizedBox(height: 24),
                              _Heading(context.l10n.assistant),
                              const SizedBox(height: 7),
                              SelectionArea(
                                child: MarkdownBody(
                                  data: response,
                                  styleSheet:
                                      MarkdownStyleSheet.fromTheme(
                                        Theme.of(context),
                                      ).copyWith(
                                        p: Theme.of(context).textTheme.bodyLarge
                                            ?.copyWith(
                                              fontSize: 16,
                                              height: 1.55,
                                            ),
                                        h3: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                ),
                              ),
                              for (final draft
                                  in _drafts[_thread] ?? const <String>[]) ...[
                                const SizedBox(height: 18),
                                _ChatBubble(draft),
                              ],
                            ],
                          ],
                        ),
                      ),
                      if (constraints.maxHeight >= 465)
                        Wrap(
                          spacing: 8,
                          runSpacing: 3,
                          children: [
                            for (final subject
                                in _live
                                    ? [
                                        context.l10n.portfolioPrompt,
                                        context.l10n.comparePrompt,
                                      ]
                                    : _subjects(context))
                              ActionChip(
                                label: Text(subject),
                                onPressed: () => _input.text = subject,
                              ),
                          ],
                        ),
                      const SizedBox(height: 7),
                      GlassSurface(
                        radius: 28,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: _beginner
                                  ? context.l10n.beginnerMode
                                  : context.l10n.experiencedMode,
                              onPressed: () =>
                                  setState(() => _beginner = !_beginner),
                              icon: Icon(
                                _beginner
                                    ? Icons.school_outlined
                                    : Icons.analytics_outlined,
                              ),
                            ),
                            Expanded(
                              child: Focus(
                                canRequestFocus: false,
                                onKeyEvent: _handleKey,
                                child: TextField(
                                  controller: _input,
                                  maxLines: 4,
                                  minLines: 1,
                                  textInputAction: TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: context.l10n.askSmartSave,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                            IconButton.filled(
                              tooltip: _live
                                  ? context.l10n.sendQuestion
                                  : _copy(
                                      context,
                                      'Add preview draft',
                                      'Сынақ нобайын қосу',
                                      'Добавить черновик',
                                    ),
                              onPressed:
                                  _busy ||
                                      (_live &&
                                          (!_ready || _pendingSave != null))
                                  ? null
                                  : _send,
                              icon: const Icon(Icons.arrow_upward),
                            ),
                          ],
                        ),
                      ),
                      if (_busy) const LinearProgressIndicator(minHeight: 2),
                      if (_error != null)
                        Semantics(liveRegion: true, child: Text(_error!)),
                      if (_pendingSave != null)
                        _WebAction(
                          child: TextButton(
                            onPressed: _busy ? null : _retrySave,
                            child: Text(context.l10n.retry),
                          ),
                        ),
                      if (_live && !_ready && _error != null)
                        _WebAction(
                          child: TextButton(
                            onPressed: _loadHistory,
                            child: Text(context.l10n.retry),
                          ),
                        ),
                      if (!_live)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _copy(
                              context,
                              'Drafts stay in this tab and aren’t sent.',
                              'Нобайлар осы қойындыда қалады және жіберілмейді.',
                              'Черновики остаются в этой вкладке и не отправляются.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          context.colors.action.withValues(alpha: .13),
          context.colors.canvas,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SelectionArea(child: Text(text)),
      ),
    ),
  );
}
