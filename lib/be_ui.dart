import 'package:flutter/material.dart';

// Flutter implementation of the visual and motion principles in beUI.
const beBackground = Color(0xfffafafa);
const beSurface = Color(0xfff5f5f5);
const beInk = Color(0xff242424);
const beMuted = Color(0xff737373);
const beBorder = Color(0xffe9e9e9);
const beBlue = Color(0xff0285f7);
const beSuccess = Color(0xff189c71);

ThemeData beTheme() {
  const scheme = ColorScheme.light(
    primary: beBlue,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: beInk,
    secondary: beInk,
    onSecondary: Colors.white,
    error: Color(0xffdc4b4b),
  );
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: beBorder),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: beBackground,
    fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC'],
    appBarTheme: const AppBarTheme(
      backgroundColor: beBackground,
      foregroundColor: beInk,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: beInk,
        letterSpacing: -.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: beBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      dragHandleColor: Color(0xffc9c9c9),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: beSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: outline,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: beBlue, width: 1.5),
      ),
      labelStyle: const TextStyle(color: beMuted),
      hintStyle: const TextStyle(color: Color(0xffa3a3a3)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: beBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
    ),
    dividerTheme: const DividerThemeData(color: beBorder, thickness: 1),
  );
}

class BeNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const BeNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  static const labels = ['概览', '账单', '账户', '统计'];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.receipt_long_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.bar_chart_rounded,
  ];
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: beBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0a000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final width = (c.maxWidth - 8) / 4;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: 4 + selectedIndex * width,
                  top: 4,
                  bottom: 4,
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xffeaf4ff),
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selectedIndex,
                        label: labels[i],
                        onTap: () => onSelected(i),
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => onSelected(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icons[i],
                                size: 21,
                                color: i == selectedIndex ? beBlue : beMuted,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == selectedIndex
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: i == selectedIndex ? beBlue : beMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BeBalanceCard extends StatelessWidget {
  final String currency, balance, income, expense;
  final List<String> currencies;
  final ValueChanged<String> onCurrencyChanged;
  final String? estimate;
  const BeBalanceCard({
    super.key,
    required this.currency,
    required this.balance,
    required this.income,
    required this.expense,
    required this.currencies,
    required this.onCurrencyChanged,
    this.estimate,
  });
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: beBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xffeaf4ff),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: beBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '账户总余额',
                      style: TextStyle(
                        color: beInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '仅统计纳入总览的账户',
                      style: TextStyle(color: beMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: beSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currency,
                    isDense: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                    items: currencies
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onCurrencyChanged(v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            child: FittedBox(
              key: ValueKey(balance),
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                balance,
                style: const TextStyle(
                  fontSize: 34,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800,
                  color: beInk,
                ),
              ),
            ),
          ),
          if (estimate != null) ...[
            const SizedBox(height: 8),
            Text(
              estimate!,
              style: const TextStyle(color: beMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BalanceStat(
                  label: '本月收入',
                  value: income,
                  icon: Icons.south_west_rounded,
                  color: beSuccess,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceStat(
                  label: '本月支出',
                  value: expense,
                  icon: Icons.north_east_rounded,
                  color: beBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _BalanceStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext c) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: beMuted, fontSize: 11)),
            const SizedBox(height: 3),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: beInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Small touch feedback that leaves the child's normal tap and semantics intact.
class BePressFeedback extends StatefulWidget {
  final Widget child;
  const BePressFeedback({super.key, required this.child});
  @override
  State<BePressFeedback> createState() => _BePressFeedbackState();
}

class _BePressFeedbackState extends State<BePressFeedback> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => setState(() => pressed = true),
      onPointerUp: (_) => setState(() => pressed = false),
      onPointerCancel: (_) => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed && !reduce ? .96 : 1,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
