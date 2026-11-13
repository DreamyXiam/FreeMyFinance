import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/main.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  testWidgets(
    'credit account editor saves only the last four digits and optional billing metadata',
    (t) async {
      t.view.physicalSize = const Size(375, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(const FinanceApp());
      await t.pumpAndSettle();
      await t.tap(find.text('账户').last);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('添加账户'));
      await t.pumpAndSettle();
      expect(find.text('选择账户分类'), findsOneWidget);
      await t.tap(find.text('信用卡'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, '账户名称'), '信用卡测试');
      await t.enterText(
        find.widgetWithText(TextFormField, '初始余额（负数代表欠款）'),
        '-100',
      );
      final tail = find.widgetWithText(TextFormField, '卡号尾号（选填）');
      await t.ensureVisible(tail);
      await t.enterText(tail, '12345678');
      await t.tap(find.text('保存').first);
      await t.pumpAndSettle();
      expect((await Ledger.load()).accounts, isEmpty);
      expect(find.text('请输入四位数字'), findsOneWidget);
      await t.enterText(tail, '1234');
      final expiry = find.widgetWithText(TextFormField, '有效期（选填）');
      await t.ensureVisible(expiry);
      await t.enterText(expiry, '09/2029');
      final limit = find.widgetWithText(TextFormField, '信用额度（选填）');
      await t.ensureVisible(limit);
      await t.enterText(limit, '5000');
      await t.tap(find.text('保存').first);
      await t.pumpAndSettle();
      final a = (await Ledger.load()).accounts.single;
      expect(a.kind, 'credit');
      expect(a.lastFour, '1234');
      expect(a.expiry, '09/2029');
      expect(a.creditLimitCents, 500000);
      expect(a.openingCents, -10000);
    },
  );
}
