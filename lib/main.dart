import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'be_ui.dart';
import 'be_tools_menu.dart';
import 'ledger.dart';
import 'wallet.dart';
import 'account_editor.dart';
import 'card_number_store.dart';
import 'reports.dart';
import 'csv_export.dart';
import 'backup_crypto.dart';
import 'xlsx_export.dart';
import 'reminders.dart';
import 'remote_rates.dart';
import 'monthly_overview.dart';
import 'ai_analysis_panel.dart';
import 'ai_settings.dart';
import 'category_swipe_tile.dart';
import 'account_icon.dart';
import 'lock_controller.dart';
import 'update_checker.dart';

const navy = beInk, teal = beBlue, canvas = beBackground, ink = beInk;
String currencySymbol(String code) => switch (code) {
  'CNY' => '¥',
  'HKD' => 'HK\$',
  'USD' => 'US\$',
  'EUR' => '€',
  'GBP' => '£',
  _ => code,
};
String money(int cents) => (cents / 100).toStringAsFixed(2);
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
int? parseAmount(String value) {
  final s = value.trim();
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(s)) return null;
  final p = s.split('.');
  return int.parse(p[0]) * 100 +
      int.parse(p.length > 1 ? p[1].padRight(2, '0') : '0');
}

int? parseRate(String value) {
  final s = value.trim();
  if (!RegExp(r'^\d{1,4}(\.\d{1,6})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final n =
      int.parse(parts[0]) * 1000000 +
      int.parse(parts.length > 1 ? parts[1].padRight(6, '0') : '0');
  return n > 0 && n <= 1000000000 ? n : null;
}

int? parseSignedAmount(String value) {
  final text = value.trim();
  if (!text.startsWith('-')) return parseAmount(text);
  final n = parseAmount(text.substring(1));
  return n == null ? null : -n;
}

int? parseBudgetAmount(String value) {
  final text = value.trim();
  if (RegExp(r'^0+(?:\.0{1,2})?$').hasMatch(text)) return 0;
  return parseAmount(text);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinanceApp());
}

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});
  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> with WidgetsBindingObserver {
  final lock = LockController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lock.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    lock.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lock.lock();
    }
  }

  @override
  Widget build(BuildContext context) => LockScope(
    controller: lock,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FreeMyFinance',
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: beTheme(),
      home: AnimatedBuilder(
        animation: lock,
        builder: (context, _) {
          if (!lock.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (lock.error != null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lock.error!),
                    TextButton(
                      onPressed: lock.initialize,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (lock.locked) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: teal),
                    const SizedBox(height: 16),
                    const Text(
                      'FreeMyFinance 已锁定',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: lock.authenticating
                          ? null
                          : () async {
                              final ok = await lock.unlock();
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('身份验证未通过')),
                                );
                              }
                            },
                      child: const Text('验证身份并解锁'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const LoadLedger();
        },
      ),
    ),
  );
}

class LockScope extends InheritedNotifier<LockController> {
  const LockScope({
    super.key,
    required LockController controller,
    required super.child,
  }) : super(notifier: controller);
  static LockController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LockScope>()!.notifier!;
}

class LoadLedger extends StatefulWidget {
  const LoadLedger({super.key});
  @override
  State<LoadLedger> createState() => _LoadLedgerState();
}

class _LoadLedgerState extends State<LoadLedger> {
  late final Future<Ledger> _ledgerFuture = Ledger.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<Ledger>(
    future: _ledgerFuture,
    builder: (context, s) {
      if (s.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '账本读取失败，请保留应用数据并重试。\n${s.error}\n如果设备密钥已经丢失，需要重新安装应用并从之前导出的备份恢复；重新安装会清除当前应用数据。',
              ),
            ),
          ),
        );
      }
      if (!s.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Home(ledger: s.data!);
    },
  );
}

