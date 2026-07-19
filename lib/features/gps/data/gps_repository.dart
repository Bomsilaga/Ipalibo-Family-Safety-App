import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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

  /// Turns a lat/lng into a human-readable place ("14 Smith St, Fitzroy")
  /// via OpenStreetMap's free Nominatim endpoint — no API key needed,
  /// unlike the full map tile (docs/06-deviations.md: that needs a Google
  /// Maps key a human must register per platform). Falls back to null
  /// (caller shows raw coordinates) on any network/parse failure.
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '18',
        },
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'IpalibosFamilyApp/1.0 (family safety app)'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>?;
      if (address == null) return body['display_name'] as String?;
      final parts = [
        (address['house_number'] as String?),
        (address['road'] as String?),
        (address['suburb'] ?? address['neighbourhood'] ?? address['city_district']) as String?,
        (address['city'] ?? address['town'] ?? address['village']) as String?,
      ].whereType<String>().toList();
      return parts.isNotEmpty ? parts.join(', ') : body['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final gpsRepositoryProvider = Provider<GpsRepository>((ref) => GpsRepository(supabase));

final latestLocationsProvider = FutureProvider<Map<String, MemberLocation>>((ref) async {
  return ref.watch(gpsRepositoryProvider).latestPerMember();
});

final safeZonesProvider = FutureProvider<List<SafeZone>>((ref) async {
  return ref.watch(gpsRepositoryProvider).safeZones();
});

/// Cached per rounded coordinate (~11m precision) so repeated check-ins
/// near the same spot don't re-hit the geocoder.
final placeNameProvider = FutureProvider.family<String?, (double, double)>((ref, coords) async {
  return ref.watch(gpsRepositoryProvider).reverseGeocode(coords.$1, coords.$2);
});
