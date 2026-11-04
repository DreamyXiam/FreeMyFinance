import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'currency balances stay separate and foreign transfers record both amounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final l = await Ledger.load();
      await l.addAccount(Account(id: 'a', name: 'A', openingCents: 10000));
      await l.addAccount(
        Account(id: 'b', name: 'B', openingCents: 0, currency: 'HKD'),
      );
      await l.addEntry(
        Entry(
          id: 'e',
          accountId: 'b',
          cents: 1000,
          income: false,
          category: '购物',
          note: '',
          date: DateTime(2026, 11, 1),
        ),
      );
      expect(l.expenseFor(DateTime(2026, 11)), 0);
      expect(l.expenseFor(DateTime(2026, 11), currency: 'HKD'), 1000);
      await l.addTransfer(
        id: 't',
        from: 'a',
        to: 'b',
        cents: 1000,
        toCents: 1100,
        date: DateTime(2026, 11, 2),
        note: '',
      );
      expect(l.balance('a'), 9000);
      expect(l.balance('b'), 100);
      await expectLater(
        l.updateAccount(
          Account(id: 'b', name: 'B', openingCents: 0, currency: 'USD'),
        ),
        throwsStateError,
      );
      final clone = await Ledger.load();
      await clone.restoreBackup(l.exportBackup());
      expect(clone.accounts.last.currency, 'HKD');
      expect(clone.balance('b'), 100);
    },
  );
}
