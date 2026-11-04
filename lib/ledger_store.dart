import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class KeyVault {
  Future<String?> read();
  Future<void> write(String value);
}

class DeviceKeyVault implements KeyVault {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: 'freemyfinance_ledger_key_v1');
  @override
  Future<void> write(String value) =>
      _storage.write(key: 'freemyfinance_ledger_key_v1', value: value);
}

class LedgerStore {
  final SharedPreferences prefs;
  final KeyVault vault;
  LedgerStore(this.prefs, this.vault);
  static const _plain = 'ledger_v1',
      _encrypted = 'ledger_encrypted_v1',
      _active = 'ledger_encryption_enabled';
  bool get encrypted => prefs.getBool(_active) ?? false;
  bool get encryptionVerified => encrypted && !prefs.containsKey(_plain);
  final _aes = AesGcm.with256bits();
  Future<SecretKey> _key() async {
    final raw = await vault.read();
    if (raw == null) throw StateError('设备加密密钥不可用，请使用导出的备份恢复');
    try {
      final data = base64Decode(raw);
      if (data.length != 32) throw const FormatException();
      return SecretKey(data);
    } catch (_) {
      throw StateError('设备加密密钥无效，请使用导出的备份恢复');
    }
  }

  Future<String> _seal(String text, SecretKey key) async {
    final box = await _aes.encrypt(
      utf8.encode(text),
      secretKey: key,
      aad: utf8.encode('FreeMyFinance-ledger:1'),
    );
    return jsonEncode({
      'version': 1,
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    });
  }

  Future<String> _open(String raw, SecretKey key) async {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['version'] != 1) throw const FormatException();
      final nonce = base64Decode(j['nonce'] as String),
          cipher = base64Decode(j['ciphertext'] as String),
          tag = base64Decode(j['tag'] as String);
      if (nonce.length != 12 || tag.length != 16) throw const FormatException();
      return utf8.decode(
        await _aes.decrypt(
          SecretBox(cipher, nonce: nonce, mac: Mac(tag)),
          secretKey: key,
          aad: utf8.encode('FreeMyFinance-ledger:1'),
        ),
      );
    } catch (_) {
      throw StateError('加密账本无法读取，请使用导出的备份恢复');
    }
  }

  Future<String?> read() async {
    if (!encrypted) return prefs.getString(_plain);
    final raw = prefs.getString(_encrypted);
    if (raw == null) throw StateError('加密账本不存在，请使用导出的备份恢复');
    final text = await _open(raw, await _key());
    if (prefs.containsKey(_plain) && !await prefs.remove(_plain)) {
      throw StateError('旧账本副本无法清理，请先导出备份');
    }
    return text;
  }

  Future<void> write(String text) async {
    if (encrypted) {
      final raw = await _seal(text, await _key());
      if (!await prefs.setString(_encrypted, raw)) throw StateError('保存失败');
    } else if (!await prefs.setString(_plain, text)) {
      throw StateError('保存失败');
    }
  }

  Future<void> enable(String text) async {
    if (encrypted) {
      await read();
      return;
    }
    final random = Random.secure();
    final encoded = base64Encode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await vault.write(encoded);
    if (await vault.read() != encoded) throw StateError('设备加密密钥验证失败');
    final key = await _key(), raw = await _seal(text, key);
    if (!await prefs.setString(_encrypted, raw)) throw StateError('加密副本保存失败');
    final saved = prefs.getString(_encrypted);
    if (saved == null || await _open(saved, key) != text) {
      throw StateError('加密副本验证失败');
    }
    if (!await prefs.setBool(_active, true)) throw StateError('加密设置保存失败');
    if (prefs.containsKey(_plain) && !await prefs.remove(_plain)) {
      throw StateError('旧账本副本无法清理，请先导出备份');
    }
  }
}
