import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Account {
  static const supportedCurrencies = ['CNY', 'HKD', 'USD', 'EUR', 'GBP'];
  final String id, name, imageUrl, currency;
  final int openingCents;
  Account({
    required this.id,
    required this.name,
    required this.openingCents,
    this.imageUrl = '',
    this.currency = 'CNY',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'openingCents': openingCents,
    'imageUrl': imageUrl,
    'currency': currency,
  };
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    openingCents: j['openingCents'],
    imageUrl: j['imageUrl'] ?? '',
    currency: j['currency'] ?? 'CNY',
  );
}

class Entry {
  final String id, accountId, category, note, transferId;
  final int cents;
  final bool income;
  final DateTime date;
  Entry({
    required this.id,
    required this.accountId,
    required this.cents,
    required this.income,
    required this.category,
    required this.note,
    required this.date,
    this.transferId = '',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'cents': cents,
    'income': income,
    'category': category,
    'note': note,
    'transferId': transferId,
    'date': date.toIso8601String(),
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'],
    accountId: j['accountId'],
    cents: j['cents'],
    income: j['income'],
    category: j['category'],
    note: j['note'],
    transferId: j['transferId'] ?? '',
    date: DateTime.parse(j['date']),
  );
}

class Ledger extends ChangeNotifier {
  final SharedPreferences _prefs;
  final List<Account> accounts;
  final List<Entry> entries;
  int monthlyBudgetCents;
  bool _saving = false;
  Ledger._(
    this._prefs,
    this.accounts,
    this.entries, [
    this.monthlyBudgetCents = 0,
  ]);
  static Future<Ledger> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('ledger_v1');
    if (raw == null) return Ledger._(p, [], []);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Ledger._(
      p,
      (j['accounts'] as List).map((e) => Account.fromJson(e)).toList(),
      (j['entries'] as List).map((e) => Entry.fromJson(e)).toList(),
      j['monthlyBudgetCents'] ?? 0,
    );
  }

  Future<void> _commit(
    List<Account> nextAccounts,
    List<Entry> nextEntries, {
    int? budget,
  }) async {
    if (_saving) throw StateError('已有操作正在保存，请重试');
    _saving = true;
    try {
      final ok = await _prefs.setString(
        'ledger_v1',
        jsonEncode({
          'accounts': nextAccounts.map((a) => a.toJson()).toList(),
          'entries': nextEntries.map((e) => e.toJson()).toList(),
          'monthlyBudgetCents': budget ?? monthlyBudgetCents,
        }),
      );
      if (!ok) throw StateError('保存失败');
      monthlyBudgetCents = budget ?? monthlyBudgetCents;
      accounts
        ..clear()
        ..addAll(nextAccounts);
      entries
        ..clear()
        ..addAll(nextEntries);
      notifyListeners();
    } finally {
      _saving = false;
    }
  }

  String exportBackup() => jsonEncode({
    'format': 'FreeMyFinance',
    'version': 4,
    'monthlyBudgetCents': monthlyBudgetCents,
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
  });

