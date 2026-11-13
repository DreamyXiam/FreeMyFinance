import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/main.dart';
import 'package:free_my_finance/monthly_overview.dart';

void main() {
  testWidgets('new managed category appears in entry editor', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    await ledger.addAccount(Account(id: 'a', name: '现金', openingCents: 0));
    await tester.pumpWidget(MaterialApp(home: CategoriesPage(ledger: ledger)));
    await tester.tap(find.text('新增分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '分类名称'), '宠物');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('宠物'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EntryForm(ledger: ledger)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '宠物'), findsOneWidget);
  });

  testWidgets(
    'monthly overview switches between months and uses selected currency',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      await ledger.addAccount(
        Account(id: 'a', name: '港币', openingCents: 0, currency: 'HKD'),
      );
      await ledger.addEntry(
        Entry(
          id: 'e',
          accountId: 'a',
          cents: 1234,
          income: false,
          category: '交通',
          note: '',
          date: DateTime(2026, 10),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthlyOverview(
              ledger: ledger,
              currency: 'HKD',
              today: DateTime(2026, 11),
            ),
          ),
        ),
      );
      expect(find.text('12.34'), findsNothing);
      await tester.tap(find.byKey(const Key('previous-month')));
      await tester.pumpAndSettle();
      expect(find.text('12.34'), findsOneWidget);
    },
  );
}
