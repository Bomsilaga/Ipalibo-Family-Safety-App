/// Mirrors `public.families` (docs/02-data-model.md).
class Family {
  const Family({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.timezone,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String timezone;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final DateTime createdAt;

  factory Family.fromJson(Map<String, dynamic> json) => Family(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        timezone: json['timezone'] as String,
        quietHoursStart: json['quiet_hours_start'] as String?,
        quietHoursEnd: json['quiet_hours_end'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
