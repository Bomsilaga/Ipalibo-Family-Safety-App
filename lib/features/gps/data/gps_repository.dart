import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/location_models.dart';

/// GPS data access (product spec §10). Foreground check-in only for now:
/// battery-conscious background tracking (significant-location-change /
/// geofencing APIs) needs platform entitlements a human must configure —
/// see docs/06-deviations.md.
class GpsRepository {
  GpsRepository(this._client);

  final SupabaseClient _client;

  /// Latest position per family member (RLS: children see only their own
  /// row come back; parents see everyone).
  Future<Map<String, MemberLocation>> latestPerMember() async {
    final rows = await _client
        .from('locations')
        .select()
        .order('recorded_at', ascending: false)
        .limit(200);
    final latest = <String, MemberLocation>{};
    for (final r in rows as List) {
      final loc = MemberLocation.fromJson(r as Map<String, dynamic>);
      latest.putIfAbsent(loc.userId, () => loc);
    }
    return latest;
  }

  /// One-tap "check in now": reads the device position (with permission
  /// prompts) and reports it as the caller's own location.
  Future<MemberLocation> checkIn({required String familyId, required String userId}) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required to check in.');
    }
    final position = await Geolocator.getCurrentPosition();
    final row = await _client
        .from('locations')
        .insert({
          'family_id': familyId,
          'user_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy_m': position.accuracy,
        })
        .select()
        .single();
    return MemberLocation.fromJson(row);
  }

  Future<List<SafeZone>> safeZones() async {
    final rows = await _client.from('safe_zones').select().order('created_at');
    return (rows as List).map((r) => SafeZone.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<SafeZone> createSafeZone({
    required String familyId,
    required String createdBy,
    required String name,
    required double latitude,
    required double longitude,
    int radiusM = 150,
  }) async {
    final row = await _client
        .from('safe_zones')
        .insert({
          'family_id': familyId,
          'created_by': createdBy,
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'radius_m': radiusM,
        })
        .select()
        .single();
    return SafeZone.fromJson(row);
  }

  Future<void> deleteSafeZone(String id) async {
    await _client.from('safe_zones').delete().eq('id', id);
  }
}

final gpsRepositoryProvider = Provider<GpsRepository>((ref) => GpsRepository(supabase));

final latestLocationsProvider = FutureProvider<Map<String, MemberLocation>>((ref) async {
  return ref.watch(gpsRepositoryProvider).latestPerMember();
});

final safeZonesProvider = FutureProvider<List<SafeZone>>((ref) async {
  return ref.watch(gpsRepositoryProvider).safeZones();
});
