import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Design System Tokens for FACEO application.
/// Strictly enforces a minimalist, flat, dark-themed aesthetic with zero 3D visual noise.
class DesignTokens {
  DesignTokens._();

  // Color Tokens
  static const Color bgDeepBlack = Color(0xFF1F1F1F);
  static const Color cardSurface = Color(0xFF313131);
  static const Color inputBackground = Color(0xFF2A2A2A);
  static const Color accentPeriwinkle = Color(0xFFB7BEFE);
  static const Color accentNeonPink = Color(0xFFFF95DD);
  static const Color accentNeonYellow = Color(0xFFF6FF7F);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textDark = Color(0xFF1F1F1F);
  static const Color dividerColor = Color(0xFF3E3E3E);
  static const Color activeSpeakerBorder = Color(0xFFB7BEFE);

  // Border Radii
  static const double radiusPillValue = 999.0;
  static const double radiusCardValue = 16.0;
  static const double radiusInputValue = 12.0;

  static final BorderRadius radiusPill = BorderRadius.circular(radiusPillValue);
  static final BorderRadius radiusCard = BorderRadius.circular(radiusCardValue);
  static final BorderRadius radiusInput = BorderRadius.circular(radiusInputValue);

  // Spacing Units
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;

  // Text Styles (GoogleFonts Poppins)
  static TextStyle get headlineLarge => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textLight,
      );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textLight,
      );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textLight,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textLight,
      );

  static TextStyle get bodySecondary => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
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

/// FACEO MaterialApp Dark Theme Configuration.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DesignTokens.bgDeepBlack,
      colorScheme: const ColorScheme.dark(
        surface: DesignTokens.cardSurface,
        primary: DesignTokens.accentPeriwinkle,
        secondary: DesignTokens.accentNeonPink,
        onPrimary: DesignTokens.textDark,
        onSecondary: DesignTokens.textDark,
        onSurface: DesignTokens.textLight,
      ),
      textTheme: TextTheme(
        headlineLarge: DesignTokens.headlineLarge,
        headlineMedium: DesignTokens.headlineMedium,
        bodyLarge: DesignTokens.bodyLarge,
        bodyMedium: DesignTokens.bodyMedium,
        bodySmall: DesignTokens.caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.bgDeepBlack,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.radiusCard,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: DesignTokens.radiusInput,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.radiusInput,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.radiusInput,
          borderSide: const BorderSide(color: DesignTokens.accentPeriwinkle, width: 1.5),
        ),
        hintStyle: DesignTokens.bodySecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.accentPeriwinkle,
          foregroundColor: DesignTokens.textDark,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: DesignTokens.buttonTextDark,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DesignTokens.dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
