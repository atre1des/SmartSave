import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_assistant_service.dart';
import '../../ai/models.dart';
import '../../ai/streaming_markdown.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../invest/investment_intelligence_screen.dart';
import 'advice_screens.dart';
import 'assistant_session.dart';

// Diagnostic flag - set to true to enable verbose layout logging
const bool kDebugLayout = true;

/// Backend connectivity status for the AI assistant
enum BackendStatus { unknown, checking, connected, disconnected }

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  bool _isStreaming = false;
  bool _isScrolling = false;
  String _streamingContent = '';
  AssistantMode _mode = AssistantMode.beginner;
  bool _showModeSelector = true;
  SmartSaveAIAssistantService? _assistantService;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _currentConversationId;
  final Map<String, List<AIMessage>> _conversations = {};

  // Backend connectivity status
  BackendStatus _backendStatus = BackendStatus.unknown;

  // Error state for the last failed request
  String? _lastError;
  bool _isRateLimitError = false;
  bool _isDailyQuotaExhausted = false;


  static const _quickActions = [
    QuickAction(
      type: QuickActionType.savingsGoal,
      title: 'Help me reach a savings goal',
      description: 'Create a plan with monthly targets',
      prefillPrompt:
          'I want to save for a goal. Help me create a realistic plan with monthly targets.',
    ),
    QuickAction(
      type: QuickActionType.explainOpportunity,
      title: 'Explain an investment opportunity',
      description: 'Understand risks, returns, and how it works',
      prefillPrompt:
          'Explain how a bank deposit differs from buying shares, in simple terms.',
    ),
    QuickAction(
      type: QuickActionType.compareDepositShares,
      title: 'Compare a deposit and shares',
      description: 'Side-by-side with risks and scenarios',
      prefillPrompt:
          'Compare putting KZT 500,000 in a 3-year deposit vs. investing in shares for 3 years. Show upside and downside scenarios.',
    ),
    QuickAction(
      type: QuickActionType.analyzePortfolio,
      title: 'Analyze my portfolio',
      description: 'Review holdings, sensitivities, and scenarios',
      prefillPrompt:
          'Analyze my current portfolio holdings and suggest what to review.',
    ),
    QuickAction(
      type: QuickActionType.exploreIPO,
      title: 'Explore an IPO',
      description: 'Learn about upcoming offerings and process',
      prefillPrompt:
          'What IPOs are currently available in Kazakhstan and how do they work?',
    ),
    QuickAction(
      type: QuickActionType.whatIfScenario,
      title: 'Show me what happens if I invest',
      description: 'Scenario analysis for a specific amount',
      prefillPrompt:
          'What would happen if I invested KZT 100,000 in shares vs. a deposit over 2 years?',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _assistantService = SmartSaveAIAssistantService(
      ref.read(financeRepositoryProvider),
    );
    // Load saved mode from session
    _mode = ref.read(assistantModeProvider);
    _loadConversationHistory();
    // Check backend connectivity
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    if (_assistantService == null) return;
    setState(() => _backendStatus = BackendStatus.checking);
    final isHealthy = await _assistantService!.isAvailable;
    if (mounted) {
      setState(
        () => _backendStatus = isHealthy
            ? BackendStatus.connected
            : BackendStatus.disconnected,
      );
    }
  }

  Future<void> _loadConversationHistory() async {
    final repository = ref.read(financeRepositoryProvider);
    String? json;
    try {
      json = await repository.assistantConversationHistory();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      for (final item in decoded) {
        final id = item['id'] as String;
        final messages = (item['messages'] as List<dynamic>)
            .map(
              (m) => AIMessage(
                role: m['role'] as String? ?? '',
                content: m['text'] as String? ?? '',
                isStreaming: m['isStreaming'] as bool? ?? false,
                error: m['error'] as String?,
              ),
            )
            .toList();
        _conversations.putIfAbsent(id, () => messages);
      }
    }
    setState(() {
      _currentConversationId ??=
          _conversations.isEmpty ? null : _conversations.keys.last;
    });
  }

  Future<void> _saveConversations() async {
    final repository = ref.read(financeRepositoryProvider);
    final encoded = jsonEncode(
      _conversations.entries
          .map(
            (entry) => {
              'id': entry.key,
              'updatedAt': DateTime.now().toIso8601String(),
              'messages': entry.value.map((m) => m.toJson()).toList(),
            },
          )
          .toList(),
    );
    try {
      await repository.saveAssistantConversationHistory(encoded);
    } catch (_) {
      if (mounted) debugPrint('[AIAssistantScreen] Could not save conversation history');
    }
  }

  void _startNewConversation() {
    _currentConversationId = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    _conversations[_currentConversationId!] = const [];
    ref.read(assistantAIConversationProvider.notifier).state = const [];
    _saveConversations();
    _scaffoldKey.currentState?.closeDrawer();
    setState(() => _showModeSelector = true);
  }

  void _selectConversation(String id) {
    final messages = _conversations[id];
    if (messages != null) {
      _currentConversationId = id;
      ref.read(assistantAIConversationProvider.notifier).state = messages;
      _scaffoldKey.currentState?.closeDrawer();
      setState(() => _showModeSelector = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    _assistantService?.dispose();
    super.dispose();
  }

  void _openFeature(Widget page) {
    assistantRouteActive.value = false;
    Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page))
        .whenComplete(() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) assistantRouteActive.value = true;
          });
        });
  }

  void _scrollToEnd() {
    // Guard against duplicate scroll animations and unmounted/detached state
    if (_isScrolling || !mounted || !_scrollController.hasClients) return;

    if (kDebugLayout) {
      debugPrint(
        '[AIAssistantScreen] _scrollToEnd: currentOffset=${_scrollController.offset.toStringAsFixed(1)}, '
        'maxScrollExtent=${_scrollController.position.maxScrollExtent.toStringAsFixed(1)}, '
        'viewportDimension=${_scrollController.position.viewportDimension.toStringAsFixed(1)}',
      );
    }

    _isScrolling = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _isScrolling = false;
        return;
      }
      _scrollController
          .animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (mounted) {
              _isScrolling = false;
              if (kDebugLayout) {
                debugPrint(
                  '[AIAssistantScreen] _scrollToEnd complete: newOffset=${_scrollController.offset.toStringAsFixed(1)}',
                );
              }
            }
          });
    });
  }

  Future<void> _send([String? suggestedPrompt]) async {
    final prompt = (suggestedPrompt ?? _input.text).trim();
    if (prompt.isEmpty || _isStreaming) return;

    debugPrint('[AIAssistantScreen] ===== SEND STARTED =====');

    // Clear previous error state
    setState(() {
      _lastError = null;
      _isRateLimitError = false;
      _isDailyQuotaExhausted = false;
    });

    // Start new conversation if needed
    if (_currentConversationId == null) {
      debugPrint('[AIAssistantScreen] Starting new conversation');
      _startNewConversation();
    }

    _input.clear();
    final conversationProvider = ref.read(
      assistantAIConversationProvider.notifier,
    );

    // Add user message
    final userMessage = AIMessage.user(prompt);
    conversationProvider.state = [...conversationProvider.state, userMessage];

    setState(() {
      _isStreaming = true;
      _streamingContent = '';
      _showModeSelector = false;
    });
    _scrollToEnd();

    await _streamResponse(prompt);
  }

  /// Runs the assistant stream for [prompt] against the current conversation.
  ///
  /// Called by [_send] (after appending the user message) and by
  /// [_retryLastMessage] (which reuses the existing user message, so no
  /// duplicate is created).
  Future<void> _streamResponse(String prompt) async {
    final conversationNotifier = ref.read(
      assistantAIConversationProvider.notifier,
    );

    try {
      await for (final chunk in _assistantService!.sendMessageStream(prompt)) {
        if (!mounted) {
          debugPrint('[AIAssistantScreen] Not mounted, returning');
          return;
        }

        debugPrint(
          '[AIAssistantScreen] Received chunk: isDone=${chunk.isDone}, contentLength=${chunk.content.length}, hasError=${chunk.error != null}',
        );

        if (chunk.isDone) {
          if (chunk.error != null) {
            // Remove the temporary empty assistant message, if present.
            final currentMessages = ref.read(assistantAIConversationProvider);
            if (currentMessages.isNotEmpty &&
                currentMessages.last.role == 'assistant' &&
                currentMessages.last.isStreaming) {
              conversationNotifier.state =
                  currentMessages.take(currentMessages.length - 1).toList();
              debugPrint(
                '[AIAssistantScreen] Removed empty streaming assistant message after error',
              );
            }
            // Store error state for UI display.
            setState(() {
              _lastError = chunk.error;
              _isRateLimitError = chunk.isRateLimitError;
              _isDailyQuotaExhausted = chunk.isDailyQuotaExhausted;
            });
          } else {
            debugPrint(
              '[AIAssistantScreen] Stream completed successfully, finalizing message',
            );
            debugPrint(
              '[AIAssistantScreen] Final streaming content length: ${_streamingContent.length}',
            );

            // Guard against a successful completion with no content: treat it
            // as an error rather than persisting an empty assistant message.
            if (_streamingContent.trim().isEmpty) {
              debugPrint(
                '[AIAssistantScreen] Stream completed with empty content; treating as error',
              );
              final currentMessages = ref.read(
                assistantAIConversationProvider,
              );
              if (currentMessages.isNotEmpty &&
                  currentMessages.last.role == 'assistant' &&
                  currentMessages.last.isStreaming) {
                conversationNotifier.state =
                    currentMessages.take(currentMessages.length - 1).toList();
              }
              setState(() {
                _lastError =
                    'The AI service returned an empty response. Please try again.';
                _isRateLimitError = false;
                _isDailyQuotaExhausted = false;
              });
              break;
            }

            // Preserve all previous messages, replace the streaming assistant
            // message with the final content.
            final currentMessages = ref.read(assistantAIConversationProvider);
            if (currentMessages.isNotEmpty &&
                currentMessages.last.role == 'assistant' &&
                currentMessages.last.isStreaming) {
              conversationNotifier.state = [
                ...currentMessages.take(currentMessages.length - 1),
                currentMessages.last.copyWith(
                  content: _streamingContent,
                  isStreaming: false,
                ),
              ];
            } else {
              conversationNotifier.state = [
                ...currentMessages,
                AIMessage.assistant(_streamingContent, isStreaming: false),
              ];
            }
            debugPrint(
              '[AIAssistantScreen] After finalizing, messages count: ${ref.read(assistantAIConversationProvider).length}',
            );
          }
          break;
        }

        _streamingContent += chunk.content;

        final currentMessages = ref.read(assistantAIConversationProvider);
        if (currentMessages.isNotEmpty &&
            currentMessages.last.role == 'assistant' &&
            currentMessages.last.isStreaming) {
          conversationNotifier.state = [
            ...currentMessages.take(currentMessages.length - 1),
            currentMessages.last.copyWith(
              content: _streamingContent,
              isStreaming: true,
            ),
          ];
        } else {
          conversationNotifier.state = [
            ...currentMessages,
            AIMessage.assistant(_streamingContent, isStreaming: true),
          ];
        }
        _scrollToEnd();
      }
    } finally {
      if (mounted) {
        debugPrint('[AIAssistantStream] Finally block - saving conversation');
        if (_currentConversationId != null) {
          _conversations[_currentConversationId!] =
              ref.read(assistantAIConversationProvider);
          _saveConversations();
          debugPrint(
            '[AIAssistantScreen] Conversation saved, ID: $_currentConversationId',
          );
        }
        setState(() => _isStreaming = false);
        _scrollToEnd();
      }
    }
  }

  void _retryLastMessage() {
    if (_isStreaming) return;
    final messages = ref.read(assistantAIConversationProvider);
    if (messages.isEmpty) return;
    final lastUserMsg = messages.where((m) => m.isUser).lastOrNull;
    if (lastUserMsg == null) return;

    // Clear previous error state
    setState(() {
      _lastError = null;
      _isRateLimitError = false;
      _isDailyQuotaExhausted = false;
    });

    setState(() {
      _isStreaming = true;
      _streamingContent = '';
      _showModeSelector = false;
    });
    _scrollToEnd();

    // Re-run the stream for the existing user message WITHOUT re-adding it,
    // so retry never duplicates the user message.
    _streamResponse(lastUserMsg.text);
  }

  void _clearConversation() {
    // Clear only the active conversation, keep other stored conversations
    if (_currentConversationId != null) {
      _conversations[_currentConversationId!] = const [];
      _saveConversations();
    }
    ref.read(assistantAIConversationProvider.notifier).state = const [];
    setState(() => _showModeSelector = true);
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == AssistantMode.beginner
          ? AssistantMode.experienced
          : AssistantMode.beginner;
    });
    ref.read(assistantModeProvider.notifier).state = _mode;
    _assistantService!.setMode(_mode);
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.firefly,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.mint, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SmartSave Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Choose what you want to explore',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Fixed entries
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('New Chat'),
              subtitle: const Text('Start a fresh conversation'),
              onTap: _startNewConversation,
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Thesis Autopsy'),
              subtitle: const Text('Record and test investment reasoning'),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _openFeature(const InvestmentIntelligenceScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.waves_outlined),
              title: const Text('Liquidity'),
              subtitle: const Text('Test order size against volume'),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _openFeature(const InvestmentIntelligenceScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline_outlined),
              title: const Text('Economic Ripple'),
              subtitle: const Text('Simulate macro shocks'),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _openFeature(const InvestmentIntelligenceScreen());
              },
            ),

            const Divider(height: 16),

            // Recent Chats
            if (_conversations.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Recent Chats',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: _conversations.entries.map((entry) {
                          final firstUserMsg = entry.value
                              .where((m) => m.isUser)
                              .firstOrNull;
                          final title = firstUserMsg?.text ?? 'Untitled';
                          final preview = title.length > 30
                              ? '${title.substring(0, 30)}...'
                              : title;
                          return ListTile(
                            dense: true,
                            title: Text(
                              preview,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              onPressed: () {
                                setState(() {
                                  _conversations.remove(entry.key);
                                  if (_currentConversationId == entry.key) {
                                    _currentConversationId = null;
                                    ref
                                            .read(
                                              assistantAIConversationProvider
                                                  .notifier,
                                            )
                                            .state =
                                        const [];
                                  }
                                });
                                _saveConversations();
                              },
                            ),
                            onTap: () => _selectConversation(entry.key),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(assistantAIConversationProvider);
    final isConnected = _backendStatus == BackendStatus.connected;
    final isChecking = _backendStatus == BackendStatus.checking;

    debugPrint(
      '[AIAssistantScreen] build() called, messages count: ${messages.length}',
    );
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      debugPrint(
        '[AIAssistantScreen] build: Message $i: role=${m.role}, contentLength=${m.content.length}, isStreaming=${m.isStreaming}, hasError=${m.error != null}',
      );
    }
    debugPrint(
      '[AIAssistantScreen] _isStreaming=$_isStreaming, _streamingContent length=${_streamingContent.length}, _showModeSelector=$_showModeSelector',
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('SmartSave Assistant'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          // AI status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.mintLight : AppColors.paleGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isChecking)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      )
                    else
                      Icon(
                        isConnected ? Icons.cloud_done : Icons.cloud_off,
                        size: 14,
                        color: isConnected ? AppColors.success : AppColors.gold,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      isChecking
                          ? 'Checking...'
                          : isConnected
                          ? 'AI Connected'
                          : 'Offline Mode',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isConnected ? AppColors.success : AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Open a SmartSave feature',
            onSelected: (value) {
              final page = switch (value) {
                'investment' => const InvestmentIntelligenceScreen(),
                'advice' => const RecommendationsScreen(),
                'thesis' =>
                  const InvestmentIntelligenceScreen(), // Will navigate to thesis tab
                'liquidity' =>
                  const InvestmentIntelligenceScreen(), // Will navigate to liquidity tab
                'ripple' =>
                  const InvestmentIntelligenceScreen(), // Will navigate to ripple tab
                _ => const InvestmentIntelligenceScreen(),
              };
              _openFeature(page);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'investment',
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Investment Intelligence'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'thesis',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Thesis Autopsy'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'liquidity',
                child: Row(
                  children: [
                    Icon(Icons.waves_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Liquidity Analysis'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ripple',
                child: Row(
                  children: [
                    Icon(Icons.timeline_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Economic Ripple'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'advice',
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Recommendations'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Clear Conversation'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Disclaimer banner
            _DisclaimerBanner(isConnected: isConnected),

            // Mode selector (shown initially)
            if (_showModeSelector && messages.isEmpty)
              _ModeSelector(currentMode: _mode, onToggle: _toggleMode),

            // Quick actions (shown initially)
            if (_showModeSelector && messages.isEmpty)
              _QuickActionsSection(actions: _quickActions, onSelect: _send),

            // Chat messages
            Expanded(
              child: messages.isEmpty && !_showModeSelector
                  ? _EmptyState(onClear: _clearConversation)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (kDebugLayout) {
                          debugPrint(
                            '[AIAssistantScreen] ListView constraints: maxWidth=${constraints.maxWidth}, '
                            'maxHeight=${constraints.maxHeight}, hasBoundedHeight=${constraints.maxHeight.isFinite}, '
                            'hasBoundedWidth=${constraints.maxWidth.isFinite}, '
                            'itemCount=${messages.length + (_isStreaming ? 1 : 0)}, '
                            'scrollOffset=${_scrollController.hasClients ? _scrollController.offset.toStringAsFixed(1) : "N/A"}, '
                            'maxScrollExtent=${_scrollController.hasClients ? _scrollController.position.maxScrollExtent.toStringAsFixed(1) : "N/A"}',
                          );
                        }
                        return messages.isEmpty && !_showModeSelector
                            ? _EmptyState(onClear: _clearConversation)
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  18,
                                ),
                                itemCount:
                                    messages.length + (_isStreaming ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (_isStreaming &&
                                      index == messages.length) {
                                    return _StreamingBubble(
                                      content: _streamingContent,
                                    );
                                  }
                                  return _MessageBubble(
                                    message: messages[index],
                                  );
                                },
                              );
                      },
                    ),
            ),

            // Error state for last failed message
            if (messages.isNotEmpty && messages.last.error != null)
              _ErrorBanner(
                error: messages.last.error!,
                onRetry: _retryLastMessage,
              )
            else if (_lastError != null)
              _ErrorBanner(
                error: _lastError!,
                onRetry: _retryLastMessage,
                isRateLimitError: _isRateLimitError,
                isDailyQuotaExhausted: _isDailyQuotaExhausted,
              ),

            // Composer
            _Composer(
              controller: _input,
              onSend: _send,
              busy: _isStreaming,
              mode: _mode,
              onModeToggle: _toggleMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
    color: isConnected ? AppColors.mintLight : AppColors.paleGold,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isConnected ? Icons.info_outline : Icons.warning_amber_rounded,
          color: isConnected ? AppColors.firefly : AppColors.gold,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isConnected
                ? 'SmartSave provides educational information and scenario-based analysis, not guaranteed outcomes. Investments can lose value. Verify current terms and make decisions at your own risk.'
                : 'Running in offline mode (backend unavailable). Responses use local rules only. Start backend server to enable AI. Educational info only — not financial advice.',
            style: TextStyle(
              color: isConnected ? AppColors.firefly : AppColors.gold,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.currentMode, required this.onToggle});
  final AssistantMode currentMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you like to proceed?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your experience level — you can switch anytime.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.school_outlined,
                title: 'I\'m new to investing',
                description:
                    'Explain concepts step by step. Ask questions. Build understanding.',
                selected: currentMode == AssistantMode.beginner,
                onTap: onToggle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                icon: Icons.analytics_outlined,
                title: 'I understand investing',
                description:
                    'Concise analysis, scenarios, comparisons, thesis monitoring.',
                selected: currentMode == AssistantMode.experienced,
                onTap: onToggle,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.firefly : Colors.white,
        border: Border.all(
          color: selected ? AppColors.firefly : AppColors.border,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: selected ? Colors.white : AppColors.firefly,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.firefly,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: selected ? Colors.white70 : AppColors.muted,
              height: 1.3,
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({required this.actions, required this.onSelect});
  final List<QuickAction> actions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions
              .map(
                (action) => _QuickActionChip(
                  action: action,
                  onTap: () => onSelect(action.prefillPrompt ?? action.title),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.action, required this.onTap});
  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(_iconForAction(action.type), size: 16),
    label: Text(action.title, style: const TextStyle(fontSize: 12)),
    onPressed: onTap,
    backgroundColor: AppColors.mintLight,
    side: BorderSide(color: AppColors.border),
  );

  IconData _iconForAction(QuickActionType type) {
    switch (type) {
      case QuickActionType.savingsGoal:
        return Icons.flag_outlined;
      case QuickActionType.explainOpportunity:
        return Icons.lightbulb_outline;
      case QuickActionType.compareDepositShares:
        return Icons.compare_arrows_outlined;
      case QuickActionType.analyzePortfolio:
        return Icons.pie_chart_outline;
      case QuickActionType.exploreIPO:
        return Icons.trending_up_outlined;
      case QuickActionType.whatIfScenario:
        return Icons.calculate_outlined;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    children: [
      const Icon(
        Icons.auto_awesome_rounded,
        size: 38,
        color: AppColors.firefly,
      ),
      const SizedBox(height: 12),
      Text(
        'What would you like to understand?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      const Text(
        'Ask about your spending, budgets, goals, investments, or explore opportunities.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Show mode selector'),
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AIMessage message;

  @override
  Widget build(BuildContext context) {
    if (kDebugLayout) {
      debugPrint(
        '[MessageBubble] build: role=${message.role}, contentLength=${message.text.length}, '
        'isStreaming=${message.isStreaming}, hasError=${message.error != null}, '
        'availableWidth=${(MediaQuery.sizeOf(context).width * 0.84).toStringAsFixed(1)}, '
        'messageEmpty=${message.text.isEmpty}',
      );
    }
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (kDebugLayout) {
            debugPrint(
              '[MessageBubble] layout constraints: maxWidth=${constraints.maxWidth.toStringAsFixed(1)}, '
              'maxHeight=${constraints.maxHeight.toStringAsFixed(1)}, '
              'hasBoundedWidth=${constraints.maxWidth.isFinite}, '
              'hasBoundedHeight=${constraints.maxHeight.isFinite}',
            );
          }
          return Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .84,
              maxHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : double.infinity,
            ),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: message.isUser ? AppColors.firefly : Colors.white,
              border: message.isUser
                  ? null
                  : Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: message.isUser
                ? SelectableText(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : AppColors.firefly,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  )
                : BufferedStreamingMarkdown(
                    content: message.text,
                    isStreaming: message.isStreaming,
                    selectable: true,
                    styleSheet: _assistantMarkdownStyleSheet(context),
                    onTapLink: (url, title, text) {
                    },
                  ),
          );
        },
      ),
    );
  }
}

MarkdownStyleSheet _assistantMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.firefly,
      height: 1.5,
      fontSize: 13,
    ),
    h1: theme.textTheme.headlineSmall?.copyWith(
      color: AppColors.firefly,
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ),
    h2: theme.textTheme.titleLarge?.copyWith(
      color: AppColors.firefly,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    h3: theme.textTheme.titleMedium?.copyWith(
      color: AppColors.firefly,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
    strong: theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.firefly,
      fontWeight: FontWeight.w700,
    ),
    em: theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.firefly,
      fontStyle: FontStyle.italic,
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.firefly,
      height: 1.5,
      fontSize: 13,
    ),
    listBulletPadding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
    listIndent: 18,
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.muted,
      fontStyle: FontStyle.italic,
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: AppColors.mint, width: 3)),
    ),
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      backgroundColor: AppColors.mintLight,
      color: AppColors.firefly,
    ),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    a: theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.prussianBlue,
      decoration: TextDecoration.underline,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border, width: 1)),
    ),
  );
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    if (kDebugLayout) {
      debugPrint(
        '[StreamingBubble] build: contentLength=${content.length}, '
        'availableWidth=${(MediaQuery.sizeOf(context).width * 0.84).toStringAsFixed(1)}, '
        'contentEmpty=${content.isEmpty}',
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (kDebugLayout) {
            debugPrint(
              '[StreamingBubble] layout constraints: maxWidth=${constraints.maxWidth.toStringAsFixed(1)}, '
              'maxHeight=${constraints.maxHeight.toStringAsFixed(1)}, '
              'hasBoundedWidth=${constraints.maxWidth.isFinite}, '
              'hasBoundedHeight=${constraints.maxHeight.isFinite}',
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .84,
                maxHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : double.infinity,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .84,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BufferedStreamingMarkdown(
                      content: content,
                      isStreaming: true,
                      selectable: true,
                      styleSheet: _assistantMarkdownStyleSheet(context),
                      onTapLink: (url, title, text) {
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.mint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
    required this.onRetry,
    this.isRateLimitError = false,
    this.isDailyQuotaExhausted = false,
    this.retryAfterSeconds,
  });
  final String error;
  final VoidCallback onRetry;
  final bool isRateLimitError;
  final bool isDailyQuotaExhausted;
  final int? retryAfterSeconds;

  @override
  Widget build(BuildContext context) {
    String displayError;
    if (isDailyQuotaExhausted) {
      displayError =
          'SmartSave AI is temporarily unavailable because the AI service has reached its daily request limit. Please try again later.';
    } else if (isRateLimitError) {
      displayError =
          'SmartSave AI is temporarily rate-limited. Please wait a moment and try again.';
    } else {
      displayError = error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      color: AppColors.paleRose,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.wine, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayError,
              style: const TextStyle(
                color: AppColors.wine,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.wine,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 32),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.busy,
    required this.mode,
    required this.onModeToggle,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool busy;
  final AssistantMode mode;
  final VoidCallback onModeToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      14,
      8,
      14,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              mode == AssistantMode.beginner
                  ? 'Beginner mode'
                  : 'Experienced mode',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: onModeToggle,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Switch',
                style: TextStyle(
                  color: AppColors.prussianBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                enabled: !busy,
                decoration: InputDecoration(
                  hintText: busy
                      ? 'Waiting for response...'
                      : 'Ask about your SmartSave data',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton.filled(
                tooltip: 'Send question',
                onPressed: busy ? null : () => onSend(controller.text),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.firefly,
                  foregroundColor: Colors.white,
                ),
                icon: busy
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
