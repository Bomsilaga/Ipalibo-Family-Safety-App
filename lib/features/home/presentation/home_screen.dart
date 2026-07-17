import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Home / "Good morning" screen: greeting in Fraunces, 4 KPI mini-cards,
/// upcoming appointments, today's tasks (docs/04-design-system.md).
///
/// The KPI values and lists are wired up once Calendar (Module 2), Tasks
/// (Module 3), Chat (Module 5), and Parental Controls (Module 6) land —
/// this lays out the shell against live family/user data from Module 1.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final appUserAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              appUserAsync.when(
                data: (user) => Text(
                  '${_greeting()}${user != null ? ', ${user.displayName}' : ''}',
                  style: typography.headline.copyWith(color: colors.emerald900),
                ),
                loading: () => Text(_greeting(), style: typography.headline.copyWith(color: colors.emerald900)),
                error: (_, _) => Text(_greeting(), style: typography.headline.copyWith(color: colors.emerald900)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                MaterialLocalizations.of(context).formatFullDate(DateTime.now()),
                style: typography.body.copyWith(color: colors.gray[6]),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: const [
                  Expanded(child: _KpiTile(label: 'Appointments', value: '0', icon: Icons.calendar_today_outlined)),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: _KpiTile(label: 'Tasks', value: '0', icon: Icons.checklist_outlined)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: const [
                  Expanded(child: _KpiTile(label: 'Messages', value: '0', icon: Icons.chat_bubble_outline)),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: _KpiTile(label: 'Unlock Requests', value: '0', icon: Icons.lock_open_outlined)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Upcoming Appointments', style: typography.subtitle.copyWith(color: colors.emerald900)),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: EmptyState(
                  icon: Icons.event_available_outlined,
                  message: 'No appointments yet — tap + to add one.',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Today\'s Tasks', style: typography.subtitle.copyWith(color: colors.emerald900)),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: EmptyState(
                  icon: Icons.task_alt_outlined,
                  message: 'No tasks due today.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.emerald500, size: 20),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: typography.title.copyWith(color: colors.emerald900)),
            Text(label, style: typography.caption.copyWith(color: colors.gray[6])),
          ],
        ),
      ),
    );
  }
}