class Home extends StatefulWidget {
  final Ledger ledger;
  const Home({super.key, required this.ledger});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 0;
  final visitedTabs = <int>{0};
  bool _generating = false;
  String search = '',
      accountFilter = '',
      categoryFilter = '',
      displayCurrency = 'CNY';
  DateTime? monthFilter;
  DateTime? dayFilter;
  final searchController = TextEditingController();
  final billController = ScrollController();
  Ledger get ledger => widget.ledger;
  @override
  void initState() {
    super.initState();
    ledger.addListener(_update);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateDueBills();
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final checker = UpdateChecker();
    try {
      final update = await checker.check(appVersion);
      if (!mounted || update == null) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('发现新版本 ${update.version}'),
          content: SingleChildScrollView(
            child: Text(
              update.notes.isEmpty ? '新版本已在 GitHub Releases 发布。' : update.notes,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: update.url));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('下载链接已复制，请在浏览器打开')),
                  );
                }
              },
              child: const Text('复制下载链接'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Offline startup must remain usable.
    } finally {
      checker.close();
    }
  }

  Future<void> _generateDueBills() async {
    if (!mounted || _generating) return;
    _generating = true;
    try {
      await ledger.applyRecurring(DateTime.now());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('到期账单自动生成失败，请在周期账单中重试')));
      }
    } finally {
      _generating = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _generateDueBills();
  }

  @override
  void dispose() {
    ledger.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    billController.dispose();
    super.dispose();
  }

  void _openCalendarDay(DateTime date) {
    searchController.clear();
    setState(() {
      dayFilter = DateTime(date.year, date.month, date.day);
      monthFilter = null;
      accountFilter = '';
      categoryFilter = '';
      search = '';
      tab = 1;
      visitedTabs.add(1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && billController.hasClients) billController.jumpTo(0);
    });
  }

  void _update() {
    if (mounted) setState(() {});
  }

  Future<void> exportBackup() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('导出备份'),
        content: const Text('备份包含账户和账单明细，文件未加密。请选择安全的位置保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('继续导出'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    try {
      final bytes = utf8.encode(ledger.exportBackup());
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          title: '导出 FreeMyFinance 备份',
          files: [XFile.fromData(bytes, mimeType: 'application/json')],
          fileNameOverrides: ['FreeMyFinance-backup.json'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('导出失败，请重试')));
      }
    }
  }

  Future<String?> requestBackupPassword({required bool creating}) async {
    final first = TextEditingController(), confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(creating ? '设置备份密码' : '输入备份密码'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(creating ? '密码无法找回，请妥善保管。' : '输入导出时设置的密码。'),
              const SizedBox(height: 12),
              TextFormField(
                controller: first,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: '备份密码'),
                validator: (v) =>
                    v == null || v.length < 8 ? '至少输入 8 个字符' : null,
              ),
              if (creating) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: '确认密码'),
                  validator: (v) => v != first.text ? '两次密码不一致' : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, first.text);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
    first.dispose();
    confirm.dispose();
    return result;
  }

  Future<void> exportEncryptedBackup() async {
    final password = await requestBackupPassword(creating: true);
    if (password == null || !mounted) return;
    try {
      final encrypted = await encryptBackup(ledger.exportBackup(), password);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          title: '导出加密备份',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(encrypted)),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: ['FreeMyFinance-encrypted-backup.json'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('加密导出失败，请重试')));
      }
    }
  }

  Future<void> exportTransactions() async {
    try {
      final bytes = [
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(exportCsv(ledger.accounts, ledger.entries)),
      ];
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          title: '导出账单 CSV',
          files: [
            XFile.fromData(Uint8List.fromList(bytes), mimeType: 'text/csv'),
          ],
          fileNameOverrides: ['FreeMyFinance-transactions.csv'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('导出失败，请重试')));
      }
    }
  }

  Future<void> exportExcel() async {
    try {
      final bytes = exportXlsx(ledger.accounts, ledger.entries);
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          title: '导出账单 Excel',
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          fileNameOverrides: ['FreeMyFinance-transactions.xlsx'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('导出失败，请重试')));
      }
    }
  }

  Future<void> importBackup() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null || !mounted) return;
      if ((await file.length() ?? 0) > 10 * 1024 * 1024) {
        throw const FormatException('备份文件超过 10 MB');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('备份文件超过 10 MB');
      }
      var contents = utf8.decode(bytes);
      if (!mounted) return;
      final envelope = jsonDecode(contents);
      if (envelope is Map && envelope['format'] == 'FreeMyFinanceEncrypted') {
        final password = await requestBackupPassword(creating: false);
        if (password == null || !mounted) return;
        contents = await decryptBackup(contents, password);
        if (!mounted) return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('恢复备份？'),
          content: const Text('恢复会替换当前设备上的所有账户和账单。请先导出当前账本备份。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('替换并恢复'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await ledger.restoreBackup(contents);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('备份已恢复')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('恢复失败：文件无效或无法读取，当前账本未替换')));
      }
    }
  }

  void _handleToolAction(String value) {
    if (value == 'export') {
      exportBackup();
    } else if (value == 'encrypted') {
      exportEncryptedBackup();
    } else if (value == 'rates') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RatesPage(ledger: ledger)),
      );
    } else if (value == 'ai-settings') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AiSettingsPage(ledger: ledger)),
      );
    } else if (value == 'storage-security') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StorageSecurityPage(ledger: ledger),
        ),
      );
    } else if (value == 'lock') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LockSettingsPage(controller: LockScope.of(context)),
        ),
      );
    } else if (value == 'reminders') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ReminderPage()));
    } else if (value == 'categories') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CategoriesPage(ledger: ledger)),
      );
    } else if (value == 'recurring') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RecurringPage(ledger: ledger)),
      );
    } else if (value == 'xlsx') {
      exportExcel();
    } else if (value == 'csv') {
      exportTransactions();
    } else {
      importBackup();
    }
  }

  Future<void> addAccount([Account? account]) async {
    if (account == null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => AccountTypePicker(ledger: ledger)),
      );
    } else {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AccountEditorPage(
            ledger: ledger,
            kind: account.kind,
            account: account,
            authenticate: () => LockScope.of(context).verifyIdentity(),
          ),
        ),
      );
    }
  }

  Future<void> addEntry([Entry? entry]) async {
    if (entry != null && entry.transferId.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('转账请删除后重新记录')));
      return;
    }
    if (ledger.accounts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先添加一个账户')));
      await addAccount();
      if (!mounted || ledger.accounts.isEmpty) return;
    }
    if (mounted) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => EntryForm(ledger: ledger, entry: entry),
      );
    }
  }

  Future<void> _markPaid(Entry entry) async {
    try {
      await ledger.markPaid(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已标记为已付款')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('标记付款失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = [...ledger.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    final categoryValues = [
      ...ledger.categoriesFor(false).map((v) => '0:$v'),
      ...ledger.categoriesFor(true).map((v) => '1:$v'),
    ];
    final effectiveCategoryFilter = categoryValues.contains(categoryFilter)
        ? categoryFilter
        : '';
    final accountNames = {
      for (final account in ledger.accounts) account.id: account.name,
    };
    final term = search.trim().toLowerCase();
    final filteredEntries = entries.where((e) {
      return (accountFilter.isEmpty || e.accountId == accountFilter) &&
          (effectiveCategoryFilter.isEmpty ||
              '${e.income ? 1 : 0}:${e.category}' == effectiveCategoryFilter) &&
          (dayFilter == null ||
              (e.date.year == dayFilter!.year &&
                  e.date.month == dayFilter!.month &&
                  e.date.day == dayFilter!.day)) &&
          (monthFilter == null ||
              (e.date.year == monthFilter!.year &&
                  e.date.month == monthFilter!.month)) &&
          (term.isEmpty ||
              '${e.category} ${e.note} ${accountNames[e.accountId] ?? ''}'
                  .toLowerCase()
                  .contains(term));
    }).toList();
    final now = DateTime.now();
    final total = ledger.accounts
        .where((a) => a.currency == displayCurrency && a.includeInNetWorth)
        .fold<int>(0, (s, a) => s + ledger.balance(a.id));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: canvas,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: beBlue,
                borderRadius: BorderRadius.circular(11),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FreeMyFinance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: beInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -.5,
                    ),
                  ),
                  Text(
                    '我的财务',
                    style: TextStyle(
                      color: beMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          BePressFeedback(
            child: IconButton(
              tooltip: '工具与设置',
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () async {
                final value = await showBeToolsMenu(context);
                if (value != null && mounted) _handleToolAction(value);
              },
            ),
          ),
          IconButton(
            onPressed: addTransfer,
            tooltip: '账户转账',
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              children: [
                BeBalanceCard(
                  currency: displayCurrency,
                  balance: '${currencySymbol(displayCurrency)} ${money(total)}',
                  income:
                      '${currencySymbol(displayCurrency)} ${money(ledger.incomeFor(now, currency: displayCurrency))}',
                  expense:
                      '${currencySymbol(displayCurrency)} ${money(ledger.expenseFor(now, currency: displayCurrency))}',
                  currencies: Account.supportedCurrencies,
                  onCurrencyChanged: (value) =>
                      setState(() => displayCurrency = value),
                  estimate:
                      !ledger.accounts.any(
                        (a) => a.currency != 'CNY' && a.includeInNetWorth,
                      )
                      ? '总余额 ¥ ${money(ledger.estimatedCnyCents() ?? 0)}'
                      : (ledger.estimatedCnyCents() == null
                            ? '未设置全部汇率，无法折合人民币'
                            : '总余额（参考折合）¥ ${money(ledger.estimatedCnyCents()!)} · ${ledger.rateSource == 'apihz' ? '接口盒子' : '手动汇率'}，非实时'),
                ),
                const SizedBox(height: 16),
                MonthlyOverview(
                  ledger: ledger,
                  currency: displayCurrency,
                  today: now,
                  onDaySelected: _openCalendarDay,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '最近账单',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        tab = 1;
                        visitedTabs.add(1);
                      }),
                      child: const Text('查看全部'),
                    ),
                  ],
                ),
                if (entries.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '还没有账单',
                    subtitle: '记下第一笔收入或支出，开始管理财务。',
                  )
                else
                  ...entries
                      .take(5)
                      .map(
                        (e) => EntryTile(
                          entry: e,
                          ledger: ledger,
                          onDelete: () => _delete(e),
                          onEdit: () => e.pending ? _markPaid(e) : addEntry(e),
                        ),
                      ),
              ],
            ),
            if (visitedTabs.contains(1))
              ListView.builder(
                controller: billController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount:
                    1 + (filteredEntries.isEmpty ? 1 : filteredEntries.length),
                itemBuilder: (context, index) {
                  if (index > 0) {
                    if (filteredEntries.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: '没有匹配的账单',
                        subtitle: '试试调整筛选条件，或添加新账单。',
                      );
                    }
                    final entry = filteredEntries[index - 1];
                    return EntryTile(
                      entry: entry,
                      ledger: ledger,
                      onDelete: () => _delete(entry),
                      onEdit: () =>
                          entry.pending ? _markPaid(entry) : addEntry(entry),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PageTitle('账单', '每一笔收支，都在这里'),
                      const SizedBox(height: 18),
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: '搜索分类、备注或账户',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => search = v),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue:
                            ledger.accounts.any((a) => a.id == accountFilter)
                            ? accountFilter
                            : '',
                        decoration: const InputDecoration(labelText: '账户筛选'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('全部账户'),
                          ),
                          ...ledger.accounts.map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => accountFilter = v ?? ''),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey('bill-category-$categoryFilter'),
                        initialValue: effectiveCategoryFilter,
                        decoration: const InputDecoration(labelText: '分类筛选'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('全部分类'),
                          ),
                          ...ledger
                              .categoriesFor(false)
                              .map(
                                (v) => DropdownMenuItem(
                                  value: '0:$v',
                                  child: Text('支出 · $v'),
                                ),
                              ),
                          ...ledger
                              .categoriesFor(true)
                              .map(
                                (v) => DropdownMenuItem(
                                  value: '1:$v',
                                  child: Text('收入 · $v'),
                                ),
                              ),
                        ],
                        onChanged: (v) =>
                            setState(() => categoryFilter = v ?? ''),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: monthFilter ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null && mounted) {
                                setState(() {
                                  monthFilter = d;
                                  dayFilter = null;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              monthFilter == null
                                  ? '选择月份'
                                  : '${monthFilter!.year} 年 ${monthFilter!.month} 月',
                            ),
                          ),
                          if (monthFilter != null)
                            TextButton(
                              onPressed: () =>
                                  setState(() => monthFilter = null),
                              child: const Text('全部日期'),
                            ),
                        ],
                      ),
                      if (dayFilter != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${dayFilter!.year} 年 ${dayFilter!.month} 月 ${dayFilter!.day} 日',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => dayFilter = null),
                                child: const Text('清除日期'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              )
            else
              const SizedBox.shrink(),
            if (visitedTabs.contains(2))
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const PageTitle('账户', '把不同账户放在一起管理'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => WalletPage(ledger: ledger),
                              ),
                            ),
                            tooltip: '打开卡包',
                            icon: const Icon(Icons.style_outlined),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: addAccount,
                            tooltip: '添加账户',
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (ledger.accounts.isEmpty)
                    const EmptyState(
                      icon: Icons.credit_card_outlined,
                      title: '添加你的第一个账户',
                      subtitle: '银行卡、现金或电子钱包都可以。',
                    )
                  else
                    ...ledger.accounts.map(
                      (a) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: beBorder),
                        ),
                        child: Row(
                          children: [
                            AccountIcon(
                              name: a.name,
                              pngBase64: a.iconPngBase64,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Account.kindLabels[a.kind] ?? '账户',
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${currencySymbol(a.currency)} ${money(ledger.balance(a.id))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: navy,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '账户操作',
                              onSelected: (value) {
                                if (value == 'edit') {
                                  addAccount(a);
                                } else {
                                  deleteAccount(a);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('编辑账户'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除账户'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              const SizedBox.shrink(),
            if (visitedTabs.contains(3))
              ReportView(ledger: ledger)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      floatingActionButton: BePressFeedback(
        child: FloatingActionButton.extended(
          onPressed: addEntry,
          backgroundColor: teal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('记一笔'),
        ),
      ),
      bottomNavigationBar: BeNavigationBar(
        selectedIndex: tab,
        onSelected: (n) => setState(() {
          tab = n;
          visitedTabs.add(n);
        }),
      ),
    );
  }

  Future<void> addTransfer() async {
    if (ledger.accounts.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('转账需要至少两个账户')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransferForm(ledger: ledger),
    );
  }

  Future<void> deleteAccount(Account account) async {
    if (ledger.entries.any((e) => e.accountId == account.id) ||
        ledger.recurring.any((r) => r.accountId == account.id)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账户仍有关联账单或周期规则，请先处理')));
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除账户？'),
        content: Text('将删除“${account.name}”。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await AccountWriter(ledger, SecureCardNumberStore()).delete(account);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
        }
      }
    }
  }

  Future<void> _delete(Entry e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这笔账单？'),
        content: Text(
          e.transferId.isEmpty ? '删除后账户余额会重新计算。' : '将同时删除转出和转入记录，并重新计算余额。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true) await ledger.deleteEntry(e.id);
  }
}

class Summary extends StatelessWidget {
  final String label;
  final int amount;
  final String currency;
  const Summary({
    super.key,
    required this.label,
    required this.amount,
    this.currency = 'CNY',
  });
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xffb8c9d3), fontSize: 12),
      ),
      const SizedBox(height: 6),
      Text(
        '${currencySymbol(currency)} ${money(amount)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class PageTitle extends StatelessWidget {
  final String title, subtitle;
  const PageTitle(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 25,
          color: ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Colors.blueGrey)),
    ],
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Icon(icon, size: 34, color: teal),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
        ),
      ],
    ),
  );
}

