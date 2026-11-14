import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ledger_store.dart';

bool _validIconPng(String value) {
  if (value.isEmpty) return true;
  try {
    final bytes = base64Decode(value);
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    return bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v);
  } catch (_) {
    return false;
  }
}

class Account {
  static const supportedCurrencies = ['CNY', 'HKD', 'USD', 'EUR', 'GBP'];
  static const kindLabels = {
    'cash': '现金',
    'debit': '储蓄卡',
    'credit': '信用卡',
    'stock': '股票',
    'fund': '基金',
    'metals': '贵金属',
    'crypto': '加密货币',
    'virtual': '虚拟账户',
    'liability': '负债',
    'receivable': '应收账款',
    'other': '其他',
  };
  final String id,
      name,
      imageUrl,
      iconPngBase64,
      currency,
      kind,
      lastFour,
      note,
      instrument,
      expiry;
  final bool includeInNetWorth, showNoteOnCard;
  final String cardRef;
  final int openingCents;
  final int? creditLimitCents, statementDay, paymentDay;
  Account({
    required this.id,
    required this.name,
    required this.openingCents,
    this.imageUrl = '',
    this.iconPngBase64 = '',
    this.currency = 'CNY',
    this.kind = 'other',
    this.lastFour = '',
    this.note = '',
    this.instrument = '',
    this.expiry = '',
    this.cardRef = '',
    this.includeInNetWorth = true,
    this.showNoteOnCard = false,
    this.creditLimitCents,
    this.statementDay,
    this.paymentDay,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'openingCents': openingCents,
    'imageUrl': imageUrl,
    'iconPngBase64': iconPngBase64,
    'currency': currency,
    'kind': kind,
    'lastFour': lastFour,
    'note': note,
    'instrument': instrument,
    'expiry': expiry,
    'cardRef': cardRef,
    'includeInNetWorth': includeInNetWorth,
    'showNoteOnCard': showNoteOnCard,
    'creditLimitCents': creditLimitCents,
    'statementDay': statementDay,
    'paymentDay': paymentDay,
  };
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    openingCents: j['openingCents'],
    imageUrl: j['imageUrl'] ?? '',
    iconPngBase64: j['iconPngBase64'] ?? '',
    currency: j['currency'] ?? 'CNY',
    kind: j['kind'] ?? 'other',
    lastFour: j['lastFour'] ?? '',
    note: j['note'] ?? '',
    instrument: j['instrument'] ?? '',
    expiry: j['expiry'] ?? '',
    cardRef: j['cardRef'] ?? '',
    includeInNetWorth: j['includeInNetWorth'] ?? true,
    showNoteOnCard: j['showNoteOnCard'] ?? false,
    creditLimitCents: j['creditLimitCents'],
    statementDay: j['statementDay'],
    paymentDay: j['paymentDay'],
  );
}

class Entry {
  final String id, accountId, category, note, transferId;
  final int cents;
  final bool income;
  final bool pending;
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
    this.pending = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'cents': cents,
    'income': income,
    'category': category,
    'note': note,
    'transferId': transferId,
    'pending': pending,
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
    pending: j['pending'] ?? false,
    date: DateTime.parse(j['date']),
  );
}

