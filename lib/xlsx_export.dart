import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import 'ledger.dart';

List<int> exportXlsx(List<Account> accounts, List<Entry> entries) {
  final book = Excel.createExcel();
  book.rename('Sheet1', '账单');
  final sheet = book['账单'];
  final names = {for (final a in accounts) a.id: a};
  final headers = ['日期', '账户', '币种', '类型', '分类', '金额', '备注', '状态'];
  sheet.appendRow(headers.map((v) => TextCellValue(v)).toList());
  for (var i = 0; i < headers.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
    );
    sheet.setColumnWidth(
      i,
      [15.0, 22.0, 10.0, 12.0, 18.0, 16.0, 32.0, 12.0][i],
    );
  }
  for (final e in entries) {
    final a = names[e.accountId];
    final date =
        '${e.date.year.toString().padLeft(4, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
    final type = e.transferId.isNotEmpty
        ? (e.income ? '转入' : '转出')
        : (e.income ? '收入' : '支出');
    sheet.appendRow([
      TextCellValue(date),
      TextCellValue(a?.name ?? '未知账户'),
      TextCellValue(a?.currency ?? 'CNY'),
      TextCellValue(type),
      TextCellValue(e.category),
      DoubleCellValue(e.cents / 100),
      TextCellValue(e.note),
      TextCellValue(e.pending ? '待付款' : '已付款'),
    ]);
  }
  final bytes = book.encode();
  if (bytes == null) throw StateError('Excel 生成失败');
  final source = ZipDecoder().decodeBytes(bytes), target = Archive();
  for (final file in source.files) {
    if (file.name == 'xl/worksheets/sheet1.xml') {
      final text = utf8.decode(file.content as List<int>);
      final filter = '<autoFilter ref="A1:H${entries.length + 1}"/>';
      if (!text.contains('</sheetData>')) throw StateError('Excel 表格结构无效');
      final data = utf8.encode(
        text.replaceFirst('</sheetData>', '</sheetData>$filter'),
      );
      target.addFile(ArchiveFile(file.name, data.length, data));
    } else {
      target.addFile(file);
    }
  }
  final result = ZipEncoder().encode(target);
  if (result == null) throw StateError('Excel 压缩失败');
  return result;
}
