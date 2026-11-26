import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/data/financial_math.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/shared/theme.dart';
import 'package:smart_save/shared/widgets.dart';

void main() {
  test('formats whole-tenge amounts without floating-point rounding', () {
    expect(formatTenge(1248500), '1 248 500 ₸');
    expect(formatTenge(-18400), '−18 400 ₸');
    expect(formatSignedTenge(420000, income: true), '+420 000 ₸');
  });

  test('goal progress and remaining amount use integer arithmetic', () {
    final goal = SavingsGoal(id: 1, name: 'Laptop', target: 240000, saved: 148000, deadline: DateTime(2027, 2), purpose: 'Purchase');
    expect(goal.remaining, 92000);
    expect(goal.progressPercent, 62);
    expect(monthlyGoalContribution(targetTenge: goal.target, savedTenge: goal.saved, monthsRemaining: 4), 23000);
    expect(monthlyGoalContribution(targetTenge: 100, savedTenge: 125, monthsRemaining: 3), 0);
  });

  test('deposit interest estimate matches the prototype example', () {
    expect(estimateSimpleInterest(principalTenge: 1000000, nominalRateBps: 1791, months: 3), 44775);
  });

  testWidgets('primary action remains actionable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: PrimaryAction(label: 'Save', onPressed: () => tapped = true)),
    ));
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(tapped, isTrue);
  });
}
