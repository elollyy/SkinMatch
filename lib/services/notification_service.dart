import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/user_model.dart';

class NotificationService extends ChangeNotifier {
  // Daily reminder
  static const _enabledKey = 'notif_enabled';
  static const _hourKey = 'notif_hour';
  static const _minuteKey = 'notif_minute';
  static const _dailyNotifId = 0;

  // Course reminders
  static const _courseEnabledKey = 'course_notif_enabled';
  static const _courseHourKey = 'course_notif_hour';
  static const _courseMinuteKey = 'course_notif_minute';
  static const _courseNotifBaseId = 100;
  static const _courseNotifCount = 60;

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _courseEnabled = false;
  TimeOfDay _courseTime = const TimeOfDay(hour: 20, minute: 0);

  bool get enabled => _enabled;
  TimeOfDay get time => _time;
  bool get courseEnabled => _courseEnabled;
  TimeOfDay get courseTime => _courseTime;

  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _time = TimeOfDay(
      hour: prefs.getInt(_hourKey) ?? 9,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
    _courseEnabled = prefs.getBool(_courseEnabledKey) ?? false;
    _courseTime = TimeOfDay(
      hour: prefs.getInt(_courseHourKey) ?? 20,
      minute: prefs.getInt(_courseMinuteKey) ?? 0,
    );

    if (_supported) {
      tz.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      if (_enabled) {
        await _scheduleDaily();
      }
    }

    notifyListeners();
  }

  // ── Daily reminder ──────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    if (value && _supported) {
      final granted = await _requestPermission();
      if (!granted) return;
    }

    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);

    if (_supported) {
      if (value) {
        await _scheduleDaily();
      } else {
        await _plugin.cancel(_dailyNotifId);
      }
    }

    notifyListeners();
  }

  Future<void> setTime(TimeOfDay time) async {
    _time = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);

    if (_supported && _enabled) {
      await _scheduleDaily();
    }

    notifyListeners();
  }

  Future<void> _scheduleDaily() async {
    await _plugin.cancel(_dailyNotifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyNotifId,
      'SkinMatch',
      'Не забудьте про уход за кожей сегодня!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'skincare_reminder',
          'Напоминания об уходе',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Course reminders ────────────────────────────────────────────────────────

  Future<void> setCourseEnabled(bool value) async {
    if (value && _supported) {
      final granted = await _requestPermission();
      if (!granted) return;
    }

    _courseEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_courseEnabledKey, value);

    notifyListeners();
  }

  Future<void> setCourseTime(TimeOfDay time) async {
    _courseTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_courseHourKey, time.hour);
    await prefs.setInt(_courseMinuteKey, time.minute);

    notifyListeners();
  }

  Future<void> updateCourseNotifications({
    UsageGuidance? guidance,
    DateTime? courseStartedAt,
    String? productName,
  }) async {
    if (!_supported) return;

    // Cancel all previously scheduled course notifications
    for (var i = 0; i < _courseNotifCount; i++) {
      await _plugin.cancel(_courseNotifBaseId + i);
    }

    if (!_courseEnabled || guidance == null || courseStartedAt == null) return;

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final now = tz.TZDateTime.now(tz.local);
    final name = productName ?? 'продукт';
    var notifIndex = 0;

    for (var offset = 0; offset < _courseNotifCount; offset++) {
      final candidate = today.add(Duration(days: offset));
      if (!guidance.isPlannedDate(
        courseStartedAt: courseStartedAt,
        date: candidate,
      )) {
        continue;
      }

      var scheduled = tz.TZDateTime(
        tz.local,
        candidate.year,
        candidate.month,
        candidate.day,
        _courseTime.hour,
        _courseTime.minute,
      );
      if (scheduled.isBefore(now)) continue;

      await _plugin.zonedSchedule(
        _courseNotifBaseId + notifIndex,
        'Курс интенсивного обновления',
        'Сегодня день нанесения $name. Не забудьте нанести продукт!',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'course_reminder',
            'Напоминания о курсе',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      notifIndex++;
      if (notifIndex >= _courseNotifCount) break;
    }
  }

  // ── Permissions ─────────────────────────────────────────────────────────────

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await impl?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }
}
