import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ledger.dart';

abstract interface class CardNumberStore {
  Future<String?> read(String reference);
  Future<void> write(String reference, String value);
  Future<void> delete(String reference);
}

class SecureCardNumberStore implements CardNumberStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _key(String ref) => 'freemyfinance_card_$ref';
  @override
  Future<String?> read(String reference) => _storage.read(key: _key(reference));
  @override
  Future<void> write(String reference, String value) =>
      _storage.write(key: _key(reference), value: value);
  @override
  Future<void> delete(String reference) =>
      _storage.delete(key: _key(reference));
}

String _newRef() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class CardCleanupWarning implements Exception {}

class AccountWriter {
  final Ledger ledger;
  final CardNumberStore store;
  AccountWriter(this.ledger, this.store);
  Future<Account> save(
    Account a, {
    String? cardNumber,
    bool update = false,
  }) async {
    if (update != ledger.accounts.any((x) => x.id == a.id)) {
      throw StateError('账户状态已改变');
    }
    final old = update ? ledger.accounts.firstWhere((x) => x.id == a.id) : null;
    if (cardNumber == null || cardNumber.isEmpty) {
      if (old != null && a.cardRef != old.cardRef) throw StateError('卡号引用无效');
      if (old != null && old.cardRef.isNotEmpty && a.lastFour != old.lastFour) {
        throw StateError('修改尾号需要重新输入完整卡号');
      }
      if (update) {
        await ledger.updateAccount(a);
      } else {
        await ledger.addAccount(a);
      }
      return a;
    }
    if (!RegExp(r'^\d{12,19}$').hasMatch(cardNumber) ||
        a.lastFour != cardNumber.substring(cardNumber.length - 4)) {
      throw StateError('卡号无效');
    }
    final ref = _newRef();
    await store.write(ref, cardNumber);
    final next = Account(
      id: a.id,
      name: a.name,
      openingCents: a.openingCents,
      imageUrl: a.imageUrl,
      currency: a.currency,
      kind: a.kind,
      lastFour: a.lastFour,
      note: a.note,
      instrument: a.instrument,
      expiry: a.expiry,
      includeInNetWorth: a.includeInNetWorth,
      showNoteOnCard: a.showNoteOnCard,
      creditLimitCents: a.creditLimitCents,
      statementDay: a.statementDay,
      paymentDay: a.paymentDay,
      cardRef: ref,
    );
    try {
      if (update) {
        await ledger.updateAccount(next);
      } else {
        await ledger.addAccount(next);
      }
    } catch (_) {
      await store.delete(ref);
      rethrow;
    }
    if (old != null && old.cardRef.isNotEmpty && old.cardRef != ref) {
      try {
        await store.delete(old.cardRef);
      } catch (_) {
        throw CardCleanupWarning();
      }
    }
    return next;
  }

  Future<void> delete(Account a) async {
    final secret = a.cardRef.isEmpty ? null : await store.read(a.cardRef);
    if (a.cardRef.isNotEmpty) await store.delete(a.cardRef);
    try {
      await ledger.deleteAccount(a.id);
    } catch (_) {
      if (secret != null) await store.write(a.cardRef, secret);
      rethrow;
    }
  }
}
