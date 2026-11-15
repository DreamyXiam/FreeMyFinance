import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('moving an account persists its order and keeps balances', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    for (final id in ['a', 'b', 'c']) {
      await ledger.addAccount(Account(id: id, name: id, openingCents: 100));
    }
    await ledger.moveAccount('c', -1);
    expect(ledger.accounts.map((a) => a.id), ['a', 'c', 'b']);
    expect((await Ledger.load()).accounts.map((a) => a.id), ['a', 'c', 'b']);
    await ledger.moveAccount('a', -1);
    expect(ledger.accounts.map((a) => a.id), ['a', 'c', 'b']);
    expect(ledger.balance('c'), 100);
  });
}
