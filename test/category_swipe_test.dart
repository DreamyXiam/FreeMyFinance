import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/category_swipe_tile.dart';

void main() {
  testWidgets(
    'short left swipe reveals green edit; full swipe reveals red delete',
    (tester) async {
      var edits = 0, deletes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: CategorySwipeTile(
                  name: '宠物',
                  onEdit: () => edits++,
                  onDelete: () => deletes++,
                ),
              ),
            ),
          ),
        ),
      );
      final tile = find.text('宠物');
      var gesture = await tester.startGesture(tester.getCenter(tile));
      await gesture.moveBy(const Offset(-75, 0));
      await tester.pump();
      expect(
        (tester
                    .widget<AnimatedContainer>(
                      find.byKey(const Key('swipe-reveal-宠物')),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        const Color(0xFF159F73),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(deletes, 0);
      gesture = await tester.startGesture(tester.getCenter(tile));
      await gesture.moveBy(const Offset(-155, 0));
      await tester.pump();
      expect(
        (tester
                    .widget<AnimatedContainer>(
                      find.byKey(const Key('swipe-reveal-宠物')),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        const Color(0xFFE14B4B),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(deletes, 1);
    },
  );
}
