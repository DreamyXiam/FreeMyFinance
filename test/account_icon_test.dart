import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test(
    'account icon is independent from card image and survives backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = await Ledger.load();
      await ledger.addAccount(
        Account(
          id: 'a',
          name: '中国银行',
          openingCents: 0,
          imageUrl: 'https://example.com/card.png',
          iconPngBase64: base64Encode([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
      );
      final other = await Ledger.load();
      expect(other.accounts.single.iconPngBase64, isNotEmpty);
      expect(other.accounts.single.imageUrl, 'https://example.com/card.png');
      await other.restoreBackup(ledger.exportBackup());
      expect(
        other.accounts.single.iconPngBase64,
        ledger.accounts.single.iconPngBase64,
      );
      final malformed =
          jsonDecode(ledger.exportBackup()) as Map<String, dynamic>;
      (malformed['accounts'] as List).first['iconPngBase64'] = 'not-png';
      await expectLater(
        other.restoreBackup(jsonEncode(malformed)),
        throwsFormatException,
      );
      expect(
        other.accounts.single.iconPngBase64,
        ledger.accounts.single.iconPngBase64,
      );
      final old = jsonDecode(ledger.exportBackup()) as Map<String, dynamic>;
      old['version'] = 11;
      (old['accounts'] as List).first.remove('iconPngBase64');
      await other.restoreBackup(jsonEncode(old));
      expect(other.accounts.single.iconPngBase64, isEmpty);
    },
  );
}
