import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';

import 'dart:convert';

import 'package:free_my_finance/ledger.dart';
import 'package:free_my_finance/xlsx_export.dart';

void main() {
  test('XLSX export contains text, numeric amount, and a filter', () {
    final data = exportXlsx(
      [Account(id: 'a', name: '卡片', openingCents: 0, currency: 'HKD')],
      [
        Entry(
          id: '1',
          accountId: 'a',
          cents: 1250,
          income: false,
          category: '餐饮',
          note: '=danger',
          date: DateTime(2026, 1, 2),
        ),
      ],
    );
    final book = Excel.decodeBytes(data);
    final rows = book.tables['账单']!.rows;
    expect(rows[1][1]!.value.toString(), '卡片');
    expect(rows[1][2]!.value.toString(), 'HKD');
    expect(rows[1][5]!.value, isA<DoubleCellValue>());
    expect(rows[1][6]!.value, isA<TextCellValue>());
    expect(rows[1][7]!.value.toString(), contains('已付款'));
    final archive = ZipDecoder().decodeBytes(data);
    final xml = utf8.decode(
      archive.files
              .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
              .content
          as List<int>,
    );
    expect(xml, contains('autoFilter'));
  });
}
