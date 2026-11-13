import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_analysis.dart';
import 'reports.dart';

class AiAnalysisPanel extends StatefulWidget {
  final Report report;
  final int year;
  final int? month;
  final String currency;
  const AiAnalysisPanel({
    super.key,
    required this.report,
    required this.year,
    required this.month,
    required this.currency,
  });
  @override
  State<AiAnalysisPanel> createState() => _AiAnalysisPanelState();
}

class _AiAnalysisPanelState extends State<AiAnalysisPanel> {
  static const keyName = 'deepseek_api_key';
  final storage = const FlutterSecureStorage();
  bool busy = false;
  String? result;

  Future<void> run() async {
    final service = AiAnalysisService();
    final summary = service.summary(
      report: widget.report,
      year: widget.year,
      month: widget.month,
      currency: widget.currency,
    );
    final key = await storage.read(key: keyName);
    if (!mounted) {
      service.close();
      return;
    }
    var enteredKey = key ?? '';
    var saveKey = true;
    final supplied = await showDialog<(String, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('AI 分析账单'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '将把当前统计范围的收支总额与支出分类汇总发送给 DeepSeek。不会发送账户名称、卡号、账单备注或逐笔明细。调用可能产生 API 费用。',
                ),
                const SizedBox(height: 12),
                Text(
                  '发送内容：${jsonEncode(summary)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: key,
                  onChanged: (v) => enteredKey = v,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'DeepSeek API Key',
                  ),
                ),
                CheckboxListTile(
                  value: saveKey,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在此设备安全保存 Key'),
                  onChanged: (v) => update(() => saveKey = v ?? false),
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
              onPressed: () =>
                  Navigator.pop(dialogContext, (enteredKey.trim(), saveKey)),
              child: const Text('发送并分析'),
            ),
          ],
        ),
      ),
    );
    if (supplied == null) {
      service.close();
      return;
    }
    if (supplied.$1.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请填写 DeepSeek API Key')));
      }
      service.close();
      return;
    }
    setState(() {
      busy = true;
      result = null;
    });
    try {
      if (supplied.$2) {
        await storage.write(key: keyName, value: supplied.$1);
      } else {
        await storage.delete(key: keyName);
      }
      final answer = await service.analyze(
        apiKey: supplied.$1,
        summary: summary,
      );
      if (mounted) setState(() => result = answer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AiAnalysisException ? e.message : '分析失败，请重试'),
          ),
        );
      }
    } finally {
      service.close();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI 分析账单',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton(
                onPressed: busy ? null : run,
                child: Text(busy ? '分析中' : '开始分析'),
              ),
            ],
          ),
          const Text('基于当前筛选的收支与分类汇总生成建议'),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (result != null) ...[
            const Divider(height: 24),
            SelectableText(result!),
          ],
        ],
      ),
    ),
  );
}
