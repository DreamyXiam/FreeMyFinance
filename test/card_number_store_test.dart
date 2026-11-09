import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/card_number_store.dart';

class FakeCardStore implements CardNumberStore {
  final map = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String id) async => map[id];
  @override
  Future<void> write(String id, String value) async {
    if (fail) throw StateError('store');
    map[id] = value;
  }

  @override
  Future<void> delete(String id) async {
    map.remove(id);
  }
}

void main() {
  test('full card number is stored outside the ledger and rolled back if ledger fails', () async {
    SharedPreferences.setMockInitialValues({});
    final l = await Ledger.load();
    final store = FakeCardStore();
    final service = AccountWriter(l, store);
    final a = Account(
      id: 'a',
      name: '卡',
      openingCents: 0,
      kind: 'debit',
      lastFour: '1111',
    );
    final saved = await service.save(a, cardNumber: '4111111111111111');
    expect(await store.read(saved.cardRef), '4111111111111111');
    expect(l.exportBackup(), isNot(contains('4111111111111111')));
    final invalid = Account(
      id: 'a',
      name: '卡',
      openingCents: 0,
      kind: 'debit',
      currency: 'INVALID',
      lastFour: '4444',
      cardRef: saved.cardRef,
    );
    await expectLater(
      service.save(invalid, cardNumber: '5555555555554444', update: true),
      throwsStateError,
    );
    expect(store.map.length, 1);
    expect(await store.read(saved.cardRef), '4111111111111111');

    await expectLater(
      service.save(a, cardNumber: '5555555555554444'),
      throwsStateError,
    );
    expect(await store.read(saved.cardRef), '4111111111111111');
    await service.delete(saved);
    expect(await store.read(saved.cardRef), isNull);
    expect(l.accounts, isEmpty);
  });
}
