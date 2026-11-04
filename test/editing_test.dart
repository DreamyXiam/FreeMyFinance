import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('edits account and entry while preserving identifiers and protects linked accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    await ledger.addAccount(Account(id: 'a', name: '储蓄卡', openingCents: 10000));
    await ledger.addEntry(
      Entry(
        id: 'e',
        accountId: 'a',
        cents: 500,
        income: false,
        category: '餐饮',
        note: '',
        date: DateTime(2026, 11, 1),
      ),
    );
    await ledger.updateAccount(
      Account(id: 'a', name: '工资卡', openingCents: 20000),
    );
    await ledger.updateEntry(
      Entry(
        id: 'e',
        accountId: 'a',
        cents: 750,
        income: false,
        category: '购物',
        note: '书',
        date: DateTime(2026, 11, 2),
      ),
    );
    expect((await Ledger.load()).balance('a'), 19250);
    expect((await Ledger.load()).entries.single.note, '书');
    await expectLater(ledger.deleteAccount('a'), throwsStateError);
    expect(ledger.accounts, hasLength(1));
    await ledger.deleteEntry('e');
    await ledger.deleteAccount('a');
    expect((await Ledger.load()).accounts, isEmpty);
  });
}
