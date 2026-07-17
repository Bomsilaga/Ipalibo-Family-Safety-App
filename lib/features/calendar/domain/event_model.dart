/// Mirrors `public.events` (docs/02-data-model.md "Calendar").
class EventModel {
  const EventModel({
    required this.id,
    required this.familyId,
    required this.ownerId,
    required this.title,
    this.description,
    this.category,
    this.color,
    this.icon,
    this.location,
    this.latitude,
    this.longitude,
    required this.startAt,
    this.endAt,
    this.allDay = false,
    this.repeatRule,
    this.reminderOffsets = const [30],
    this.status = 'confirmed',
    this.visibility = 'family',
    this.participantIds = const [],
  });

  final String id;
  final String familyId;
  final String ownerId;
  final String title;
  final String? description;
  final String? category;
  final String? color;
  final String? icon;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final String? repeatRule;
  final List<int> reminderOffsets;
  final String status;
  final String visibility;
  final List<String> participantIds;

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        ownerId: json['owner_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        location: json['location'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        startAt: DateTime.parse(json['start_at'] as String).toLocal(),
        endAt: json['end_at'] != null ? DateTime.parse(json['end_at'] as String).toLocal() : null,
        allDay: json['all_day'] as bool? ?? false,
        repeatRule: json['repeat_rule'] as String?,
        reminderOffsets:
            (json['reminder_offsets'] as List?)?.map((e) => e as int).toList() ?? const [30],
        status: json['status'] as String? ?? 'confirmed',
        visibility: json['visibility'] as String? ?? 'family',
        participantIds: (json['event_participants'] as List?)
                ?.map((e) => (e as Map<String, dynamic>)['user_id'] as String)
                .toList() ??
            const [],
      );

  /// Whether this event overlaps [other] in time — the basis of the
  /// conflict-detection warning (product spec §5).
  bool overlaps(EventModel other) {
    final thisEnd = endAt ?? startAt.add(const Duration(hours: 1));
    final otherEnd = other.endAt ?? other.startAt.add(const Duration(hours: 1));
    return startAt.isBefore(otherEnd) && other.startAt.isBefore(thisEnd);
  }
}
