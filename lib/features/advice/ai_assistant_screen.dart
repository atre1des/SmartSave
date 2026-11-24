import '../../l10n/app_locale.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_assistant_service.dart';
import '../../ai/conversations.dart';
import '../../ai/models.dart';
import '../../ai/openrouter_provider.dart';
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
  const AIAssistantScreen({super.key, this.provider});

  final OpenRouterProvider? provider;

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

  // Backend connectivity status
  BackendStatus _backendStatus = BackendStatus.unknown;

  // Error state for the last failed request
  String? _lastError;
  bool _isRateLimitError = false;
  bool _isDailyQuotaExhausted = false;

  static List<QuickAction> _quickActions(BuildContext context) => [
    QuickAction(
      type: QuickActionType.savingsGoal,
      title: context.l10n.goalAction,
      description: context.l10n.goalActionDescription,
      prefillPrompt: context.l10n.goalPrompt,
    ),
    QuickAction(
      type: QuickActionType.explainOpportunity,
      title: context.l10n.opportunityAction,
      description: context.l10n.opportunityDescription,
      prefillPrompt: context.l10n.opportunityPrompt,
    ),
    QuickAction(
      type: QuickActionType.compareDepositShares,
      title: context.l10n.compareAction,
      description: context.l10n.compareDescription,
      prefillPrompt: context.l10n.comparePrompt,
    ),
    QuickAction(
      type: QuickActionType.analyzePortfolio,
      title: context.l10n.portfolioAction,
      description: context.l10n.portfolioDescription,
      prefillPrompt: context.l10n.portfolioPrompt,
    ),
    QuickAction(
      type: QuickActionType.exploreIPO,
      title: context.l10n.ipoAction,
      description: context.l10n.ipoDescription,
      prefillPrompt: context.l10n.ipoPrompt,
    ),
    QuickAction(
      type: QuickActionType.whatIfScenario,
      title: context.l10n.scenarioAction,
      description: context.l10n.scenarioDescription,
      prefillPrompt: context.l10n.scenarioPrompt,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _assistantService = SmartSaveAIAssistantService(
      ref.read(financeRepositoryProvider),
      provider: widget.provider,
    );
    // Load saved mode from session
    _mode = ref.read(assistantModeProvider);
    // Check backend connectivity
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    if (_assistantService == null) return;
    _showProxyStatus(null);
    _showProxyStatus(await _assistantService!.isProxyReachable);
  }

  void _showProxyStatus(bool? reachable) {
    if (!mounted) return;
    setState(
      () => _backendStatus = switch (reachable) {
        null => BackendStatus.checking,
        true => BackendStatus.connected,
        false => BackendStatus.disconnected,
      },
    );
  }

  void _startNewConversation() {
    ref.read(aiConversationsProvider).startNew();
    _scaffoldKey.currentState?.closeDrawer();
    setState(() {
      _lastError = null;
      _showModeSelector = true;
    });
  }

  void _selectConversation(String id) {
    unawaited(ref.read(aiConversationsProvider).select(id));
    _scaffoldKey.currentState?.closeDrawer();
    setState(() {
      _lastError = null;
      _showModeSelector = false;
    });
  }

  VoidCallback? _cancelActiveRequest;
  ConversationRequest? _failedRequest;

  @override
  void dispose() {
    _cancelActiveRequest?.call();
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
    final conversations = ref.read(aiConversationsProvider);
    final request = conversations.begin(prompt);
    if (request == null) return;
    _input.clear();
    await _streamResponse(conversations, request);
  }

  Future<void> _streamResponse(
    AIConversations conversations,
    ConversationRequest request,
  ) async {
    _failedRequest = null;
    _cancelActiveRequest = () => scheduleMicrotask(() {
      unawaited(conversations.finish(request));
    });
    setState(() {
      _lastError = null;
      _isRateLimitError = false;
      _isDailyQuotaExhausted = false;
      _isStreaming = true;
      _streamingContent = '';
      _showModeSelector = false;
    });
    _scrollToEnd();
    AIMessage? reply;
    var isLocalFallback = false;
    try {
      await for (final chunk in _assistantService!.sendMessageStream(
        request.prompt,
        history: request.history,
        languageCode: context.l10n.localeName,
        onProxyStatus: _showProxyStatus,
      )) {
        if (!mounted) return;
        if (chunk.isDone) {
          if (chunk.error != null || _streamingContent.trim().isEmpty) {
            setState(() {
              _lastError = chunk.error ?? context.l10n.aiRetryMessage;
              _isRateLimitError = chunk.isRateLimitError;
              _isDailyQuotaExhausted = chunk.isDailyQuotaExhausted;
            });
          } else {
            reply = AIMessage.assistant(
              _streamingContent,
              isLocalFallback: isLocalFallback,
            );
          }
        } else {
          isLocalFallback |= chunk.isLocalFallback;
          setState(() => _streamingContent += chunk.content);
          _scrollToEnd();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _lastError = context.l10n.aiRetryMessage);
    } finally {
      if (mounted && _lastError != null) _failedRequest = request;
      await conversations.finish(request, reply: reply);
      _cancelActiveRequest = null;
      if (mounted) {
        setState(() => _isStreaming = false);
        _scrollToEnd();
      }
    }
  }

  void _retryLastMessage() {
    final conversations = ref.read(aiConversationsProvider);
    final failed = _failedRequest;
    if (_lastError == null ||
        failed == null ||
        failed.id != conversations.activeId) {
      return;
    }
    final last = conversations.messages.lastOrNull;
    if (last == null || !last.isUser || last.content != failed.prompt) return;
    final request = conversations.begin(last.content, retry: true);
    if (request != null) _streamResponse(conversations, request);
  }

  void _clearConversation() {
    ref.read(aiConversationsProvider).clear();
    setState(() {
      _lastError = null;
      _showModeSelector = true;
    });
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

  Widget _buildDrawer(AIConversations conversations) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.emphasis,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: context.colors.progress, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.assistant,
                          style: TextStyle(
                            color: context.colors.onEmphasis,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          context.l10n.chooseExplore,
                          style: TextStyle(color: context.colors.onEmphasis, fontSize: 11),
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
              title: Text(context.l10n.newChat),
              subtitle: Text(context.l10n.startConversation),
              onTap: conversations.busy || !conversations.ready
                  ? null
                  : _startNewConversation,
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(context.l10n.thesisReview),
              subtitle: Text(context.l10n.recordReasoning),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _openFeature(const InvestmentIntelligenceScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.waves_outlined),
              title: Text(context.l10n.liquidity),
              subtitle: Text(context.l10n.testOrderSize),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _openFeature(const InvestmentIntelligenceScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline_outlined),
              title: Text(context.l10n.economicRipple),
              subtitle: Text(context.l10n.simulateMacro),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _openFeature(const InvestmentIntelligenceScreen());
              },
            ),

            const Divider(height: 16),

            // Recent Chats
            if (conversations.entries.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        context.l10n.recentChats,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: conversations.entries.map((entry) {
                          final firstUserMsg = entry.value
                              .where((m) => m.isUser)
                              .firstOrNull;
                          final title =
                              firstUserMsg?.text ?? context.l10n.untitledChat;
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
                              onPressed: conversations.busy
                                  ? null
                                  : () {
                                      conversations.delete(entry.key);
                                      setState(() => _lastError = null);
                                    },
                            ),
                            onTap: conversations.busy
                                ? null
                                : () => _selectConversation(entry.key),
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
    final conversations = ref.watch(aiConversationsProvider);
    final messages = conversations.messages;
    final waitingForFirstChunk = _isStreaming && _lastError == null;
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
        title: Text(context.l10n.assistant),
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
                  color: isConnected ? context.colors.subtleSurface : context.colors.noticeSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isChecking)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.warning,
                        ),
                      )
                    else
                      Icon(
                        isConnected ? Icons.cloud_done : Icons.cloud_off,
                        size: 14,
                        color: isConnected ? context.colors.positive : context.colors.warning,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      isChecking
                          ? context.l10n.aiConnecting
                          : isConnected
                          ? context.l10n.proxyReachable
                          : context.l10n.offlineMode,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isConnected ? context.colors.positive : context.colors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.assistantFeature,
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
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'investment',
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.investmentIntelligence),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'thesis',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.thesisReview),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'liquidity',
                child: Row(
                  children: [
                    Icon(Icons.waves_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.liquidityAnalysis),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ripple',
                child: Row(
                  children: [
                    Icon(Icons.timeline_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.economicRipple),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'advice',
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.recommendations),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text(context.l10n.clearConversation),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(conversations),
      body: SafeArea(
        child: Column(
          children: [
            if (!_showModeSelector || messages.isNotEmpty)
              _DisclaimerBanner(
                isConnected: isConnected,
                isChecking: isChecking,
              ),

            Expanded(
              child: messages.isEmpty && _showModeSelector
                  ? ListView(
                      children: [
                        _DisclaimerBanner(
                          isConnected: isConnected,
                          isChecking: isChecking,
                        ),
                        _ModeSelector(
                          currentMode: _mode,
                          onToggle: _toggleMode,
                        ),
                        _QuickActionsSection(
                          actions: _quickActions(context),
                          onSelect: _send,
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (kDebugLayout) {
                          debugPrint(
                            '[AIAssistantScreen] ListView constraints: maxWidth=${constraints.maxWidth}, '
                            'maxHeight=${constraints.maxHeight}, hasBoundedHeight=${constraints.maxHeight.isFinite}, '
                            'hasBoundedWidth=${constraints.maxWidth.isFinite}, '
                            'itemCount=${messages.length + (waitingForFirstChunk ? 1 : 0)}, '
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
                                    messages.length +
                                    (waitingForFirstChunk ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == messages.length) {
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
            else if (_lastError != null &&
                _failedRequest?.id == conversations.activeId)
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
              busy: conversations.busy || !conversations.ready,
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
  const _DisclaimerBanner({
    required this.isConnected,
    required this.isChecking,
  });
  final bool isChecking;
  final bool isConnected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
    color: isConnected ? context.colors.subtleSurface : context.colors.noticeSurface,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isConnected ? Icons.info_outline : Icons.warning_amber_rounded,
          color: isConnected ? context.colors.text : context.colors.warning,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isChecking
                ? context.l10n.aiWakingNotice
                : isConnected
                ? context.l10n.aiProxyNotice
                : context.l10n.aiOfflineNotice,
            style: TextStyle(
              color: isConnected ? context.colors.text : context.colors.warning,
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
          context.l10n.aiHowProceed,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.chooseLevel,
          style: TextStyle(color: context.colors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.school_outlined,
                title: context.l10n.beginnerChoice,
                description: context.l10n.aiBeginnerExplainer,
                selected: currentMode == AssistantMode.beginner,
                onTap: onToggle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                icon: Icons.analytics_outlined,
                title: context.l10n.experiencedChoice,
                description: context.l10n.aiAdvancedExplainer,
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
        color: selected ? context.colors.emphasis : context.colors.surface,
        border: Border.all(
          color: selected ? context.colors.text : context.colors.outline,
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
            color: selected ? context.colors.onEmphasis : context.colors.text,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? context.colors.onEmphasis : context.colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: selected ? context.colors.onEmphasis : context.colors.muted,
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
        Text(
          context.l10n.quickActions,
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
    backgroundColor: context.colors.subtleSurface,
    side: BorderSide(color: context.colors.outline),
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
      Icon(
        Icons.auto_awesome_rounded,
        size: 38,
        color: context.colors.text,
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.localWelcome,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        context.l10n.assistantWelcome,
        style: TextStyle(color: context.colors.muted, fontSize: 12),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.refresh, size: 16),
        label: Text(context.l10n.showModeSelector),
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
              color: message.isUser ? context.colors.emphasis : context.colors.surface,
              border: message.isUser
                  ? null
                  : Border.all(color: context.colors.outline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: message.isUser
                ? SelectableText(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? context.colors.onEmphasis : context.colors.text,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  )
                : BufferedStreamingMarkdown(
                    content: message.text,
                    isStreaming: message.isStreaming,
                    selectable: true,
                    styleSheet: _assistantMarkdownStyleSheet(context),
                    onTapLink: (url, title, text) {},
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
      color: context.colors.text,
      height: 1.5,
      fontSize: 13,
    ),
    h1: theme.textTheme.headlineSmall?.copyWith(
      color: context.colors.text,
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ),
    h2: theme.textTheme.titleLarge?.copyWith(
      color: context.colors.text,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    h3: theme.textTheme.titleMedium?.copyWith(
      color: context.colors.text,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
    strong: theme.textTheme.bodyMedium?.copyWith(
      color: context.colors.text,
      fontWeight: FontWeight.w700,
    ),
    em: theme.textTheme.bodyMedium?.copyWith(
      color: context.colors.text,
      fontStyle: FontStyle.italic,
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(
      color: context.colors.text,
      height: 1.5,
      fontSize: 13,
    ),
    listBulletPadding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
    listIndent: 18,
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: context.colors.muted,
      fontStyle: FontStyle.italic,
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: context.colors.progress, width: 3)),
    ),
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      backgroundColor: context.colors.subtleSurface,
      color: context.colors.text,
    ),
    codeblockDecoration: BoxDecoration(
      color: context.colors.text,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    a: theme.textTheme.bodyMedium?.copyWith(
      color: context.colors.action,
      decoration: TextDecoration.underline,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.colors.outline, width: 1)),
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
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.outline),
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
                      onTapLink: (url, title, text) {},
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.progress,
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
  });
  final String error;
  final VoidCallback onRetry;
  final bool isRateLimitError;
  final bool isDailyQuotaExhausted;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final displayError = isDailyQuotaExhausted
        ? strings.aiDailyLimit
        : isRateLimitError
        ? strings.aiRateLimit
        : strings.localeName == 'en'
        ? error
        : strings.aiRetryMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      color: context.colors.noticeSurface,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.colors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayError,
              style: TextStyle(
                color: context.colors.error,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 32),
            ),
            child: Text(
              context.l10n.retry,
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

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final desktop =
        kIsWeb ||
        switch (defaultTargetPlatform) {
          TargetPlatform.windows ||
          TargetPlatform.macOS ||
          TargetPlatform.linux => true,
          _ => false,
        };
    final keyboard = HardwareKeyboard.instance;
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!desktop ||
        !enter ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final value = controller.value;
    if (value.isComposingRangeValid && !value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    if (busy || event is KeyRepeatEvent) return KeyEventResult.handled;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (keyboard.isShiftPressed) {
      final selection = value.selection;
      final start = selection.isValid ? selection.start : value.text.length;
      final end = selection.isValid ? selection.end : start;
      controller.value = TextEditingValue(
        text: value.text.replaceRange(start, end, '\n'),
        selection: TextSelection.collapsed(offset: start + 1),
      );
    } else if (value.text.trim().isNotEmpty) {
      onSend(value.text);
    }
    return KeyEventResult.handled;
  }

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
                  ? context.l10n.beginnerMode
                  : context.l10n.experiencedMode,
              style: TextStyle(
                color: context.colors.muted,
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
                context.l10n.switchMode,
                style: TextStyle(
                  color: context.colors.action,
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
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: _handleKey,
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  readOnly: busy,
                  decoration: InputDecoration(
                    hintText: busy
                        ? context.l10n.waiting
                        : context.l10n.askSmartSave,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: context.colors.surface,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton.filled(
                tooltip: context.l10n.sendQuestion,
                onPressed: busy ? null : () => onSend(controller.text),
                style: IconButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                ),
                icon: busy
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.onPrimary,
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
