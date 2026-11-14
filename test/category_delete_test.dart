import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'deleting a used tag moves its entries into the uncategorized fallback',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      await ledger.addAccount(Account(id: 'a', name: '现金', openingCents: 0));
      await ledger.addCategory('宠物', income: false);
      await ledger.addEntry(
        Entry(
          id: 'e',
          accountId: 'a',
          cents: 1200,
          income: false,
          category: '宠物',
          note: '',
          date: DateTime(2026, 11, 13),
        ),
      );
      await ledger.deleteCategory('宠物', income: false);
      expect(ledger.categoriesFor(false), isNot(contains('宠物')));
      expect(ledger.entries.single.category, '其他支出');
      expect((await Ledger.load()).entries.single.category, '其他支出');
      await ledger.deleteCategory('其他支出', income: false);
      expect(ledger.entries.single.category, '未分类支出');
      expect(ledger.categoriesFor(false), isNot(contains('其他支出')));
    },
  );
}
