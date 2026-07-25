import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The gold laurel crest from the brand mockup. Drawn rather than shipped
/// as an asset so it stays crisp at any size and picks up the theme's gold
/// token instead of baking a colour into a PNG.
class BrandCrest extends StatelessWidget {
  const BrandCrest({super.key, this.size = 72, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gold = color ?? context.appColors.gold500;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Laurel wreath: two mirrored arcs opening at the top, the way
          // the crest reads in the mockup.
          Icon(Icons.eco_outlined, size: size * 0.92, color: gold.withValues(alpha: 0.55)),
          Transform.flip(
            flipX: true,
            child: Icon(Icons.eco_outlined, size: size * 0.92, color: gold.withValues(alpha: 0.55)),
          ),
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: gold, width: size * 0.035),
            ),
            alignment: Alignment.center,
            child: Text(
              'I',
              style: TextStyle(
                color: gold,
                fontSize: size * 0.30,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ],
      ),
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
