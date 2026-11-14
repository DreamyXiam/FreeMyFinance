import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_icon.dart';

class InstalledAppIcon {
  final String name, packageName;
  const InstalledAppIcon(this.name, this.packageName);
}

Future<String> encodeAccountIcon(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
  try {
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    if (data == null) throw const FormatException('图片无效');
    final icon = data.buffer.asUint8List();
    if (icon.length > 150000) throw const FormatException('图片过大');
    return base64Encode(icon);
  } finally {
    codec.dispose();
  }
}

abstract interface class AppIconSource {
  Future<List<InstalledAppIcon>> listApps();
  Future<String> loadIcon(String packageName);
}

class AndroidAppIconSource implements AppIconSource {
  const AndroidAppIconSource();
  static const channel = MethodChannel(
    'org.freemyfinance.free_my_finance/app_icons',
  );
  @override
  Future<List<InstalledAppIcon>> listApps() async {
    final raw =
        await channel.invokeListMethod<Map<dynamic, dynamic>>('listApps') ?? [];
    return [
      for (final app in raw)
        InstalledAppIcon(app['name'] as String, app['packageName'] as String),
    ];
  }

  @override
  Future<String> loadIcon(String packageName) async =>
      await channel.invokeMethod<String>('loadIcon', {
        'packageName': packageName,
      }) ??
      '';
}

Future<String?> showAccountIconPicker(
  BuildContext context, {
  required String accountName,
  required String currentIcon,
  AppIconSource source = const AndroidAppIconSource(),
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _AccountIconSheet(
    accountName: accountName,
    currentIcon: currentIcon,
    source: source,
  ),
);

class _AccountIconSheet extends StatefulWidget {
  final String accountName, currentIcon;
  final AppIconSource source;
  const _AccountIconSheet({
    required this.accountName,
    required this.currentIcon,
    required this.source,
  });
  @override
  State<_AccountIconSheet> createState() => _AccountIconSheetState();
}

class _AccountIconSheetState extends State<_AccountIconSheet> {
  List<InstalledAppIcon>? apps;
  String search = '';
  bool searching = false, busy = false;
  final iconFutures = <String, Future<String>>{};

  Future<List<InstalledAppIcon>> getApps() async {
    if (apps != null) return apps!;
    final result = await widget.source.listApps();
    apps = result;
    return result;
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> pickApp(InstalledAppIcon app) async {
    setState(() => busy = true);
    try {
      final icon = await widget.source.loadIcon(app.packageName);
      if (mounted) Navigator.pop(context, icon);
    } catch (_) {
      message('无法读取此应用图标');
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> quickMatch() async {
    setState(() => busy = true);
    try {
      final items = await getApps();
      final query = widget.accountName.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        '',
      );
      final matches = items.where((app) {
        final name = app.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        return query.isNotEmpty &&
            (name.contains(query) || query.contains(name));
      }).toList();
      if (matches.isEmpty) {
        message('没有找到匹配的本机应用，可搜索或使用名称首字');
        if (mounted) setState(() => busy = false);
        return;
      }
      await pickApp(matches.first);
    } on MissingPluginException {
      message('仅 Android 支持读取本机应用图标');
      if (mounted) setState(() => busy = false);
    } catch (_) {
      message('读取本机应用失败');
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openSearch() async {
    setState(() {
      searching = true;
      busy = true;
    });
    try {
      await getApps();
    } on MissingPluginException {
      message('仅 Android 支持读取本机应用图标');
    } catch (_) {
      message('读取本机应用失败');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> upload() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final icon = await encodeAccountIcon(bytes);
      if (mounted) Navigator.pop(context, icon);
    } catch (_) {
      message('读取图片失败，请换一张图片');
    }
  }

  Widget action(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F5EF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF159F73)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: busy ? null : onTap,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shown = (apps ?? [])
        .where(
          (app) => app.name.toLowerCase().contains(search.trim().toLowerCase()),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '账户图标',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                ),
                AccountIcon(
                  name: widget.accountName,
                  pngBase64: widget.currentIcon,
                  size: 48,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('选择一种方式设置账户图标', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (!searching)
              Expanded(
                child: ListView(
                  children: [
                    action(
                      '快速匹配',
                      '按账户名匹配本机应用图标',
                      Icons.auto_awesome,
                      quickMatch,
                    ),
                    action(
                      '使用名称首字',
                      '自动生成颜色和首字图标',
                      Icons.text_fields,
                      () => Navigator.pop(context, ''),
                    ),
                    action('搜索添加', '从本机应用中选择图标', Icons.search, openSearch),
                    action(
                      '本地上传',
                      '选择一张本地图片作为账户图标',
                      Icons.image_outlined,
                      upload,
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '搜索本机应用',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 8),
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: shown.isEmpty && !busy
                    ? const Center(child: Text('没有匹配的应用'))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, index) {
                          final app = shown[index];
                          final icon = iconFutures.putIfAbsent(
                            app.packageName,
                            () => widget.source.loadIcon(app.packageName),
                          );
                          return ListTile(
                            leading: FutureBuilder<String>(
                              future: icon,
                              builder: (context, snapshot) => AccountIcon(
                                name: app.name,
                                pngBase64: snapshot.data ?? '',
                                size: 40,
                              ),
                            ),
                            title: Text(app.name),
                            subtitle: Text(
                              app.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: busy ? null : () => pickApp(app),
                          );
                        },
                      ),
              ),
            ],
            TextButton(
              onPressed: () => searching
                  ? setState(() => searching = false)
                  : Navigator.pop(context),
              child: Text(searching ? '返回方式选择' : '取消'),
            ),
          ],
        ),
      ),
    );
  }
}
