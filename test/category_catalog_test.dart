import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'categories persist, follow new entries, and round trip through backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      await ledger.addAccount(Account(id: 'a', name: '测试账户', openingCents: 0));
      await ledger.addCategory('宠物', income: false);
      expect(ledger.categoriesFor(false), contains('宠物'));
      expect(ledger.categoriesFor(true), isNot(contains('宠物')));
      await ledger.addEntry(
        Entry(
          id: 'e',
          accountId: 'a',
          cents: 2500,
          income: false,
          category: '宠物',
          note: '',
          date: DateTime(2026, 11),
        ),
      );
      await ledger.renameCategory('宠物', '养宠', income: false);
      expect(ledger.entries.single.category, '养宠');
      expect(ledger.categoriesFor(false), contains('养宠'));
      expect(ledger.categoriesFor(false), isNot(contains('宠物')));
      final backup = ledger.exportBackup();
      final restored = await Ledger.load();
      await restored.restoreBackup(backup);
      expect(restored.categoriesFor(false), contains('养宠'));
      final bad = jsonDecode(backup) as Map<String, dynamic>;
      bad['expenseCategories'] = [42];
      await expectLater(
        restored.restoreBackup(jsonEncode(bad)),
        throwsFormatException,
      );
      expect(restored.categoriesFor(false), contains('养宠'));
    },
  );

  test('old backups migrate categories from existing entries', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    await ledger.addAccount(Account(id: 'a', name: '测试账户', openingCents: 0));
    await ledger.addEntry(
      Entry(
        id: 'e',
        accountId: 'a',
        cents: 100,
        income: true,
        category: '红包',
        note: '',
        date: DateTime(2026, 11),
      ),
    );
    final old = jsonDecode(ledger.exportBackup()) as Map<String, dynamic>;
    old['version'] = 9;
    old.remove('expenseCategories');
    old.remove('incomeCategories');
    await ledger.restoreBackup(jsonEncode(old));
    expect(ledger.categoriesFor(true), contains('红包'));
  });
}
