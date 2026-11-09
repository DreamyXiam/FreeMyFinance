import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:free_my_finance/remote_rates.dart';

void main() {
  test(
    'fetches all rates via POST, rounds precisely, returns source update time',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        final from = r.bodyFields['from'];
        return http.Response(
          jsonEncode({
            'code': 200,
            'from': from,
            'to': 'CNY',
            'money': '1',
            'rate': from == 'HKD' ? '0.8521426568435' : '7.1234567',
            'uptime': '2026-11-05 08:00:01',
          }),
          200,
        );
      });
      final result = await RemoteRateClient(client)
          .fetch('12345678', 'private-key');
      expect(result.rates['HKD'], 852143);
      expect(result.rates['USD'], 7123457);
      expect(result.providerTime, '2026-11-05 08:00:01');
      expect(requests, hasLength(4));
      for (final r in requests) {
        expect(r.method, 'POST');
        expect(r.url.query, isEmpty);
        expect(r.bodyFields['money'], '1');
      }
    },
  );
  test('rejects service errors and mismatched currencies', () async {
    final client = MockClient(
      (r) async => http.Response(
        jsonEncode({
          'code': 200,
          'from': 'BAD',
          'to': 'CNY',
          'rate': '1',
          'uptime': '2026-11-05 08:00:01',
        }),
        200,
      ),
    );
    await expectLater(
      RemoteRateClient(client).fetch('12345678', 'key'),
      throwsFormatException,
    );
  });
}
