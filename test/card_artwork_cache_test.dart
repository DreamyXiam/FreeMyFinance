import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:free_my_finance/card_artwork_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'selected artwork remains on disk for 30 days and then refreshes',
    () async {
      final directory = await Directory('build/test_card_artwork_cache')
          .create(recursive: true);
      addTearDown(() => directory.delete(recursive: true));
      var now = DateTime.utc(2026, 1, 1);
      var downloads = 0;
      final client = MockClient((_) async {
        downloads++;
        return http.Response.bytes(
          [0x89, 0x50, 0x4e, 0x47, downloads],
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      final cache = CardArtworkCache(
        directory: () async => directory,
        client: client,
        now: () => now,
      );
      final first = await cache.get('https://aircards.org/originals/card.png');
      expect(first, isNotNull);
      expect(await first!.exists(), isTrue);
      now = now.add(const Duration(days: 29));
      final reopened = CardArtworkCache(
        directory: () async => directory,
        client: client,
        now: () => now,
      );
      final same = await reopened.get(
        'https://aircards.org/originals/card.png',
      );
      expect(same!.path, first.path);
      expect(downloads, 1);

      now = now.add(const Duration(days: 1));
      final refreshed = await reopened.get(
        'https://aircards.org/originals/card.png',
      );
      expect(downloads, 2);
      expect(refreshed!.path, isNot(first.path));
      expect(await first.exists(), isFalse);
    },
  );

  test(
    'different URLs have separate files; failed downloads are not cached',
    () async {
      final directory = await Directory('build/test_card_artwork_isolation')
          .create(recursive: true);
      addTearDown(() => directory.delete(recursive: true));
      final cache = CardArtworkCache(
        directory: () async => directory,
        client: MockClient((request) async {
          if (request.url.path.endsWith('bad.png')) {
            return http.Response('not found', 404);
          }
          return http.Response.bytes(
            [0x89, 0x50, 0x4e, 0x47],
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      final one = await cache.get('https://aircards.org/a.png');
      final two = await cache.get('https://aircards.org/b.png');
      expect(one!.path, isNot(two!.path));
      expect(await cache.get('https://aircards.org/bad.png'), isNull);
      expect(await cache.get('http://aircards.org/a.png'), isNull);
    },
  );
}
