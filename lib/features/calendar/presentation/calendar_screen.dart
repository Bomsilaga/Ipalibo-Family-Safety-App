import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import '../data/calendar_repository.dart';
import '../domain/event_model.dart';
import 'event_quick_add_sheet.dart';

/// Calendar month view per the mockups: member filter chips (incl.
/// "Everyone"), month grid with colour-coded event chips per owner,
/// quick-add from the "+" button (docs/04-design-system.md).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  String? _filterUserId; // null = Everyone

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final eventsAsync = ref.watch(monthEventsProvider(_month));
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          ),
          Center(
            child: Text(
              '${_monthName(_month.month)} ${_month.year}',
              style: typography.small.copyWith(color: colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.gold500,
        foregroundColor: colors.emerald900,
        onPressed: () => _openQuickAdd(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 64,
            child: membersAsync.when(
              data: (members) => _memberChips(members),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ),
          eventsAsync.when(
            data: (events) {
              final filtered = _filterUserId == null
                  ? events
                  : events
                      .where((e) =>
                          e.ownerId == _filterUserId ||
                          e.participantIds.contains(_filterUserId))
                      .toList();
              return Expanded(
                child: Column(
                  children: [
                    _monthGrid(filtered),
                    const Divider(height: 1),
                    Expanded(child: _dayList(filtered)),
                  ],
                ),
              );
            },
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (error, _) => Expanded(
              child: EmptyState(icon: Icons.error_outline, message: 'Could not load events: $error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberChips(List<AppUser> members) {
    final colors = context.appColors;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: FilterChip(
            label: const Text('Everyone'),
            selected: _filterUserId == null,
            selectedColor: colors.emerald500.withValues(alpha: 0.2),
            onSelected: (_) => setState(() => _filterUserId = null),
          ),
        ),
        for (final member in members)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              avatar: MemberAvatar(user: member, radius: 10),
              label: Text(member.displayName),
              selected: _filterUserId == member.id,
              selectedColor: memberColor(member.avatarColor).withValues(alpha: 0.2),
              onSelected: (_) => setState(() => _filterUserId = member.id),
            ),
          ),
      ],
    );
  }

  Widget _monthGrid(List<EventModel> events) {
    final colors = context.appColors;
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = (firstDay.weekday - 1) % 7; // Monday-first grid

    final byDay = <int, List<EventModel>>{};
    for (final e in events) {
      if (e.startAt.month == _month.month && e.startAt.year == _month.year) {
        byDay.putIfAbsent(e.startAt.day, () => []).add(e);
      }
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: [
        for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
        for (var day = 1; day <= daysInMonth; day++)
          InkWell(
            onTap: () => setState(() => _selectedDay = DateTime(_month.year, _month.month, day)),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: _isSelected(day) ? colors.emerald500.withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$day',
                      style: context.appTypography.small.copyWith(
                        fontWeight: _isToday(day) ? FontWeight.w700 : FontWeight.w400,
                        color: _isToday(day) ? colors.emerald700 : null,
                      )),
                  if (byDay.containsKey(day))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final e in byDay[day]!.take(3))
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: e.color != null ? memberColor(e.color!) : colors.emerald500,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _dayList(List<EventModel> events) {
    final dayEvents = events
        .where((e) =>
            e.startAt.year == _selectedDay.year &&
            e.startAt.month == _selectedDay.month &&
            e.startAt.day == _selectedDay.day)
        .toList();
    if (dayEvents.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        message: 'No appointments this day — tap + to add one.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final e in dayEvents)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: e.color != null
                      ? memberColor(e.color!)
                      : context.appColors.emerald500,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(e.title),
              subtitle: Text(
                '${_fmtTime(e.startAt)}${e.endAt != null ? ' – ${_fmtTime(e.endAt!)}' : ''}'
                '${e.location != null ? ' · ${e.location}' : ''}',
                style: context.appTypography.mono,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openQuickAdd(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventQuickAddSheet(initialDay: _selectedDay),
    );
    if (created == true) ref.invalidate(monthEventsProvider(_month));
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == _month.year && now.month == _month.month && now.day == day;
  }

  bool _isSelected(int day) =>
      _selectedDay.year == _month.year &&
      _selectedDay.month == _month.month &&
      _selectedDay.day == day;

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _monthName(int m) => const [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][m - 1];
}
