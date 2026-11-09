import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/card_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bundled catalog has 780 valid records and all five fields', () async {
    final catalog = await CardCatalog.load();
    expect(catalog.cards, hasLength(780));
    expect(catalog.cards.map((e) => e.id).toSet(), hasLength(780));
    for (final field in CardField.values) {
      expect(catalog.options(field, {}), isNotEmpty);
    }
    expect(
      catalog.cards.every((e) => Uri.parse(e.imageUrl).scheme == 'https'),
      isTrue,
    );
  });
}
