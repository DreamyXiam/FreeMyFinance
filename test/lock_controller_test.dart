import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/lock_controller.dart';

void main() {
  test('lock requires authentication to unlock or disable', () async {
    SharedPreferences.setMockInitialValues({});
    var allowed = true;
    final l = LockController(authenticate: () async => allowed);
    await l.initialize();
    expect(await l.setEnabled(true), isTrue);
    expect(l.enabled, isTrue);
    l.lock();
    expect(l.locked, isTrue);
    allowed = false;
    expect(await l.unlock(), isFalse);
    expect(l.locked, isTrue);
    expect(await l.setEnabled(false), isFalse);
    expect(l.enabled, isTrue);
    allowed = true;
    expect(await l.unlock(), isTrue);
    expect(l.locked, isFalse);
    expect(await l.setEnabled(false), isTrue);
    final fresh = LockController(authenticate: () async => true);
    await fresh.initialize();
    expect(fresh.enabled, isFalse);
  });
}
