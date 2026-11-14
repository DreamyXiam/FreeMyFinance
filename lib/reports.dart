import 'ledger.dart';

class Report {
  final int income, expenses;
  final Map<String, int> categories;
  Report(this.income, this.expenses, this.categories);
  static Report calculate(
    List<Entry> entries, {
    required int year,
    int? month,
    String? accountId,
    Set<String>? allowedAccountIds,
  }) {
    var income = 0, expenses = 0;
    final categories = <String, int>{};
    for (final e in entries) {
      if ((allowedAccountIds != null &&
              !allowedAccountIds.contains(e.accountId)) ||
          e.transferId.isNotEmpty ||
          e.pending ||
          e.date.year != year ||
          (month != null && e.date.month != month) ||
          (accountId != null && e.accountId != accountId)) {
        continue;
      }
      if (e.income) {
        income += e.cents;
      } else {
        expenses += e.cents;
        categories[e.category] = (categories[e.category] ?? 0) + e.cents;
      }
    }
    return Report(income, expenses, categories);
  }
}
