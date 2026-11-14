import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:free_my_finance/update_checker.dart';

void main() {
  test('only newer stable GitHub releases prompt an update', () async {
    final checker = UpdateChecker(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.github.com/repos/DreamyXiam/FreeMyFinance/releases/latest',
        );
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'tag_name': 'v1.1.0',
            'html_url': 'https://github.com/DreamyXiam/FreeMyFinance/releases/tag/v1.1.0',
            'body': '更新说明',
          })),
          200,
        );
      }),
    );
    expect((await checker.check('1.0.0'))?.version, '1.1.0');
    expect(await checker.check('1.1.0'), isNull);
    expect(await checker.check('2.0.0'), isNull);
    checker.close();
  });
}
