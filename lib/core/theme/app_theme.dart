import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the app's [ThemeData], exposing [AppColors], [AppTypography], and
/// [AppSpacing] as [ThemeExtension]s so every feature module pulls tokens
/// from one source instead of hardcoding hex values.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final typography = AppTypography.standard;
    const spacing = AppSpacing();

    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.emerald900,
      brightness: brightness,
      primary: colors.emerald900,
      secondary: colors.gold500,
      error: colors.danger,
      surface: brightness == Brightness.light ? colors.white : colors.white,
    );

    // Base every text style on Inter (not just the ones we explicitly set
    // below) so unstyled Material widgets — dialogs, menus, tooltips —
    // don't silently fall back to the platform default font.
    final baseTextTheme = GoogleFonts.interTextTheme(
      brightness == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.ivory,
      extensions: [colors, typography, spacing],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.emerald900,
        foregroundColor: colors.white,
        elevation: AppSpacing.elevations[0],
        titleTextStyle: typography.title.copyWith(color: colors.white),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: typography.display.copyWith(color: colors.emerald900),
        headlineLarge: typography.headline.copyWith(color: colors.emerald900),
        titleLarge: typography.title,
        titleMedium: typography.subtitle,
        bodyLarge: typography.bodyLarge,
        bodyMedium: typography.body,
        bodySmall: typography.small,
        labelSmall: typography.caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.gold500,
          foregroundColor: colors.emerald900,
          textStyle: typography.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.emerald900,
          side: BorderSide(color: colors.emerald900),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          borderSide: BorderSide(color: colors.gray[3]),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          borderSide: BorderSide(color: colors.gray[3]),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          borderSide: BorderSide(color: colors.emerald500, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.white,
        elevation: AppSpacing.elevations[1],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.white,
        selectedItemColor: colors.emerald900,
        unselectedItemColor: colors.gray[5],
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(color: colors.gray[2]),
    );
  }
}

/// Convenience accessors: `context.appColors`, `context.appTypography`, `context.appSpacing`.
extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  AppTypography get appTypography => Theme.of(this).extension<AppTypography>()!;
  AppSpacing get appSpacing => Theme.of(this).extension<AppSpacing>()!;
}
