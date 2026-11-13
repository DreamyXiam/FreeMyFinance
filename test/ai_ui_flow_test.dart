import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ai_analysis.dart';
import 'package:free_my_finance/ai_analysis_panel.dart';
import 'package:free_my_finance/ai_settings.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/reports.dart';

class FakeAiKeyStore extends AiKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async {
    value = key;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  testWidgets('AI settings save a key separately from the backed up prompt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    final keys = FakeAiKeyStore();
    await tester.pumpWidget(
      MaterialApp(
        home: AiSettingsPage(ledger: ledger, keyStore: keys),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '输入 API Key'),
      'private-key',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '希望 AI 如何分析账单？'),
      '只分析支出分类',
    );
    await tester.ensureVisible(find.text('保存设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(keys.value, 'private-key');
    expect((await Ledger.load()).aiPrompt, '只分析支出分类');
    expect(ledger.exportBackup(), isNot(contains('private-key')));
    expect(find.text('已在此设备安全保存'), findsOneWidget);
    await tester.ensureVisible(find.text('删除已保存的 Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除已保存的 Key'));
    await tester.pumpAndSettle();
    expect(keys.value, isNull);
  });

  testWidgets('analysis uses preset prompt and adds viewable history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    final keys = FakeAiKeyStore()..value = 'private-key';
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(jsonEncode(body), contains(defaultAiAnalysisPrompt));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '本月餐饮支出较高。'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAnalysisPanel(
            ledger: ledger,
            report: Report(10000, 2500, {'餐饮': 2500}),
            year: 2026,
            month: 11,
            currency: 'CNY',
            singleAccount: false,
            keyStore: keys,
            serviceFactory: () => AiAnalysisService(client: client),
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始分析'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请根据所选期间的账单汇总'), findsOneWidget);
    await tester.tap(find.text('发送并分析'));
    await tester.pumpAndSettle();
    expect(ledger.aiHistory.single.response, '本月餐饮支出较高。');
    await tester.tap(find.text('历史记录 (1)'));
    await tester.pumpAndSettle();
    expect(find.text('2026-11 · CNY'), findsOneWidget);
    await tester.tap(find.text('2026-11 · CNY'));
    await tester.pumpAndSettle();
    expect(find.text('本月餐饮支出较高。'), findsOneWidget);
    expect(find.text('使用的提示词'), findsOneWidget);
  });
}
