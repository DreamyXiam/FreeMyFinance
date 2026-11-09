import 'package:flutter_test/flutter_test.dart';
import 'package:free_my_finance/card_catalog.dart';

void main() {
  test('five filters and search compose without losing distinct cards', () {
    final c = CardCatalog.fromObjects([
      {
        'id': '1',
        'brand': 'VISA',
        'country': 'CN',
        'issuer': '甲银行',
        'type': '信用卡',
        'level': '金',
        'name': '甲金卡',
        'imageUrl': 'https://aircards.org/originals/a.png',
        'previewUrl': 'https://aircards.org/previews/a.webp',
      },
      {
        'id': '2',
        'brand': 'VISA',
        'country': 'HK',
        'issuer': '乙银行',
        'type': '借记卡',
        'level': '普通',
        'name': '乙卡',
        'imageUrl': 'https://aircards.org/originals/b.png',
        'previewUrl': 'https://aircards.org/previews/b.webp',
      },
      {
        'id': '3',
        'brand': 'AMEX',
        'country': 'CN',
        'issuer': '甲银行',
        'type': '信用卡',
        'level': '白金',
        'name': '甲白金',
        'imageUrl': 'https://aircards.org/originals/c.png',
        'previewUrl': 'https://aircards.org/previews/c.webp',
      },
    ]);
    expect(
      c
          .filter({
            CardField.brand: 'VISA',
            CardField.country: 'CN',
            CardField.issuer: '甲银行',
            CardField.type: '信用卡',
            CardField.level: '金',
          })
          .single
          .id,
      '1',
    );
    expect(c.filter({CardField.country: 'CN'}, query: '白金').single.id, '3');
    expect(
      c.options(CardField.brand, {CardField.country: 'CN'}),
      containsAll(['VISA', 'AMEX']),
    );
  });
}
