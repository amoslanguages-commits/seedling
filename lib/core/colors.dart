import 'package:flutter/material.dart';

class SeedlingColors {
  // Flat Green Identity - No Light/Dark Mode
  static const Color seedlingGreen = Color(0xFF4CAF50);
  static const Color deepRoot = Color(0xFF2E7D32);
  static const Color freshSprout = Color(0xFF81C784);
  static const Color morningDew = Color(0xFFA5D6A7);
  static const Color soil = Color(0xFF5D4037);
  static const Color sunlight = Color(0xFFFFF59D);
  static const Color water = Color(0xFF4FC3F7);
  static const Color background = Color(0xFFF1F8E9);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1B5E20);
  static const Color textSecondary = Color(0xFF558B2F);
  static const Color error = Color(0xFFE57373);
  static const Color success = Color(0xFF66BB6A);
  
  // Time-of-Growth States
  static Color getMorningDew() => morningDew.withValues(alpha: 0.3);
  static Color getActiveLearning() => seedlingGreen.withValues(alpha: 0.9);
  static Color getMastery() => deepRoot.withValues(alpha: 0.95);
}
