import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/reports.dart';

void main() {
  test(
    'transfer moves money atomically and is excluded from income and expenses',
    () async {
      SharedPreferences.setMockInitialValues({});
      final l = await Ledger.load();
      await l.addAccount(Account(id: 'a', name: 'A', openingCents: 10000));
      await l.addAccount(Account(id: 'b', name: 'B', openingCents: 200));
      await l.addTransfer(
        id: 't',
        from: 'a',
        to: 'b',
        cents: 3000,
        date: DateTime(2026, 11, 4),
        note: '',
      );
      expect(l.balance('a'), 7000);
      expect(l.balance('b'), 3200);
      expect(l.incomeFor(DateTime(2026, 11)), 0);
      expect(l.expenseFor(DateTime(2026, 11)), 0);
      expect(Report.calculate(l.entries, year: 2026).income, 0);
      await expectLater(
        l.addTransfer(
          id: 'x',
          from: 'a',
          to: 'a',
          cents: 1,
          date: DateTime.now(),
          note: '',
        ),
        throwsStateError,
      );
      final backup = l.exportBackup();
      final other = await Ledger.load();
      await other.restoreBackup(backup);
      expect(other.entries.where((e) => e.transferId == 't'), hasLength(2));
      final restored = await Ledger.load();
      await restored.deleteEntry(restored.entries.first.id);
      expect(restored.entries, isEmpty);
      expect(restored.balance('a'), 10000);
      expect(restored.balance('b'), 200);
    },
  );
}
