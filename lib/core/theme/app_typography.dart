import 'package:flutter/material.dart';

/// Type scale for The Ipalibos, per docs/04-design-system.md.
///
/// Primary (body/UI): Inter · Secondary (display/headings): Fraunces ·
/// Monospace (data/timestamps): IBM Plex Mono.
///
/// Font files are not bundled yet — family names are declared here so they
/// resolve once added under `assets/fonts/` and registered in pubspec.yaml;
/// until then Flutter falls back to the platform default.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.subtitle,
    required this.bodyLarge,
    required this.body,
    required this.small,
    required this.caption,
    required this.mono,
  });

  final TextStyle display; // 56 - Fraunces
  final TextStyle headline; // 40 - Fraunces
  final TextStyle title; // 28 - Inter
  final TextStyle subtitle; // 22 - Inter
  final TextStyle bodyLarge; // 18 - Inter
  final TextStyle body; // 16 - Inter
  final TextStyle small; // 14 - Inter
  final TextStyle caption; // 12 - Inter
  final TextStyle mono; // IBM Plex Mono, for timestamps/codes

  static const _primaryFamily = 'Inter';
  static const _displayFamily = 'Fraunces';
  static const _monoFamily = 'IBMPlexMono';

  static const standard = AppTypography(
    display: TextStyle(
      fontFamily: _displayFamily,
      fontSize: 56,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    headline: TextStyle(
      fontFamily: _displayFamily,
      fontSize: 40,
      fontWeight: FontWeight.w600,
      height: 1.15,
    ),
    title: TextStyle(
      fontFamily: _primaryFamily,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    subtitle: TextStyle(
      fontFamily: _primaryFamily,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    bodyLarge: TextStyle(
      fontFamily: _primaryFamily,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    body: TextStyle(
      fontFamily: _primaryFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    small: TextStyle(
      fontFamily: _primaryFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.35,
    ),
    caption: TextStyle(
      fontFamily: _primaryFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    mono: TextStyle(
      fontFamily: _monoFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
  );

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? bodyLarge,
    TextStyle? body,
    TextStyle? small,
    TextStyle? caption,
    TextStyle? mono,
  }) {
    return AppTypography(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      body: body ?? this.body,
      small: small ?? this.small,
      caption: caption ?? this.caption,
      mono: mono ?? this.mono,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      small: TextStyle.lerp(small, other.small, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}
