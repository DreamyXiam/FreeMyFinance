import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('AI prompt and analysis history survive reload and backup', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    expect(ledger.aiPrompt, contains('支出'));
    await ledger.setAiPrompt('分析餐饮开支并提出建议');
    final record = AiAnalysisRecord(
      id: 'analysis-1',
      createdAt: DateTime(2026, 11, 13, 18, 0),
      period: '2026-11',
      currency: 'CNY',
      scope: '全部账户',
      prompt: ledger.aiPrompt,
      summary: '{"income":100,"expenses":20}',
      response: '餐饮占支出较高。',
    );
    await ledger.addAiAnalysis(record);
    final reloaded = await Ledger.load();
    expect(reloaded.aiPrompt, '分析餐饮开支并提出建议');
    expect(reloaded.aiHistory.single.response, '餐饮占支出较高。');
    final backup = reloaded.exportBackup();
    await reloaded.deleteAiAnalysis('analysis-1');
    expect(reloaded.aiHistory, isEmpty);
    await reloaded.restoreBackup(backup);
    expect(reloaded.aiHistory.single.prompt, '分析餐饮开支并提出建议');
    final invalid = jsonDecode(backup) as Map<String, dynamic>;
    invalid['aiHistory'][0]['response'] = 3;
    await expectLater(
      reloaded.restoreBackup(jsonEncode(invalid)),
      throwsFormatException,
    );
    expect(reloaded.aiHistory.single.response, '餐饮占支出较高。');
  });

  test('old backup starts with default AI prompt and empty history', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    final old = jsonDecode(ledger.exportBackup()) as Map<String, dynamic>;
    old['version'] = 10;
    old.remove('aiPrompt');
    old.remove('aiHistory');
    await ledger.restoreBackup(jsonEncode(old));
    expect(ledger.aiPrompt, contains('收入'));
    expect(ledger.aiHistory, isEmpty);
  });
}
