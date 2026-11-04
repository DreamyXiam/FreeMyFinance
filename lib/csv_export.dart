import 'ledger.dart';

String _cell(String value, {bool text = true}) {
  var s = value;
  if (text && RegExp(r'^[\s]*[=+\-@\t\r]').hasMatch(s)) s = "'$s";
  return '"${s.replaceAll('"', '""')}"';
}

String exportCsv(List<Account> accounts, List<Entry> entries) {
  final names = {for (final a in accounts) a.id: a.name};
  final rows = <String>['日期,账户,类型,分类,金额,备注'];
  for (final e in entries) {
    final day =
        '${e.date.year.toString().padLeft(4, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
    final type = e.transferId.isNotEmpty
        ? (e.income ? '转入' : '转出')
        : (e.income ? '收入' : '支出');
    final amount =
        '${e.cents ~/ 100}.${(e.cents % 100).toString().padLeft(2, '0')}';
    rows.add(
      [
        _cell(day),
        _cell(names[e.accountId] ?? '未知账户'),
        _cell(type),
        _cell(e.category),
        _cell(amount, text: false),
        _cell(e.note),
      ].join(','),
    );
  }
  return '${rows.join('\r\n')}\r\n';
}
