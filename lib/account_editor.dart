import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'card_number_store.dart';
import 'card_catalog_page.dart';
import 'card_catalog.dart';

import 'be_ui.dart';
import 'ledger.dart';
import 'wallet.dart';

int? _parseAmount(String value, {bool signed = false}) {
  final s = value.trim();
  final sign = signed && s.startsWith('-') ? -1 : 1;
  final n = sign < 0 ? s.substring(1) : s;
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(n)) return null;
  final parts = n.split('.');
  return sign *
      (int.parse(parts[0]) * 100 +
          int.parse(parts.length > 1 ? parts[1].padRight(2, '0') : '0'));
}

String _amount(int cents) => (cents / 100).toStringAsFixed(2);
const _descriptions = <String, String>{
  'cash': '现金、备用金',
  'debit': '银行储蓄卡、活期账户',
  'credit': '信用卡余额、额度和账期',
  'stock': '证券账户、市值',
  'fund': '基金账户、持仓金额',
  'metals': '黄金、白银等持仓',
  'crypto': '数字资产账户',
  'virtual': '支付宝、微信、电子钱包',
  'liability': '贷款和其他负债',
  'receivable': '借出款项、待收款',
  'other': '其他账户',
};
const _icons = <String, IconData>{
  'cash': Icons.payments_outlined,
  'debit': Icons.credit_card_rounded,
  'credit': Icons.credit_score_rounded,
  'stock': Icons.show_chart_rounded,
  'fund': Icons.pie_chart_outline_rounded,
  'metals': Icons.diamond_outlined,
  'crypto': Icons.currency_bitcoin_rounded,
  'virtual': Icons.account_balance_wallet_outlined,
  'liability': Icons.receipt_long_outlined,
  'receivable': Icons.call_received_rounded,
  'other': Icons.account_balance_outlined,
};

