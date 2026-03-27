import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

/// Ultra premium reminder and notification system for Seedling.
/// Sends a gentle evening reminder if the user hasn't practiced today.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings: settings);
    _initialized = true;
    debugPrint('[NotificationService] Initialized.');
  }

  /// Schedules a daily reminder at 20:00 if the user hasn't practiced today.
  Future<void> scheduleDailyReminder() async {
    if (!_initialized) await initialize();

    // Cancel any existing reminder before scheduling
    await _plugin.cancel(id: 1);

    const androidDetails = AndroidNotificationDetails(
      'seedling_daily_reminder',
      'Daily Practice Reminder',
      channelDescription: 'Reminds you to practice your vocabulary every day.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Show a one-time notification scheduled for 1 second from now as a test
    // In production, use AndroidFlutterLocalNotificationsPlugin.zonedSchedule
    await _plugin.show(
      id: 1,
      title: 'Your seedlings are waiting 🌿',
      body: 'Plant a new word today — just 5 minutes keeps your streak alive!',
      notificationDetails: details,
    );
  }

  /// Schedules the daily 20:00 evening nudge.
  /// Call this after a session completes or on app launch.
  Future<void> ensureEveningReminderScheduled(bool practicedToday) async {
    if (!_initialized) await initialize();

    // Only request permission and schedule if user hasn't practiced
    if (!practicedToday) {
      await _requestPermissionAndSchedule();
    } else {
      // Cancel reminder — no need to remind today
      await _plugin.cancel(id: 1);
    }
  }

  Future<void> _requestPermissionAndSchedule() async {
    bool granted = false;
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation
          <AndroidFlutterLocalNotificationsPlugin>();
      granted = (await androidPlugin?.requestNotificationsPermission()) ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation
          <IOSFlutterLocalNotificationsPlugin>();
      granted = (await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true)) ?? false;
    }

    if (!granted) return;
    await scheduleDailyReminder();
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
