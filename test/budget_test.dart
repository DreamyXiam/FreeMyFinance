import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/main.dart' show parseBudgetAmount, ReportView;

void main() {
  test('budget form accepts zero to disable and regular amounts', () {
    expect(parseBudgetAmount('0'), 0);
    expect(parseBudgetAmount('0.00'), 0);
    expect(parseBudgetAmount('25.50'), 2550);
    expect(parseBudgetAmount('-1'), isNull);
  });
  testWidgets(
    'statistics budget dialog saves zero without a disposed controller',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      await ledger.setMonthlyBudget(10000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReportView(ledger: ledger)),
        ),
      );
      await tester.tap(find.text('设置').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '0');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(ledger.monthlyBudgetCents, 0);
    },
  );
  test('monthly budget survives app restart and backup restore', () async {
    SharedPreferences.setMockInitialValues({});
    final l = await Ledger.load();
    await l.setMonthlyBudget(123450);
    final backup = l.exportBackup();
    await l.setMonthlyBudget(0);
    await l.restoreBackup(backup);
    expect(l.monthlyBudgetCents, 123450);
    expect((await Ledger.load()).monthlyBudgetCents, 123450);
    await expectLater(l.setMonthlyBudget(-1), throwsStateError);
  });
}
