import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/backup_crypto.dart';

void main() {
  test(
    'encrypted backup authenticates password and detects tampering',
    () async {
      const source = '{"账单":"秘密内容"}';
      final encoded = await encryptBackup(
        source,
        'correct horse battery staple',
      );
      expect(encoded, isNot(contains('秘密内容')));
      expect(
        await decryptBackup(encoded, 'correct horse battery staple'),
        source,
      );
      await expectLater(
        decryptBackup(encoded, 'wrong passphrase'),
        throwsA(isA<FormatException>()),
      );
      final changed = encoded.replaceFirst(
        'FreeMyFinanceEncrypted',
        'FreeMyFinanceXncrypted',
      );
      await expectLater(
        decryptBackup(changed, 'correct horse battery staple'),
        throwsA(isA<FormatException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
