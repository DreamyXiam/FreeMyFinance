import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_checker.dart';

class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  UpdateSource source = UpdateSource.github;
  bool checking = false;
  String? status;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          source = prefs.getString(updateSourcePreferenceKey) == 'markdown'
              ? UpdateSource.markdown
              : UpdateSource.github;
        });
      }
    });
  }

  Future<void> select(UpdateSource value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(updateSourcePreferenceKey, value.name);
    if (mounted) {
      setState(() {
        source = value;
        status = null;
      });
    }
  }

  Future<void> checkNow() async {
    setState(() {
      checking = true;
      status = null;
    });
    final checker = UpdateChecker();
    try {
      final update = await checker.check(appVersion, source: source);
      if (mounted) {
        setState(
          () => status = update == null
              ? '当前已是最新版'
              : '发现 ${update.version}：${update.url}',
        );
      }
    } catch (_) {
      if (mounted) setState(() => status = '检查失败，请确认网络或仓库中的备用链接');
    } finally {
      checker.close();
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('更新设置')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '应用启动时检查最新正式版',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        RadioGroup<UpdateSource>(
          groupValue: source,
          onChanged: (v) {
            if (v != null) select(v);
          },
          child: Column(
            children: [
              const RadioListTile<UpdateSource>(
                title: Text('GitHub Release'),
                subtitle: Text('从 GitHub 官方发布页下载'),
                value: UpdateSource.github,
              ),
              const RadioListTile<UpdateSource>(
                title: Text('仓库内的备用链接'),
                subtitle: Text(
                  '读取 update_sources.md 的 download_url；新版本号仍以 GitHub Release 为准',
                ),
                value: UpdateSource.markdown,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('备用下载链接由仓库维护者填写。未配置或无效时，请切换回 GitHub。'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: checking ? null : checkNow,
          icon: const Icon(Icons.refresh),
          label: const Text('立即检查更新'),
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SelectableText(status!),
          ),
        const SizedBox(height: 20),
        const Center(child: Text('FreeMyFinance  v$appVersion')),
      ],
    ),
  );
}
