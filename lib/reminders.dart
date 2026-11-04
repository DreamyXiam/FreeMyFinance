import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _reminderId = 701;
tz.TZDateTime nextDailyReminder(tz.TZDateTime now, int minuteOfDay) {
  if (minuteOfDay < 0 || minuteOfDay >= 1440) {
    throw ArgumentError('invalid time');
  }
  final h = minuteOfDay ~/ 60, m = minuteOfDay % 60;
  var next = tz.TZDateTime(now.location, now.year, now.month, now.day, h, m);
  if (!next.isAfter(now)) {
    next = tz.TZDateTime(now.location, now.year, now.month, now.day + 1, h, m);
  }
  return next;
}

class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void> _init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('目前仅支持安卓');
    }
    tzdata.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  Future<bool> enable(int minuteOfDay) async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    if (granted == false) return false;
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'FreeMyFinance',
      body: '记得记录今天的收支。',
      scheduledDate: nextDailyReminder(
        tz.TZDateTime.now(tz.local),
        minuteOfDay,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '记账提醒',
          channelDescription: '每天提醒记录收支',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_reminder_minutes', minuteOfDay);
    await prefs.setBool('daily_reminder_enabled', true);
    return true;
  }

  Future<void> disable() async {
    await _init();
    await _plugin.cancel(id: _reminderId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder_enabled', false);
  }
}
