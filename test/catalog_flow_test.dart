import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/main.dart';

void main() {
  testWidgets('account editor selects a card through the catalog', (t) async {
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
    await t.tap(find.text('储蓄卡'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('从卡面库选择'));
    await t.tap(find.text('从卡面库选择'));
    await t.pump(const Duration(milliseconds: 400));
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('选择卡面'), findsOneWidget);
    expect(find.textContaining('780 张卡面'), findsOneWidget);
    await t.tap(find.text('卡组织'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, '搜索卡组织'), 'VISA');
    await t.pumpAndSettle();
    await t.tap(find.text('VISA').last);
    await t.pumpAndSettle();
    expect(find.text('卡组织：VISA'), findsOneWidget);
    await t.ensureVisible(find.text('ANZ Access Visa Debit').first);
    await t.tap(find.text('ANZ Access Visa Debit').first);
    await t.pumpAndSettle();
    final image = t.widget<TextFormField>(
      find.widgetWithText(TextFormField, '卡面图片 HTTPS 地址（选填）'),
    );
    expect(
      image.controller!.text,
      startsWith('https://aircards.org/originals/'),
    );
  });
}
