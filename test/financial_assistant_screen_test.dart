import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/features/advice/financial_assistant_screen.dart';

void main() {
  testWidgets('assistant screen renders its local-demo disclosure', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FinancialAssistantScreen())),
    );
    expect(find.text('SmartSave Assistant'), findsOneWidget);
    expect(find.textContaining('No generative AI'), findsOneWidget);
  });
}
