import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/main.dart';

void main() {
  testWidgets('create account and expense updates the balance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FinanceApp());
    await tester.pumpAndSettle();
    expect(find.text('还没有账单'), findsOneWidget);
    await tester.tap(find.byTooltip('添加账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('储蓄卡'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '账户名称'), '我的银行卡');
    await tester.enterText(
      find.widgetWithText(TextFormField, '初始余额（可为负）'),
      '100',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('¥ 100.00'), findsOneWidget);
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '金额'), '12.50');
    await tester.ensureVisible(find.text('保存账单'));
    await tester.tap(find.text('保存账单'));
    await tester.pumpAndSettle();
    expect(find.text('¥ 87.50'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
  });
  test('amount parsing uses exact cents', () {
    expect(parseAmount('12.3'), 1230);
    expect(parseAmount('0.01'), 1);
    expect(parseAmount('1.001'), isNull);
    expect(parseSignedAmount('-12.30'), -1230);
  });
}