class Recurring {
  final String id, accountId, category, note;
  final int cents, day;
  final bool income;
  final DateTime nextDate;
  final DateTime startDate;
  final DateTime? endDate;
  final String frequency;
  final bool enabled;
  Recurring({
    required this.id,
    required this.accountId,
    required this.cents,
    required this.income,
    required this.category,
    required this.note,
    required this.day,
    required this.nextDate,
    DateTime? startDate,
    this.endDate,
    this.frequency = 'monthly',
    this.enabled = true,
  }) : startDate = startDate ?? nextDate;
  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'cents': cents,
    'income': income,
    'category': category,
    'note': note,
    'day': day,
    'nextDate': nextDate.toIso8601String(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'frequency': frequency,
    'enabled': enabled,
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
    startDate: j['startDate'] == null ? null : DateTime.parse(j['startDate']),
    endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate']),
    frequency: j['frequency'] ?? 'monthly',
    enabled: j['enabled'] ?? true,
  );
  Recurring copyWith({DateTime? nextDate, bool? enabled, String? category}) =>
      Recurring(
        id: id,
        accountId: accountId,
        cents: cents,
        income: income,
        category: category ?? this.category,
        note: note,
        day: day,
        nextDate: nextDate ?? this.nextDate,
        startDate: startDate,
        endDate: endDate,
        frequency: frequency,
        enabled: enabled ?? this.enabled,
      );
  Recurring advance() {
    if (frequency == 'weekly') {
      return copyWith(nextDate: nextDate.add(const Duration(days: 7)));
    }
    final months = frequency == 'yearly'
        ? 12
        : frequency == 'quarterly'
        ? 3
        : 1;
    final nextMonth = DateTime(nextDate.year, nextDate.month + months);
    final y = nextMonth.year;
    final m = nextMonth.month;
    final last = DateTime(y, m + 1, 0).day;
    return copyWith(nextDate: DateTime(y, m, day < last ? day : last));
  }
}

const defaultAiAnalysisPrompt =
    '请根据所选期间的账单汇总，分析收入、支出、结余和主要支出分类占比。指出值得关注的开支，并给出最多三条具体、可执行的记账建议。请引用数据中的金额；没有对比数据时不要推断趋势，也不要提供投资建议。';

class AiAnalysisRecord {
  final String id, period, currency, scope, prompt, summary, response;
  final DateTime createdAt;
  const AiAnalysisRecord({
    required this.id,
    required this.createdAt,
    required this.period,
    required this.currency,
    required this.scope,
    required this.prompt,
    required this.summary,
    required this.response,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'period': period,
    'currency': currency,
    'scope': scope,
    'prompt': prompt,
    'summary': summary,
    'response': response,
  };
  factory AiAnalysisRecord.fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic> ||
        raw['id'] is! String ||
        (raw['id'] as String).isEmpty ||
        (raw['id'] as String).length > 80 ||
        raw['createdAt'] is! String ||
        raw['period'] is! String ||
        !RegExp(r'^\d{4}(-(?:0[1-9]|1[0-2]))?$').hasMatch(raw['period']) ||
        !Account.supportedCurrencies.contains(raw['currency']) ||
        (raw['scope'] != '全部账户' && raw['scope'] != '单个账户') ||
        raw['prompt'] is! String ||
        (raw['prompt'] as String).trim().isEmpty ||
        (raw['prompt'] as String).length > 2000 ||
        raw['summary'] is! String ||
        (raw['summary'] as String).isEmpty ||
        (raw['summary'] as String).length > 20000 ||
        raw['response'] is! String ||
        (raw['response'] as String).trim().isEmpty ||
        (raw['response'] as String).length > 30000) {
      throw const FormatException('AI 分析记录无效');
    }
    try {
      return AiAnalysisRecord(
        id: raw['id'],
        createdAt: DateTime.parse(raw['createdAt']),
        period: raw['period'],
        currency: raw['currency'],
        scope: raw['scope'],
        prompt: raw['prompt'],
        summary: raw['summary'],
        response: raw['response'],
      );
    } on FormatException {
      throw const FormatException('AI 分析记录日期无效');
    }
  }
}

class Ledger extends ChangeNotifier {
  static const defaultExpenseCategories = [
    '餐饮',
    '购物',
    '交通',
    '住房',
    '娱乐',
    '医疗',
    '其他支出',
  ];
  static const defaultIncomeCategories = ['工资', '奖金', '转入', '其他收入'];
  static List<String> _categoryList(dynamic raw, List<String> defaults) {
    if (raw == null) return [...defaults];
    if (raw is! List ||
        raw.any((v) => v is! String || v.trim().isEmpty || v.length > 30)) {
      throw const FormatException('分类数据无效');
    }
    return (raw.cast<String>().toSet()).toList();
  }

