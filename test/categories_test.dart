import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'renaming a category updates existing entries and recurring rules',
    () async {
      SharedPreferences.setMockInitialValues({});
      final l = await Ledger.load();
      await l.addAccount(Account(id: 'a', name: 'A', openingCents: 0));
      await l.addEntry(
        Entry(
          id: 'e',
          accountId: 'a',
          cents: 1,
          income: false,
          category: '餐饮',
          note: '',
          date: DateTime(2026),
        ),
      );
      await l.addRecurring(
        Recurring(
          id: 'r',
          accountId: 'a',
          cents: 2,
          income: false,
          category: '餐饮',
          note: '',
          day: 1,
          nextDate: DateTime(2026),
        ),
      );
      await l.renameCategory('餐饮', '吃饭');
      final loaded = await Ledger.load();
      expect(loaded.entries.single.category, '吃饭');
      expect(loaded.recurring.single.category, '吃饭');
      await expectLater(l.renameCategory('吃饭', ''), throwsStateError);
    },
  );
}
