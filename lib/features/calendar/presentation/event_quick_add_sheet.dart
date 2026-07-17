import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/member_avatar.dart';
import '../data/calendar_repository.dart';

/// Quick-add appointment sheet: person picker (multi-select), title,
/// date, start/end time, location, reminder (product spec §5).
class EventQuickAddSheet extends ConsumerStatefulWidget {
  const EventQuickAddSheet({super.key, required this.initialDay});

  final DateTime initialDay;

  @override
  ConsumerState<EventQuickAddSheet> createState() => _EventQuickAddSheetState();
}

class _EventQuickAddSheetState extends ConsumerState<EventQuickAddSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _day = widget.initialDay;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  final Set<String> _participants = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    final me = await ref.read(currentAppUserProvider.future);
    if (me?.familyId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final startAt = DateTime(_day.year, _day.month, _day.day, _startTime.hour, _startTime.minute);
      final result = await ref.read(calendarRepositoryProvider).createEvent(
            familyId: me!.familyId!,
            ownerId: me.id,
            title: title,
            startAt: startAt,
            location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
            participantIds: _participants.isEmpty ? [me.id] : _participants.toList(),
          );
      if (!mounted) return;
      if (result.conflicts.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Heads up: overlaps with ${result.conflicts.first.title}',
          ),
        ));
      }
      Navigator.of(context).pop(true);
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
            Text('New appointment', style: context.appTypography.subtitle),
            const SizedBox(height: AppSpacing.md),
            membersAsync.when(
              data: (members) => Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final m in members)
                    FilterChip(
                      avatar: MemberAvatar(user: m, radius: 10),
                      label: Text(m.displayName),
                      selected: _participants.contains(m.id),
                      onSelected: (sel) => setState(() {
                        sel ? _participants.add(m.id) : _participants.remove(m.id);
                      }),
                    ),
                ],
              ),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(hintText: 'Location (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('${_day.day}/${_day.month}/${_day.year}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _day,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setState(() => _day = picked);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_outlined, size: 16),
                    label: Text(_startTime.format(context)),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _startTime);
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: context.appTypography.small.copyWith(color: colors.danger)),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add appointment'),
            ),
          ],
        ),
      ),
    );
  }
}
