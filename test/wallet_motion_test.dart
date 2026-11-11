import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/wallet.dart';

void main() {
  testWidgets(
    'wallet cards visibly move while dragging and settle on a selected card',
    (t) async {
      t.view.physicalSize = const Size(375, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      for (var i = 0; i < 4; i++) {
        await ledger.addAccount(
          Account(id: '$i', name: '测试$i', openingCents: 100),
        );
      }
      await t.pumpWidget(MaterialApp(home: WalletPage(ledger: ledger)));
      await t.pumpAndSettle();
      final first = find.byKey(const ValueKey('wallet-card-0'));
      final before = t.getTopLeft(first);
      final gesture = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('wallet-stack'))),
      );
      await gesture.moveBy(const Offset(0, -20));
      await t.pump();
      await gesture.moveBy(const Offset(0, -90));
      await t.pump();
      expect(t.getTopLeft(first).dy, lessThan(before.dy));
      await gesture.up();
      await t.pumpAndSettle();
      expect(find.text('1 / 4'), findsNothing);
    },
  );
}
