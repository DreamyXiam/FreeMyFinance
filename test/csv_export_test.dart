import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/csv_export.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('CSV quotes user text and neutralizes spreadsheet formulas', () {
    final out = exportCsv(
      [Account(id: 'a', name: '=bad', openingCents: 0)],
      [
        Entry(
          id: 'e',
          accountId: 'a',
          cents: 1234,
          income: false,
          category: '餐饮',
          note: 'hello, "x"',
          date: DateTime(2026, 11, 4),
        ),
      ],
    );
    expect(out, contains("'=bad"));
    expect(out, contains('"hello, ""x"""'));
    expect(out, contains('12.34'));
    expect(out, contains('2026-11-04'));
    expect(out, contains('已付款'));
  });
  test('pending recurring bills export as unpaid', () {
    final out = exportCsv(
      [Account(id: 'a', name: '卡', openingCents: 0)],
      [
        Entry(
          id: 'r',
          accountId: 'a',
          cents: 100,
          income: false,
          category: '订阅',
          note: '',
          date: DateTime(2026, 11, 4),
          pending: true,
        ),
      ],
    );
    expect(out, contains('待付款'));
  });
}
