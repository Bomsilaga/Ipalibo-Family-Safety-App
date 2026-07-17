import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../data/tasks_repository.dart';
import '../domain/task_model.dart';

/// Task Detail per the mockup: category tag, due-time line (red when
/// close/overdue), instructions block, repeat indicator, and the large
/// "I've Completed This" button pinned to the bottom.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  final TaskModel task;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final me = await ref.read(currentAppUserProvider.future);
    if (me == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(tasksRepositoryProvider).completeTask(
            task: widget.task,
            userId: me.id,
            evidenceNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      ref.invalidate(openTasksProvider);
      if (mounted) context.pushReplacement('/task-completed', extra: widget.task.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not complete: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final task = widget.task;
    final status = deriveStatus(task, DateTime.now());
    final dueSoonOrOverdue = status != 'upcoming';

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: Text(task.category[0].toUpperCase() + task.category.substring(1))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(task.title, style: typography.title.copyWith(color: colors.emerald900)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Due ${task.dueDate.toIso8601String().substring(0, 10)} at ${task.dueTime.substring(0, 5)}',
                    style: typography.mono.copyWith(
                      color: dueSoonOrOverdue ? colors.danger : colors.gray[6],
                      fontWeight: dueSoonOrOverdue ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  if (task.repeatRule != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(children: [
                      Icon(Icons.repeat, size: 14, color: colors.gray[5]),
                      const SizedBox(width: AppSpacing.xs),
                      Text('Repeats', style: typography.caption.copyWith(color: colors.gray[5])),
                    ]),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (task.subject != null) _metaRow(Icons.school_outlined, 'Subject: ${task.subject}'),
                  if (task.bookTitle != null) _metaRow(Icons.auto_stories_outlined, 'Book: ${task.bookTitle}'),
                  if (task.instructionsRich != null || task.description != null) ...[
                    Text('Instructions', style: typography.subtitle),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(task.instructionsRich ?? task.description!, style: typography.body),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (task.requiresEvidence) ...[
                    Text('Add a note about what you did', style: typography.small),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'e.g. Cleaned my room and made the bed'),
                    ),
                  ],
                  if (task.requiresApproval)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'A parent will confirm this once you mark it done.',
                        style: typography.caption.copyWith(color: colors.gray[6]),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _complete,
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("I've Completed This"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(children: [
        Icon(icon, size: 18, color: context.appColors.emerald700),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: context.appTypography.body),
      ]),
    );
  }
}
