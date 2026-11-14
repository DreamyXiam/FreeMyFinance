import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/main.dart';

void main() {
  testWidgets('tapping a calendar day opens bills filtered to that day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    await ledger.addAccount(Account(id: 'a', name: '现金', openingCents: 0));
    final today = DateTime.now();
    await ledger.addEntry(
      Entry(
        id: 'one',
        accountId: 'a',
        cents: 100,
        income: false,
        category: '当天分类',
        note: '',
        date: today,
      ),
    );
    await ledger.addEntry(
      Entry(
        id: 'two',
        accountId: 'a',
        cents: 200,
        income: false,
        category: '前一天分类',
        note: '',
        date: today.subtract(const Duration(days: 1)),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: Home(ledger: ledger)));
    await tester.pumpAndSettle();
    final dayKey = Key(
      'calendar-day-${today.year}-${today.month}-${today.day}',
    );
    await tester.ensureVisible(find.byKey(dayKey));
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    expect(find.text('账单'), findsWidgets);
    expect(find.text('当天分类'), findsOneWidget);
    expect(find.text('前一天分类'), findsNothing);
    expect(find.text('清除日期'), findsOneWidget);
  });
}
