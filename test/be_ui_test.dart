import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/be_ui.dart';

void main() {
  testWidgets('navigation shows the selected section and responds to taps', (
    t,
  ) async {
    var selected = 0;
    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: BeNavigationBar(
              selectedIndex: selected,
              onSelected: (i) => setState(() => selected = i),
            ),
          ),
        ),
      ),
    );
    expect(find.text('概览'), findsOneWidget);
    await t.tap(find.text('账户'));
    await t.pumpAndSettle();
    expect(selected, 2);
    expect(
      t.getSemantics(find.text('账户')),
      matchesSemantics(
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        label: '账户',
      ),
    );
  });
  testWidgets('balance card keeps long balances legible on narrow screens', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BeBalanceCard(
            currency: 'CNY',
            balance: '¥ 999999999999.99',
            income: '¥ 1.00',
            expense: '¥ 0.00',
            currencies: const ['CNY'],
            onCurrencyChanged: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('¥ 999999999999.99'), findsOneWidget);
  });
}
