import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';
import '../advice/ai_assistant_screen.dart';
import '../advice/assistant_session.dart';
import 'invest_screen.dart';

class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen> {
  String _sortBy = 'relevance';

  // Sample stocks - 6-element tuples matching _StockTile from invest_screen.dart
  static const List<(String, String, String, String, String, bool)> _stocks = [
    ('Halyk Bank', 'HSBK', 'Medium', '245,00 ₸', '+1,8%', true),
    ('Kaspi.kz', 'KSPI', 'Medium', '42 300 ₸', '+0,6%', true),
    ('KEGOC', 'KEGC', 'Low', '1 480 ₸', '−0,4%', true),
    ('Kazatomprom', 'KAP', 'High', '21 900 ₸', '+2,3%', false),
    ('Air Astana', 'AASN', 'Medium', '3 200 ₸', '+0,2%', false),
    ('Kcell', 'KCEL', 'Low', '890 ₸', '−0,1%', false),
  ];

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stocks for You'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'relevance', child: Text('Relevance to profile')),
              PopupMenuItem(value: 'name', child: Text('Name (A-Z)')),
              PopupMenuItem(value: 'change', child: Text('Price change')),
              PopupMenuItem(value: 'risk', child: Text('Risk level')),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 4),
                  Text(_sortBy == 'relevance' ? 'Relevance' : _sortBy.capitalize()),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: finance.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.firefly))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  // Risk profile badge
                  SurfaceCard(
                    color: AppColors.mintLight,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: AppColors.firefly),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Risk profile: ${ref.watch(authServiceProvider).getRiskProfile() ?? 'moderate'} · Kazakhstan',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const SectionHeading('Available Stocks'),
                  const SizedBox(height: 8),

                  // Disclaimer
                  const SurfaceCard(
                    color: AppColors.paleGold,
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.gold, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sample quotes only. Not investment advice. No securities can be purchased from SmartSave. Prices are illustrative and do not reflect real-time market data.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  for (final stock in _stocks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _StockTile(
                        stock: stock,
                        onTap: () => _push(context, StockDetailsScreen(stock: stock)),
                        onAskAI: () => _askAIAboutStock(stock),
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    'Fictional sample quotes. Not investment advice. No securities can be purchased from SmartSave.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
        ),
    );
  }

  void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _askAIAboutStock((String, String, String, String, String, bool) stock) {
    assistantRouteActive.value = true;
    appNavigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(builder: (_) => AIAssistantScreen()),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        assistantRouteActive.value = false;
        // TODO: Prefill the AI chat with a question about this stock
      });
    });
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.stock,
    required this.onTap,
    required this.onAskAI,
  });
  final (String, String, String, String, String, bool) stock;
  final VoidCallback onTap;
  final VoidCallback onAskAI;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.mintLight,
          child: Text(
            stock.$2.substring(0, 2),
            style: const TextStyle(color: AppColors.firefly, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stock.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('${stock.$2} · ${stock.$3} · ${stock.$4} risk', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                stock.$6 ? '✓ Fits your profile' : '! Above your profile',
                style: TextStyle(fontSize: 10, color: stock.$6 ? AppColors.success : AppColors.wine),
              ),
              const SizedBox(height: 4),
              Text(
                stock.$5,
                style: TextStyle(fontSize: 12, color: stock.$5.startsWith('+') ? AppColors.success : AppColors.wine),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(stock.$5, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(
              stock.$6 ? '✓' : '✗',
              style: const TextStyle(fontSize: 12, color: AppColors.success),
            ),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onAskAI,
          icon: const Icon(Icons.psychology_outlined, size: 20, color: AppColors.prussianBlue),
          tooltip: 'Ask SmartSave AI about this stock',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.mintLight,
            foregroundColor: AppColors.prussianBlue),
        ),
      ],
    ),
  );
}