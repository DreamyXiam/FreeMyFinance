import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/update_download.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'org.freemyfinance.free_my_finance/update_download',
  );
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'start') return 42;
          if (call.method == 'status') {
            return {'state': 'running', 'downloaded': 512, 'total': 1024};
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('starts HTTPS APK download and reports progress', () async {
    final downloader = UpdateDownloader();
    final id = await downloader.start(
      'https://example.com/app.apk',
      version: '1.0.3',
    );
    expect(id, 42);
    expect(calls.first.method, 'start');
    expect(calls.first.arguments, {
      'url': 'https://example.com/app.apk',
      'version': '1.0.3',
    });
    final progress = await downloader.status(id);
    expect(progress.state, 'running');
    expect(progress.fraction, .5);
    await downloader.open(id);
    expect(calls.last.method, 'open');
  });

  test('rejects non-HTTPS download links before invoking Android', () async {
    expect(
      () => UpdateDownloader().start(
        'http://example.com/app.apk',
        version: '1.0.3',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });
}
