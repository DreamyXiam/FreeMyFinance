import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/ledger_store.dart';

class FakeVault implements KeyVault {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async {
    if (fail) throw StateError('vault failed');
    value = key;
  }
}

void main() {
  test(
    'encryption migrates only after key and ciphertext verify, survives reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final vault = FakeVault();
      final l = await Ledger.load(vault: vault);
      await l.addAccount(Account(id: 'a', name: '隐私账户', openingCents: 123));
      vault.fail = true;
      await expectLater(l.enableLocalEncryption(), throwsStateError);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('ledger_v1'), contains('隐私账户'));
      expect(l.localEncryptionEnabled, isFalse);
      vault.fail = false;
      await l.enableLocalEncryption();
      expect(l.localEncryptionEnabled, isTrue);
      expect(p.getString('ledger_v1'), isNull);
      expect(p.getString('ledger_encrypted_v1'), isNot(contains('隐私账户')));
      final restored = await Ledger.load(vault: vault);
      expect(restored.accounts.single.name, '隐私账户');
      await restored.addEntry(
        Entry(
          id: 'e',
          accountId: 'a',
          cents: 23,
          income: false,
          category: '餐饮',
          note: '',
          date: DateTime(2026),
        ),
      );
      expect((await Ledger.load(vault: vault)).balance('a'), 100);
      expect(p.getString('ledger_v1'), isNull);
      expect(p.getString('ledger_encrypted_v1'), isNot(contains('餐饮')));
      final original = p.getString('ledger_encrypted_v1')!;
      final envelope = jsonDecode(original) as Map<String, dynamic>;
      final cipher = base64Decode(envelope['ciphertext']);
      cipher[0] ^= 1;
      envelope['ciphertext'] = base64Encode(cipher);
      await p.setString('ledger_encrypted_v1', jsonEncode(envelope));
      await expectLater(Ledger.load(vault: vault), throwsStateError);
      await p.setString('ledger_encrypted_v1', original);
      vault.value = null;
      await expectLater(Ledger.load(vault: vault), throwsStateError);
    },
  );
}
