import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _notificationsKey = 'notifications_enabled';
  static const String _soundKey = 'sound_effects_enabled';
  static const String _hapticsKey = 'haptics_enabled';
  static const String _hourKey = 'reminder_hour';
  static const String _minuteKey = 'reminder_minute';
  static const String _dailyGoalKey = 'daily_word_goal';
  static const String _syncKey = 'cloud_sync_enabled';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Getters
  bool get notificationsEnabled => _prefs?.getBool(_notificationsKey) ?? true;
  bool get soundEffectsEnabled => _prefs?.getBool(_soundKey) ?? true;
  bool get hapticsEnabled => _prefs?.getBool(_hapticsKey) ?? true;
  int get reminderHour => _prefs?.getInt(_hourKey) ?? 20;
  int get reminderMinute => _prefs?.getInt(_minuteKey) ?? 0;
  int get dailyWordGoal => _prefs?.getInt(_dailyGoalKey) ?? 10;
  bool get cloudSyncEnabled => _prefs?.getBool(_syncKey) ?? true;

  TimeOfDay get reminderTime => TimeOfDay(hour: reminderHour, minute: reminderMinute);

  // Setters
  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs?.setBool(_notificationsKey, value);
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    await _prefs?.setBool(_soundKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    await _prefs?.setBool(_hapticsKey, value);
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    await _prefs?.setInt(_hourKey, time.hour);
    await _prefs?.setInt(_minuteKey, time.minute);
  }

  Future<void> setDailyWordGoal(int goal) async {
    await _prefs?.setInt(_dailyGoalKey, goal);
  }

  Future<void> setCloudSyncEnabled(bool value) async {
    await _prefs?.setBool(_syncKey, value);
  }
}
