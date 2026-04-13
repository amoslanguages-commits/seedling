import 'package:flutter/services.dart';
import 'audio_service.dart';
import 'settings_service.dart';

/// HapticService — Centralized, premium-quality haptic feedback engine.
///
/// Wraps standard Flutter HapticFeedback and extended AudioService haptics.
class HapticService {
  HapticService._();

  /// Standard selection click for UI elements (buttons, toggles).
  static Future<void> light() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Medium impact for confirmations or list re-ordering.
  static Future<void> medium() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact for destructive actions or massive successes.
  static Future<void> heavy() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Specialized "Success" pattern (double light pulse).
  static Future<void> success() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await AudioService.haptic(HapticType.correct);
    } catch (_) {}
  }

  /// Specialized "Error" pattern (heavy single jolt).
  static Future<void> error() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await AudioService.haptic(HapticType.wrong);
    } catch (_) {}
  }

  /// Specialized "Plant" pattern (weighted organic feedback).
  static Future<void> plant() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await AudioService.haptic(HapticType.plant);
    } catch (_) {}
  }

  /// Specialized "Selection" for more premium UI navigation.
  static Future<void> selection() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await AudioService.haptic(HapticType.selection);
    } catch (_) {}
  }

  /// Specialized "Level Up" (triple light pulse).
  static Future<void> levelUp() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await AudioService.haptic(HapticType.levelUp);
    } catch (_) {}
  }

  // ── Compatibility Aliases ──────────────────────────────────
  static Future<void> lightImpact() async => await light();
  static Future<void> mediumImpact() async => await medium();
  static Future<void> heavyImpact() async => await heavy();
  static Future<void> selectionClick() async => await light();
  static Future<void> lightTap() async => await light();

  /// Specialized "Celebration" pattern (Multi-pulse grand finish).
  static Future<void> celebration() async {
    if (!SettingsService().hapticsEnabled) return;
    try {
      await AudioService.haptic(HapticType.sessionComplete);
    } catch (_) {}
  }
}
