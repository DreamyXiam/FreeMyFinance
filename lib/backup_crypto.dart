import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const _format = 'FreeMyFinanceEncrypted';
const _iterations = 210000;
final _cipher = AesGcm.with256bits();
final _kdf = Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: _iterations,
  bits: 256,
);
List<int> _randomBytes(int count) {
  final r = Random.secure();
  return List.generate(count, (_) => r.nextInt(256));
}

Future<String> encryptBackup(String data, String password) async {
  if (password.length < 8) throw const FormatException('密码至少 8 个字符');
  final salt = _randomBytes(16), nonce = _randomBytes(12);
  final key = await _kdf.deriveKeyFromPassword(password: password, nonce: salt);
  final box = await _cipher.encrypt(
    utf8.encode(data),
    secretKey: key,
    nonce: nonce,
    aad: utf8.encode('$_format:1'),
  );
  return jsonEncode({
    'format': _format,
    'version': 1,
    'kdf': 'PBKDF2-HMAC-SHA256',
    'iterations': _iterations,
    'cipher': 'AES-256-GCM',
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(box.cipherText),
    'tag': base64Encode(box.mac.bytes),
  });
}

Future<String> decryptBackup(String data, String password) async {
  try {
    final o = jsonDecode(data);
    if (o is! Map<String, dynamic> ||
        o['format'] != _format ||
        o['version'] != 1 ||
        o['iterations'] != _iterations ||
        o['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        o['cipher'] != 'AES-256-GCM') {
      throw const FormatException('加密备份格式无效');
    }
    final salt = base64Decode(o['salt'] as String),
        nonce = base64Decode(o['nonce'] as String),
        cipher = base64Decode(o['ciphertext'] as String),
        tag = base64Decode(o['tag'] as String);
    if (salt.length != 16 || nonce.length != 12 || tag.length != 16) {
      throw const FormatException('加密备份格式无效');
    }
    final key = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final plain = await _cipher.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(tag)),
      secretKey: key,
      aad: utf8.encode('$_format:1'),
    );
    return utf8.decode(plain);
  } catch (_) {
    throw const FormatException('密码错误或备份已损坏');
  }
}
