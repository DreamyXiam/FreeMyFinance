import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:free_my_finance/update_checker.dart';

void main() {
  test(
    'alternative source reads a download URL from the repository Markdown',
    () async {
      final checker = UpdateChecker(
        client: MockClient((request) async {
          if (request.url.host == 'api.github.com') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'tag_name': 'v1.0.3',
                  'html_url': 'https://github.com/DreamyXiam/FreeMyFinance/releases/tag/v1.0.3',
                  'body': '修复说明',
                }),
              ),
              200,
            );
          }
          expect(
            request.url.path,
            '/DreamyXiam/FreeMyFinance/main/update_sources.md',
          );
          return http.Response.bytes(
            utf8.encode(
              '''# 下载源\n\ndownload_url: https://example.com/app-1.0.3.apk\n''',
            ),
            200,
          );
        }),
      );
      final update = await checker.check(
        '1.0.2',
        source: UpdateSource.markdown,
      );
      expect(update?.version, '1.0.3');
      expect(update?.url, 'https://example.com/app-1.0.3.apk');
      checker.close();
    },
  );

  test(
    'alternative source rejects an unsafe or missing download URL',
    () async {
      final checker = UpdateChecker(
        client: MockClient((request) async {
          if (request.url.host == 'api.github.com') {
            return http.Response(
              jsonEncode({
                'tag_name': 'v1.0.3',
                'html_url': 'https://github.com/DreamyXiam/FreeMyFinance/releases/tag/v1.0.3',
              }),
              200,
            );
          }
          return http.Response('download_url: http://example.com/app.apk', 200);
        }),
      );
      expect(
        () => checker.check('1.0.2', source: UpdateSource.markdown),
        throwsFormatException,
      );
      checker.close();
    },
  );

  test('only newer stable GitHub releases prompt an update', () async {
    final checker = UpdateChecker(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.github.com/repos/DreamyXiam/FreeMyFinance/releases/latest',
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'tag_name': 'v1.1.0',
              'html_url': 'https://github.com/DreamyXiam/FreeMyFinance/releases/tag/v1.1.0',
              'body': '更新说明',
            }),
          ),
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
