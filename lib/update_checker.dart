import 'dart:convert';

import 'package:http/http.dart' as http;

const appVersion = '1.0.0';

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

  Future<AvailableUpdate?> check(String installedVersion) async {
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
    return AvailableUpdate(
      version,
      url.toString(),
      data['body'] as String? ?? '',
    );
  }

  void close() => client.close();
}
