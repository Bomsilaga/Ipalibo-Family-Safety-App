/// Mirrors `public.locations` (docs/02-data-model.md "GPS Safety").
class MemberLocation {
  const MemberLocation({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.batteryPct,
    required this.recordedAt,
  });

  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final int? batteryPct;
  final DateTime recordedAt;

  factory MemberLocation.fromJson(Map<String, dynamic> json) => MemberLocation(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        batteryPct: json['battery_pct'] as int?,
        recordedAt: DateTime.parse(json['recorded_at'] as String).toLocal(),
      );
}

/// Mirrors `public.safe_zones`.
class SafeZone {
  const SafeZone({
    required this.id,
    required this.familyId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  final String id;
  final String familyId;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusM;

  factory SafeZone.fromJson(Map<String, dynamic> json) => SafeZone(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusM: json['radius_m'] as int,
      );
}
