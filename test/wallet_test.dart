import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/main.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  testWidgets(
    'wallet opens from accounts and vertical swipe changes selected card',
    (t) async {
      t.view.physicalSize = const Size(375, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final l = await Ledger.load();
      for (var i = 0; i < 3; i++) {
        await l.addAccount(
          Account(id: '$i', name: '测试账户$i', openingCents: 100),
        );
      }
      await t.pumpWidget(const FinanceApp());
      await t.pumpAndSettle();
      await t.tap(find.text('账户').last);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('打开卡包'));
      await t.pumpAndSettle();
      expect(find.text('卡包'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      await t.drag(
        find.byKey(const ValueKey('wallet-stack')),
        const Offset(0, -170),
      );
      await t.pumpAndSettle();
      expect(find.text('1 / 3'), findsNothing);
      expect(find.textContaining(' / 3'), findsOneWidget);
    },
  );
}
