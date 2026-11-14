import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/account_icon_picker.dart';

void main() {
  testWidgets('local image is reduced to a backup-safe PNG icon', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 512, 512),
        ui.Paint()..color = const ui.Color(0xFF22AA66),
      );
      final image = await recorder.endRecording().toImage(512, 512);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final encoded = await encodeAccountIcon(png!.buffer.asUint8List());
      expect(encoded.length, lessThan(200000));
      final decoded = base64Decode(encoded);
      expect(decoded.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(decoded);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 96);
      frame.image.dispose();
      codec.dispose();
    });
  });
}