class EntryTile extends StatelessWidget {
  final Entry entry;
  final Ledger ledger;
  final VoidCallback onDelete, onEdit;
  const EntryTile({
    super.key,
    required this.entry,
    required this.ledger,
    required this.onDelete,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext c) {
    final names = ledger.accounts.where((a) => a.id == entry.accountId);
    final name = names.isEmpty ? '未知账户' : names.first.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: beBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: CircleAvatar(
            backgroundColor: entry.income
                ? const Color(0xffe5f6ef)
                : const Color(0xffeaf4ff),
            child: Icon(
              entry.income ? Icons.south_west : Icons.north_east,
              color: entry.income ? teal : navy,
              size: 19,
            ),
          ),
          onTap: onEdit,
          title: Text(
            entry.category,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${entry.pending ? '待付款 · 点击标记为已付款 · ' : ''}$name · ${entry.date.year}/${entry.date.month.toString().padLeft(2, '0')}/${entry.date.day.toString().padLeft(2, '0')}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.income ? '+' : '−'}${currencySymbol(names.isEmpty ? 'CNY' : names.first.currency)}${money(entry.cents)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: entry.income ? teal : ink,
                  fontSize: 15,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: '删除账单',
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EntryForm extends StatefulWidget {
  final Ledger ledger;
  final Entry? entry;
  const EntryForm({super.key, required this.ledger, this.entry});
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      note = TextEditingController(),
      categoryInput = TextEditingController(text: '餐饮');
  late String account;
  bool income = false, saving = false;
  String category = '餐饮';
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    account = e?.accountId ?? widget.ledger.accounts.first.id;
    if (e != null) {
      amount.text = money(e.cents);
      note.text = e.note;
      income = e.income;
      category = e.category;
      categoryInput.text = e.category;
      date = e.date;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    categoryInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.ledger.categoriesFor(income);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.entry == null ? '记一笔' : '编辑账单',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('支出')),
                  ButtonSegment(value: true, label: Text('收入')),
                ],
                selected: {income},
                onSelectionChanged: (s) => setState(() {
                  income = s.first;
                  category =
                      widget.ledger.categoriesFor(income).firstOrNull ?? '';
                  categoryInput.text = category;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '',
                ),
                validator: (v) {
                  final n = parseAmount(v ?? '');
                  return n == null || n <= 0 ? '请输入大于零的金额，最多两位小数' : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: account,
                decoration: const InputDecoration(labelText: '账户'),
                items: widget.ledger.accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => account = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: categoryInput,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '分类',
                  hintText: '选择分类或输入新分类，保存后同步到分类管理',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入分类' : null,
              ),
              Wrap(
                spacing: 6,
                children: categories
                    .map(
                      (v) => ActionChip(
                        label: Text(v),
                        onPressed: () => setState(() {
                          category = v;
                          categoryInput.text = v;
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: note,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '备注（选填）'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日期'),
                subtitle: Text(
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => date = d);
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => saving = true);
                        try {
                          final entry = Entry(
                            id: widget.entry?.id ?? uid(),
                            accountId: account,
                            cents: parseAmount(amount.text)!,
                            income: income,
                            category: categoryInput.text.trim(),
                            note: note.text.trim(),
                            date: date,
                          );
                          if (widget.entry == null) {
                            await widget.ledger.addEntry(entry);
                          } else {
                            await widget.ledger.updateEntry(entry);
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('保存失败，请重试')),
                            );
                          }
                        }
                      },
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('保存账单'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportView extends StatefulWidget {
  final Ledger ledger;
  const ReportView({super.key, required this.ledger});
  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  int year = DateTime.now().year, month = DateTime.now().month;
  String account = '', currency = 'CNY';
  Future<void> setBudget() async {
    var budgetInput = money(widget.ledger.monthlyBudgetCents);
    final form = GlobalKey<FormState>();
    final value = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('设置每月预算'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: budgetInput,
            onChanged: (value) => budgetInput = value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '预算金额（元，0 为关闭）'),
            validator: (v) =>
                parseBudgetAmount(v ?? '') == null ? '请输入有效金额' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, parseBudgetAmount(budgetInput));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value != null) {
      try {
        await widget.ledger.setMonthlyBudget(value);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('保存预算失败')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = {
      DateTime.now().year,
      year,
      ...widget.ledger.entries.map((e) => e.date.year),
    }.toList()..sort((a, b) => b.compareTo(a));
    final selectedAccount =
        widget.ledger.accounts.any(
          (a) => a.id == account && a.currency == currency,
        )
        ? account
        : '';
    final r = Report.calculate(
      widget.ledger.entries,
      year: year,
      month: month == 0 ? null : month,
      accountId: selectedAccount.isEmpty ? null : selectedAccount,
      allowedAccountIds: widget.ledger.accounts
          .where((a) => a.currency == currency)
          .map((a) => a.id)
          .toSet(),
    );
    final rows = r.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        const PageTitle('统计', '按时间和账户查看收支'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: currency,
          decoration: const InputDecoration(labelText: '统计币种'),
          items: Account.supportedCurrencies
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() {
            currency = v!;
            account = '';
          }),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: Text(
              widget.ledger.monthlyBudgetCents == 0
                  ? '每月预算未设置'
                  : '本月预算 ¥ ${money(widget.ledger.monthlyBudgetCents)}',
            ),
            subtitle: Text(
              widget.ledger.monthlyBudgetCents == 0
                  ? '设置每月支出上限'
                  : '本月支出 ¥ ${money(widget.ledger.expenseFor(DateTime.now()))} · ${widget.ledger.expenseFor(DateTime.now()) > widget.ledger.monthlyBudgetCents ? '已超预算' : '预算内'}',
            ),
            trailing: TextButton(onPressed: setBudget, child: const Text('设置')),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(labelText: '年份'),
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y 年')))
                    .toList(),
                onChanged: (v) => setState(() => year = v!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: month,
                decoration: const InputDecoration(labelText: '月份'),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('全年')),
                  ...List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1} 月'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => month = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('report-account-$currency-$selectedAccount'),
          initialValue: selectedAccount,
          decoration: const InputDecoration(labelText: '账户'),
          items: [
            const DropdownMenuItem(value: '', child: Text('全部账户')),
            ...widget.ledger.accounts
                .where((a) => a.currency == currency)
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
          ],
          onChanged: (v) => setState(() => account = v ?? ''),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Summary(
                  label: '收入',
                  amount: r.income,
                  currency: currency,
                ),
              ),
              Expanded(
                child: Summary(
                  label: '支出',
                  amount: r.expenses,
                  currency: currency,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AiAnalysisPanel(
          key: ValueKey('ai-$year-$month-$currency-$selectedAccount'),
          ledger: widget.ledger,
          report: r,
          year: year,
          month: month == 0 ? null : month,
          currency: currency,
          singleAccount: selectedAccount.isNotEmpty,
        ),
        const SizedBox(height: 24),
        const Text(
          '支出分类',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.bar_chart,
            title: '暂无支出',
            subtitle: '选择其他时间或账户查看。',
          )
        else
          ...rows.map(
            (e) => Card(
              child: ListTile(
                title: Text(e.key),
                subtitle: LinearProgressIndicator(
                  value: r.expenses == 0 ? 0 : e.value / r.expenses,
                ),
                trailing: Text('${currencySymbol(currency)} ${money(e.value)}'),
              ),
            ),
          ),
      ],
    );
  }
}

class TransferForm extends StatefulWidget {
  final Ledger ledger;
  const TransferForm({super.key, required this.ledger});
  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      note = TextEditingController(),
      received = TextEditingController();
  late String from, to;
  DateTime date = DateTime.now();
  bool saving = false;
  @override
  void initState() {
    super.initState();
    from = widget.ledger.accounts[0].id;
    to = widget.ledger.accounts[1].id;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    received.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      4,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '账户转账',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: from,
              decoration: const InputDecoration(labelText: '转出账户'),
              items: widget.ledger.accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => from = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: to,
              decoration: const InputDecoration(labelText: '转入账户'),
              items: widget.ledger.accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => to = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '转出金额'),
              validator: (v) {
                final n = parseAmount(v ?? '');
                return n == null || n <= 0 ? '请输入大于零的金额' : null;
              },
            ),
            const SizedBox(height: 12),
            if (widget.ledger.accounts
                    .firstWhere((a) => a.id == from)
                    .currency !=
                widget.ledger.accounts
                    .firstWhere((a) => a.id == to)
                    .currency) ...[
              TextFormField(
                controller: received,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '实际到账金额（转入币种）'),
                validator: (v) {
                  final n = parseAmount(v ?? '');
                  return n == null || n <= 0 ? '请输入实际到账金额' : null;
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: note,
              maxLength: 80,
              decoration: const InputDecoration(labelText: '备注（选填）'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              subtitle: Text(
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null && mounted) setState(() => date = d);
              },
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      if (from == to) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请选择不同账户')),
                        );
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        await widget.ledger.addTransfer(
                          id: uid(),
                          from: from,
                          to: to,
                          cents: parseAmount(amount.text)!,
                          toCents:
                              widget.ledger.accounts
                                      .firstWhere((a) => a.id == from)
                                      .currency ==
                                  widget.ledger.accounts
                                      .firstWhere((a) => a.id == to)
                                      .currency
                              ? null
                              : parseAmount(received.text),
                          date: date,
                          note: note.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('保存失败，请重试')),
                          );
                        }
                      }
                    },
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('保存转账'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RecurringPage extends StatefulWidget {
  final Ledger ledger;
  const RecurringPage({super.key, required this.ledger});
  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  @override
  void initState() {
    super.initState();
    widget.ledger.addListener(refresh);
  }

  @override
  void dispose() {
    widget.ledger.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> addRule() async {
    if (widget.ledger.accounts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先添加账户')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RecurringForm(ledger: widget.ledger),
    );
  }

  Future<void> apply() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('生成到期账单？'),
        content: const Text('将按周期规则生成截至今天的账单。已生成的月份不会重复生成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('生成'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final count = await widget.ledger.applyRecurring(DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已生成 $count 笔账单')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('生成失败，请检查规则或稍后重试')));
      }
    }
  }

  Future<void> remove(Recurring rule) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除周期规则？'),
        content: const Text('已生成的账单会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await widget.ledger.deleteRecurring(rule.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('周期账单')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: addRule,
      icon: const Icon(Icons.add),
      label: const Text('添加规则'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        const Text('打开应用时自动生成到期账单。生成后在账单中点击“标记为已付款”。'),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: widget.ledger.recurring.isEmpty ? null : apply,
          child: const Text('生成至今天'),
        ),
        if (widget.ledger.recurring.isEmpty)
          const EmptyState(
            icon: Icons.repeat,
            title: '还没有周期规则',
            subtitle: '可以添加每周、每月、每季度或每年的固定收支。',
          )
        else
          ...widget.ledger.recurring.map((r) {
            final a = widget.ledger.accounts.firstWhere(
              (a) => a.id == r.accountId,
            );
            final date =
                '${r.nextDate.year}-${r.nextDate.month.toString().padLeft(2, '0')}-${r.nextDate.day.toString().padLeft(2, '0')}';
            return Card(
              child: ListTile(
                title: Text(
                  '${r.category} · ${r.income ? '收入' : '支出'} ${currencySymbol(a.currency)}${money(r.cents)}',
                ),
                subtitle: Text(
                  '${a.name} · ${const {'weekly': '每周', 'monthly': '每月', 'quarterly': '每季度', 'yearly': '每年'}[r.frequency]} · 下次 $date${r.endDate == null ? '' : ' · 截止 ${r.endDate!.year}/${r.endDate!.month}/${r.endDate!.day}'}${r.note.isEmpty ? '' : ' · ${r.note}'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: r.enabled,
                      onChanged: (value) async {
                        try {
                          await widget.ledger.setRecurringEnabled(r.id, value);
                          if (value) {
                            await widget.ledger.applyRecurring(DateTime.now());
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('切换失败，请重试')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      onPressed: () => remove(r),
                      tooltip: '删除规则',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ),
  );
}

class RecurringForm extends StatefulWidget {
  final Ledger ledger;
  const RecurringForm({super.key, required this.ledger});
  @override
  State<RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<RecurringForm> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      category = TextEditingController(text: '其他支出'),
      note = TextEditingController();
  late String account;
  bool income = false, saving = false, enabled = true;
  String frequency = 'monthly';
  int day = DateTime.now().day;
  DateTime start = DateTime.now();
  DateTime? end;
  @override
  void initState() {
    super.initState();
    account = widget.ledger.accounts.first.id;
    start = DateTime(start.year, start.month, start.day);
    day = start.day;
  }

  @override
  void dispose() {
    amount.dispose();
    category.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      4,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '添加周期账单',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('支出')),
                ButtonSegment(value: true, label: Text('收入')),
              ],
              selected: {income},
              onSelectionChanged: (v) => setState(() {
                income = v.first;
                category.text = income ? '其他收入' : '其他支出';
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: account,
              decoration: const InputDecoration(labelText: '账户'),
              items: widget.ledger.accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} · ${a.currency}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => account = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '金额'),
              validator: (v) {
                final n = parseAmount(v ?? '');
                return n == null || n <= 0 ? '请输入大于零的金额' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: category,
              maxLength: 30,
              decoration: const InputDecoration(labelText: '分类'),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入分类' : null,
            ),
            Wrap(
              spacing: 6,
              children:
                  (income
                          ? const ['薪水', '生活费', '副业收入', '投资汇报', '其他收入']
                          : const ['订阅', 'AI/软件', '固定生活支出', '其他费用'])
                      .map(
                        (label) => ActionChip(
                          label: Text(label),
                          onPressed: () =>
                              setState(() => category.text = label),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: '频率'),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('每周')),
                DropdownMenuItem(value: 'monthly', child: Text('每月')),
                DropdownMenuItem(value: 'quarterly', child: Text('每季度')),
                DropdownMenuItem(value: 'yearly', child: Text('每年')),
              ],
              onChanged: (value) => setState(() => frequency = value!),
            ),
            if (frequency != 'weekly') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: day,
                decoration: const InputDecoration(labelText: '发生日（短月取月末）'),
                items: [
                  for (var value = 1; value <= 31; value++)
                    DropdownMenuItem(value: value, child: Text('$value 日')),
                ],
                onChanged: (value) => setState(() => day = value!),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              maxLength: 80,
              decoration: const InputDecoration(labelText: '备注（选填）'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('开始日期'),
              subtitle: Text(
                '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: start,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null && mounted) setState(() => start = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('结束日期（可选）'),
              subtitle: Text(
                end == null
                    ? '不设结束日期'
                    : '${end!.year}-${end!.month}-${end!.day}',
              ),
              trailing: end == null
                  ? const Icon(Icons.calendar_today_outlined)
                  : IconButton(
                      tooltip: '清除结束日期',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => end = null),
                    ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: end != null && !end!.isBefore(start)
                      ? end!
                      : start,
                  firstDate: start,
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) setState(() => end = picked);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用'),
              value: enabled,
              onChanged: (value) => setState(() => enabled = value),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      if (end != null && end!.isBefore(start)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('结束日期不能早于开始日期')),
                        );
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        await widget.ledger.addRecurring(
                          Recurring(
                            id: uid(),
                            accountId: account,
                            cents: parseAmount(amount.text)!,
                            income: income,
                            category: category.text.trim(),
                            note: note.text.trim(),
                            day: frequency == 'weekly' ? start.day : day,
                            nextDate: frequency == 'weekly'
                                ? start
                                : () {
                                    var candidate = DateTime(
                                      start.year,
                                      start.month,
                                      day.clamp(
                                        1,
                                        DateTime(
                                          start.year,
                                          start.month + 1,
                                          0,
                                        ).day,
                                      ),
                                    );
                                    if (candidate.isBefore(start)) {
                                      candidate = DateTime(
                                        start.year,
                                        start.month + 1,
                                        day.clamp(
                                          1,
                                          DateTime(
                                            start.year,
                                            start.month + 2,
                                            0,
                                          ).day,
                                        ),
                                      );
                                    }
                                    return candidate;
                                  }(),
                            startDate: start,
                            endDate: end,
                            enabled: enabled,
                            frequency: frequency,
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('保存失败，请重试')),
                          );
                        }
                      }
                    },
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('保存规则'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CategoriesPage extends StatefulWidget {
  final Ledger ledger;
  const CategoriesPage({super.key, required this.ledger});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  @override
  void initState() {
    super.initState();
    widget.ledger.addListener(refresh);
  }

  @override
  void dispose() {
    widget.ledger.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> rename(String oldName, bool income) async {
    var name = oldName;
    final form = GlobalKey<FormState>();
    final next = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('重命名分类'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('将同时修改所有使用该名称的账单和周期规则。'),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: oldName,
                onChanged: (v) => name = v,
                maxLength: 30,
                decoration: const InputDecoration(labelText: '分类名称'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入分类名称' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, name.trim());
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (next == null || next == oldName) return;
    try {
      await widget.ledger.renameCategory(oldName, next, income: income);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('修改失败，请重试')));
      }
    }
  }

  Future<void> addCategory() async {
    var name = '';
    final form = GlobalKey<FormState>();
    bool income = false;
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增分类标签'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('支出')),
                    ButtonSegment(value: true, label: Text('收入')),
                  ],
                  selected: {income},
                  onSelectionChanged: (v) =>
                      setDialogState(() => income = v.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  onChanged: (v) => name = v,
                  autofocus: true,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: '分类名称'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入分类名称' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(dialogContext, (name.trim(), income));
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await widget.ledger.addCategory(result.$1, income: result.$2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is StateError ? e.message : '添加失败，请重试')),
        );
      }
    }
  }

  Future<void> deleteCategory(String name, bool income) async {
    final fallback = Ledger.categoryFallbackFor(name, income: income);
    final count =
        widget.ledger.entries
            .where(
              (e) =>
                  e.transferId.isEmpty &&
                  e.income == income &&
                  e.category == name,
            )
            .length +
        widget.ledger.recurring
            .where((r) => r.income == income && r.category == name)
            .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('删除“$name”？'),
        content: Text(
          count == 0
              ? '此分类标签将从分类管理中移除。'
              : '已有 $count 条账单或周期规则使用此分类，删除后将归入“$fallback”。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.ledger.deleteCategory(name, income: income);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除分类失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCategory,
        icon: const Icon(Icons.add),
        label: const Text('新增分类'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('这里的标签会同步到记一笔；在记一笔输入的新分类也会自动加入。'),
          for (final income in [false, true]) ...[
            const SizedBox(height: 18),
            Text(
              income ? '收入分类' : '支出分类',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...widget.ledger
                .categoriesFor(income)
                .map(
                  (name) => CategorySwipeTile(
                    key: ValueKey(
                      'category-${income ? 'income' : 'expense'}-$name',
                    ),
                    name: name,
                    onEdit: () => rename(name, income),
                    onDelete: () => deleteCategory(name, income),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});
  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  bool enabled = false, busy = true;
  int minutes = 20 * 60;
  final service = ReminderService();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        enabled = p.getBool('daily_reminder_enabled') ?? false;
        minutes = p.getInt('daily_reminder_minutes') ?? 1200;
        busy = false;
      });
    }
  }

  Future<void> configure() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (selected == null || !mounted) return;
    setState(() => busy = true);
    try {
      final value = selected.hour * 60 + selected.minute;
      final granted = await service.enable(value);
      if (!mounted) return;
      setState(() {
        if (granted) {
          enabled = true;
          minutes = value;
        }
        busy = false;
      });
      if (!granted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('通知权限未开启，请在系统设置中允许通知')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('设置提醒失败，请检查系统通知权限')));
      }
    }
  }

  Future<void> disable() async {
    setState(() => busy = true);
    try {
      await service.disable();
      if (mounted) {
        setState(() {
          enabled = false;
          busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('关闭提醒失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('记账提醒')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          title: const Text('每日记账提醒'),
          subtitle: Text(
            enabled
                ? '每天 ${TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context)}'
                : '开启后选择提醒时间',
          ),
          value: enabled,
          onChanged: busy
              ? null
              : (v) {
                  if (v) {
                    configure();
                  } else {
                    disable();
                  }
                },
        ),
        if (enabled)
          TextButton.icon(
            onPressed: busy ? null : configure,
            icon: const Icon(Icons.schedule),
            label: const Text('更改时间'),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('提醒内容不包含账单金额。通知时间可能因系统省电设置稍有延迟；周期账单仍需在应用内手动生成。'),
        ),
      ],
    ),
  );
}

class LockSettingsPage extends StatelessWidget {
  final LockController controller;
  const LockSettingsPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('应用锁')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: const Text('使用设备身份验证'),
            subtitle: const Text('使用设备的指纹、人脸或锁屏密码解锁'),
            value: controller.enabled,
            onChanged: controller.authenticating
                ? null
                : (value) async {
                    final ok = await controller.setEnabled(value);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('身份验证未通过，设置未更改')),
                      );
                    }
                  },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('应用锁用于限制打开应用，不会加密手机中的账本文件。导出时可选择加密备份。切换到后台会重新锁定。'),
          ),
        ],
      ),
    ),
  );
}

