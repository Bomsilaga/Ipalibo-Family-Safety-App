import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/member_avatar.dart';
import '../data/tasks_repository.dart';

/// Parent task builder (product spec §6): title, instructions, category,
/// assignee(s) (bulk assignment), due date/time, grace period, repeat,
/// evidence and approval toggles.
class TaskBuilderSheet extends ConsumerStatefulWidget {
  const TaskBuilderSheet({super.key});

  @override
  ConsumerState<TaskBuilderSheet> createState() => _TaskBuilderSheetState();
}

class _TaskBuilderSheetState extends ConsumerState<TaskBuilderSheet> {
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _category = 'chore';
  DateTime _dueDate = DateTime.now();
  TimeOfDay _dueTime = const TimeOfDay(hour: 17, minute: 0);
  String? _repeat;
  bool _requiresApproval = false;
  bool _requiresEvidence = false;
  final Set<String> _assignees = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    if (_assignees.isEmpty) {
      setState(() => _error = 'Pick at least one assignee');
      return;
    }
    final me = await ref.read(currentAppUserProvider.future);
    if (me?.familyId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(tasksRepositoryProvider).createTask(
            familyId: me!.familyId!,
            createdBy: me.id,
            title: _titleController.text.trim(),
            category: _category,
            dueDate: _dueDate,
            dueTime:
                '${_dueTime.hour.toString().padLeft(2, '0')}:${_dueTime.minute.toString().padLeft(2, '0')}:00',
            instructions: _instructionsController.text.trim().isEmpty
                ? null
                : _instructionsController.text.trim(),
            repeatRule: _repeat,
            requiresApproval: _requiresApproval,
            requiresEvidence: _requiresEvidence,
            assigneeIds: _assignees.toList(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final membersAsync = ref.watch(familyMembersProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New task', style: context.appTypography.subtitle),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'Title')),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _instructionsController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Instructions (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final cat in const ['chore', 'homework', 'reading', 'other'])
                  ChoiceChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Assign to', style: context.appTypography.small),
            const SizedBox(height: AppSpacing.sm),
            membersAsync.when(
              data: (members) {
                final children = members.where((m) => m.role == UserRole.child).toList();
                if (children.isEmpty) {
                  return Text(
                    'No children on this family yet — add one from the Family tab first.',
                    style: context.appTypography.small.copyWith(color: colors.gray[6]),
                  );
                }
                return Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final m in children)
                      FilterChip(
                        avatar: MemberAvatar(user: m, radius: 10),
                        label: Text(m.displayName),
                        selected: _assignees.contains(m.id),
                        onSelected: (sel) => setState(() {
                          sel ? _assignees.add(m.id) : _assignees.remove(m.id);
                        }),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text('${_dueDate.day}/${_dueDate.month}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_outlined, size: 16),
                  label: Text(_dueTime.format(context)),
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _dueTime);
                    if (picked != null) setState(() => _dueTime = picked);
                  },
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: _repeat,
              decoration: const InputDecoration(hintText: 'Repeat'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Does not repeat')),
                DropdownMenuItem(value: 'FREQ=DAILY', child: Text('Daily')),
                DropdownMenuItem(value: 'FREQ=WEEKLY', child: Text('Weekly')),
              ],
              onChanged: (v) => setState(() => _repeat = v),
            ),
            SwitchListTile(
              title: const Text('Needs photo/note evidence'),
              value: _requiresEvidence,
              onChanged: (v) => setState(() => _requiresEvidence = v),
            ),
            SwitchListTile(
              title: const Text('Needs parent approval'),
              value: _requiresApproval,
              onChanged: (v) => setState(() => _requiresApproval = v),
            ),
            if (_error != null)
              Text(_error!, style: context.appTypography.small.copyWith(color: colors.danger)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create task'),
            ),
          ],
        ),
      ),
    );
  }
}
