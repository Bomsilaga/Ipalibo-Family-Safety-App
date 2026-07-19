import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/call_model.dart';

/// Voice/video calls (Daily.co). The API key never reaches the client —
/// start-call/end-call create/tear down rooms server-side; this repository
/// only talks to those functions and reads the family-scoped `calls` table
/// that signals "someone is calling" to every device via Realtime.
class CallsRepository {
  CallsRepository(this._client);

  final SupabaseClient _client;

  Future<CallModel> startCall({required String chatId, String type = 'video'}) async {
    final response = await _client.functions.invoke(
      'start-call',
      body: {'chat_id': chatId, 'type': type},
    );
    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] != null ? '${data['error']}' : 'Could not start call (${response.status}).';
      throw StateError(message);
    }
    return CallModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> endCall(String callId) async {
    await _client.functions.invoke('end-call', body: {'call_id': callId});
  }

  /// Live view of every call for the family — the app filters this down
  /// to "is there a ringing call I didn't start" for the incoming-call
  /// banner.
  Stream<List<CallModel>> callsStream(String familyId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(CallModel.fromJson).toList());
  }
}

final callsRepositoryProvider = Provider<CallsRepository>((ref) => CallsRepository(supabase));
