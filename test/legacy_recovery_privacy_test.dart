import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/features/profile/profile_screen.dart';

void main() {
  testWidgets(
    'an account cannot claim shared legacy data through privacy settings',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PrivacyDataScreen())),
      );
      await tester.tap(find.text('Recover legacy data'));
      await tester.pumpAndSettle();

      expect(find.text('Legacy record recovery'), findsOneWidget);
      expect(find.textContaining('cannot verify who owns'), findsOneWidget);
      expect(find.text('These are my records'), findsNothing);
    },
  );
}
