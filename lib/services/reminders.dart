import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/content.dart';
import '../data/settings.dart';

/// Three daily reminders. Each carries the verse (morning) or the short confession (midday),
/// so the lock screen itself becomes a small moment with God.
class Reminders {
  Reminders._();
  static final Reminders instance = Reminders._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {
      // falls back to UTC; schedules still fire at the stored local offsets
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    _ready = true;
  }

  Future<bool> requestPermission() async {
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a != null) return (await a.requestNotificationsPermission()) ?? true;
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (i != null) return (await i.requestPermissions(alert: true, badge: false, sound: true)) ?? false;
    return true;
  }

  /// Re-plan the next 7 days of reminders. Called at launch and when settings change.
  Future<void> schedule(Settings s) async {
    await init();
    await _plugin.cancelAll();
    final content = Content.instance;
    final now = DateTime.now();
    var id = 100;
    for (var d = 0; d < 7; d++) {
      final day = now.add(Duration(days: d));
      final verse = content.verseFor(day, s);
      final confession = content.confessionFor(day, s);
      final plans = <(String, int, String, String)>[
        ('morning', s.morningAt, 'Put Him first', '${verse.text} (${verse.ref})'),
        ('midday', s.middayAt, 'Look up', confession.short),
        ('evening', s.eveningAt, 'Give thanks', 'Three things to thank Him for today.'),
      ];
      for (final (which, minutes, title, body) in plans) {
        if (minutes < 0) continue;
        final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
        if (at.isBefore(tz.TZDateTime.now(tz.local))) continue;
        try {
          await _plugin.zonedSchedule(
            id++,
            title,
            body,
            at,
            NotificationDetails(
              android: AndroidNotificationDetails('gratideo_$which', 'Gratideo $which', channelDescription: 'Daily $which reminder', importance: Importance.high, priority: Priority.high, styleInformation: BigTextStyleInformation(body)),
              iOS: const DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: which,
          );
        } catch (e) {
          debugPrint('reminder not scheduled: $e');
        }
      }
    }
  }
}
