import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';

/// One-tap SOS (product spec §11): grabs the freshest position it can
/// without blocking the alert, then calls the sos-fanout Edge Function,
/// which writes the sos_event and notifies all parents with the
/// quiet-hours-exempt 'emergency' category.
class SosRepository {
  SosRepository(this._client);

  final SupabaseClient _client;

  Future<int> sendSos({String? message}) async {
    double? lat;
    double? lng;
    try {
      // Best-effort, short timeout: an SOS must never hang on GPS.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 5)),
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {
      // Send without coordinates rather than not sending at all.
    }

    final response = await _client.functions.invoke(
      'sos-fanout',
      body: {
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (message != null) 'message': message,
      },
    );
    if (response.status != 200) {
      throw StateError('SOS failed: ${response.data}');
    }
    return (response.data as Map<String, dynamic>)['parents_notified'] as int? ?? 0;
  }
}

final sosRepositoryProvider = Provider<SosRepository>((ref) => SosRepository(supabase));
