import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as db;
import 'package:timezone/timezone.dart' as tz;
import 'package:free_my_finance/reminders.dart';

void main() {
  test('daily reminder chooses next local wall clock time across DST', () {
    db.initializeTimeZones();
    final loc = tz.getLocation('America/New_York');
    final after = tz.TZDateTime(loc, 2026, 3, 7, 21);
    final result = nextDailyReminder(after, 20 * 60);
    expect(result.day, 8);
    expect(result.hour, 20);
    final before = tz.TZDateTime(loc, 2026, 3, 7, 19);
    expect(nextDailyReminder(before, 1200).day, 7);
  });
}
