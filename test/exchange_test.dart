import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('manual exchange rates show a CNY estimate only when every currency has a rate', () async {
    SharedPreferences.setMockInitialValues({});
    final l = await Ledger.load();
    await l.addAccount(Account(id: 'a', name: 'CNY', openingCents: 100));
    await l.addAccount(
      Account(id: 'b', name: 'HKD', openingCents: 101, currency: 'HKD'),
    );
    expect(l.estimatedCnyCents(), isNull);
    await l.setManualRates({'HKD': 900000});
    expect(l.estimatedCnyCents(), 191);
    final copy = await Ledger.load();
    expect(copy.estimatedCnyCents(), 191);
    final backup = copy.exportBackup();
    await copy.setManualRates({});
    await copy.restoreBackup(backup);
    expect(copy.manualRates['HKD'], 900000);
    await copy.setManualRates(
      {'HKD': 852143},
      source: 'apihz',
      providerTime: '2026-11-05 08:00:01',
    );
    final fetched = await Ledger.load();
    expect(fetched.rateSource, 'apihz');
    expect(fetched.rateProviderTime, '2026-11-05 08:00:01');
    final remoteBackup = fetched.exportBackup();
    await fetched.setManualRates({});
    await fetched.restoreBackup(remoteBackup);
    expect(fetched.rateProviderTime, '2026-11-05 08:00:01');
    await fetched.setManualRates({'HKD': 900000});
    expect(fetched.rateSource, 'manual');
    expect(fetched.rateProviderTime, isNull);
    await expectLater(copy.setManualRates({'XYZ': 100}), throwsStateError);
  });
}