class StorageSecurityPage extends StatefulWidget {
  final Ledger ledger;
  const StorageSecurityPage({super.key, required this.ledger});
  @override
  State<StorageSecurityPage> createState() => _StorageSecurityPageState();
}

class _StorageSecurityPageState extends State<StorageSecurityPage> {
  bool busy = false;
  Future<void> enable() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('启用本地加密？'),
        content: const Text(
          '请先导出并妥善保存备份。加密密钥由设备保管；卸载应用、清除数据或设备密钥丢失后，可能只能从备份恢复。此功能尚需安卓真机验证。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('已备份，启用加密'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.ledger.enableLocalEncryption();
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('本地账本加密已启用')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('加密未完成，请保留应用数据并检查备份')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('本地账本加密')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: Text(
            widget.ledger.localEncryptionEnabled ? '本地账本已加密' : '本地账本未加密',
          ),
          subtitle: const Text('账本数据使用设备保管的密钥加密；导出文件的保护方式由导出选项决定。'),
        ),
        const SizedBox(height: 16),
        if (!widget.ledger.localEncryptionEnabled)
          FilledButton(
            onPressed: busy ? null : enable,
            child: const Text('启用本地加密'),
          ),
        const SizedBox(height: 16),
        const Text(
          '请定期导出加密备份并保管密码。卸载应用或清除应用数据可能同时删除账本和设备密钥。当前版本不支持在应用内关闭本地加密。',
        ),
      ],
    ),
  );
}

