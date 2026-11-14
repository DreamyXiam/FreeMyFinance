import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/account_icon_picker.dart';

class FakeAppIcons implements AppIconSource {
  @override
  Future<List<InstalledAppIcon>> listApps() async => [
    const InstalledAppIcon('支付宝', 'com.example.alipay'),
    const InstalledAppIcon('微信', 'com.example.wechat'),
  ];
  @override
  Future<String> loadIcon(String packageName) async => 'icon-from-$packageName';
}

void main() {
  testWidgets(
    'quick match picks an installed app icon, while initials stay available',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => selected = await showAccountIconPicker(
                  context,
                  accountName: '支付宝',
                  currentIcon: '',
                  source: FakeAppIcons(),
                ),
                child: const Text('打开图标选择'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开图标选择'));
      await tester.pumpAndSettle();
      expect(find.text('快速匹配'), findsOneWidget);
      await tester.tap(find.text('快速匹配'));
      await tester.pumpAndSettle();
      expect(selected, 'icon-from-com.example.alipay');
      await tester.tap(find.text('打开图标选择'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('本地上传'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('本地上传'), findsOneWidget);
      await tester.ensureVisible(find.text('使用名称首字'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('使用名称首字'));
      await tester.pumpAndSettle();
      expect(selected, '');
    },
  );
}
