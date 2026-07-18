import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/core/theme/app_colors.dart';
import 'package:ipalibos/core/theme/app_spacing.dart';
import 'package:ipalibos/core/theme/app_theme.dart';
import 'package:ipalibos/core/theme/app_typography.dart';

void main() {
  testWidgets('AppTheme exposes AppColors/AppTypography/AppSpacing extensions', (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(capturedContext.appColors, isA<AppColors>());
    expect(capturedContext.appTypography, isA<AppTypography>());
    expect(capturedContext.appSpacing, isA<AppSpacing>());
    expect(capturedContext.appColors.emerald900, const Color(0xFF0D4B45));
    expect(capturedContext.appColors.gold500, const Color(0xFFC8A44D));
  });

  testWidgets('dark theme preserves brand colours instead of dropping to pure black', (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final colors = capturedContext.appColors;
    expect(colors.emerald900, const Color(0xFF0D4B45));
    expect(colors.ivory, isNot(Colors.black));
  });
}
