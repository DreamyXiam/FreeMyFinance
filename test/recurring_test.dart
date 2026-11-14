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
      expect(l.balance('a'), 0);
      final backup = l.exportBackup();
      final clone = await Ledger.load();
      await clone.restoreBackup(backup);
      expect(clone.recurring.single.nextDate, DateTime(2026, 4, 30));
      await expectLater(l.deleteAccount('a'), throwsStateError);
    },
  );

  test(
    'weekly, quarterly and yearly rules generate pending bills once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      await ledger.addAccount(Account(id: 'a', name: '卡', openingCents: 10000));
      for (final (id, frequency) in [
        ('w', 'weekly'),
        ('q', 'quarterly'),
        ('y', 'yearly'),
      ]) {
        await ledger.addRecurring(
          Recurring(
            id: id,
            accountId: 'a',
            cents: 100,
            income: false,
            category: '订阅',
            note: '',
            day: 31,
            nextDate: DateTime(2026, 1, 31),
            frequency: frequency,
            startDate: DateTime(2026, 1, 31),
            endDate: DateTime(2026, 4, 30),
          ),
        );
      }
      expect(await ledger.applyRecurring(DateTime(2026, 4, 30)), 16);
      expect(ledger.entries.every((entry) => entry.pending), isTrue);
      expect(ledger.balance('a'), 10000);
      expect(await ledger.applyRecurring(DateTime(2026, 4, 30)), 0);
      final bill = ledger.entries.first;
      await ledger.markPaid(bill.id);
      expect(ledger.balance('a'), 9900);
      expect(
        (await Ledger.load()).entries.where((e) => e.pending),
        hasLength(15),
      );
    },
  );

  test('disabled rule skips dates and month end stays anchored', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    await ledger.addAccount(Account(id: 'a', name: '卡', openingCents: 0));
    await ledger.addRecurring(
      Recurring(
        id: 'm',
        accountId: 'a',
        cents: 100,
        income: true,
        category: '薪水',
        note: '',
        day: 31,
        nextDate: DateTime(2026, 1, 31),
        enabled: false,
        startDate: DateTime(2026, 1, 31),
      ),
    );
    expect(await ledger.applyRecurring(DateTime(2026, 3, 31)), 0);
    await ledger.setRecurringEnabled('m', true);
    expect(await ledger.applyRecurring(DateTime(2026, 3, 31)), 3);
    expect(ledger.entries.map((e) => e.date.day), [31, 28, 31]);
  });
}
