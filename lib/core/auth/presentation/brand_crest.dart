import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The gold laurel crest from the brand mockup.
///
/// This was previously approximated in Dart out of two mirrored
/// `Icons.eco_outlined` glyphs and a bordered circle, which read as
/// "two leaves next to a letter" rather than as a wreath. It's now the
/// real artwork (`assets/brand/crest.png`), keyed to transparency so the
/// same file sits on the emerald welcome screen and the ivory sign-in
/// screen without a background plate.
class BrandCrest extends StatelessWidget {
  const BrandCrest({super.key, this.size = 72, this.color});

  final double size;

  /// Tints the crest. Left null the artwork keeps its own gold gradient,
  /// which is what the mockup shows.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/crest.png',
      width: size,
      height: size,
      color: color,
      filterQuality: FilterQuality.medium,
      // The crest is decorative — the wordmark beside it already carries
      // the name for screen readers.
      excludeFromSemantics: true,
    );
  }
}

/// "THE IPALIBOS" wordmark — small caps with the wide letter-spacing used
/// throughout the mockup's headers.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.color, this.fontSize = 13});

  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'THE IPALIBOS',
      style: TextStyle(
        color: color ?? context.appColors.emerald900,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: fontSize * 0.18,
      ),
    );
  }
}
