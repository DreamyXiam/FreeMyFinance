import 'package:flutter/material.dart';

import 'be_ui.dart';
import 'ledger.dart';

class MonthlyOverview extends StatefulWidget {
  final Ledger ledger;
  final String currency;
  final DateTime today;
  const MonthlyOverview({
    super.key,
    required this.ledger,
    required this.currency,
    required this.today,
  });

  @override
  State<MonthlyOverview> createState() => _MonthlyOverviewState();
}

class _MonthlyOverviewState extends State<MonthlyOverview> {
  late DateTime visibleMonth;
  @override
  void initState() {
    super.initState();
    visibleMonth = DateTime(widget.today.year, widget.today.month);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final leading = first.weekday - 1;
    final days = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final cellCount = ((leading + days + 6) ~/ 7) * 7;
    final accountCurrencies = {
      for (final account in widget.ledger.accounts)
        account.id: account.currency,
    };
    final incomes = <int, int>{};
    final expenses = <int, int>{};
    for (final entry in widget.ledger.entries) {
      if (entry.transferId.isNotEmpty ||
          accountCurrencies[entry.accountId] != widget.currency ||
          entry.date.year != visibleMonth.year ||
          entry.date.month != visibleMonth.month) {
        continue;
      }
      final target = entry.income ? incomes : expenses;
      target[entry.date.day] = (target[entry.date.day] ?? 0) + entry.cents;
    }
    String money(int cents) => (cents / 100).toStringAsFixed(2);
    Widget dayAmount(int? cents, Color color) => SizedBox(
      height: 13,
      child: cents == null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money(cents),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${visibleMonth.year}/${visibleMonth.month.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('previous-month'),
                  tooltip: '上个月',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => visibleMonth = DateTime(
                      visibleMonth.year,
                      visibleMonth.month - 1,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  key: const Key('next-month'),
                  tooltip: '下个月',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => visibleMonth = DateTime(
                      visibleMonth.year,
                      visibleMonth.month + 1,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(color: beMuted, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              mainAxisExtent: 58,
              ),
              itemBuilder: (context, index) {
                final date = DateTime(
                  visibleMonth.year,
                  visibleMonth.month,
                  index - leading + 1,
                );
                final current = date.month == visibleMonth.month;
                final today =
                    date.year == widget.today.year &&
                    date.month == widget.today.month &&
                    date.day == widget.today.day;
                return Column(
                  children: [
                    Container(
                      width: 29,
                      height: 27,
                      decoration: BoxDecoration(
                        color: today ? beBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        today ? '今' : '${date.day}',
                        style: TextStyle(
                          color: today
                              ? Colors.white
                              : current
                              ? beInk
                              : beMuted.withValues(alpha: 0.45),
                          fontWeight: today ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (current) ...[
                      dayAmount(incomes[date.day], const Color(0xFF159F73)),
                      dayAmount(expenses[date.day], const Color(0xFFEA795D)),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Text(
                  '● 收入',
                  style: TextStyle(color: Color(0xFF159F73), fontSize: 12),
                ),
                SizedBox(width: 16),
                Text(
                  '● 支出',
                  style: TextStyle(color: Color(0xFFEA795D), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
