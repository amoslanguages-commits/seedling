import 'package:flutter/material.dart';

class SeedlingColors {
  // Signature Branding - Immersive Living Forest Theme
  static const Color seedlingGreen = Color(0xFF4BAE4F); // Luminous Growth
  static const Color deepRoot = Color(0xFF07140B);     // Deep Earth Shadow
  static const Color freshSprout = Color(0xFF81C784);   // New Growth
  static const Color morningDew = Color(0xFFA5D6A7);    // Soft Ambient Green
  static const Color soil = Color(0xFF3E2723);          // Dark Earth
  static const Color sunlight = Color(0xFFFFD54F);      // Emotional Reward
  static const Color water = Color(0xFF4FC3F7);         // Vitality
  static const Color background = Color(0xFF0B1910);    // Midnight Forest Deep Canvas
  static const Color cardBackground = Color(0xFF14261A); // Leaf Surface
  static const Color textPrimary = Color(0xFFF5F5DC);    // Warm Personal Cream
  static const Color textSecondary = Color(0xFF9EAD94);  // Muted Nature Green
  static const Color error = Color(0xFFE57373);         // Soft Wilt
  static const Color success = Color(0xFF66BB6A);       // Vital Success
  static const Color warning = Color(0xFFFFB74D);       // Alert / Stakes
  static const Color waterBlue = Color(0xFF4FC3F7);     // Legacy alias for water
  
  // Time-of-Growth States - Refined for Forest Ambience
  static Color getMorningDew() => morningDew.withValues(alpha: 0.15);
  static Color getActiveLearning() => seedlingGreen.withValues(alpha: 0.7);
  static Color getMastery() => sunlight.withValues(alpha: 0.85); // Mastery feels like sunlight
}
