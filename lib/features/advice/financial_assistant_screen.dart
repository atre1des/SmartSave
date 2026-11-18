import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../shared/theme.dart';
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

  static const _suggestions = [
    'How is my spending?',
    'Am I within budget?',
    'How are my goals progressing?',
    'What can I review about investments?',
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
      ).answer(prompt);
      if (!mounted) return;
      conversation.state = [
        ...conversation.state,
        AssistantMessage(text: response, isUser: false),
      ];
    } catch (_) {
      if (!mounted) return;
      conversation.state = [
        ...conversation.state,
        const AssistantMessage(
          text:
              'I could not read the local finance records. Reopen SmartSave and try again.',
          isUser: false,
        ),
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
      appBar: AppBar(
        title: const Text('SmartSave Assistant'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Open a SmartSave feature',
            onSelected: (value) {
              final page = value == 'investment'
                  ? const InvestmentIntelligenceScreen()
                  : const RecommendationsScreen();
              _openFeature(page);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'investment',
                child: Text('Investment Intelligence'),
              ),
              PopupMenuItem(value: 'advice', child: Text('Recommendations')),
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
    color: AppColors.mintLight,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: AppColors.firefly, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Local demo helper · Uses saved SQLite data and fixed rules. No generative AI, bank connection, or live market feed is connected.',
            style: TextStyle(
              color: AppColors.firefly,
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
              avatar: const Icon(Icons.arrow_outward_rounded, size: 15),
              label: Text(suggestion, style: const TextStyle(fontSize: 12)),
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
      const Icon(
        Icons.chat_bubble_outline_rounded,
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
        'Ask about saved spending, budgets, goals, or your investment-research workflow.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
        color: message.isUser ? AppColors.firefly : Colors.white,
        border: message.isUser ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(
        message.text,
        style: TextStyle(
          color: message.isUser ? Colors.white : AppColors.firefly,
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
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mint),
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
            decoration: const InputDecoration(
              hintText: 'Ask about your SmartSave data',
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
  );
}
