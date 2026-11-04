import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
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
