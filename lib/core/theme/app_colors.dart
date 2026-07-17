import 'package:flutter/material.dart';

/// Brand and semantic colour tokens for The Ipalibos, per docs/04-design-system.md.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.emerald900,
    required this.emerald700,
    required this.emerald500,
    required this.gold500,
    required this.ivory,
    required this.white,
    required this.success,
    required this.warning,
    required this.danger,
    required this.information,
    required this.disabled,
    required this.gray,
  });

  final Color emerald900;
  final Color emerald700;
  final Color emerald500;
  final Color gold500;
  final Color ivory;
  final Color white;
  final Color success;
  final Color warning;
  final Color danger;
  final Color information;
  final Color disabled;
  final List<Color> gray; // gray[0]..gray[9] for the 50..900 ramp

  static const light = AppColors(
    emerald900: Color(0xFF0D4B45),
    emerald700: Color(0xFF146A60),
    emerald500: Color(0xFF23907F),
    gold500: Color(0xFFC8A44D),
    ivory: Color(0xFFF8F7F2),
    white: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFF9A825),
    danger: Color(0xFFD32F2F),
    information: Color(0xFF1976D2),
    disabled: Color(0xFFBDBDBD),
    gray: [
      Color(0xFFFAFAFA), // 50
      Color(0xFFF5F5F5), // 100
      Color(0xFFEEEEEE), // 200
      Color(0xFFE0E0E0), // 300
      Color(0xFFBDBDBD), // 400
      Color(0xFF9E9E9E), // 500
      Color(0xFF757575), // 600
      Color(0xFF616161), // 700
      Color(0xFF424242), // 800
      Color(0xFF212121), // 900
    ],
  );

  /// Dark mode preserves brand colours rather than dropping to pure black.
  static const dark = AppColors(
    emerald900: Color(0xFF0D4B45),
    emerald700: Color(0xFF146A60),
    emerald500: Color(0xFF2FB09B),
    gold500: Color(0xFFD8B85F),
    ivory: Color(0xFF14201E),
    white: Color(0xFF1B2A27),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFBC02D),
    danger: Color(0xFFEF5350),
    information: Color(0xFF42A5F5),
    disabled: Color(0xFF5A5A5A),
    gray: [
      Color(0xFF212121),
      Color(0xFF262626),
      Color(0xFF2E2E2E),
      Color(0xFF3B3B3B),
      Color(0xFF4A4A4A),
      Color(0xFF616161),
      Color(0xFF828282),
      Color(0xFFA0A0A0),
      Color(0xFFC7C7C7),
      Color(0xFFF5F5F5),
    ],
  );

  /// Rotating palette assigned to family members (`users.avatar_color`),
  /// separate from the brand palette, used for calendar/chat/GPS colour-coding.
  static const List<Color> memberPalette = [
    Color(0xFF23907F), // emerald
    Color(0xFFC8A44D), // gold
    Color(0xFF1976D2), // blue
    Color(0xFFD32F2F), // red
    Color(0xFF8E24AA), // purple
    Color(0xFFF57C00), // orange
    Color(0xFF00897B), // teal
    Color(0xFFAD1457), // pink
  ];

  @override
  AppColors copyWith({
    Color? emerald900,
    Color? emerald700,
    Color? emerald500,
    Color? gold500,
    Color? ivory,
    Color? white,
    Color? success,
    Color? warning,
    Color? danger,
    Color? information,
    Color? disabled,
    List<Color>? gray,
  }) {
    return AppColors(
      emerald900: emerald900 ?? this.emerald900,
      emerald700: emerald700 ?? this.emerald700,
      emerald500: emerald500 ?? this.emerald500,
      gold500: gold500 ?? this.gold500,
      ivory: ivory ?? this.ivory,
      white: white ?? this.white,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      information: information ?? this.information,
      disabled: disabled ?? this.disabled,
      gray: gray ?? this.gray,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      emerald900: Color.lerp(emerald900, other.emerald900, t)!,
      emerald700: Color.lerp(emerald700, other.emerald700, t)!,
      emerald500: Color.lerp(emerald500, other.emerald500, t)!,
      gold500: Color.lerp(gold500, other.gold500, t)!,
      ivory: Color.lerp(ivory, other.ivory, t)!,
      white: Color.lerp(white, other.white, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      information: Color.lerp(information, other.information, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      gray: List.generate(
        gray.length,
        (i) => Color.lerp(gray[i], other.gray[i], t)!,
      ),
    );
  }
}
