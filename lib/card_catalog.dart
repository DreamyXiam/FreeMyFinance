import 'dart:convert';

import 'package:flutter/services.dart';

enum CardField { brand, country, issuer, type, level }

extension CardFieldName on CardField {
  String get label => switch (this) {
    CardField.brand => '卡组织',
    CardField.country => '国家代码',
    CardField.issuer => '发行方',
    CardField.type => '卡类型',
    CardField.level => '等级',
  };
}

String cardFieldDisplay(CardField field, String value) {
  if (field == CardField.type) {
    return switch (value) {
      'Debit' => '借记卡',
      'Credit' => '信用卡',
      'Prepaid' => '预付卡',
      'Charge' => '签账卡',
      _ => value,
    };
  }
  return value;
}

class CardArtwork {
  final String id,
      brand,
      country,
      issuer,
      type,
      level,
      name,
      imageUrl,
      previewUrl;
  const CardArtwork({
    required this.id,
    required this.brand,
    required this.country,
    required this.issuer,
    required this.type,
    required this.level,
    required this.name,
    required this.imageUrl,
    required this.previewUrl,
  });
  factory CardArtwork.fromJson(Map<String, dynamic> j) => CardArtwork(
    id: j['id'],
    brand: j['brand'],
    country: j['country'],
    issuer: j['issuer'],
    type: j['type'],
    level: j['level'],
    name: j['name'],
    imageUrl: j['imageUrl'],
    previewUrl: j['previewUrl'],
  );
  String field(CardField f) => switch (f) {
    CardField.brand => brand,
    CardField.country => country,
    CardField.issuer => issuer,
    CardField.type => type,
    CardField.level => level,
  };
}

class CardCatalog {
  final List<CardArtwork> cards;
  CardCatalog._(this.cards);
  factory CardCatalog.fromObjects(List<dynamic> values) => CardCatalog._(
    values
        .map((x) => CardArtwork.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
  );
  static Future<CardCatalog> load() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/card_catalog.json'),
    ) as Map<String, dynamic>;
    return CardCatalog.fromObjects(data['cards'] as List);
  }

  List<CardArtwork> filter(
    Map<CardField, String> filters, {
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    return cards.where((a) {
      for (final e in filters.entries) {
        if (e.value.isNotEmpty && a.field(e.key) != e.value) return false;
      }
      return q.isEmpty ||
          [
            a.name,
            a.issuer,
            a.brand,
            a.country,
            a.type,
            a.level,
          ].any((v) => v.toLowerCase().contains(q));
    }).toList();
  }

  List<String> options(CardField field, Map<CardField, String> filters) {
    final others = Map<CardField, String>.from(filters)..remove(field);
    final values = filter(others)
        .map((a) => a.field(field))
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }
}
