import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class SettingsService extends ChangeNotifier {
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
  static const String _nativeLangKey = 'native_language_code';
  static const String _ambientTrackKey = 'selected_ambient_track';
  static const String _brainwaveTypeKey = 'selected_brainwave_type';
  static const String _ambientEnabledKey = 'ambient_enabled';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Getters
  bool get notificationsEnabled => _prefs?.getBool(_notificationsKey) ?? true;
  bool get soundEffectsEnabled => _prefs?.getBool(_soundKey) ?? true;
  bool get hapticsEnabled => _prefs?.getBool(_hapticsKey) ?? true;
  bool get ambientEnabled => _prefs?.getBool(_ambientEnabledKey) ?? true;
  int get reminderHour => _prefs?.getInt(_hourKey) ?? 20;
  int get reminderMinute => _prefs?.getInt(_minuteKey) ?? 0;
  int get dailyWordGoal => _prefs?.getInt(_dailyGoalKey) ?? 10;
  bool get cloudSyncEnabled => _prefs?.getBool(_syncKey) ?? true;
  String get nativeLanguageCode => _prefs?.getString(_nativeLangKey) ?? 'en';
  String get selectedAmbientTrack => _prefs?.getString(_ambientTrackKey) ?? 'garden';
  String get selectedBrainwaveType => _prefs?.getString(_brainwaveTypeKey) ?? 'none';

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  // Setters
  Future<void> setAmbientEnabled(bool value) async {
    await _prefs?.setBool(_ambientEnabledKey, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs?.setBool(_notificationsKey, value);
    notifyListeners();
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    await _prefs?.setBool(_soundKey, value);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    await _prefs?.setBool(_hapticsKey, value);
    notifyListeners();
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    await _prefs?.setInt(_hourKey, time.hour);
    await _prefs?.setInt(_minuteKey, time.minute);
    notifyListeners();
  }

  Future<void> setDailyWordGoal(int goal) async {
    await _prefs?.setInt(_dailyGoalKey, goal);
    notifyListeners();
  }

  Future<void> setCloudSyncEnabled(bool value) async {
    await _prefs?.setBool(_syncKey, value);
    notifyListeners();
  }

  Future<void> setNativeLanguageCode(String code) async {
    await _prefs?.setString(_nativeLangKey, code);
    notifyListeners();
  }

  Future<void> setSelectedAmbientTrack(String track) async {
    await _prefs?.setString(_ambientTrackKey, track);
    notifyListeners();
  }

  Future<void> setSelectedBrainwaveType(String type) async {
    await _prefs?.setString(_brainwaveTypeKey, type);
    notifyListeners();
  }
}
