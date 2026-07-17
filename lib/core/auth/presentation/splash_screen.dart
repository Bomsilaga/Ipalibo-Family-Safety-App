import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// Onboarding/splash: emerald-900 full-bleed background, gold logomark,
/// ivory wordmark (docs/04-design-system.md "Key components").
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.emerald900,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_moon_outlined, color: colors.gold500, size: 72),
            const SizedBox(height: AppSpacing.md),
            Text(
              'The Ipalibos',
              style: context.appTypography.headline.copyWith(color: colors.ivory),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your Family. Organised. Safe. Connected.',
              style: context.appTypography.body.copyWith(color: colors.ivory.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.gold500),
            ),
          ],
        ),
      ),
    );
  }
}
