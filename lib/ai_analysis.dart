import 'dart:convert';

import 'package:http/http.dart' as http;

import 'reports.dart';

class AiAnalysisException implements Exception {
  final String message;
  const AiAnalysisException(this.message);
  @override
  String toString() => message;
}

class AiAnalysisService {
  final http.Client client;
  AiAnalysisService({http.Client? client}) : client = client ?? http.Client();

  Map<String, dynamic> summary({
    required Report report,
    required int year,
    required int? month,
    required String currency,
  }) => {
    'period': month == null
        ? '$year'
        : '$year-${month.toString().padLeft(2, '0')}',
    'currency': currency,
    'income': report.income / 100,
    'expenses': report.expenses / 100,
    'net': (report.income - report.expenses) / 100,
    'expense_categories': {
      for (final e in report.categories.entries) e.key: e.value / 100,
    },
  };

  Future<String> analyze({
    required String apiKey,
    required Map<String, dynamic> summary,
    required String prompt,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiAnalysisException('请先填写 DeepSeek API Key');
    }
    if (prompt.trim().isEmpty || prompt.length > 2000) {
      throw const AiAnalysisException('请填写不超过 2000 字的分析提示词');
    }
    late http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('https://api.deepseek.com/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'deepseek-flash',
              'stream': false,
              'max_tokens': 900,
              'messages': [
                {
                  'role': 'system',
                  'content': '你是个人记账数据分析助手。仅依据提供的汇总数据回答；不要推断身份、编造趋势或提供投资建议。',
                },
                {
                  'role': 'user',
                  'content': '${prompt.trim()}\n\n账单汇总：${jsonEncode(summary)}',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
    } on Exception {
      throw const AiAnalysisException('连接 DeepSeek 失败，请检查网络后重试');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiAnalysisException('API Key 无效或没有访问权限');
    }
    if (response.statusCode == 429) {
      throw const AiAnalysisException('请求过于频繁，请稍后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiAnalysisException('DeepSeek 请求失败（${response.statusCode}）');
    }
    try {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = body['choices'] as List;
      final content =
          (choices.first as Map<String, dynamic>)['message']['content']
              as String?;
      if (content == null || content.trim().isEmpty) {
        throw const FormatException();
      }
      return content.trim();
    } catch (_) {
      throw const AiAnalysisException('DeepSeek 返回内容为空或格式不正确');
    }
  }

  void close() => client.close();
}