class AccountTypePicker extends StatelessWidget {
  final Ledger ledger;
  const AccountTypePicker({super.key, required this.ledger});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('选择账户分类')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          '选择最适合的类型',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: beInk,
          ),
        ),
        const SizedBox(height: 6),
        const Text('用于整理账户，之后可以查看余额和账单。', style: TextStyle(color: beMuted)),
        const SizedBox(height: 20),
        ...Account.kindLabels.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: beBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AccountEditorPage(ledger: ledger, kind: e.key),
                    ),
                  );
                  if (saved == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xffeaf4ff),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(_icons[e.key], color: beBlue),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.value,
                              style: const TextStyle(
                                color: beInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _descriptions[e.key]!,
                              style: const TextStyle(
                                color: beMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: beMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class AccountEditorPage extends StatefulWidget {
  final Ledger ledger;
  final String kind;
  final Account? account;
  final Future<bool> Function()? authenticate;
  final CardNumberStore? cardStore;
  const AccountEditorPage({
    super.key,
    required this.ledger,
    required this.kind,
    this.account,
    this.authenticate,
    this.cardStore,
  });
  @override
  State<AccountEditorPage> createState() => _AccountEditorPageState();
}

class _AccountEditorPageState extends State<AccountEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _opening = TextEditingController(text: '0'),
      _image = TextEditingController(),
      _lastFour = TextEditingController(),
      _cardNumber = TextEditingController(),
      _note = TextEditingController(),
      _instrument = TextEditingController(),
      _expiry = TextEditingController(),
      _limit = TextEditingController();
  late String _currency;
  int? _statementDay, _paymentDay;
  String _previewUrl = '';
  bool _saving = false, _include = true, _showNote = true, _obscureCard = true;
  CardNumberStore get _cardStore => widget.cardStore ?? SecureCardNumberStore();
  bool get _isCard => widget.kind == 'debit' || widget.kind == 'credit';
  bool get _isCredit => widget.kind == 'credit';
  bool get _hasBilling => _isCredit || widget.kind == 'liability';
  bool get _isInvestment =>
      ['stock', 'fund', 'metals', 'crypto'].contains(widget.kind);
  bool get _currencyLocked =>
      widget.account != null &&
      widget.ledger.entries.any((e) => e.accountId == widget.account!.id);
  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _currency = a?.currency ?? 'CNY';
    if (a != null) {
      _name.text = a.name;
      _opening.text = _amount(a.openingCents);
      _image.text = a.imageUrl;
      _previewUrl = a.imageUrl;
      _lastFour.text = a.lastFour;
      _note.text = a.note;
      _instrument.text = a.instrument;
      _expiry.text = a.expiry;
      _include = a.includeInNetWorth;
      _showNote = a.showNoteOnCard;
      _limit.text = a.creditLimitCents == null
          ? ''
          : _amount(a.creditLimitCents!);
      _statementDay = a.statementDay;
      _paymentDay = a.paymentDay;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _opening,
      _image,
      _lastFour,
      _cardNumber,
      _note,
      _instrument,
      _expiry,
      _limit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final a = Account(
      id:
          widget.account?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      openingCents: _parseAmount(_opening.text, signed: true)!,
      currency: _currency,
      imageUrl: _image.text.trim(),
      kind: widget.kind,
      lastFour: _isCard ? _lastFour.text.trim() : '',
      cardRef: widget.account?.cardRef ?? '',
      note: _note.text.trim(),
      instrument: _isInvestment ? _instrument.text.trim() : '',
      expiry: _isCard ? _expiry.text.trim() : '',
      includeInNetWorth: _include,
      showNoteOnCard: _showNote,
      creditLimitCents: _isCredit && _limit.text.trim().isNotEmpty
          ? _parseAmount(_limit.text)
          : null,
      statementDay: _hasBilling ? _statementDay : null,
      paymentDay: _hasBilling ? _paymentDay : null,
    );
    try {
      await AccountWriter(widget.ledger, _cardStore).save(
        a,
        cardNumber: _cardNumber.text.trim().isEmpty
            ? null
            : _cardNumber.text.trim(),
        update: widget.account != null,
      );
      if (mounted) Navigator.pop(context, true);
    } on CardCleanupWarning {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        messenger.showSnackBar(
          const SnackBar(content: Text('账户已保存，但旧卡号清理失败，请检查设备安全存储')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请检查后重试')));
      }
    }
  }

  Future<void> _chooseCardArtwork() async {
    final card = await Navigator.of(context).push<CardArtwork>(
      MaterialPageRoute(builder: (_) => const CardCatalogPage()),
    );
    if (card == null || !mounted) return;
    setState(() {
      _image.text = card.imageUrl;
      _previewUrl = card.previewUrl;
      if (_name.text.trim().isEmpty) _name.text = card.name;
    });
  }

  Future<void> _viewSavedCard() async {
    final a = widget.account;
    if (a == null || a.cardRef.isEmpty) return;
    try {
      final ok =
          await (widget.authenticate?.call() ??
              LocalAuthentication().authenticate(
                localizedReason: '验证身份后查看已保存的卡号',
              ));
      if (!ok || !mounted) return;
      final value = await _cardStore.read(a.cardRef);
      if (!mounted) return;
      if (value == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('此设备未保存完整卡号，请重新输入')));
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('已保存的卡号'),
          content: SelectableText(value),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取卡号，请检查设备身份验证和安全存储')));
      }
    }
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 9),
        child: Text(
          title,
          style: const TextStyle(
            color: beMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: beBorder),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
  Widget _dayField(String title, int? current, ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int>(
        key: ValueKey('$title-$current'),
        initialValue: current,
        decoration: InputDecoration(
          labelText: title,
          suffixIcon: current == null
              ? null
              : IconButton(
                  tooltip: '清除$title',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close),
                ),
        ),
        hint: const Text('未设置'),
        items: List.generate(
          31,
          (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} 日')),
        ),
        onChanged: onChanged,
      );
  @override
  Widget build(BuildContext context) {
    final old = widget.account;
    final opening = _parseAmount(_opening.text, signed: true) ?? 0;
    final adjustment = old == null
        ? 0
        : widget.ledger.balance(old.id) - old.openingCents;
    final preview = Account(
      id: 'preview',
      name: _name.text.trim().isEmpty
          ? Account.kindLabels[widget.kind]!
          : _name.text.trim(),
      openingCents: opening,
      currency: _currency,
      imageUrl: _previewUrl,
      kind: widget.kind,
      lastFour: _lastFour.text.trim(),
      expiry: _expiry.text.trim(),
      note: _note.text.trim(),
      showNoteOnCard: _showNote,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(old == null ? '添加账户' : '编辑账户'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    '账户预览',
                    style: TextStyle(
                      color: beInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Account.kindLabels[widget.kind]!,
                    style: const TextStyle(color: beMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1.586,
                child: WalletCard(
                  account: preview,
                  balance: opening + adjustment,
                ),
              ),
              _section('卡面管理', [
                if (_isCard) ...[
                  OutlinedButton.icon(
                    onPressed: _chooseCardArtwork,
                    icon: const Icon(Icons.collections_outlined),
                    label: const Text('从卡面库选择'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _image,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: '卡面图片 HTTPS 地址（选填）',
                    suffixIcon: IconButton(
                      tooltip: '更新卡面预览',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () {
                        final u = Uri.tryParse(_image.text.trim());
                        if (_image.text.trim().isEmpty ||
                            (u != null &&
                                u.scheme == 'https' &&
                                u.host.isNotEmpty)) {
                          setState(() => _previewUrl = _image.text.trim());
                        }
                      },
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    final u = Uri.tryParse(_image.text.trim());
                    if (u != null && u.scheme == 'https' && u.host.isNotEmpty) {
                      setState(() => _previewUrl = _image.text.trim());
                    }
                  },
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return null;
                    final uri = Uri.tryParse(text);
                    return uri == null ||
                            uri.scheme != 'https' ||
                            uri.host.isEmpty
                        ? '请输入有效的 HTTPS 图片地址'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '填写图片地址后可刷新预览。',
                  style: TextStyle(color: beMuted, fontSize: 12),
                ),
              ]),
              _section('账户信息', [
                TextFormField(
                  controller: _name,
                  maxLength: 30,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '账户名称',
                    hintText: '例如：招商银行',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入账户名称' : null,
                ),
                if (_isInvestment) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _instrument,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: '关联标的（选填）',
                      hintText: '手动输入名称或代码',
                      helperText: '仅作记录，暂不自动同步行情',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: InputDecoration(
                    labelText: '账户币种',
                    helperText: _currencyLocked ? '已有账单的账户不能更改币种' : null,
                  ),
                  items: Account.supportedCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _currencyLocked
                      ? null
                      : (v) => setState(() => _currency = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _isCredit || widget.kind == 'liability'
                        ? '初始余额（负数代表欠款）'
                        : _isInvestment
                        ? '初始市值（手动填写）'
                        : '初始余额（可为负）',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => _parseAmount(v ?? '', signed: true) == null
                      ? '请输入有效金额，最多两位小数'
                      : null,
                ),
              ]),
              if (_isCard)
                _section('卡片信息', [
                  TextFormField(
                    controller: _cardNumber,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: _obscureCard,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: InputDecoration(
                      labelText: widget.account?.cardRef.isNotEmpty == true
                          ? '完整卡号（留空则保持不变）'
                          : '完整卡号（选填）',
                      suffixIcon: IconButton(
                        tooltip: _obscureCard ? '显示已输入的卡号' : '隐藏已输入的卡号',
                        icon: Icon(
                          _obscureCard
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureCard = !_obscureCard),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length >= 4) {
                        _lastFour.text = value.substring(value.length - 4);
                      }
                      setState(() {});
                    },
                    validator: (value) {
                      final v = (value ?? '').trim();
                      return v.isEmpty || RegExp(r'^\d{12,19}$').hasMatch(v)
                          ? null
                          : '请输入 12 至 19 位数字';
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '完整卡号仅保存在本机安全存储，不包含在账本备份中。',
                    style: TextStyle(color: beMuted, fontSize: 12),
                  ),
                  if (widget.account?.cardRef.isNotEmpty == true)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _viewSavedCard,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('验证身份后查看已保存卡号'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastFour,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    decoration: const InputDecoration(
                      labelText: '卡号尾号（选填）',
                      hintText: '仅输入后四位',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final tail = (v ?? '').trim(),
                          number = _cardNumber.text.trim();
                      if (tail.isNotEmpty && tail.length != 4) return '请输入四位数字';
                      if (number.isNotEmpty &&
                          number.length >= 4 &&
                          tail != number.substring(number.length - 4)) {
                        return '尾号与完整卡号不一致';
                      }
                      final old = widget.account;
                      if (old != null &&
                          old.cardRef.isNotEmpty &&
                          number.isEmpty &&
                          tail != old.lastFour) {
                        return '修改尾号请重新输入完整卡号';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _expiry,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: '有效期（选填）',
                      hintText: 'MM/YYYY',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final x = (v ?? '').trim();
                      return x.isEmpty ||
                              RegExp(r'^(0[1-9]|1[0-2])/\d{4}$').hasMatch(x)
                          ? null
                          : '请输入 MM/YYYY';
                    },
                  ),
                ]),
              if (_hasBilling)
                _section(_isCredit ? '信用卡额度与账期' : '账单与账期', [
                  if (_isCredit)
                    TextFormField(
                      controller: _limit,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '信用额度（选填）'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty || _parseAmount(v!) != null
                          ? null
                          : '请输入有效金额',
                    ),
                  const SizedBox(height: 12),
                  _dayField(
                    '每月账单日（选填）',
                    _statementDay,
                    (v) => setState(() => _statementDay = v),
                  ),
                  const SizedBox(height: 12),
                  _dayField(
                    '每月还款日（选填）',
                    _paymentDay,
                    (v) => setState(() => _paymentDay = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '账期仅作记录，暂不自动生成提醒。',
                    style: TextStyle(color: beMuted, fontSize: 12),
                  ),
                ]),
              _section('备注', [
                TextFormField(
                  controller: _note,
                  maxLength: 80,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: '备注（选填）'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在卡片上显示备注'),
                  value: _showNote,
                  onChanged: (v) => setState(() => _showNote = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('纳入资产总览'),
                  subtitle: const Text('关闭后不会计入账户总余额及人民币折算'),
                  value: _include,
                  onChanged: (v) => setState(() => _include = v),
                ),
              ]),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(old == null ? '保存账户' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
