import 'package:flutter/material.dart';

class SeedlingColors {
  // Signature Branding - Immersive Living Forest Theme
  static const Color seedlingGreen = Color(0xFF4BAE4F); // Luminous Growth
  static const Color deepRoot = Color(0xFF07140B); // Deep Earth Shadow
  static const Color freshSprout = Color(0xFF81C784); // New Growth
  static const Color morningDew = Color(0xFFA5D6A7); // Soft Ambient Green
  static const Color soil = Color(0xFF3E2723); // Dark Earth
  static const Color sunlight = Color(0xFFFFD54F); // Emotional Reward
  static const Color water = Color(0xFF4FC3F7); // Vitality
  static const Color background = Color(
    0xFF0B1910,
  ); // Deep Forest Canvas
  static const Color cardBackground = Color(0xFF14261A); // Leaf Surface
  static const Color textPrimary = Color(0xFFF5F5DC); // Warm Personal Cream
  static const Color textSecondary = Color(0xFF9EAD94); // Muted Nature Green
  static const Color error = Color(0xFFE57373); // Soft Wilt
  static const Color success = Color(0xFF66BB6A); // Vital Success
  static const Color warning = Color(0xFFFFB74D); // Alert / Stakes
  static const Color waterBlue = Color(0xFF4FC3F7); // Legacy alias for water

  // Competition & Rankings - Botanical Accents
  static const Color autumnGold = Color(
    0xFFFFCA28,
  ); // 1st Place / Sun-kissed leaves
  static const Color mistSilver = Color(0xFFE0E0E0); // 2nd Place / Morning fog
  static const Color bronzeLeaf = Color(
    0xFFCD7F32,
  ); // 3rd Place / Dried autumn leaf
  static const Color hibiscusRed = Color(
    0xFFFF5252,
  ); // Live Duel / Heart of the forest
  static const Color royalPurple = Color(
    0xFF7E57C2,
  ); // Elite Ranks / Rare orchid

  // Time-of-Growth States - Refined for Forest Ambience
  static Color getMorningDew() => morningDew.withValues(alpha: 0.15);
  static Color getActiveLearning() => seedlingGreen.withValues(alpha: 0.7);
  static Color getMastery() =>
      sunlight.withValues(alpha: 0.85); // Mastery feels like sunlight
}
