import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteRates {
  final Map<String, int> rates;
  final String providerTime;
  const RemoteRates(this.rates, this.providerTime);
}

class RemoteRateClient {
  final http.Client client;
  RemoteRateClient(this.client);
  static const _currencies = ['HKD', 'USD', 'EUR', 'GBP'];
  static int _toMicros(Object? raw) {
    final text = raw.toString().trim();
    final match = RegExp(r'^(\d{1,4})(?:\.(\d{1,20}))?$').firstMatch(text);
    if (match == null) throw const FormatException('汇率格式无效');
    final whole = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(7, '0');
    final micros =
        whole * 1000000 +
        int.parse(fraction.substring(0, 6)) +
        (int.parse(fraction[6]) >= 5 ? 1 : 0);
    if (micros <= 0 || micros > 1000000000) {
      throw const FormatException('汇率超出范围');
    }
    return micros;
  }

  Future<RemoteRates> fetch(String id, String key) async {
    if (!RegExp(r'^\d{1,20}$').hasMatch(id) ||
        key.isEmpty ||
        key.length > 256) {
      throw const FormatException('请填写有效的用户 ID 和密钥');
    }
    final result = <String, int>{};
    final times = <String>[];
    for (final currency in _currencies) {
      final response = await client
          .post(
            Uri.https('cn.apihz.cn', '/api/jinrong/huilv.php'),
            body: {
              'id': id,
              'key': key,
              'from': currency,
              'to': 'CNY',
              'money': '1',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw const FormatException('汇率服务暂不可用');
      final data = jsonDecode(response.body);
      if (data is! Map ||
          data['code'] != 200 ||
          data['from'] != currency ||
          data['to'] != 'CNY') {
        throw const FormatException('汇率服务返回无效结果');
      }
      final time = data['uptime'];
      if (time is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(time)) {
        throw const FormatException('汇率更新时间无效');
      }
      result[currency] = _toMicros(data['rate']);
      times.add(time);
    }
    times.sort();
    return RemoteRates(result, times.first);
  }
}
