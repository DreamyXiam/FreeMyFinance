import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'monthly rule clamps month end, is idempotent, and survives backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final l = await Ledger.load();
      await l.addAccount(Account(id: 'a', name: '工资卡', openingCents: 0));
      await l.addRecurring(
        Recurring(
          id: 'r',
          accountId: 'a',
          cents: 500,
          income: false,
          category: '房租',
          note: '',
          day: 31,
          nextDate: DateTime(2026, 1, 31),
        ),
      );
      expect(await l.applyRecurring(DateTime(2026, 3, 30)), 2);
      expect(l.entries.map((e) => e.date.day), [31, 28]);
      expect(await l.applyRecurring(DateTime(2026, 3, 30)), 0);
      expect(await l.applyRecurring(DateTime(2026, 3, 31)), 1);
      expect(l.balance('a'), -1500);
      final backup = l.exportBackup();
      final clone = await Ledger.load();
      await clone.restoreBackup(backup);
      expect(clone.recurring.single.nextDate, DateTime(2026, 4, 30));
      await expectLater(l.deleteAccount('a'), throwsStateError);
    },
  );
}
