import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:free_my_finance/account_editor.dart';
import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/card_number_store.dart';

class FakeStore implements CardNumberStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String r) async => values[r];
  @override
  Future<void> write(String r, String v) async {
    values[r] = v;
  }

  @override
  Future<void> delete(String r) async {
    values.remove(r);
  }
}

void main() {
  testWidgets('card number field saves securely and is absent from backup', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ledger = await Ledger.load();
    final store = FakeStore();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => AccountEditorPage(
                    ledger: ledger,
                    kind: 'debit',
                    cardStore: store,
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('打开'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, '账户名称'), '银行卡');
    final number = find.widgetWithText(TextFormField, '完整卡号（选填）');
    await t.ensureVisible(number);
    await t.enterText(number, '4111111111111111');
    await t.tap(find.text('保存').first);
    await t.pumpAndSettle();
    final a = ledger.accounts.single;
    expect(a.lastFour, '1111');
    expect(await store.read(a.cardRef), '4111111111111111');
    expect(ledger.exportBackup(), isNot(contains('4111111111111111')));
  });
}
