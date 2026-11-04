import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ledger_store.dart';

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

class Recurring {
  final String id, accountId, category, note;
  final int cents, day;
  final bool income;
  final DateTime nextDate;
  Recurring({
    required this.id,
    required this.accountId,
    required this.cents,
    required this.income,
    required this.category,
    required this.note,
    required this.day,
    required this.nextDate,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'cents': cents,
    'income': income,
    'category': category,
    'note': note,
    'day': day,
    'nextDate': nextDate.toIso8601String(),
  };
  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
    id: j['id'],
    accountId: j['accountId'],
    cents: j['cents'],
    income: j['income'],
    category: j['category'],
    note: j['note'],
    day: j['day'],
    nextDate: DateTime.parse(j['nextDate']),
  );
  Recurring advance() {
    final y = nextDate.month == 12 ? nextDate.year + 1 : nextDate.year;
    final m = nextDate.month == 12 ? 1 : nextDate.month + 1;
    final last = DateTime(y, m + 1, 0).day;
    return Recurring(
      id: id,
      accountId: accountId,
      cents: cents,
      income: income,
      category: category,
      note: note,
      day: day,
      nextDate: DateTime(y, m, day < last ? day : last),
    );
  }
}

class Ledger extends ChangeNotifier {
  final LedgerStore _store;
  final List<Account> accounts;
  final List<Entry> entries;
  int monthlyBudgetCents;
  final List<Recurring> recurring;
  final Map<String, int> manualRates;
  DateTime? ratesUpdatedAt;
  bool _saving = false;
  Ledger._(
    this._store,
    this.accounts,
    this.entries, [
    this.monthlyBudgetCents = 0,
    List<Recurring>? rules,
    Map<String, int>? rates,
    this.ratesUpdatedAt,
  ]) : recurring = rules ?? [],
       manualRates = rates ?? {};
  static Future<Ledger> load({KeyVault? vault}) async {
    final p = await SharedPreferences.getInstance();
    final store = LedgerStore(p, vault ?? DeviceKeyVault());
    final raw = await store.read();
    if (raw == null) return Ledger._(store, [], []);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Ledger._(
      store,
      (j['accounts'] as List).map((e) => Account.fromJson(e)).toList(),
      (j['entries'] as List).map((e) => Entry.fromJson(e)).toList(),
      j['monthlyBudgetCents'] ?? 0,
      (j['recurring'] as List? ?? [])
          .map((e) => Recurring.fromJson(e))
          .toList(),
      Map<String, int>.from(j['manualRates'] ?? {}),
      j['ratesUpdatedAt'] == null ? null : DateTime.parse(j['ratesUpdatedAt']),
    );
  }

