import 'package:flutter/material.dart';

import 'ledger.dart';

class AiHistoryPage extends StatefulWidget {
  final Ledger ledger;
  const AiHistoryPage({super.key, required this.ledger});
  @override
  State<AiHistoryPage> createState() => _AiHistoryPageState();
}

class _AiHistoryPageState extends State<AiHistoryPage> {
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

  Future<void> remove(AiAnalysisRecord record) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条分析记录？'),
        content: const Text('只删除本地保存的分析结果，不影响账单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.ledger.deleteAiAnalysis(record.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 分析历史')),
    body: widget.ledger.aiHistory.isEmpty
        ? const Center(child: Text('还没有分析记录'))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('分析记录保存在本地账本中，并随账本备份。'),
              const SizedBox(height: 14),
              for (final record in widget.ledger.aiHistory)
                Card(
                  child: ListTile(
                    title: Text('${record.period} · ${record.currency}'),
                    subtitle: Text(
                      '${record.scope} · ${record.createdAt.year}-${record.createdAt.month.toString().padLeft(2, '0')}-${record.createdAt.day.toString().padLeft(2, '0')} ${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: IconButton(
                      tooltip: '删除分析记录',
                      onPressed: () => remove(record),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => _AiHistoryDetail(record: record),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _AiHistoryDetail extends StatelessWidget {
  final AiAnalysisRecord record;
  const _AiHistoryDetail({required this.record});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${record.period} · ${record.currency}')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '分析结果',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SelectableText(record.response),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '使用的提示词',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SelectableText(record.prompt),
        const SizedBox(height: 20),
        const Text(
          '分析时的账单汇总',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SelectableText(record.summary),
      ],
    ),
  );
}
