import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Account {
  final String id, name, imageUrl;
  final int openingCents;
  Account({
    required this.id,
    required this.name,
    required this.openingCents,
    this.imageUrl = '',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'openingCents': openingCents,
    'imageUrl': imageUrl,
  };
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    openingCents: j['openingCents'],
    imageUrl: j['imageUrl'] ?? '',
  );
}

class Entry {
  final String id, accountId, category, note;
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
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'cents': cents,
    'income': income,
    'category': category,
    'note': note,
    'date': date.toIso8601String(),
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'],
    accountId: j['accountId'],
    cents: j['cents'],
    income: j['income'],
    category: j['category'],
    note: j['note'],
    date: DateTime.parse(j['date']),
  );
}

class Ledger extends ChangeNotifier {
  final SharedPreferences _prefs;
  final List<Account> accounts;
  final List<Entry> entries;
  Ledger._(this._prefs, this.accounts, this.entries);
  static Future<Ledger> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('ledger_v1');
    if (raw == null) return Ledger._(p, [], []);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Ledger._(
      p,
      (j['accounts'] as List).map((e) => Account.fromJson(e)).toList(),
      (j['entries'] as List).map((e) => Entry.fromJson(e)).toList(),
    );
  }

  Future<void> _save() async {
    final ok = await _prefs.setString(
      'ledger_v1',
      jsonEncode({
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
      }),
    );
    if (!ok) throw StateError('保存失败');
    notifyListeners();
  }

  String exportBackup() => jsonEncode({
    'format': 'FreeMyFinance',
    'version': 1,
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
  });

  Future<void> restoreBackup(String text) async {
    try {
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic> ||
          data['format'] != 'FreeMyFinance' ||
          data['version'] != 1 ||
          data['accounts'] is! List ||
          data['entries'] is! List) {
        throw const FormatException('无效的备份格式');
      }
      final newAccounts = <Account>[];
      final ids = <String>{};
      for (final item in data['accounts'] as List) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            item['name'] is! String ||
            (item['name'] as String).trim().isEmpty ||
            item['openingCents'] is! int ||
            (item['openingCents'] as int) < 0 ||
            (item['imageUrl'] != null && item['imageUrl'] is! String)) {
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
            item['date'] is! String) {
          throw const FormatException('账单数据无效');
        }
        final entry = Entry.fromJson(item);
        if (!entryIds.add(entry.id)) throw const FormatException('账单编号重复');
        newEntries.add(entry);
      }
      final raw = jsonEncode({
        'accounts': newAccounts.map((a) => a.toJson()).toList(),
        'entries': newEntries.map((e) => e.toJson()).toList(),
      });
      if (!await _prefs.setString('ledger_v1', raw)) throw StateError('保存失败');
      accounts
        ..clear()
        ..addAll(newAccounts);
      entries
        ..clear()
        ..addAll(newEntries);
      notifyListeners();
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('备份内容无效');
    }
  }

  Future<void> addAccount(Account a) async {
    accounts.add(a);
    await _save();
  }

  Future<void> addEntry(Entry e) async {
    entries.add(e);
    await _save();
  }

  Future<void> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
    await _save();
  }

  int balance(String id) =>
      accounts.firstWhere((a) => a.id == id).openingCents +
      entries
          .where((e) => e.accountId == id)
          .fold(0, (int s, e) => s + (e.income ? e.cents : -e.cents));
  int _sum(DateTime month, bool income) => entries
      .where(
        (e) =>
            e.income == income &&
            e.date.year == month.year &&
            e.date.month == month.month,
      )
      .fold(0, (int s, e) => s + e.cents);
  int incomeFor(DateTime month) => _sum(month, true);
  int expenseFor(DateTime month) => _sum(month, false);
}
