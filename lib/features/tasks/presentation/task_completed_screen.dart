import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// The payoff screen after a chore tap — congratulatory headline,
/// timestamp, one "Done" button. Keep it quick (docs/04-design-system.md).
class TaskCompletedScreen extends StatelessWidget {
  const TaskCompletedScreen({super.key, required this.taskTitle});

  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final now = TimeOfDay.now();
    return Scaffold(
      backgroundColor: colors.emerald900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.emoji_events_outlined, size: 96, color: colors.gold500),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Well done!',
                textAlign: TextAlign.center,
                style: typography.headline.copyWith(color: colors.ivory),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '"$taskTitle" completed at ${now.format(context)}',
                textAlign: TextAlign.center,
                style: typography.body.copyWith(color: colors.ivory.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => context.go('/tasks'),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
