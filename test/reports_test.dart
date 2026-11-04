import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/reports.dart';

void main() {
  test('reports group income and expense by category for chosen period and account', () {
    final rows = [
      Entry(
        id: '1',
        accountId: 'a',
        cents: 100,
        income: false,
        category: '餐饮',
        note: '',
        date: DateTime(2026, 1, 2),
      ),
      Entry(
        id: '2',
        accountId: 'b',
        cents: 250,
        income: false,
        category: '餐饮',
        note: '',
        date: DateTime(2026, 1, 3),
      ),
      Entry(
        id: '3',
        accountId: 'a',
        cents: 600,
        income: true,
        category: '工资',
        note: '',
        date: DateTime(2026, 2, 3),
      ),
    ];
    final jan = Report.calculate(rows, year: 2026, month: 1);
    expect(jan.expenses, 350);
    expect(jan.categories['餐饮'], 350);
    expect(jan.income, 0);
    final year = Report.calculate(rows, year: 2026, accountId: 'a');
    expect(year.expenses, 100);
    expect(year.income, 600);
  });
}
