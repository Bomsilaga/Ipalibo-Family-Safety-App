import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/tasks_repository.dart';
import '../domain/task_model.dart';
import 'task_builder_sheet.dart';

/// Tasks tab: open chores/homework/reading grouped by day, status pill per
/// task, inline "Done" action, parent "+" to open the task builder.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tasksAsync = ref.watch(openTasksProvider);
    final meAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: meAsync.maybeWhen(
        data: (me) => me != null && hasPermission(me, AppAction.createTasks)
            ? FloatingActionButton(
                backgroundColor: colors.gold500,
                foregroundColor: colors.emerald900,
                onPressed: () async {
                  final created = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const TaskBuilderSheet(),
                  );
                  if (created == true) ref.invalidate(openTasksProvider);
                },
                child: const Icon(Icons.add_task),
              )
            : null,
        orElse: () => null,
      ),
      body: tasksAsync.when(
        data: (tasks) {
          final me = meAsync.value;
          final mine = me == null
              ? tasks
              : tasks
                  .where((t) => t.assigneeIds.contains(me.id) || me.role.toStringValue() == 'parent')
                  .toList();
          if (mine.isEmpty) {
            return const EmptyState(
              icon: Icons.checklist_outlined,
              message: 'No chores, homework, or reading assigned yet.',
            );
          }
          final byDate = <String, List<TaskModel>>{};
          for (final t in mine) {
            byDate.putIfAbsent(t.dueDate.toIso8601String().substring(0, 10), () => []).add(t);
          }
          final dates = byDate.keys.toList()..sort();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final date in dates) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(date,
                      style: context.appTypography.small
                          .copyWith(color: colors.gray[6], fontWeight: FontWeight.w600)),
                ),
                for (final task in byDate[date]!) _TaskCard(task: task),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(icon: Icons.error_outline, message: 'Could not load tasks: $error'),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final status = deriveStatus(task, DateTime.now());
    final (pillColor, pillText) = switch (status) {
      'upcoming' => (colors.information, 'Upcoming'),
      'due' => (colors.warning, 'Due'),
      _ => (colors.danger, 'Missed'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: () => context.push('/task/${task.id}', extra: task),
        leading: Icon(
          switch (task.category) {
            'homework' => Icons.menu_book_outlined,
            'reading' => Icons.auto_stories_outlined,
            _ => Icons.cleaning_services_outlined,
          },
          color: colors.emerald700,
        ),
        title: Text(task.title),
        subtitle: Text('Due ${task.dueTime.substring(0, 5)}', style: context.appTypography.mono),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: pillColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Text(pillText,
              style: context.appTypography.caption
                  .copyWith(color: pillColor, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
