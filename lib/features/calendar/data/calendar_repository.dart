import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/event_model.dart';

class CalendarRepository {
  CalendarRepository(this._client);

  final SupabaseClient _client;

  Future<List<EventModel>> eventsForMonth(DateTime month) async {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 1);
    final rows = await _client
        .from('events')
        .select('*, event_participants(user_id)')
        .gte('start_at', first.toUtc().toIso8601String())
        .lt('start_at', last.toUtc().toIso8601String())
        .neq('status', 'cancelled')
        .order('start_at');
    return (rows as List).map((r) => EventModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Creates an event plus its participant rows; returns any conflicting
  /// events for the same participants so the UI can warn (spec §5 —
  /// warn, don't block).
  Future<({EventModel event, List<EventModel> conflicts})> createEvent({
    required String familyId,
    required String ownerId,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String? description,
    String? location,
    bool allDay = false,
    String? repeatRule,
    List<int> reminderOffsets = const [30],
    required List<String> participantIds,
  }) async {
    final row = await _client
        .from('events')
        .insert({
          'family_id': familyId,
          'owner_id': ownerId,
          'title': title,
          'description': description,
          'location': location,
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt?.toUtc().toIso8601String(),
          'all_day': allDay,
          'repeat_rule': repeatRule,
          'reminder_offsets': reminderOffsets,
        })
        .select()
        .single();

    if (participantIds.isNotEmpty) {
      await _client.from('event_participants').insert([
        for (final userId in participantIds) {'event_id': row['id'], 'user_id': userId},
      ]);
    }

    final created = EventModel.fromJson({...row, 'event_participants': []});
    final dayEvents = await eventsForMonth(startAt);
    final conflicts = dayEvents
        .where((e) =>
            e.id != created.id &&
            e.overlaps(created) &&
            e.participantIds.any(participantIds.contains))
        .toList();
    return (event: created, conflicts: conflicts);
  }

  Future<void> deleteEvent(String eventId) async {
    await _client.from('events').delete().eq('id', eventId);
  }
}

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(supabase);
});

/// Keyed by the first day of the month being viewed.
final monthEventsProvider =
    FutureProvider.family<List<EventModel>, DateTime>((ref, month) async {
  return ref.watch(calendarRepositoryProvider).eventsForMonth(month);
});
