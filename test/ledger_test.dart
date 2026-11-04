import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'ledger persists accounts and calculates income and expenses in cents',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      final card = Account(
        id: '1',
        name: '银行卡',
        openingCents: 10000,
        imageUrl: 'https://example.com/card.png',
      );
      await ledger.addAccount(card);
      await ledger.addEntry(
        Entry(
          id: 'a',
          accountId: '1',
          cents: 1250,
          income: false,
          category: '餐饮',
          note: '',
          date: DateTime(2026, 11, 1),
        ),
      );
      await ledger.addEntry(
        Entry(
          id: 'b',
          accountId: '1',
          cents: 5000,
          income: true,
          category: '工资',
          note: '',
          date: DateTime(2026, 11, 2),
        ),
      );
      final restored = await Ledger.load();
      expect(restored.balance('1'), 13750);
      expect(restored.accounts.single.imageUrl, 'https://example.com/card.png');
      expect(restored.incomeFor(DateTime(2026, 11)), 5000);
      expect(restored.expenseFor(DateTime(2026, 11)), 1250);
      await restored.deleteEntry('a');
      expect((await Ledger.load()).balance('1'), 15000);
    },
  );
}
