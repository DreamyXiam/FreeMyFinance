import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/main.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  testWidgets(
    'edit entry and make foreign currency transfer on narrow screen',
    (t) async {
      t.view.physicalSize = const Size(375, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final l = await Ledger.load();
      await l.addAccount(Account(id: 'a', name: '人民币', openingCents: 10000));
      await l.addAccount(
        Account(id: 'b', name: '港币', currency: 'HKD', openingCents: 0),
      );
      await l.addEntry(
        Entry(
          id: 'e',
          accountId: 'a',
          cents: 100,
          income: false,
          category: '餐饮',
          note: '',
          date: DateTime(2026, 11, 1),
        ),
      );
      await t.pumpWidget(const FinanceApp());
      await t.pumpAndSettle();
      await t.tap(find.text('餐饮').first);
      await t.pumpAndSettle();
      expect(find.text('编辑账单'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, '金额'), '2');
      await t.ensureVisible(find.text('保存账单'));
      await t.tap(find.text('保存账单'));
      await t.pumpAndSettle();
      expect((await Ledger.load()).balance('a'), 9800);
      await t.tap(find.byTooltip('账户转账'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, '转出金额'), '10');
      await t.enterText(
        find.widgetWithText(TextFormField, '实际到账金额（转入币种）'),
        '11',
      );
      await t.ensureVisible(find.text('保存转账'));
      await t.tap(find.text('保存转账'));
      await t.pumpAndSettle();
      final updated = await Ledger.load();
      expect(updated.balance('a'), 8800);
      expect(updated.balance('b'), 1100);
    },
  );
}
