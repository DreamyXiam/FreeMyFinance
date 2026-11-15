import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Keeps selected account artwork across launches for up to 30 days.
class CardArtworkCache {
  CardArtworkCache({
    Future<Directory> Function()? directory,
    http.Client? client,
    DateTime Function()? now,
  }) : _directory = directory ?? _defaultDirectory,
       _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  static final instance = CardArtworkCache();
  static const lifetime = Duration(days: 30);
  static const _maximumBytes = 10 * 1024 * 1024;

  final Future<Directory> Function() _directory;
  final http.Client _client;
  final DateTime Function() _now;
  final Map<String, Future<File?>> _pending = {};

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}card_artwork_cache',
    );
  }

  Future<File?> get(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return Future.value(null);
    }
    return _pending.putIfAbsent(url, () async {
      try {
        return await _load(uri);
      } catch (_) {
        return null;
      } finally {
        _pending.remove(url);
      }
    });
  }

  Future<File?> _load(Uri uri) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final digest = await Sha256().hash(utf8.encode(uri.toString()));
    final key = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    File? cached;
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.endsWith('.img')) continue;
      final modified = (await entry.stat()).modified;
      final age = _now().difference(modified);
      if (age.isNegative || age >= lifetime) {
        await entry.delete();
      } else if (entry.uri.pathSegments.last.startsWith('$key-')) {
        cached = entry;
      }
    }
    if (cached != null) return cached;

    final response = await _client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 ||
        !(response.headers['content-type'] ?? '').toLowerCase().startsWith(
          'image/',
        )) {
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 12),
    )) {
      if (bytes.length + chunk.length > _maximumBytes) return null;
      bytes.add(chunk);
    }
    if (bytes.length < 4) return null;

    final file = File(
      '${directory.path}${Platform.pathSeparator}$key-${_now().millisecondsSinceEpoch}.img',
    );
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes.takeBytes(), flush: true);
      await temporary.rename(file.path);
      await file.setLastModified(_now());
      return file;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
