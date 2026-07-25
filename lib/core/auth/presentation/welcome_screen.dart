import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import 'brand_crest.dart';

/// Signed-out landing screen, matching the brand mockup: full-bleed
/// emerald, gold crest and wordmark, gold "Get Started" and a quieter
/// "I already have an account".
///
/// Splitting sign-up and sign-in into two clearly-labelled doors here is
/// what makes the rest of auth feel obvious — the old single screen made
/// people toggle a small text link to find the mode they wanted.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: colors.emerald900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(child: BrandCrest(size: 96, color: colors.gold500)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'THE\nIPALIBOS',
                textAlign: TextAlign.center,
                style: typography.headline.copyWith(
                  color: colors.ivory,
                  height: 1.05,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your Family. Organised.\nSafe. Connected.',
                textAlign: TextAlign.center,
                style: typography.body.copyWith(color: colors.gold500),
              ),
              const Spacer(flex: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold500,
                  foregroundColor: colors.emerald900,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () => context.go('/sign-in?mode=signup'),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go('/sign-in'),
                child: Text(
                  'I already have an account',
                  style: typography.body.copyWith(color: colors.ivory),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
