import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'be_ui.dart';
import 'ledger.dart';

const _bg = beBackground, _ink = beInk;
String _symbol(String c) => switch (c) {
  'CNY' => '¥',
  'HKD' => 'HK\$',
  'USD' => 'US\$',
  'EUR' => '€',
  'GBP' => '£',
  _ => c,
};
String _money(int cents) => (cents / 100).toStringAsFixed(2);
String _valueLabel(String kind) => switch (kind) {
  'cash' => '现金余额',
  'stock' => '股票市值',
  'fund' => '基金价值',
  'metals' || 'crypto' => '资产市值',
  'liability' => '负债余额',
  'receivable' => '应收余额',
  _ => '余额',
};
List<Color> _palette(String kind) => switch (kind) {
  'cash' => [const Color(0xff5d7180), const Color(0xff29364a)],
  'debit' => [const Color(0xff3c86a8), const Color(0xff193d68)],
  'credit' => [const Color(0xff515464), const Color(0xff22232e)],
  'stock' => [const Color(0xff4d79c5), const Color(0xff253758)],
  'fund' => [const Color(0xff578f81), const Color(0xff294f57)],
  'metals' => [const Color(0xffb0925c), const Color(0xff6a503b)],
  'crypto' => [const Color(0xffa36c44), const Color(0xff5b3345)],
  'virtual' => [const Color(0xff7b7bb6), const Color(0xff414872)],
  'liability' => [const Color(0xffa36b6b), const Color(0xff5b3545)],
  'receivable' => [const Color(0xff4b9a86), const Color(0xff27565d)],
  _ => [const Color(0xff527188), const Color(0xff293c50)],
};

