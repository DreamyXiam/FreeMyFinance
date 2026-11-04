import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AuthCheck = Future<bool> Function();

class LockController extends ChangeNotifier {
  final AuthCheck authenticate;
  bool enabled = false, locked = true, ready = false, authenticating = false;
  String? error;
  LockController({AuthCheck? authenticate})
    : authenticate =
          authenticate ??
          (() => LocalAuthentication().authenticate(
            localizedReason: '请验证身份以访问 FreeMyFinance',
          ));
  Future<void> initialize() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled = p.getBool('app_lock_enabled') ?? false;
      locked = enabled;
      error = null;
    } catch (_) {
      error = '无法读取应用锁状态';
      locked = true;
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> _check() async {
    if (authenticating) return false;
    authenticating = true;
    notifyListeners();
    try {
      return await authenticate();
    } catch (_) {
      return false;
    } finally {
      authenticating = false;
      notifyListeners();
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (!await _check()) return false;
    try {
      final p = await SharedPreferences.getInstance();
      if (!await p.setBool('app_lock_enabled', value)) return false;
      enabled = value;
      locked = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock() async {
    if (!await _check()) return false;
    locked = false;
    notifyListeners();
    return true;
  }

  void lock() {
    if (enabled && !authenticating) {
      locked = true;
      notifyListeners();
    }
  }
}
