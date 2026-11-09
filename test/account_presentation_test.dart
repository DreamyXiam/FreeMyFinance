import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('account presentation fields and exclusion survive backup', () async {
    SharedPreferences.setMockInitialValues({});
    final l = await Ledger.load();
    await l.addAccount(
      Account(
        id: 'a',
        name: '基金',
        openingCents: 50000,
        kind: 'fund',
        instrument: '000001',
        includeInNetWorth: false,
        showNoteOnCard: true,
        note: '定投',
      ),
    );
    expect(l.estimatedCnyCents(), 0);
    final restored = await Ledger.load();
    final a = restored.accounts.single;
    expect(a.kind, 'fund');
    expect(a.instrument, '000001');
    expect(a.includeInNetWorth, isFalse);
    expect(a.showNoteOnCard, isTrue);
    final backup = restored.exportBackup();
    await restored.restoreBackup(backup);
    expect(restored.accounts.single.instrument, '000001');
  });
}