  Future<void> _commit(
    List<Account> nextAccounts,
    List<Entry> nextEntries, {
    int? budget,
    List<Recurring>? rules,
    Map<String, int>? rates,
    DateTime? ratesDate,
  }) async {
    if (_saving) throw StateError('已有操作正在保存，请重试');
    _saving = true;
    try {
      await _store.write(
        jsonEncode({
          'accounts': nextAccounts.map((a) => a.toJson()).toList(),
          'entries': nextEntries.map((e) => e.toJson()).toList(),
          'monthlyBudgetCents': budget ?? monthlyBudgetCents,
          'recurring': (rules ?? recurring).map((r) => r.toJson()).toList(),
          'manualRates': rates ?? manualRates,
          'ratesUpdatedAt': (rates == null ? ratesUpdatedAt : ratesDate)
              ?.toIso8601String(),
        }),
      );
      monthlyBudgetCents = budget ?? monthlyBudgetCents;
      if (rates != null) {
        manualRates
          ..clear()
          ..addAll(rates);
        ratesUpdatedAt = ratesDate;
      }
      if (rules != null) {
        recurring
          ..clear()
          ..addAll(rules);
      }
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

  bool get localEncryptionEnabled => _store.encryptionVerified;
  Future<void> enableLocalEncryption() async {
    if (_saving) throw StateError('已有操作正在保存，请重试');
    _saving = true;
    try {
      final raw = jsonEncode({
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'monthlyBudgetCents': monthlyBudgetCents,
        'recurring': recurring.map((r) => r.toJson()).toList(),
        'manualRates': manualRates,
        'ratesUpdatedAt': ratesUpdatedAt?.toIso8601String(),
      });
      await _store.enable(raw);
      notifyListeners();
    } finally {
      _saving = false;
    }
  }

  String exportBackup() => jsonEncode({
    'format': 'FreeMyFinance',
    'version': 6,
    'manualRates': manualRates,
    'ratesUpdatedAt': ratesUpdatedAt?.toIso8601String(),
    'monthlyBudgetCents': monthlyBudgetCents,
    'recurring': recurring.map((r) => r.toJson()).toList(),
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
              data['version'] != 4 &&
              data['version'] != 5 &&
              data['version'] != 6) ||
          data['accounts'] is! List ||
          data['entries'] is! List) {
        throw const FormatException('无效的备份格式');
      }
      final rawRates = data['manualRates'] ?? {};
      if (rawRates is! Map) throw const FormatException('汇率数据无效');
      final rates = <String, int>{};
      for (final e in rawRates.entries) {
        if (e.key is! String ||
            e.key == 'CNY' ||
            !Account.supportedCurrencies.contains(e.key) ||
            e.value is! int ||
            (e.value as int) <= 0 ||
            (e.value as int) > 1000000000) {
          throw const FormatException('汇率数据无效');
        }
        rates[e.key] = e.value;
      }
      final rawDate = data['ratesUpdatedAt'];
      if (rawDate != null && rawDate is! String) {
        throw const FormatException('汇率日期无效');
      }
      final ratesDate = rawDate == null
          ? null
          : DateTime.parse(rawDate as String);
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
      final rawRules = data['recurring'] ?? [];
      if (rawRules is! List) throw const FormatException('周期账单无效');
      final newRules = <Recurring>[];
      final ruleIds = <String>{};
      for (final item in rawRules) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            !ruleIds.add(item['id']) ||
            item['accountId'] is! String ||
            !ids.contains(item['accountId']) ||
            item['cents'] is! int ||
            (item['cents'] as int) <= 0 ||
            item['income'] is! bool ||
            item['category'] is! String ||
            (item['category'] as String).trim().isEmpty ||
            item['note'] is! String ||
            item['day'] is! int ||
            (item['day'] as int) < 1 ||
            (item['day'] as int) > 31 ||
            item['nextDate'] is! String) {
          throw const FormatException('周期账单无效');
        }
        final rule = Recurring.fromJson(item);
        final last = DateTime(
          rule.nextDate.year,
          rule.nextDate.month + 1,
          0,
        ).day;
        if (rule.nextDate.day != (rule.day < last ? rule.day : last)) {
          throw const FormatException('周期日期无效');
        }
        newRules.add(rule);
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
      await _commit(
        newAccounts,
        newEntries,
        budget: budget,
        rules: newRules,
        rates: rates,
        ratesDate: ratesDate,
      );
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('备份内容无效');
    }
  }

  Future<void> setManualRates(Map<String, int> rates) async {
    for (final e in rates.entries) {
      if (e.key == 'CNY' ||
          !Account.supportedCurrencies.contains(e.key) ||
          e.value <= 0 ||
          e.value > 1000000000) {
        throw StateError('汇率无效');
      }
    }
    await _commit(
      [...accounts],
      [...entries],
      rates: Map.of(rates),
      ratesDate: DateTime.now(),
    );
  }

  int? estimatedCnyCents() {
    var total = BigInt.zero;
    for (final a in accounts) {
      final rate = a.currency == 'CNY' ? 1000000 : manualRates[a.currency];
      if (rate == null) return null;
      final n = BigInt.from(balance(a.id)) * BigInt.from(rate);
      final abs = (n.abs() + BigInt.from(500000)) ~/ BigInt.from(1000000);
      total += n.isNegative ? -abs : abs;
    }
    if (!total.isValidInt) throw StateError('金额超出范围');
    return total.toInt();
  }

  Future<void> setMonthlyBudget(int cents) async {
    if (cents < 0) throw StateError('预算不能为负');
    await _commit([...accounts], [...entries], budget: cents);
  }

  Future<void> renameCategory(String oldName, String newName) async {
    final name = newName.trim();
    if (oldName.trim().isEmpty || name.isEmpty || name.length > 30) {
      throw StateError('分类名称无效');
    }
    final updatedEntries = entries
        .map(
          (e) => e.transferId.isEmpty && e.category == oldName
              ? Entry(
                  id: e.id,
                  accountId: e.accountId,
                  cents: e.cents,
                  income: e.income,
                  category: name,
                  note: e.note,
                  date: e.date,
                )
              : e,
        )
        .toList();
    final updatedRules = recurring
        .map(
          (r) => r.category == oldName
              ? Recurring(
                  id: r.id,
                  accountId: r.accountId,
                  cents: r.cents,
                  income: r.income,
                  category: name,
                  note: r.note,
                  day: r.day,
                  nextDate: r.nextDate,
                )
              : r,
        )
        .toList();
    await _commit([...accounts], updatedEntries, rules: updatedRules);
  }

  Future<void> addRecurring(Recurring rule) async {
    if (rule.id.isEmpty ||
        recurring.any((r) => r.id == rule.id) ||
        !accounts.any((a) => a.id == rule.accountId) ||
        rule.cents <= 0 ||
        rule.day < 1 ||
        rule.day > 31 ||
        rule.category.trim().isEmpty) {
      throw StateError('周期账单无效');
    }
    final last = DateTime(rule.nextDate.year, rule.nextDate.month + 1, 0).day;
    if (rule.nextDate.day != (rule.day < last ? rule.day : last)) {
      throw StateError('周期日期无效');
    }
    await _commit([...accounts], [...entries], rules: [...recurring, rule]);
  }

  Future<void> deleteRecurring(String id) async => _commit(
    [...accounts],
    [...entries],
    rules: recurring.where((r) => r.id != id).toList(),
  );
  Future<int> applyRecurring(DateTime today) async {
    final cutoff = DateTime(today.year, today.month, today.day);
    final nextEntries = [...entries];
    final nextRules = <Recurring>[];
    var count = 0;
    for (final initial in recurring) {
      var rule = initial;
      var iterations = 0;
      while (!rule.nextDate.isAfter(cutoff)) {
        if (++iterations > 120) throw StateError('单个周期规则最多补记 120 个月');
        final id =
            'recurring-${rule.id}-${rule.nextDate.year}-${rule.nextDate.month}';
        if (!nextEntries.any((e) => e.id == id)) {
          nextEntries.add(
            Entry(
              id: id,
              accountId: rule.accountId,
              cents: rule.cents,
              income: rule.income,
              category: rule.category,
              note: rule.note,
              date: rule.nextDate,
            ),
          );
          count++;
        }
        rule = rule.advance();
      }
      nextRules.add(rule);
    }
    if (count > 0 ||
        nextRules.asMap().entries.any(
          (e) => e.value.nextDate != recurring[e.key].nextDate,
        )) {
      await _commit([...accounts], nextEntries, rules: nextRules);
    }
    return count;
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
    if (entries.any((e) => e.accountId == id) ||
        recurring.any((r) => r.accountId == id)) {
      throw StateError('账户仍有关联账单或周期规则');
    }
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
