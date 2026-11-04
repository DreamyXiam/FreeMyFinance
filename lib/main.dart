import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

import 'ledger.dart';

const navy = Color(0xff142946),
    teal = Color(0xff007f83),
    canvas = Color(0xfff2f6f8),
    ink = Color(0xff172d40);
String money(int cents) => (cents / 100).toStringAsFixed(2);
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
int? parseAmount(String value) {
  final s = value.trim();
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(s)) return null;
  final p = s.split('.');
  return int.parse(p[0]) * 100 +
      int.parse(p.length > 1 ? p[1].padRight(2, '0') : '0');
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
      final contents = utf8.decode(bytes);
      if (!mounted) return;
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

  Future<void> addAccount() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AccountForm(ledger: ledger),
    );
  }

  Future<void> addEntry() async {
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
        builder: (_) => EntryForm(ledger: ledger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = [...ledger.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    final total = ledger.accounts.fold<int>(
      0,
      (s, a) => s + ledger.balance(a.id),
    );
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
              } else {
                importBackup();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('导出备份')),
              PopupMenuItem(value: 'import', child: Text('恢复备份')),
            ],
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
                            '账户总余额 · CNY',
                            style: TextStyle(
                              color: Color(0xffb8c9d3),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '¥ ${money(total)}',
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
                              amount: ledger.incomeFor(now),
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
                              amount: ledger.expenseFor(now),
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
                        ),
                      ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                const PageTitle('账单', '每一笔收支，都在这里'),
                const SizedBox(height: 18),
                if (entries.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '还没有账单',
                    subtitle: '点击下方按钮添加第一笔。',
                  )
                else
                  ...entries.map(
                    (e) => EntryTile(
                      entry: e,
                      ledger: ledger,
                      onDelete: () => _delete(e),
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
                            '¥ ${money(ledger.balance(a.id))}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
        ],
      ),
    );
  }

  Future<void> _delete(Entry e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这笔账单？'),
        content: const Text('删除后账户余额会重新计算。'),
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
  const Summary({super.key, required this.label, required this.amount});
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
        '¥ ${money(amount)}',
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
  final VoidCallback onDelete;
  const EntryTile({
    super.key,
    required this.entry,
    required this.ledger,
    required this.onDelete,
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
              '${entry.income ? '+' : '−'}¥${money(entry.cents)}',
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
    );
  }
}

class AccountForm extends StatefulWidget {
  final Ledger ledger;
  const AccountForm({super.key, required this.ledger});
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      opening = TextEditingController(text: '0'),
      imageUrl = TextEditingController();
  bool saving = false;
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
            const Text(
              '添加账户',
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
            TextFormField(
              controller: opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '初始余额（元）'),
              validator: (v) =>
                  parseAmount(v ?? '') == null ? '请输入有效金额，最多两位小数' : null,
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
                        await widget.ledger.addAccount(
                          Account(
                            id: uid(),
                            name: name.text.trim(),
                            openingCents: parseAmount(opening.text)!,
                            imageUrl: imageUrl.text.trim(),
                          ),
                        );
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
  const EntryForm({super.key, required this.ledger});
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), note = TextEditingController();
  late String account;
  bool income = false, saving = false;
  String category = '餐饮';
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    account = widget.ledger.accounts.first.id;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
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
              const Text(
                '记一笔',
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
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '金额（元）',
                  prefixText: '¥ ',
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
              DropdownButtonFormField<String>(
                key: ValueKey(income),
                initialValue: category,
                decoration: const InputDecoration(labelText: '分类'),
                items: categories
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
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
                          await widget.ledger.addEntry(
                            Entry(
                              id: uid(),
                              accountId: account,
                              cents: parseAmount(amount.text)!,
                              income: income,
                              category: category,
                              note: note.text.trim(),
                              date: date,
                            ),
                          );
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
