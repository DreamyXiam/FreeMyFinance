import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('account category and optional card metadata survive backup', () async {
    SharedPreferences.setMockInitialValues({});
    final l = await Ledger.load();
    await l.addAccount(
      Account(
        id: 'a',
        name: '我的卡',
        openingCents: -10000,
        currency: 'CNY',
        kind: 'credit',
        lastFour: '1234',
        note: '常用',
        creditLimitCents: 500000,
        statementDay: 7,
        paymentDay: 26,
      ),
    );
    final other = await Ledger.load();
    final a = other.accounts.single;
    expect(a.kind, 'credit');
    expect(a.lastFour, '1234');
    expect(a.creditLimitCents, 500000);
    expect(a.statementDay, 7);
    expect(a.paymentDay, 26);
    final backup = other.exportBackup();
    await other.restoreBackup(backup);
    expect(other.accounts.single.note, '常用');
  });
  test('older backup remains compatible and invalid card metadata cannot overwrite it', () async {
    SharedPreferences.setMockInitialValues({});
    final l = await Ledger.load();
    final old = jsonEncode({
      'format': 'FreeMyFinance',
      'version': 6,
      'accounts': [
        {'id': 'old', 'name': '旧账户', 'openingCents': 100, 'currency': 'CNY'},
      ],
      'entries': [],
    });
    await l.restoreBackup(old);
    expect(l.accounts.single.kind, 'other');
    expect(l.accounts.single.includeInNetWorth, isTrue);
    final invalid = jsonDecode(l.exportBackup()) as Map<String, dynamic>;
    invalid['accounts'][0]['lastFour'] = '12345678';
    await expectLater(
      l.restoreBackup(jsonEncode(invalid)),
      throwsFormatException,
    );
    expect((await Ledger.load()).accounts.single.name, '旧账户');
  });
}
