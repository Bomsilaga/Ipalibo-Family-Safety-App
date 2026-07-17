import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../tasks/data/tasks_repository.dart';
import '../../tasks/domain/task_model.dart';

/// Daily briefing (product spec §16): a short assistive summary built
/// strictly from the calling user's own visible data — the assistant
/// never has permissions beyond the user invoking it.
class DailyBriefingScreen extends ConsumerWidget {
  const DailyBriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final briefingAsync = ref.watch(dailyBriefingProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Daily Briefing')),
      body: briefingAsync.when(
        data: (briefing) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(briefing.greeting, style: typography.headline.copyWith(color: colors.emerald900)),
            const SizedBox(height: AppSpacing.lg),
            for (final line in briefing.lines)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Icon(line.icon, color: colors.emerald700),
                  title: Text(line.text),
                ),
              ),
            if (briefing.lines.isEmpty)
              const EmptyState(
                icon: Icons.self_improvement_outlined,
                message: 'Nothing on today — enjoy the quiet.',
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(icon: Icons.error_outline, message: 'Could not build briefing: $error'),
      ),
    );
  }
}

class BriefingLine {
  const BriefingLine(this.icon, this.text);
  final IconData icon;
  final String text;
}

class Briefing {
  const Briefing({required this.greeting, required this.lines});
  final String greeting;
  final List<BriefingLine> lines;
}

final dailyBriefingProvider = FutureProvider<Briefing>((ref) async {
  final me = await ref.watch(currentAppUserProvider.future);
  final hour = DateTime.now().hour;
  final greeting =
      '${hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening'}'
      '${me != null ? ', ${me.displayName}' : ''}';
  if (me == null) return Briefing(greeting: greeting, lines: const []);

  final lines = <BriefingLine>[];
  final today = DateTime.now();

  final events = await ref.watch(calendarRepositoryProvider).eventsForMonth(today);
  final todaysEvents = events
      .where((e) =>
          e.startAt.day == today.day &&
          e.startAt.month == today.month &&
          (e.participantIds.contains(me.id) || e.ownerId == me.id))
      .toList();
  for (final e in todaysEvents.take(4)) {
    lines.add(BriefingLine(
      Icons.event_outlined,
      '${e.title} at ${e.startAt.hour.toString().padLeft(2, '0')}:${e.startAt.minute.toString().padLeft(2, '0')}',
    ));
  }
  // Conflict flag (assistive, spec §16 "flags calendar conflicts").
  for (var i = 0; i < todaysEvents.length; i++) {
    for (var j = i + 1; j < todaysEvents.length; j++) {
      if (todaysEvents[i].overlaps(todaysEvents[j])) {
        lines.add(BriefingLine(
          Icons.warning_amber_outlined,
          'Heads up: "${todaysEvents[i].title}" overlaps "${todaysEvents[j].title}".',
        ));
      }
    }
  }

  final tasks = await ref.watch(tasksRepositoryProvider).tasksDueOn(today);
  final myTasks = tasks.where((t) => t.assigneeIds.contains(me.id)).toList();
  for (final t in myTasks.take(4)) {
    final status = deriveStatus(t, DateTime.now());
    lines.add(BriefingLine(
      status == 'missed' ? Icons.error_outline : Icons.task_alt_outlined,
      '${t.title} — due ${t.dueTime.substring(0, 5)}${status == 'missed' ? ' (overdue)' : ''}',
    ));
  }

  return Briefing(greeting: greeting, lines: lines);
});
