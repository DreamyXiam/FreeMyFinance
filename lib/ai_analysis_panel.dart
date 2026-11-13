import 'dart:convert';

import 'package:flutter/material.dart';

import 'ai_analysis.dart';
import 'ai_history_page.dart';
import 'ai_settings.dart';
import 'ledger.dart';
import 'reports.dart';

class AiAnalysisPanel extends StatefulWidget {
  final Ledger ledger;
  final Report report;
  final int year;
  final int? month;
  final String currency;
  final bool singleAccount;
  final AiKeyStore? keyStore;
  final AiAnalysisService Function()? serviceFactory;
  const AiAnalysisPanel({
    super.key,
    required this.ledger,
    required this.report,
    required this.year,
    required this.month,
    required this.currency,
    required this.singleAccount,
    this.keyStore,
    this.serviceFactory,
  });
  @override
  State<AiAnalysisPanel> createState() => _AiAnalysisPanelState();
}

class _AiAnalysisPanelState extends State<AiAnalysisPanel> {
  late final keyStore = widget.keyStore ?? const AiKeyStore();
  bool busy = false;
  String? result;

  Future<void> run() async {
    final service = widget.serviceFactory?.call() ?? AiAnalysisService();
    try {
      final key = await keyStore.read();
      if (!mounted) return;
      if (key == null || key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('请先在设置中填写 DeepSeek API Key'),
            action: SnackBarAction(
              label: '去设置',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AiSettingsPage(ledger: widget.ledger),
                ),
              ),
            ),
          ),
        );
        return;
      }
      final summary = service.summary(
        report: widget.report,
        year: widget.year,
        month: widget.month,
        currency: widget.currency,
      );
      final summaryText = jsonEncode(summary);
      var prompt = widget.ledger.aiPrompt;
      final confirmedPrompt = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('AI 分析账单'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '将向 DeepSeek 发送当前筛选范围的收支及分类汇总。不会发送账户名称、卡号、备注或逐笔账单；调用可能产生 API 费用。',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: prompt,
                  onChanged: (v) => prompt = v,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: '分析提示词'),
                ),
                const SizedBox(height: 10),
                Text(
                  '发送的账单汇总：$summaryText',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
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
              onPressed: () => Navigator.pop(dialogContext, prompt.trim()),
              child: const Text('发送并分析'),
            ),
          ],
        ),
      );
      if (!mounted || confirmedPrompt == null) return;
      if (confirmedPrompt.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请填写分析提示词')));
        return;
      }
      setState(() {
        busy = true;
        result = null;
      });
      final answer = await service.analyze(
        apiKey: key,
        summary: summary,
        prompt: confirmedPrompt,
      );
      if (!mounted) return;
      setState(() => result = answer);
      try {
        final now = DateTime.now();
        await widget.ledger.addAiAnalysis(
          AiAnalysisRecord(
            id: now.microsecondsSinceEpoch.toString(),
            createdAt: now,
            period: summary['period'] as String,
            currency: widget.currency,
            scope: widget.singleAccount ? '单个账户' : '全部账户',
            prompt: confirmedPrompt,
            summary: summaryText,
            response: answer,
          ),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('分析完成，但保存历史记录失败')));
        }
      }
    } on AiAnalysisException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('分析失败，请检查设置后重试')));
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
          const SizedBox(height: 6),
          const Text('基于当前筛选的收支与分类汇总生成建议'),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AiHistoryPage(ledger: widget.ledger),
              ),
            ),
            icon: const Icon(Icons.history),
            label: Text('历史记录 (${widget.ledger.aiHistory.length})'),
          ),
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
