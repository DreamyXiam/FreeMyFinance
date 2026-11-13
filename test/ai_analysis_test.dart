import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:free_my_finance/ai_analysis.dart';
import 'package:free_my_finance/reports.dart';

void main() {
  test('sends only report aggregate and parses DeepSeek response', () async {
    late Map<String, dynamic> sent;
    final service = AiAnalysisService(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.deepseek.com/chat/completions',
        );
        expect(
          request.headers.entries
              .firstWhere((e) => e.key.toLowerCase() == 'authorization')
              .value,
          'Bearer secret',
        );
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '支出主要在餐饮。'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final summary = service.summary(
      report: Report(10000, 3000, {'餐饮': 3000}),
      year: 2026,
      month: 11,
      currency: 'CNY',
    );
    final answer = await service.analyze(
      apiKey: 'secret',
      summary: summary,
      prompt: '请分析这份月度账单',
    );
    expect(answer, '支出主要在餐饮。');
    expect(sent['model'], 'deepseek-flash');
    expect(jsonEncode(sent), contains('请分析这份月度账单'));
    expect(jsonEncode(sent), isNot(contains('secret')));
    expect(jsonEncode(sent), isNot(contains('cardRef')));
    expect(summary['expense_categories'], {'餐饮': 30.0});
    service.close();
  });

  test('reports authentication errors without leaking the key', () async {
    final service = AiAnalysisService(
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      service.analyze(apiKey: 'sensitive', summary: {}, prompt: '分析'),
      throwsA(
        isA<AiAnalysisException>().having(
          (e) => e.message,
          'message',
          isNot(contains('sensitive')),
        ),
      ),
    );
    service.close();
  });
}
