import 'package:flutter/material.dart';

import 'be_ui.dart';

Future<String?> showBeToolsMenu(BuildContext context) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: reduced ? AnimationStyle.noAnimation : null,
    builder: (context) => const _ToolsSheet(),
  );
}

class _ToolItem {
  final String id, title, subtitle;
  final IconData icon;
  const _ToolItem(this.id, this.title, this.subtitle, this.icon);
}

const _groups = <String, List<_ToolItem>>{
  '日常管理': [
    _ToolItem('recurring', '周期账单', '管理固定收支', Icons.repeat_rounded),
    _ToolItem('categories', '分类管理', '整理账单分类', Icons.category_outlined),
    _ToolItem('reminders', '记账提醒', '设置每日提醒', Icons.notifications_none_rounded),
    _ToolItem('rates', '汇率设置', '手动或联网获取参考汇率', Icons.currency_exchange_rounded),
  ],
  '数据与备份': [
    _ToolItem(
      'encrypted',
      '导出加密备份',
      '使用密码保护备份',
      Icons.enhanced_encryption_outlined,
    ),
    _ToolItem('export', '导出未加密备份', '保存完整账本数据', Icons.ios_share_rounded),
    _ToolItem('import', '恢复备份', '从备份文件恢复账本', Icons.restore_rounded),
    _ToolItem('csv', '导出账单 CSV', '用于表格处理', Icons.table_rows_outlined),
    _ToolItem('xlsx', '导出账单 Excel', '导出可筛选表格', Icons.grid_on_rounded),
  ],
  '隐私与安全': [
    _ToolItem('lock', '应用锁', '使用设备身份验证', Icons.lock_outline_rounded),
    _ToolItem('storage-security', '本地账本加密', '管理设备内数据保护', Icons.shield_outlined),
  ],
};

class _ToolsSheet extends StatelessWidget {
  const _ToolsSheet();
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .78,
    minChildSize: .45,
    maxChildSize: .94,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '工具与设置',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: beInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '管理账本、备份与安全',
                    style: TextStyle(color: beMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '关闭菜单',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        for (final group in _groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 9),
            child: Text(
              group.key,
              style: const TextStyle(
                color: beMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: beBorder),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (var i = 0; i < group.value.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.only(left: 62, right: 14),
                        child: Divider(height: 1),
                      ),
                    _ToolRow(item: group.value[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ToolRow extends StatelessWidget {
  final _ToolItem item;
  const _ToolRow({required this.item});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xffeaf4ff),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(item.icon, color: beBlue, size: 20),
    ),
    title: Text(
      item.title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: beInk,
      ),
    ),
    subtitle: Text(
      item.subtitle,
      style: const TextStyle(color: beMuted, fontSize: 12),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, color: beMuted),
    onTap: () => Navigator.pop(context, item.id),
  );
}
