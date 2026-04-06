import 'package:flutter/services.dart';
import 'audio_service.dart';

/// HapticService — Centralized, premium-quality haptic feedback engine.
///
/// Wraps standard Flutter HapticFeedback and extended AudioService haptics.
class HapticService {
  HapticService._();

  /// Standard selection click for UI elements (buttons, toggles).
  static Future<void> light() async => await HapticFeedback.selectionClick();

  /// Medium impact for confirmations or list re-ordering.
  static Future<void> medium() async => await HapticFeedback.mediumImpact();

  /// Heavy impact for destructive actions or massive successes.
  static Future<void> heavy() async => await HapticFeedback.heavyImpact();

  /// Specialized "Success" pattern (double light pulse).
  static Future<void> success() async =>
      await AudioService.haptic(HapticType.correct);

  /// Specialized "Error" pattern (heavy single jolt).
  static Future<void> error() async =>
      await AudioService.haptic(HapticType.wrong);

  /// Specialized "Plant" pattern (weighted organic feedback).
  static Future<void> plant() async =>
      await AudioService.haptic(HapticType.plant);

  /// Specialized "Selection" for more premium UI navigation.
  static Future<void> selection() async =>
      await AudioService.haptic(HapticType.selection);

  /// Specialized "Level Up" (triple light pulse).
  static Future<void> levelUp() async =>
      await AudioService.haptic(HapticType.levelUp);

  // ── Compatibility Aliases ──────────────────────────────────
  static Future<void> lightImpact() async => await light();
  static Future<void> mediumImpact() async => await medium();
  static Future<void> heavyImpact() async => await heavy();
  static Future<void> selectionClick() async => await light();
  static Future<void> lightTap() async => await light();
}
