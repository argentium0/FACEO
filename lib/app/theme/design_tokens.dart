import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Design System Tokens for FACEO application.
/// Enforces a minimal, high-contrast, flat dark-themed aesthetic with zero 3D visual noise.
class DesignTokens {
  DesignTokens._();

  // Background Tokens
  static const Color bgDeepBlack = Color(0xFF1F1F1F); // Main Scaffold Background
  static const Color cardSurface = Color(0xFF313131); // Cards, Tiles, Inputs Background
  static const Color inputBackground = Color(0xFF313131); // Input Field Surface

  // Accent Tokens
  static const Color accentNeonPink = Color(0xFFFF95DD);   // Primary Accent
  static const Color accentNeonYellow = Color(0xFFF6FF7F); // Secondary Accent
  static const Color accentPeriwinkle = Color(0xFFB7BEFE); // Tertiary Accent

  // Neutral & Text Tokens
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textDark = Color(0xFF1F1F1F);
  static const Color dividerColor = Color(0xFF3E3E3E);
  static const Color activeSpeakerBorder = Color(0xFFB7BEFE);

  // Border Radii (Pill-shaped & High Radius Shapes)
  static const double radiusPillValue = 999.0;
  static const double radiusCardValue = 24.0;
  static const double radiusInputValue = 999.0;

  static final BorderRadius radiusPill = BorderRadius.circular(radiusPillValue);
  static final BorderRadius radiusCard = BorderRadius.circular(radiusCardValue);
  static final BorderRadius radiusInput = BorderRadius.circular(radiusInputValue);

  // Spacing Units
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;

  // Typography Tokens (GoogleFonts Poppins)
  static TextStyle get displayLarge => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textLight,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineLarge => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textLight,
      );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textLight,
      );

  static TextStyle get titleMedium => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textLight,
      );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textLight,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textLight,
      );

  static TextStyle get bodySecondary => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  static TextStyle get buttonTextDark => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get buttonTextLight => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textLight,
      );
}
