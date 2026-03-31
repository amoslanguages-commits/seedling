import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class SeedlingTypography {
  // Signature Font: Outfit - Rounded, modern, and premium geometry
  static TextStyle get base => GoogleFonts.outfit(
        color: SeedlingColors.textPrimary,
      );

  static final TextStyle display = base.copyWith(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
  );

  static final TextStyle heading1 = base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static final TextStyle heading2 = base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );
  
  static final TextStyle heading3 = base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static final TextStyle bodyLarge = base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  
  static final TextStyle body = base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: SeedlingColors.textSecondary,
  );
  
  static final TextStyle caption = base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: SeedlingColors.textSecondary,
  );
}