class WalletPage extends StatefulWidget {
  final Ledger ledger;
  const WalletPage({super.key, required this.ledger});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _animation;
  final Map<String, Widget> _cardCache = {};
  double _position = 0;
  String _currency = '全部';
  bool _sortByName = false;
  List<Account> get _items {
    final list = widget.ledger.accounts
        .where((a) => _currency == '全部' || a.currency == _currency)
        .toList();
    if (_sortByName) list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addListener(() {
          if (_animation != null && mounted) {
            setState(
              () => _position = _animation!.value.clamp(
                0.0,
                math.max(0, _items.length - 1).toDouble(),
              ),
            );
          }
        });
    widget.ledger.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.ledger.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _cardCache.clear();
        final n = _items.length;
        _position = n == 0 ? 0 : _position.clamp(0.0, (n - 1).toDouble());
      });
    }
  }

  Widget _cachedCard(Account account) => _cardCache.putIfAbsent(
    account.id,
    () => RepaintBoundary(
      child: WalletCard(
        account: account,
        balance: widget.ledger.balance(account.id),
      ),
    ),
  );

  void _goTo(int value) {
    final items = _items;
    if (items.isEmpty) return;
    final index = value.clamp(0, items.length - 1);
    _controller.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _position = index.toDouble());
      return;
    }
    _animation = Tween<double>(
      begin: _position,
      end: index.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward(from: 0);
  }

  void _showAccount(Account account) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('账户余额'),
                trailing: Text(
                  '${_symbol(account.currency)} ${_money(widget.ledger.balance(account.id))}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('币种'),
                trailing: Text(account.currency),
              ),
              const SizedBox(height: 8),
              const Text(
                '可在账户列表中编辑账户。',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final selected = items.isEmpty
        ? 0
        : _position.round().clamp(0, items.length - 1);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text(
          '卡包',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: _ink,
          ),
        ),
        actions: [
          PopupMenuButton<bool>(
            tooltip: '排序',
            icon: const Icon(Icons.swap_vert),
            initialValue: _sortByName,
            onSelected: (v) => setState(() {
              _controller.stop();
              _sortByName = v;
              _position = 0;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('默认顺序')),
              PopupMenuItem(value: true, child: Text('按名称排序')),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: '筛选币种',
            icon: const Icon(Icons.filter_list),
            initialValue: _currency,
            onSelected: (v) => setState(() {
              _controller.stop();
              _currency = v;
              _position = 0;
            }),
            itemBuilder: (_) => [
              '全部',
              ...Account.supportedCurrencies,
            ].map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Row(
                children: [
                  Text(
                    items.isEmpty
                        ? '暂无账户'
                        : '${selected + 1} / ${items.length}',
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_currency != '全部')
                    Text(
                      _currency,
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.credit_card_off_outlined,
                              size: 42,
                              color: Colors.blueGrey,
                            ),
                            SizedBox(height: 14),
                            Text(
                              '还没有卡片',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '先在账户页添加账户，或调整筛选条件。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.blueGrey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = math.min(
                          constraints.maxWidth - 32,
                          520.0,
                        );
                        final height = width / 1.586;
                        final step = math.max(62.0, height * .43);
                        final anchor = math.max(
                          8.0,
                          (constraints.maxHeight - height) * .35,
                        );
                        final visible = <int>[];
                        for (var i = 0; i < items.length; i++) {
                          final y = anchor + (i - _position) * step;
                          if (y + height >= -50 &&
                              y < constraints.maxHeight + 50) {
                            visible.add(i);
                          }
                        }
                        visible.sort(
                          (a, b) => (b - _position).abs().compareTo(
                            (a - _position).abs(),
                          ),
                        );
                        return GestureDetector(
                          key: const ValueKey('wallet-stack'),
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) => _controller.stop(),
                          onVerticalDragUpdate: (d) => setState(
                            () => _position =
                                (_position - (d.primaryDelta ?? 0) / step)
                                    .clamp(0.0, (items.length - 1).toDouble()),
                          ),
                          onVerticalDragCancel: () => _goTo(_position.round()),
                          onVerticalDragEnd: (d) {
                            final velocity = d.primaryVelocity ?? 0;
                            _goTo((_position - velocity / (step * 5)).round());
                          },
                          onTapUp: (details) {
                            for (final i in visible.reversed) {
                              final y = anchor + (i - _position) * step;
                              final left = (constraints.maxWidth - width) / 2;
                              if (details.localPosition.dx >= left &&
                                  details.localPosition.dx <= left + width &&
                                  details.localPosition.dy >= y &&
                                  details.localPosition.dy <= y + height) {
                                if (i == selected) {
                                  _showAccount(items[i]);
                                } else {
                                  _goTo(i);
                                }
                                break;
                              }
                            }
                          },
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              for (final i in visible)
                                Positioned(
                                  key: ValueKey('wallet-card-$i'),
                                  left: (constraints.maxWidth - width) / 2,
                                  top: anchor + (i - _position) * step,
                                  width: width,
                                  height: height,
                                  child: Transform.translate(
                                    offset: Offset(
                                      ((i - _position) * 3).clamp(-12.0, 12.0),
                                      0,
                                    ),
                                    child: Transform.rotate(
                                      angle: ((i - _position) * .012).clamp(
                                        -.04,
                                        .04,
                                      ),
                                      child: Transform.scale(
                                        scale:
                                            1 -
                                            math.min(
                                              (i - _position).abs() * .04,
                                              .14,
                                            ),
                                        child: _cachedCard(items[i]),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: items.isEmpty || selected == 0
                        ? null
                        : () => _goTo(selected - 1),
                    tooltip: '上一张',
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  const SizedBox(width: 20),
                  IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭卡包',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _ink,
                      minimumSize: const Size(56, 56),
                    ),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: items.isEmpty || selected == items.length - 1
                        ? null
                        : () => _goTo(selected + 1),
                    tooltip: '下一张',
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WalletCard extends StatelessWidget {
  final Account account;
  final int balance;
  const WalletCard({super.key, required this.account, required this.balance});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${account.name}，余额 ${_symbol(account.currency)} ${_money(balance)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x400d1a25),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _palette(account.kind),
                  ),
                ),
              ),
              if (account.imageUrl.isEmpty)
                Positioned(
                  right: -30,
                  top: -55,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .10),
                    ),
                  ),
                ),
              if (account.imageUrl.isNotEmpty)
                Image.network(
                  account.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x22000000),
                      Color(0xbb000000),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            account.lastFour.isEmpty
                                ? account.name
                                : '${account.name} · ${account.lastFour}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x55000000),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${Account.kindLabels[account.kind] ?? '账户'} · ${account.currency}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (account.expiry.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '有效期 ${account.expiry}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (account.showNoteOnCard && account.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          account.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _valueLabel(account.kind),
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_symbol(account.currency)} ${_money(balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
