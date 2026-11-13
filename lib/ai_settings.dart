import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ledger.dart';

class AiKeyStore {
  static const keyName = 'deepseek_api_key';
  final FlutterSecureStorage storage;
  const AiKeyStore({this.storage = const FlutterSecureStorage()});
  Future<String?> read() => storage.read(key: keyName);
  Future<void> write(String key) => storage.write(key: keyName, value: key);
  Future<void> delete() => storage.delete(key: keyName);
}

class AiSettingsPage extends StatefulWidget {
  final Ledger ledger;
  final AiKeyStore? keyStore;
  const AiSettingsPage({super.key, required this.ledger, this.keyStore});
  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final keyStore = widget.keyStore ?? const AiKeyStore();
  final keyController = TextEditingController();
  late final TextEditingController promptController;
  bool configured = false, busy = true, visible = false;

  @override
  void initState() {
    super.initState();
    promptController = TextEditingController(text: widget.ledger.aiPrompt);
    load();
  }

  Future<void> load() async {
    try {
      final key = await keyStore.read();
      if (mounted) {
        setState(() {
          configured = key != null && key.isNotEmpty;
          busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法读取已保存的 API Key')));
      }
    }
  }

  @override
  void dispose() {
    keyController.dispose();
    promptController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final prompt = promptController.text.trim();
    if (prompt.isEmpty || prompt.length > 2000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('提示词长度须为 1 至 2000 字')));
      return;
    }
    setState(() => busy = true);
    try {
      if (keyController.text.trim().isNotEmpty) {
        await keyStore.write(keyController.text.trim());
      }
      await widget.ledger.setAiPrompt(prompt);
      if (!mounted) return;
      keyController.clear();
      setState(() => busy = false);
      // A successful write is verified by reading the secure store again.
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('AI 分析设置已保存')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }

  Future<void> removeKey() async {
    setState(() => busy = true);
    try {
      await keyStore.delete();
      if (mounted) {
        setState(() {
          configured = false;
          busy = false;
          keyController.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除 API Key 失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 分析设置')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DeepSeek API Key',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  configured ? '已在此设备安全保存' : '尚未设置',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  obscureText: !visible,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: configured ? '新 Key（留空则保持现有）' : '输入 API Key',
                    suffixIcon: IconButton(
                      tooltip: visible ? '隐藏 Key' : '显示 Key',
                      onPressed: () => setState(() => visible = !visible),
                      icon: Icon(
                        visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                if (configured)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : removeKey,
                      child: const Text('删除已保存的 Key'),
                    ),
                  ),
                const Text('API Key 只保存在当前设备的安全存储中，不写入账本或备份。调用接口可能产生费用。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '默认分析提示词',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: promptController,
                  maxLines: 8,
                  minLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(hintText: '希望 AI 如何分析账单？'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        promptController.text = defaultAiAnalysisPrompt,
                    child: const Text('恢复预设提示词'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('保存设置'),
          ),
        ),
      ],
    ),
  );
}
