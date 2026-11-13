import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/be_tools_menu.dart';

void main() {
  testWidgets(
    'tools menu exposes all actions and returns the selected action',
    (t) async {
      String? result;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async {
                  result = await showBeToolsMenu(c);
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('打开'));
      await t.pumpAndSettle();
      expect(find.text('工具与设置'), findsOneWidget);
      expect(find.text('周期账单'), findsOneWidget);
      expect(find.text('AI 分析设置'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('恢复备份'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await t.ensureVisible(find.text('恢复备份'));
      await t.pumpAndSettle();
      await t.tap(find.text('恢复备份'));
      await t.pumpAndSettle();
      expect(result, 'import');
    },
  );
}
