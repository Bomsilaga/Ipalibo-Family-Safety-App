import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../parental_controls/data/unlock_repository.dart';
import '../../tasks/data/tasks_repository.dart';
import '../../tasks/domain/task_model.dart';

/// Home / "Good morning" screen per the mockup: greeting + date, 4 KPI
/// mini-cards, Upcoming Appointments, Today's Tasks with inline Done.
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
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    final eventsAsync = ref.watch(monthEventsProvider(month));
    final tasksAsync = ref.watch(openTasksProvider);
    final unlockAsync = ref.watch(unlockRequestsProvider);

    final me = appUserAsync.value;
    final now = DateTime.now();
    final upcoming = (eventsAsync.value ?? [])
        .where((e) => e.startAt.isAfter(now))
        .take(3)
        .toList();
    final todaysTasks = (tasksAsync.value ?? [])
        .where((t) =>
            t.dueDate.year == now.year &&
            t.dueDate.month == now.month &&
            t.dueDate.day == now.day &&
            (me == null || t.assigneeIds.contains(me.id) || t.createdBy == me.id))
        .toList();
    final pendingUnlocks =
        (unlockAsync.value ?? []).where((r) => r.isPending).length;

    return Scaffold(
      backgroundColor: colors.ivory,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthEventsProvider(month));
            ref.invalidate(openTasksProvider);
            ref.invalidate(unlockRequestsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                '${_greeting()}${me != null ? ', ${me.displayName}' : ''}',
                style: typography.headline.copyWith(color: colors.emerald900),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                MaterialLocalizations.of(context).formatFullDate(now),
                style: typography.body.copyWith(color: colors.gray[6]),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      label: 'Appointments',
                      value: '${upcoming.length}',
                      icon: Icons.calendar_today_outlined,
                      onTap: () => context.go('/calendar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _KpiTile(
                      label: 'Tasks today',
                      value: '${todaysTasks.length}',
                      icon: Icons.checklist_outlined,
                      onTap: () => context.go('/tasks'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      label: 'Messages',
                      value: '·',
                      icon: Icons.chat_bubble_outline,
                      onTap: () => context.go('/chat'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _KpiTile(
                      label: 'Unlock Requests',
                      value: '$pendingUnlocks',
                      icon: Icons.lock_open_outlined,
                      onTap: () => context.push('/unlock-requests'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Upcoming Appointments',
                  style: typography.subtitle.copyWith(color: colors.emerald900)),
              const SizedBox(height: AppSpacing.sm),
              if (upcoming.isEmpty)
                const Card(
                  child: EmptyState(
                    icon: Icons.event_available_outlined,
                    message: 'No appointments yet — tap + on the Calendar tab.',
                  ),
                )
              else
                for (final e in upcoming)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: Icon(Icons.event_outlined, color: colors.emerald700),
                      title: Text(e.title),
                      subtitle: Text(
                        '${e.startAt.day}/${e.startAt.month} '
                        '${e.startAt.hour.toString().padLeft(2, '0')}:${e.startAt.minute.toString().padLeft(2, '0')}',
                        style: typography.mono,
                      ),
                    ),
                  ),
              const SizedBox(height: AppSpacing.xl),
              Text("Today's Tasks", style: typography.subtitle.copyWith(color: colors.emerald900)),
              const SizedBox(height: AppSpacing.sm),
              if (todaysTasks.isEmpty)
                const Card(
                  child: EmptyState(
                    icon: Icons.task_alt_outlined,
                    message: 'No tasks due today.',
                  ),
                )
              else
                for (final t in todaysTasks) _HomeTaskTile(task: t),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTaskTile extends ConsumerWidget {
  const _HomeTaskTile({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: () => context.push('/task/${task.id}', extra: task),
        leading: Icon(Icons.circle_outlined, color: colors.warning),
        title: Text(task.title),
        subtitle: Text('Due ${task.dueTime.substring(0, 5)}', style: context.appTypography.mono),
        trailing: TextButton(
          onPressed: () async {
            final me = await ref.read(currentAppUserProvider.future);
            if (me == null) return;
            await ref.read(tasksRepositoryProvider).completeTask(task: task, userId: me.id);
            ref.invalidate(openTasksProvider);
            if (context.mounted) context.push('/task-completed', extra: task.title);
          },
          child: const Text('Done'),
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.icon, this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        onTap: onTap,
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
      ),
    );
  }
}
