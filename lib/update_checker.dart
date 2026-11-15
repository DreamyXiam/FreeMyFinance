import 'dart:convert';

import 'package:http/http.dart' as http;

const appVersion = '1.0.2';

enum UpdateSource { github, markdown }

const updateSourcePreferenceKey = 'update_source';

class AvailableUpdate {
  final String version, url, notes;
  const AvailableUpdate(this.version, this.url, this.notes);
}

class UpdateChecker {
  final http.Client client;
  UpdateChecker({http.Client? client}) : client = client ?? http.Client();

  static int _compare(String left, String right) {
    final a = left.replaceFirst(RegExp(r'^v'), '').split('.');
    final b = right.replaceFirst(RegExp(r'^v'), '').split('.');
    if (a.length != 3 || b.length != 3) throw const FormatException('版本号无效');
    for (var i = 0; i < 3; i++) {
      final difference = int.parse(a[i]).compareTo(int.parse(b[i]));
      if (difference != 0) return difference;
    }
    return 0;
  }

  Future<AvailableUpdate?> check(
    String installedVersion, {
    UpdateSource source = UpdateSource.github,
  }) async {
    final response = await client
        .get(
          Uri.https(
            'api.github.com',
            '/repos/DreamyXiam/FreeMyFinance/releases/latest',
          ),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw const FormatException('更新源不可用');
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final version = (data['tag_name'] as String).replaceFirst(
      RegExp(r'^v'),
      '',
    );
    final url = Uri.tryParse(data['html_url'] as String? ?? '');
    if (url == null || url.scheme != 'https' || url.host != 'github.com') {
      throw const FormatException('发布链接无效');
    }
    if (_compare(version, installedVersion) <= 0) return null;
    var downloadUrl = url.toString();
    if (source == UpdateSource.markdown) {
      final manifest = await client
          .get(
            Uri.https(
              'raw.githubusercontent.com',
              '/DreamyXiam/FreeMyFinance/main/update_sources.md',
            ),
          )
          .timeout(const Duration(seconds: 6));
      if (manifest.statusCode != 200 || manifest.bodyBytes.length > 16384) {
        throw const FormatException('备用更新源不可用');
      }
      final line = utf8
          .decode(manifest.bodyBytes)
          .split('\n')
          .firstWhere(
            (line) => line.trimLeft().startsWith('download_url:'),
            orElse: () => '',
          );
      final candidate = Uri.tryParse(line.split(':').skip(1).join(':').trim());
      if (candidate == null ||
          candidate.scheme != 'https' ||
          candidate.host.isEmpty ||
          candidate.userInfo.isNotEmpty) {
        throw const FormatException('备用更新链接必须是 HTTPS 地址');
      }
      downloadUrl = candidate.toString();
    }
    return AvailableUpdate(version, downloadUrl, data['body'] as String? ?? '');
  }

  void close() => client.close();
}