class RatesPage extends StatefulWidget {
  final Ledger ledger;
  const RatesPage({super.key, required this.ledger});
  @override
  State<RatesPage> createState() => _RatesPageState();
}

class _RatesPageState extends State<RatesPage> {
  final form = GlobalKey<FormState>();
  late Map<String, TextEditingController> fields;
  bool busy = false;
  String? fetchedProviderTime;
  final secureRates = const FlutterSecureStorage();
  @override
  void initState() {
    super.initState();
    fetchedProviderTime = widget.ledger.rateSource == 'apihz'
        ? widget.ledger.rateProviderTime
        : null;
    fields = {
      for (final code in Account.supportedCurrencies.where((c) => c != 'CNY'))
        code: TextEditingController(
          text: widget.ledger.manualRates.containsKey(code)
              ? (widget.ledger.manualRates[code]! / 1000000).toStringAsFixed(6)
              : '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.ledger.setManualRates(
        {
          for (final e in fields.entries)
            if (e.value.text.trim().isNotEmpty) e.key: parseRate(e.value.text)!,
        },
        source: fetchedProviderTime == null ? 'manual' : 'apihz',
        providerTime: fetchedProviderTime,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存汇率失败')));
      }
    }
  }

  Future<void> fetchRates() async {
    String savedId = '', savedKey = '';
    try {
      savedId = await secureRates.read(key: 'apihz_user_id') ?? '';
      savedKey = await secureRates.read(key: 'apihz_user_key') ?? '';
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法读取已保存的接口凭据')));
      }
      return;
    }
    if (!mounted) return;
    final id = TextEditingController(
          text: savedId.isEmpty ? '88888888' : savedId,
        ),
        key = TextEditingController(
          text: savedKey.isEmpty ? '88888888' : savedKey,
        );
    var remember = savedId.isNotEmpty && savedKey.isNotEmpty;
    final credentials =
        await showDialog<({String id, String key, bool remember})>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
              title: const Text('获取每日汇率'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('使用接口盒子的个人 ID 和密钥，仅请求各币种兑换 1 元的参考汇率。'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: id,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '用户 ID'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: key,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: '通讯密钥'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: remember,
                      onChanged: (v) => setDialog(() => remember = v ?? false),
                      title: const Text('在本机安全保存凭据'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, (
                    id: id.text.trim(),
                    key: key.text,
                    remember: remember,
                  )),
                  child: const Text('获取'),
                ),
              ],
            ),
          ),
        );
    id.dispose();
    key.dispose();
    if (credentials == null || !mounted) return;
    setState(() => busy = true);
    final client = http.Client();
    try {
      final result = await RemoteRateClient(client)
          .fetch(credentials.id, credentials.key);
      try {
        if (credentials.remember) {
          await secureRates.write(key: 'apihz_user_id', value: credentials.id);
          await secureRates.write(
            key: 'apihz_user_key',
            value: credentials.key,
          );
        } else {
          await secureRates.delete(key: 'apihz_user_id');
          await secureRates.delete(key: 'apihz_user_key');
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('汇率已获取，但凭据设置未保存')));
        }
      }
      if (!mounted) return;
      setState(() {
        for (final e in result.rates.entries) {
          fields[e.key]?.text = (e.value / 1000000).toStringAsFixed(6);
        }
        fetchedProviderTime = result.providerTime;
        busy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('汇率已获取，请核对后保存')));
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('获取汇率失败，请检查凭据或网络；原汇率未改变')));
      }
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('汇率设置')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('输入 1 单位外币折合多少人民币。汇率仅供参考，留空表示未设置。'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : fetchRates,
            icon: const Icon(Icons.refresh),
            label: const Text('从接口盒子获取每日汇率'),
          ),
          if (fetchedProviderTime != null)
            Text(
              '来源：接口盒子 · 数据时间：$fetchedProviderTime',
              style: const TextStyle(color: beMuted, fontSize: 12),
            ),
          if (widget.ledger.ratesUpdatedAt != null)
            Text(
              '上次保存：${widget.ledger.ratesUpdatedAt!.year}-${widget.ledger.ratesUpdatedAt!.month.toString().padLeft(2, '0')}-${widget.ledger.ratesUpdatedAt!.day.toString().padLeft(2, '0')}',
            ),
          const SizedBox(height: 16),
          ...fields.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: e.value,
                onChanged: (_) {
                  if (fetchedProviderTime != null) {
                    setState(() => fetchedProviderTime = null);
                  }
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: '1 ${e.key} = 人民币'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty || parseRate(v!) != null
                    ? null
                    : '请输入大于零且不超过 1000 的汇率，最多六位小数',
              ),
            ),
          ),
          FilledButton(
            onPressed: busy ? null : save,
            child: const Text('保存汇率'),
          ),
        ],
      ),
    ),
  );
}
