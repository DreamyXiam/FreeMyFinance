import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

import 'ledger.dart';
import 'reports.dart';
import 'csv_export.dart';
import 'backup_crypto.dart';

const navy = Color(0xff142946),
    teal = Color(0xff007f83),
    canvas = Color(0xfff2f6f8),
    ink = Color(0xff172d40);
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

int? parseSignedAmount(String value) {
  final text = value.trim();
  if (!text.startsWith('-')) return parseAmount(text);
  final n = parseAmount(text.substring(1));
  return n == null ? null : -n;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'FreeMyFinance',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: teal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: canvas,
      fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC'],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff2f6f8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const LoadLedger(),
  );
}

class LoadLedger extends StatelessWidget {
  const LoadLedger({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<Ledger>(
    future: Ledger.load(),
    builder: (context, s) {
      if (s.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('账本读取失败，请保留应用数据并重试。\n${s.error}'),
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

class _HomeState extends State<Home> {
  int tab = 0;
  String search = '', accountFilter = '', displayCurrency = 'CNY';
  DateTime? monthFilter;
  Ledger get ledger => widget.ledger;
  @override
  void initState() {
    super.initState();
    ledger.addListener(_update);
  }

  @override
  void dispose() {
    ledger.removeListener(_update);
    super.dispose();
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

  Future<void> addAccount([Account? account]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AccountForm(ledger: ledger, account: account),
    );
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

  @override
  Widget build(BuildContext context) {
    final entries = [...ledger.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    final filteredEntries = entries.where((e) {
      final accountName = ledger.accounts
          .where((a) => a.id == e.accountId)
          .map((a) => a.name)
          .join();
      final term = search.trim().toLowerCase();
      return (accountFilter.isEmpty || e.accountId == accountFilter) &&
          (monthFilter == null ||
              (e.date.year == monthFilter!.year &&
                  e.date.month == monthFilter!.month)) &&
          (term.isEmpty ||
              '${e.category} ${e.note} $accountName'.toLowerCase().contains(
                term,
              ));
    }).toList();
    final now = DateTime.now();
    final total = ledger.accounts
        .where((a) => a.currency == displayCurrency)
        .fold<int>(0, (s, a) => s + ledger.balance(a.id));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: canvas,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FreeMyFinance',
              style: TextStyle(
                color: navy,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -.5,
              ),
            ),
            Text(
              '让每一笔都有迹可循',
              style: TextStyle(color: Color(0xff71818e), fontSize: 11),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: '备份与恢复',
            onSelected: (value) {
              if (value == 'export') {
                exportBackup();
              } else if (value == 'encrypted') {
                exportEncryptedBackup();
              } else if (value == 'csv') {
                exportTransactions();
              } else {
                importBackup();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'encrypted', child: Text('导出加密备份')),
              PopupMenuItem(value: 'export', child: Text('导出未加密备份')),
              PopupMenuItem(value: 'import', child: Text('恢复备份')),
              PopupMenuItem(value: 'csv', child: Text('导出账单 CSV')),
            ],
          ),
          IconButton(
            onPressed: addTransfer,
            tooltip: '账户转账',
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            onPressed: addAccount,
            tooltip: '添加账户',
            icon: const Icon(Icons.add_card_rounded),
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Color(0xff91d6d3),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '账户余额',
                            style: TextStyle(
                              color: Color(0xffb8c9d3),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DropdownButton<String>(
                          value: displayCurrency,
                          dropdownColor: navy,
                          style: const TextStyle(color: Colors.white),
                          items: Account.supportedCurrencies
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => displayCurrency = v!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${currencySymbol(displayCurrency)} ${money(total)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Summary(
                              label: '本月收入',
                              amount: ledger.incomeFor(
                                now,
                                currency: displayCurrency,
                              ),
                              currency: displayCurrency,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white24,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Summary(
                              label: '本月支出',
                              amount: ledger.expenseFor(
                                now,
                                currency: displayCurrency,
                              ),
                              currency: displayCurrency,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                      onPressed: () => setState(() => tab = 1),
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
                          onEdit: () => addEntry(e),
                        ),
                      ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                const PageTitle('账单', '每一笔收支，都在这里'),
                const SizedBox(height: 18),
                TextField(
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
                    const DropdownMenuItem(value: '', child: Text('全部账户')),
                    ...ledger.accounts.map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => accountFilter = v ?? ''),
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
                          setState(() => monthFilter = d);
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
                        onPressed: () => setState(() => monthFilter = null),
                        child: const Text('全部日期'),
                      ),
                  ],
                ),
                if (filteredEntries.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '没有匹配的账单',
                    subtitle: '试试调整筛选条件，或添加新账单。',
                  )
                else
                  ...filteredEntries.map(
                    (e) => EntryTile(
                      entry: e,
                      ledger: ledger,
                      onDelete: () => _delete(e),
                      onEdit: () => addEntry(e),
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const PageTitle('账户', '把不同账户放在一起管理'),
                    IconButton.filledTonal(
                      onPressed: addAccount,
                      tooltip: '添加账户',
                      icon: const Icon(Icons.add),
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
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xffdef2ef),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: a.imageUrl.isEmpty
                                ? const Icon(Icons.credit_card, color: teal)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.network(
                                      a.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.credit_card,
                                        color: teal,
                                      ),
                                    ),
                                  ),
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
                                const Text(
                                  '账户余额',
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
                              PopupMenuItem(value: 'edit', child: Text('编辑账户')),
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
            ),
            ReportView(ledger: ledger),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEntry,
        backgroundColor: teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (n) => setState(() => tab = n),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xffd8efec),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: '概览',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '账单',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '账户',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
        ],
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
    if (ledger.entries.any((e) => e.accountId == account.id)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账户仍有关联账单，请先处理账单')));
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
        await ledger.deleteAccount(account.id);
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
                ? const Color(0xffddf3ea)
                : const Color(0xffe7eef8),
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
            '$name · ${entry.date.year}/${entry.date.month.toString().padLeft(2, '0')}/${entry.date.day.toString().padLeft(2, '0')}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
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

class AccountForm extends StatefulWidget {
  final Ledger ledger;
  final Account? account;
  const AccountForm({super.key, required this.ledger, this.account});
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      opening = TextEditingController(text: '0'),
      imageUrl = TextEditingController();
  bool saving = false;
  String currency = 'CNY';
  @override
  void initState() {
    super.initState();
    final a = widget.account;
    if (a != null) {
      name.text = a.name;
      opening.text = money(a.openingCents);
      imageUrl.text = a.imageUrl;
      currency = a.currency;
    }
  }

  @override
  void dispose() {
    name.dispose();
    opening.dispose();
    imageUrl.dispose();
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
            Text(
              widget.account == null ? '添加账户' : '编辑账户',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '账户名称',
                hintText: '例如：储蓄卡、现金',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入账户名称' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: currency,
              decoration: const InputDecoration(labelText: '币种'),
              items: Account.supportedCurrencies
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged:
                  widget.account != null &&
                      widget.ledger.entries.any(
                        (e) => e.accountId == widget.account!.id,
                      )
                  ? null
                  : (v) => setState(() => currency = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: '初始余额（可为负）'),
              validator: (v) =>
                  parseSignedAmount(v ?? '') == null ? '请输入有效金额，最多两位小数' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: imageUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: '卡面图片 HTTPS 地址（选填）'),
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return null;
                final uri = Uri.tryParse(text);
                return uri == null || uri.scheme != 'https' || uri.host.isEmpty
                    ? '请输入有效的 HTTPS 图片地址'
                    : null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => saving = true);
                      try {
                        final account = Account(
                          id: widget.account?.id ?? uid(),
                          name: name.text.trim(),
                          openingCents: parseSignedAmount(opening.text)!,
                          imageUrl: imageUrl.text.trim(),
                          currency: currency,
                        );
                        if (widget.account == null) {
                          await widget.ledger.addAccount(account);
                        } else {
                          await widget.ledger.updateAccount(account);
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
                child: Text('保存账户'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
    final categories = income
        ? ['工资', '奖金', '转入', '其他收入']
        : ['餐饮', '购物', '交通', '住房', '娱乐', '医疗', '其他支出'];
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
                  category = income ? '工资' : '餐饮';
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
                  hintText: '选择常用分类或输入新分类',
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
    final controller = TextEditingController(
      text: money(widget.ledger.monthlyBudgetCents),
    );
    final form = GlobalKey<FormState>();
    final value = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('设置每月预算'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '预算金额（元，0 为关闭）'),
            validator: (v) => parseAmount(v ?? '') == null ? '请输入有效金额' : null,
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
                Navigator.pop(c, parseAmount(controller.text));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
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
