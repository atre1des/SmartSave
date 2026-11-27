import '../../shared/widgets.dart';
import '../../l10n/app_locale.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/glass.dart';
import 'assistant_session.dart';
import '../invest/investment_intelligence_screen.dart';
import 'advice_screens.dart';
import 'financial_assistant_service.dart';

class FinancialAssistantScreen extends ConsumerStatefulWidget {
  const FinancialAssistantScreen({super.key});

  @override
  ConsumerState<FinancialAssistantScreen> createState() =>
      _FinancialAssistantScreenState();
}

class _FinancialAssistantScreenState
    extends ConsumerState<FinancialAssistantScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  bool _isResponding = false;

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

  List<String> get _suggestions => [
    context.l10n.localSpendingPrompt,
    context.l10n.localBudgetPrompt,
    context.l10n.localGoalsPrompt,
    context.l10n.localInvestPrompt,
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      assistantRouteActive.value = false;
    });
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedPrompt]) async {
    final prompt = (suggestedPrompt ?? _input.text).trim();
    if (prompt.isEmpty || _isResponding) return;
    _input.clear();
    final conversation = ref.read(assistantConversationProvider.notifier);
    conversation.state = [
      ...conversation.state,
      AssistantMessage(text: prompt, isUser: true),
    ];
    setState(() => _isResponding = true);
    _scrollToEnd();
    try {
      final repository = ref.read(financeRepositoryProvider);
      final response = await FinancialAssistantService(
        repository,
      ).answer(prompt, languageCode: context.l10n.localeName);
      if (!mounted) return;
      conversation.state = [
        ...conversation.state,
        AssistantMessage(text: response, isUser: false),
      ];
    } catch (_) {
      if (!mounted) return;
      conversation.state = [
        ...conversation.state,
        AssistantMessage(text: context.l10n.localReadError, isUser: false),
      ];
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(assistantConversationProvider);
    return Scaffold(
      appBar: EditorialHeader(
        title: Text(context.l10n.assistant),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.l10n.assistantFeature,
            onSelected: (value) {
              final page = value == 'investment'
                  ? const InvestmentIntelligenceScreen()
                  : const RecommendationsScreen();
              _openFeature(page);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'investment',
                child: Text(context.l10n.investmentIntelligence),
              ),
              PopupMenuItem(
                value: 'advice',
                child: Text(context.l10n.recommendations),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _AssistantDisclosure(),
            _SuggestionChipsRow(suggestions: _suggestions, onSelect: _send),
            Expanded(
              child: messages.isEmpty
                  ? _Welcome(suggestions: _suggestions, onSelect: _send)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      itemCount: messages.length + (_isResponding ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isResponding && index == messages.length) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(message: messages[index]);
                      },
                    ),
            ),
            _Composer(controller: _input, onSend: _send, busy: _isResponding),
          ],
        ),
      ),
    );
  }
}

class _AssistantDisclosure extends StatelessWidget {
  const _AssistantDisclosure();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
    color: context.colors.subtleSurface,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: context.colors.text, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.localDisclosure,
            style: TextStyle(
              color: context.colors.text,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SuggestionChipsRow extends StatelessWidget {
  const _SuggestionChipsRow({
    required this.suggestions,
    required this.onSelect,
  });
  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        for (final suggestion in suggestions)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
              label: Text(
                suggestion,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              onPressed: () => onSelect(suggestion),
            ),
          ),
      ],
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.suggestions, required this.onSelect});
  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    children: [
      Icon(
        Icons.auto_awesome,
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
        context.l10n.localAssistantHint,
        style: TextStyle(color: context.colors.muted, fontSize: 12),
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AssistantMessage message;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .84,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: message.isUser
            ? context.colors.emphasis
            : context.colors.surface,
        border: message.isUser
            ? null
            : Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(
        message.text,
        style: TextStyle(
          color: message.isUser
              ? context.colors.onEmphasis
              : context.colors.text,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    ),
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.progress,
        ),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.busy,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      14,
      8,
      14,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    child: GlassSurface(
      radius: 28,
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              decoration: InputDecoration(
                hintText: context.l10n.askSmartSave,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
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
    ),
  );
}
