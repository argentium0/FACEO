import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// FACEO MaterialApp Global Dark Theme Configuration.
/// Maps design system tokens into global Flutter ThemeData.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DesignTokens.bgDeepBlack,
      colorScheme: const ColorScheme.dark(
        surface: DesignTokens.cardSurface,
        primary: DesignTokens.accentNeonPink,
        secondary: DesignTokens.accentNeonYellow,
        tertiary: DesignTokens.accentPeriwinkle,
        onPrimary: DesignTokens.textDark,
        onSecondary: DesignTokens.textDark,
        onSurface: DesignTokens.textLight,
      ),
      textTheme: TextTheme(
        displayLarge: DesignTokens.displayLarge,
        headlineLarge: DesignTokens.headlineLarge,
        headlineMedium: DesignTokens.headlineMedium,
        titleMedium: DesignTokens.titleMedium,
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
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.radiusCard,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          borderSide: const BorderSide(color: DesignTokens.accentPeriwinkle, width: 2),
        ),
        hintStyle: DesignTokens.bodySecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.accentNeonPink,
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
