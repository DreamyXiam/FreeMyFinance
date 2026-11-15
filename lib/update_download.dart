import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'update_checker.dart';

class UpdateProgress {
  final String state;
  final int downloaded, total;
  const UpdateProgress(this.state, this.downloaded, this.total);
  double? get fraction =>
      total > 0 ? (downloaded / total).clamp(0.0, 1.0) : null;
}

class UpdateDownloader {
  static const channel = MethodChannel(
    'org.freemyfinance.free_my_finance/update_download',
  );

  Future<int> start(String url, {required String version}) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !uri.path.toLowerCase().endsWith('.apk') ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('APK 下载链接无效');
    }
    final id = await channel.invokeMethod<int>('start', {
      'url': url,
      'version': version,
    });
    if (id == null) throw const FormatException('无法开始下载');
    return id;
  }

  Future<UpdateProgress> status(int id) async {
    final raw = await channel.invokeMapMethod<dynamic, dynamic>('status', {
      'id': id,
    });
    if (raw == null) throw const FormatException('无法读取下载进度');
    return UpdateProgress(
      raw['state'] as String,
      (raw['downloaded'] as num).toInt(),
      (raw['total'] as num).toInt(),
    );
  }

  Future<void> open(int id) => channel.invokeMethod<void>('open', {'id': id});
}

class UpdatePrompt extends StatefulWidget {
  final AvailableUpdate update;
  const UpdatePrompt({super.key, required this.update});
  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  final downloader = UpdateDownloader();
  Timer? timer;
  int? id;
  UpdateProgress? progress;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> poll() async {
    if (id == null || busy) return;
    busy = true;
    try {
      final next = await downloader.status(id!);
      if (!mounted) return;
      setState(() => progress = next);
      if (next.state == 'success' || next.state == 'failed') timer?.cancel();
    } catch (_) {
      timer?.cancel();
      if (mounted) setState(() => error = '无法读取下载状态，请查看系统下载通知');
    } finally {
      busy = false;
    }
  }

  Future<void> start() async {
    setState(() {
      error = null;
      busy = true;
    });
    try {
      final nextId = await downloader.start(
        widget.update.url,
        version: widget.update.version,
      );
      if (!mounted) return;
      setState(() {
        id = nextId;
        progress = const UpdateProgress('running', 0, -1);
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) => poll());
    } catch (_) {
      if (mounted) setState(() => error = '下载启动失败，请检查备用链接或切换 GitHub 源');
    } finally {
      busy = false;
    }
  }

  Future<void> install() async {
    try {
      await downloader.open(id!);
    } catch (_) {
      if (mounted) setState(() => error = '无法打开安装器，请从系统下载通知打开 APK');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return AlertDialog(
      title: Text('发现新版本 ${widget.update.version}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.update.notes.isEmpty ? '新版本已发布。' : widget.update.notes),
            if (progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress!.fraction),
              const SizedBox(height: 8),
              Text(
                progress!.state == 'success'
                    ? '下载完成，可开始安装'
                    : progress!.state == 'failed'
                    ? '下载失败，请重试或使用浏览器'
                    : progress!.total > 0
                    ? '已下载 ${(progress!.fraction! * 100).round()}%'
                    : '正在下载；离开此页后可查看系统下载通知',
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.update.url));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('下载链接已复制')));
            }
          },
          child: const Text('复制链接'),
        ),
        if (isAndroid)
          FilledButton(
            onPressed: busy || (id != null && progress?.state != 'failed')
                ? (progress?.state == 'success' ? install : null)
                : start,
            child: Text(
              progress?.state == 'success'
                  ? '安装更新'
                  : progress?.state == 'failed'
                  ? '重新下载'
                  : '应用内下载',
            ),
          ),
      ],
    );
  }
}