  static List<String> _mergeCategories(
    List<String> catalog,
    List<Entry> entries,
    List<Recurring> rules,
    bool income,
  ) => {
    ...catalog,
    ...entries
        .where((e) => e.transferId.isEmpty && e.income == income)
        .map((e) => e.category),
    ...rules.where((r) => r.income == income).map((r) => r.category),
  }.toList();
  final LedgerStore _store;
  final List<Account> accounts;
  final List<Entry> entries;
  int monthlyBudgetCents;
  final List<Recurring> recurring;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final List<AiAnalysisRecord> aiHistory;
  String aiPrompt;
  final Map<String, int> manualRates;
  DateTime? ratesUpdatedAt;
  String rateSource;
  String? rateProviderTime;
  bool _saving = false;
  Ledger._(
    this._store,
    this.accounts,
    this.entries, [
    this.monthlyBudgetCents = 0,
    List<Recurring>? rules,
    Map<String, int>? rates,
    this.ratesUpdatedAt,
    this.rateSource = 'manual',
    this.rateProviderTime,
    List<String>? expenses,
    List<String>? incomes,
    this.aiPrompt = defaultAiAnalysisPrompt,
    List<AiAnalysisRecord>? history,
  ]) : recurring = rules ?? [],
       aiHistory = history ?? [],
       expenseCategories = _mergeCategories(
         expenses ?? defaultExpenseCategories,
         entries,
         rules ?? [],
         false,
       ),
       incomeCategories = _mergeCategories(
         incomes ?? defaultIncomeCategories,
         entries,
         rules ?? [],
         true,
       ),
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
      j['rateSource'] ?? 'manual',
      j['rateProviderTime'],
      _categoryList(j['expenseCategories'], defaultExpenseCategories),
      _categoryList(j['incomeCategories'], defaultIncomeCategories),
      j['aiPrompt'] ?? defaultAiAnalysisPrompt,
      (j['aiHistory'] as List? ?? [])
          .map((e) => AiAnalysisRecord.fromJson(e))
          .toList(),
    );
  }

  Future<void> _commit(
    List<Account> nextAccounts,
    List<Entry> nextEntries, {
    int? budget,
    List<Recurring>? rules,
    Map<String, int>? rates,
    DateTime? ratesDate,
    String? nextRateSource,
    String? nextProviderTime,
    List<String>? expenses,
    List<String>? incomes,
    String? prompt,
    List<AiAnalysisRecord>? history,
  }) async {
    if (_saving) throw StateError('已有操作正在保存，请重试');
    _saving = true;
    try {
      final nextExpenses = _mergeCategories(
        expenses ?? expenseCategories,
        nextEntries,
        rules ?? recurring,
        false,
      );
      final nextIncomes = _mergeCategories(
        incomes ?? incomeCategories,
        nextEntries,
        rules ?? recurring,
        true,
      );
      await _store.write(
        jsonEncode({
          'accounts': nextAccounts.map((a) => a.toJson()).toList(),
          'entries': nextEntries.map((e) => e.toJson()).toList(),
          'expenseCategories': nextExpenses,
          'incomeCategories': nextIncomes,
          'aiPrompt': prompt ?? aiPrompt,
          'aiHistory': (history ?? aiHistory).map((r) => r.toJson()).toList(),
          'monthlyBudgetCents': budget ?? monthlyBudgetCents,
          'recurring': (rules ?? recurring).map((r) => r.toJson()).toList(),
          'manualRates': rates ?? manualRates,
          'rateSource': rates == null
              ? rateSource
              : (nextRateSource ?? 'manual'),
          'rateProviderTime': rates == null
              ? rateProviderTime
              : nextProviderTime,
          'ratesUpdatedAt': (rates == null ? ratesUpdatedAt : ratesDate)
              ?.toIso8601String(),
        }),
      );
      monthlyBudgetCents = budget ?? monthlyBudgetCents;
      aiPrompt = prompt ?? aiPrompt;
      if (history != null) {
        aiHistory
          ..clear()
          ..addAll(history);
      }
      expenseCategories
        ..clear()
        ..addAll(nextExpenses);
      incomeCategories
        ..clear()
        ..addAll(nextIncomes);
      if (rates != null) {
        manualRates
          ..clear()
          ..addAll(rates);
        ratesUpdatedAt = ratesDate;
        rateSource = nextRateSource ?? 'manual';
        rateProviderTime = nextProviderTime;
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
        'expenseCategories': expenseCategories,
        'incomeCategories': incomeCategories,
        'aiPrompt': aiPrompt,
        'aiHistory': aiHistory.map((r) => r.toJson()).toList(),
        'monthlyBudgetCents': monthlyBudgetCents,
        'recurring': recurring.map((r) => r.toJson()).toList(),
        'manualRates': manualRates,
        'rateSource': rateSource,
        'rateProviderTime': rateProviderTime,
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
    'version': 13,
    'expenseCategories': expenseCategories,
    'incomeCategories': incomeCategories,
    'aiPrompt': aiPrompt,
    'aiHistory': aiHistory.map((r) => r.toJson()).toList(),
    'manualRates': manualRates,
    'rateSource': rateSource,
    'rateProviderTime': rateProviderTime,
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
              data['version'] != 6 &&
              data['version'] != 7 &&
              data['version'] != 8 &&
              data['version'] != 9 &&
              data['version'] != 10 &&
              data['version'] != 11 &&
              data['version'] != 12 &&
              data['version'] != 13) ||
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
      final source = data['rateSource'] ?? 'manual';
      final providerTime = data['rateProviderTime'];
      if ((source != 'manual' && source != 'apihz') ||
          (providerTime != null &&
              (providerTime is! String ||
                  !RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')
                      .hasMatch(providerTime))) ||
          (source == 'apihz' && providerTime == null)) {
        throw const FormatException('汇率来源无效');
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
            (item['iconPngBase64'] != null &&
                (item['iconPngBase64'] is! String ||
                    (item['iconPngBase64'] as String).length > 200000 ||
                    !_validIconPng(item['iconPngBase64'] as String))) ||
            (item['currency'] != null &&
                !Account.supportedCurrencies.contains(item['currency'])) ||
            (item['kind'] != null &&
                !Account.kindLabels.containsKey(item['kind'])) ||
            (item['lastFour'] != null &&
                (item['lastFour'] is! String ||
                    ((item['lastFour'] as String).isNotEmpty &&
                        !RegExp(r'^\d{4}$').hasMatch(item['lastFour'])))) ||
            (item['note'] != null && item['note'] is! String) ||
            (item['cardRef'] != null &&
                (item['cardRef'] is! String ||
                    ((item['cardRef'] as String).isNotEmpty &&
                        !RegExp(r'^[a-f0-9]{32}$')
                            .hasMatch(item['cardRef'])))) ||
            (item['instrument'] != null && item['instrument'] is! String) ||
            (item['expiry'] != null &&
                (item['expiry'] is! String ||
                    ((item['expiry'] as String).isNotEmpty &&
                        !RegExp(r'^(0[1-9]|1[0-2])/\d{4}$')
                            .hasMatch(item['expiry'])))) ||
            (item['includeInNetWorth'] != null &&
                item['includeInNetWorth'] is! bool) ||
            (item['showNoteOnCard'] != null &&
                item['showNoteOnCard'] is! bool) ||
            (item['creditLimitCents'] != null &&
                (item['creditLimitCents'] is! int ||
                    (item['creditLimitCents'] as int) < 0)) ||
            (item['statementDay'] != null &&
                (item['statementDay'] is! int ||
                    (item['statementDay'] as int) < 1 ||
                    (item['statementDay'] as int) > 31)) ||
            (item['paymentDay'] != null &&
                (item['paymentDay'] is! int ||
                    (item['paymentDay'] as int) < 1 ||
                    (item['paymentDay'] as int) > 31))) {
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
            item['nextDate'] is! String ||
            (item['frequency'] != null &&
                !const [
                  'weekly',
                  'monthly',
                  'quarterly',
                  'yearly',
                ].contains(item['frequency'])) ||
            (item['enabled'] != null && item['enabled'] is! bool) ||
            (item['startDate'] != null && item['startDate'] is! String) ||
            (item['endDate'] != null && item['endDate'] is! String)) {
          throw const FormatException('周期账单无效');
        }
        final rule = Recurring.fromJson(item);
        final last = DateTime(
          rule.nextDate.year,
          rule.nextDate.month + 1,
          0,
        ).day;
        if ((rule.frequency != 'weekly' &&
                rule.nextDate.day != (rule.day < last ? rule.day : last)) ||
            (rule.endDate != null && rule.endDate!.isBefore(rule.startDate)) ||
            rule.nextDate.isBefore(rule.startDate)) {
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
            (item['pending'] != null && item['pending'] is! bool) ||
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
      final newExpenses = _categoryList(
        data['expenseCategories'],
        defaultExpenseCategories,
      );
      final newIncomes = _categoryList(
        data['incomeCategories'],
        defaultIncomeCategories,
      );
      final rawPrompt = data['aiPrompt'] ?? defaultAiAnalysisPrompt;
      if (rawPrompt is! String ||
          rawPrompt.trim().isEmpty ||
          rawPrompt.length > 2000) {
        throw const FormatException('AI 提示词无效');
      }
      final rawHistory = data['aiHistory'] ?? [];
      if (rawHistory is! List) throw const FormatException('AI 分析记录无效');
      final newHistory = rawHistory
          .map((r) => AiAnalysisRecord.fromJson(r))
          .toList();
      if (newHistory.map((r) => r.id).toSet().length != newHistory.length) {
        throw const FormatException('AI 分析记录编号重复');
      }
      await _commit(
        newAccounts,
        newEntries,
        budget: budget,
        rules: newRules,
        rates: rates,
        ratesDate: ratesDate,
        nextRateSource: source,
        nextProviderTime: providerTime,
        expenses: newExpenses,
        incomes: newIncomes,
        prompt: rawPrompt,
        history: newHistory,
      );
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('备份内容无效');
    }
  }

  Future<void> setManualRates(
    Map<String, int> rates, {
    String source = 'manual',
    String? providerTime,
  }) async {
    if ((source != 'manual' && source != 'apihz') ||
        (source == 'apihz' &&
            (providerTime == null ||
                !RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')
                    .hasMatch(providerTime)))) {
      throw StateError('汇率来源无效');
    }
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
      nextRateSource: source,
      nextProviderTime: source == 'apihz' ? providerTime : null,
    );
  }

  int? estimatedCnyCents() {
    var total = BigInt.zero;
    for (final a in accounts.where((a) => a.includeInNetWorth)) {
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

  Future<void> setAiPrompt(String value) async {
    final next = value.trim();
    if (next.isEmpty || next.length > 2000) {
      throw StateError('提示词长度须为 1 至 2000 字');
    }
    await _commit([...accounts], [...entries], prompt: next);
  }

  Future<void> addAiAnalysis(AiAnalysisRecord record) async {
    AiAnalysisRecord.fromJson(record.toJson());
    if (aiHistory.any((r) => r.id == record.id)) throw StateError('分析记录已存在');
    await _commit([...accounts], [...entries], history: [record, ...aiHistory]);
  }

  Future<void> deleteAiAnalysis(String id) async {
    await _commit(
      [...accounts],
      [...entries],
      history: aiHistory.where((r) => r.id != id).toList(),
    );
  }

  List<String> categoriesFor(bool income) =>
      List.unmodifiable(income ? incomeCategories : expenseCategories);

  Future<void> addCategory(String value, {required bool income}) async {
    final name = value.trim();
    if (name.isEmpty || name.length > 30) throw StateError('分类名称无效');
    final existing = income ? incomeCategories : expenseCategories;
    if (existing.contains(name)) throw StateError('分类已存在');
    await _commit(
      [...accounts],
      [...entries],
      expenses: income ? null : [...expenseCategories, name],
      incomes: income ? [...incomeCategories, name] : null,
    );
  }

  Future<void> deleteCategory(String value, {required bool income}) async {
    final catalog = income ? incomeCategories : expenseCategories;
    final fallback = categoryFallbackFor(value, income: income);
    if (!catalog.contains(value)) throw StateError('分类不存在');
    final reassigned =
        entries.any(
          (e) =>
              e.transferId.isEmpty && e.income == income && e.category == value,
        ) ||
        recurring.any((r) => r.income == income && r.category == value);
    final nextEntries = [
      for (final entry in entries)
        if (entry.transferId.isEmpty &&
            entry.income == income &&
            entry.category == value)
          Entry(
            id: entry.id,
            accountId: entry.accountId,
            cents: entry.cents,
            income: entry.income,
            category: fallback,
            note: entry.note,
            date: entry.date,
            pending: entry.pending,
          )
        else
          entry,
    ];
    final nextRules = [
      for (final rule in recurring)
        if (rule.income == income && rule.category == value)
          rule.copyWith(category: fallback)
        else
          rule,
    ];
    final nextCatalog = <String>{
      ...catalog.where((name) => name != value),
      if (reassigned) fallback,
    }.toList();
    await _commit(
      [...accounts],
      nextEntries,
      rules: nextRules,
      expenses: income ? null : nextCatalog,
      incomes: income ? nextCatalog : null,
    );
  }

  static String categoryFallbackFor(String value, {required bool income}) {
    final other = income ? '其他收入' : '其他支出';
    return value == other ? (income ? '未分类收入' : '未分类支出') : other;
  }

  Future<void> renameCategory(
    String oldName,
    String newName, {
    bool? income,
  }) async {
    final name = newName.trim();
    if (oldName.trim().isEmpty || name.isEmpty || name.length > 30) {
      throw StateError('分类名称无效');
    }
    final updatedEntries = entries
        .map(
          (e) =>
              e.transferId.isEmpty &&
                  e.category == oldName &&
                  (income == null || e.income == income)
              ? Entry(
                  id: e.id,
                  accountId: e.accountId,
                  cents: e.cents,
                  income: e.income,
                  category: name,
                  note: e.note,
                  date: e.date,
                  pending: e.pending,
                )
              : e,
        )
        .toList();
    final updatedRules = recurring
        .map(
          (r) => r.category == oldName && (income == null || r.income == income)
              ? r.copyWith(category: name)
              : r,
        )
        .toList();
    await _commit(
      [...accounts],
      updatedEntries,
      rules: updatedRules,
      expenses: (income == null || !income)
          ? [
              for (final v in expenseCategories)
                if (v == oldName) name else v,
            ]
          : null,
      incomes: (income == null || income)
          ? [
              for (final v in incomeCategories)
                if (v == oldName) name else v,
            ]
          : null,
    );
  }

  Future<void> addRecurring(Recurring rule) async {
    if (rule.id.isEmpty ||
        recurring.any((r) => r.id == rule.id) ||
        !accounts.any((a) => a.id == rule.accountId) ||
        rule.cents <= 0 ||
        rule.day < 1 ||
        rule.day > 31 ||
        !const [
          'weekly',
          'monthly',
          'quarterly',
          'yearly',
        ].contains(rule.frequency) ||
        (rule.endDate != null && rule.endDate!.isBefore(rule.startDate)) ||
        rule.nextDate.isBefore(rule.startDate) ||
        rule.category.trim().isEmpty) {
      throw StateError('周期账单无效');
    }
    final last = DateTime(rule.nextDate.year, rule.nextDate.month + 1, 0).day;
    if (rule.frequency != 'weekly' &&
        rule.nextDate.day != (rule.day < last ? rule.day : last)) {
      throw StateError('周期日期无效');
    }
    await _commit([...accounts], [...entries], rules: [...recurring, rule]);
  }

  Future<void> deleteRecurring(String id) async => _commit(
    [...accounts],
    [...entries],
    rules: recurring.where((r) => r.id != id).toList(),
  );
  Future<void> setRecurringEnabled(String id, bool enabled) async {
    if (!recurring.any((rule) => rule.id == id)) throw StateError('周期规则不存在');
    await _commit(
      [...accounts],
      [...entries],
      rules: [
        for (final rule in recurring)
          if (rule.id == id) rule.copyWith(enabled: enabled) else rule,
      ],
    );
  }

  Future<void> markPaid(String id) async {
    final matches = entries.where((entry) => entry.id == id && entry.pending);
    if (matches.isEmpty) throw StateError('待付款账单不存在');
    await _commit(
      [...accounts],
      [
        for (final entry in entries)
          if (entry.id == id)
            Entry.fromJson({...entry.toJson(), 'pending': false})
          else
            entry,
      ],
    );
  }

  Future<int> applyRecurring(DateTime today) async {
    final cutoff = DateTime(today.year, today.month, today.day);
    final nextEntries = [...entries];
    final existingIds = entries.map((entry) => entry.id).toSet();
    final nextRules = <Recurring>[];
    var count = 0;
    for (final initial in recurring) {
      var rule = initial;
      if (!rule.enabled) {
        nextRules.add(rule);
        continue;
      }
      var iterations = 0;
      while (!rule.nextDate.isAfter(cutoff) &&
          (rule.endDate == null || !rule.nextDate.isAfter(rule.endDate!))) {
        if (++iterations > 1500) throw StateError('单个周期规则补记超过 1500 次');
        final id =
            'recurring-${rule.id}-${rule.nextDate.year}-${rule.nextDate.month}-${rule.nextDate.day}';
        if (existingIds.add(id)) {
          nextEntries.add(
            Entry(
              id: id,
              accountId: rule.accountId,
              cents: rule.cents,
              income: rule.income,
              category: rule.category,
              note: rule.note,
              date: rule.nextDate,
              pending: true,
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

  void _validateAccount(Account a) {
    if (!Account.kindLabels.containsKey(a.kind) ||
        !Account.supportedCurrencies.contains(a.currency) ||
        a.iconPngBase64.length > 200000 ||
        !_validIconPng(a.iconPngBase64) ||
        (a.lastFour.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(a.lastFour)) ||
        (a.cardRef.isNotEmpty &&
            !RegExp(r'^[a-f0-9]{32}$').hasMatch(a.cardRef)) ||
        (a.expiry.isNotEmpty &&
            !RegExp(r'^(0[1-9]|1[0-2])/\d{4}$').hasMatch(a.expiry)) ||
        (a.creditLimitCents != null && a.creditLimitCents! < 0) ||
        (a.statementDay != null &&
            (a.statementDay! < 1 || a.statementDay! > 31)) ||
        (a.paymentDay != null && (a.paymentDay! < 1 || a.paymentDay! > 31))) {
      throw StateError('账户信息无效');
    }
  }

  Future<void> addAccount(Account a) async {
    _validateAccount(a);
    if (accounts.any((x) => x.id == a.id) ||
        !Account.supportedCurrencies.contains(a.currency)) {
      throw StateError('账户无效');
    }
    await _commit([...accounts, a], [...entries]);
  }

  Future<void> updateAccount(Account a) async {
    _validateAccount(a);
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
          .where((e) => e.accountId == id && !e.pending)
          .fold(0, (int s, e) => s + (e.income ? e.cents : -e.cents));
  int _sum(DateTime month, bool income, String currency) => entries
      .where(
        (e) =>
            e.transferId.isEmpty &&
            !e.pending &&
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