  Future<void> restoreBackup(String text) async {
    try {
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic> ||
          data['format'] != 'FreeMyFinance' ||
          (data['version'] != 1 &&
              data['version'] != 2 &&
              data['version'] != 3 &&
              data['version'] != 4) ||
          data['accounts'] is! List ||
          data['entries'] is! List) {
        throw const FormatException('无效的备份格式');
      }
      final budget = data['monthlyBudgetCents'] ?? 0;
      if (budget is! int || budget < 0) throw const FormatException('预算数据无效');
      final newAccounts = <Account>[];
      final ids = <String>{};
      for (final item in data['accounts'] as List) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            item['name'] is! String ||
            (item['name'] as String).trim().isEmpty ||
            item['openingCents'] is! int ||
            (item['imageUrl'] != null && item['imageUrl'] is! String) ||
            (item['currency'] != null &&
                !Account.supportedCurrencies.contains(item['currency']))) {
          throw const FormatException('账户数据无效');
        }
        final a = Account.fromJson(item);
        if (!ids.add(a.id)) throw const FormatException('账户编号重复');
        newAccounts.add(a);
      }
      final newEntries = <Entry>[];
      final entryIds = <String>{};
      for (final item in data['entries'] as List) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            item['accountId'] is! String ||
            !ids.contains(item['accountId']) ||
            item['cents'] is! int ||
            (item['cents'] as int) <= 0 ||
            item['income'] is! bool ||
            item['category'] is! String ||
            (item['category'] as String).trim().isEmpty ||
            item['note'] is! String ||
            (item['transferId'] != null && item['transferId'] is! String) ||
            item['date'] is! String) {
          throw const FormatException('账单数据无效');
        }
        final entry = Entry.fromJson(item);
        if (!entryIds.add(entry.id)) throw const FormatException('账单编号重复');
        newEntries.add(entry);
      }
      final transferIds = newEntries
          .where((e) => e.transferId.isNotEmpty)
          .map((e) => e.transferId)
          .toSet();
      for (final id in transferIds) {
        final pair = newEntries.where((e) => e.transferId == id).toList();
        if (pair.length != 2 ||
            pair[0].income == pair[1].income ||
            pair[0].accountId == pair[1].accountId ||
            (newAccounts
                        .firstWhere((a) => a.id == pair[0].accountId)
                        .currency ==
                    newAccounts
                        .firstWhere((a) => a.id == pair[1].accountId)
                        .currency &&
                pair[0].cents != pair[1].cents)) {
          throw const FormatException('转账数据无效');
        }
      }
      await _commit(newAccounts, newEntries, budget: budget);
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('备份内容无效');
    }
  }

  Future<void> setMonthlyBudget(int cents) async {
    if (cents < 0) throw StateError('预算不能为负');
    await _commit([...accounts], [...entries], budget: cents);
  }

  Future<void> addAccount(Account a) async {
    if (accounts.any((x) => x.id == a.id) ||
        !Account.supportedCurrencies.contains(a.currency)) {
      throw StateError('账户无效');
    }
    await _commit([...accounts, a], [...entries]);
  }

  Future<void> updateAccount(Account a) async {
    if (!accounts.any((x) => x.id == a.id)) throw StateError('账户不存在');
    if (!Account.supportedCurrencies.contains(a.currency) ||
        (accounts.firstWhere((x) => x.id == a.id).currency != a.currency &&
            entries.any((e) => e.accountId == a.id))) {
      throw StateError('有关联账单的账户不能更改币种');
    }
    await _commit(
      [
        for (final x in accounts)
          if (x.id == a.id) a else x,
      ],
      [...entries],
    );
  }

  Future<void> deleteAccount(String id) async {
    if (entries.any((e) => e.accountId == id)) throw StateError('账户仍有关联账单');
    await _commit(accounts.where((a) => a.id != id).toList(), [...entries]);
  }

  Future<void> addEntry(Entry e) async {
    if (!accounts.any((a) => a.id == e.accountId) ||
        e.cents <= 0 ||
        entries.any((x) => x.id == e.id)) {
      throw StateError('账单无效');
    }
    await _commit([...accounts], [...entries, e]);
  }

  Future<void> updateEntry(Entry e) async {
    if (e.transferId.isNotEmpty ||
        entries.any((x) => x.id == e.id && x.transferId.isNotEmpty) ||
        !entries.any((x) => x.id == e.id) ||
        !accounts.any((a) => a.id == e.accountId) ||
        e.cents <= 0) {
      throw StateError('账单无效');
    }
    await _commit(
      [...accounts],
      [
        for (final x in entries)
          if (x.id == e.id) e else x,
      ],
    );
  }

  Future<void> addTransfer({
    required String id,
    required String from,
    required String to,
    required int cents,
    int? toCents,
    required DateTime date,
    required String note,
  }) async {
    if (id.isEmpty ||
        from == to ||
        cents <= 0 ||
        !accounts.any((a) => a.id == from) ||
        !accounts.any((a) => a.id == to) ||
        entries.any(
          (e) => e.transferId == id || e.id == '$id-out' || e.id == '$id-in',
        )) {
      throw StateError('转账信息无效');
    }
    final sourceCurrency = accounts.firstWhere((a) => a.id == from).currency;
    final destinationCurrency = accounts.firstWhere((a) => a.id == to).currency;
    if (sourceCurrency != destinationCurrency &&
        (toCents == null || toCents <= 0)) {
      throw StateError('跨币种转账需要填写实际到账金额');
    }
    if (sourceCurrency == destinationCurrency &&
        toCents != null &&
        toCents != cents) {
      throw StateError('同币种转账金额必须一致');
    }
    final out = Entry(
      id: '$id-out',
      accountId: from,
      cents: cents,
      income: false,
      category: '账户转账',
      note: note,
      date: date,
      transferId: id,
    );
    final incoming = Entry(
      id: '$id-in',
      accountId: to,
      cents: toCents ?? cents,
      income: true,
      category: '账户转账',
      note: note,
      date: date,
      transferId: id,
    );
    await _commit([...accounts], [...entries, out, incoming]);
  }

  Future<void> deleteEntry(String id) async {
    final matches = entries.where((e) => e.id == id);
    if (matches.isEmpty) return;
    final transferId = matches.first.transferId;
    await _commit(
      [...accounts],
      entries
          .where(
            (e) =>
                e.id != id &&
                (transferId.isEmpty || e.transferId != transferId),
          )
          .toList(),
    );
  }

  int balance(String id) =>
      accounts.firstWhere((a) => a.id == id).openingCents +
      entries
          .where((e) => e.accountId == id)
          .fold(0, (int s, e) => s + (e.income ? e.cents : -e.cents));
  int _sum(DateTime month, bool income, String currency) => entries
      .where(
        (e) =>
            e.transferId.isEmpty &&
            accounts.any(
              (a) => a.id == e.accountId && a.currency == currency,
            ) &&
            e.income == income &&
            e.date.year == month.year &&
            e.date.month == month.month,
      )
      .fold(0, (int s, e) => s + e.cents);
  int incomeFor(DateTime month, {String currency = 'CNY'}) =>
      _sum(month, true, currency);
  int expenseFor(DateTime month, {String currency = 'CNY'}) =>
      _sum(month, false, currency);
}
