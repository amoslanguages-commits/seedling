import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'settings_service.dart';

/// Ultra premium reminder and notification system for Seedling.
/// Sends a smart evening reminder that reflects how many words are due today.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final _settings = SettingsService();

  // Notification IDs
  static const int _kDailyReminderId = 1;
  static const int _kWateringReminderId = 2;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      var currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone.toString()));
    } catch (_) {
      // Fallback
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
    debugPrint('[NotificationService] Initialized.');
  }

  // ── Core permission request ────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return (await androidPlugin?.requestNotificationsPermission()) ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return (await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          false;
    }
    return false;
  }

  // ── Show a generic daily reminder notification ────────────────────────────

  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    if (!_initialized) await initialize();
    if (!_settings.notificationsEnabled) return;
    await _scheduleNotification(
      id: _kDailyReminderId,
      title: 'Your seedlings are waiting 🌿',
      body: 'Plant a new word today — just 5 minutes keeps your streak alive!',
      hour: hour,
      minute: minute,
    );
  }

  // ── Smart watering reminder (dynamic due-count) ───────────────────────────

  /// Call this on app launch with the actual count of due SRS words.
  /// If [dueCount] > 0, shows an urgent "N plants need watering" notification.
  Future<void> scheduleSmartReminder({
    required int dueCount,
    required bool practicedToday,
    int? hour,
    int? minute,
  }) async {
    if (!_initialized) await initialize();

    if (!_settings.notificationsEnabled) {
      await _plugin.cancelAll();
      return;
    }

    // Always cancel stale notifications first
    await _plugin.cancel(id: _kWateringReminderId);
    await _plugin.cancel(id: _kDailyReminderId);

    if (practicedToday) {
      debugPrint('[NotificationService] Practiced today — reminders cleared.');
      return;
    }

    final granted = await requestPermission();
    if (!granted) {
      debugPrint('[NotificationService] Permission denied.');
      return;
    }

    if (dueCount > 0) {
      // 🌊 Urgent watering reminder
      await _scheduleNotification(
        id: _kWateringReminderId,
        title: '$dueCount plant${dueCount > 1 ? 's' : ''} need watering 💧',
        body: dueCount == 1
            ? 'One word is fading from memory — quick review to save it!'
            : '$dueCount words are due for review. Don\'t let your garden wilt!',
        hour: hour ?? 20,
        minute: minute ?? 0,
      );
      debugPrint(
        '[NotificationService] Watering reminder scheduled ($dueCount due).',
      );
    } else {
      // 🌱 Gentle daily nudge
      await _scheduleNotification(
        id: _kDailyReminderId,
        title: 'Your garden is thriving 🌿',
        body:
            'All caught up! Plant something new to keep growing your vocabulary.',
        hour: hour ?? 20,
        minute: minute ?? 0,
      );
      debugPrint(
        '[NotificationService] Daily nudge scheduled (0 due, not practiced).',
      );
    }
  }

  // ── Internal helper ───────────────────────────────────────────────────────

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'seedling_reminders',
      'Garden Reminders',
      channelDescription:
          'Reminds you to review and plant vocabulary every day.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
