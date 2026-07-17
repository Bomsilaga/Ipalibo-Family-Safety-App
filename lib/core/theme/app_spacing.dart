import 'package:flutter/material.dart';

/// 8-point spacing grid and shape tokens, per docs/04-design-system.md.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
  static const double huge = 56;
  static const double massive = 64;

  static const double radiusSmall = 8;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusPill = 999;

  static const List<double> elevations = [0, 1, 2, 3, 4, 5];

  @override
  AppSpacing copyWith() => const AppSpacing();

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) => this;
}
