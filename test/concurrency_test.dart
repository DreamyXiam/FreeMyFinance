import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';

void main() {
  test('overlapping changes do not silently discard an account', () async {
    SharedPreferences.setMockInitialValues({});
    final l = await Ledger.load();
    final outcomes = await Future.wait([
      l
          .addAccount(Account(id: '1', name: 'A', openingCents: 0))
          .then((_) => true, onError: (_) => false),
      l
          .addAccount(Account(id: '2', name: 'B', openingCents: 0))
          .then((_) => true, onError: (_) => false),
    ]);
    expect(
      (await Ledger.load()).accounts.length,
      outcomes.where((v) => v).length,
    );
  });
}
