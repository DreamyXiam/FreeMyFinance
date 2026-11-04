import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'backup restores all records and rejects invalid data without changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      await ledger.addAccount(
        Account(
          id: 'a',
          name: '现金',
          openingCents: 100,
          imageUrl: 'https://example.com/a.png',
        ),
      );
      await ledger.addEntry(
        Entry(
          id: 'b',
          accountId: 'a',
          cents: 30,
          income: false,
          category: '餐饮',
          note: '午餐',
          date: DateTime(2026, 11, 1),
        ),
      );
      final backup = ledger.exportBackup();
      await ledger.deleteEntry('b');
      await ledger.restoreBackup(backup);
      expect(ledger.balance('a'), 70);
      expect(ledger.entries.single.note, '午餐');
      final bad = jsonDecode(backup) as Map<String, dynamic>;
      bad['entries'][0]['accountId'] = 'missing';
      await expectLater(
        ledger.restoreBackup(jsonEncode(bad)),
        throwsFormatException,
      );
      expect((await Ledger.load()).balance('a'), 70);
    },
  );
}
