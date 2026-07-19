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

  /// WhatsApp-style group calls: one live room per chat. If someone in the
  /// family already started a call here that's still ringing or active,
  /// everyone who taps the call button joins THAT room instead of each
  /// spinning up their own disconnected one (that was the "only one
  /// caller's call ever connects" bug — every tap created a brand new
  /// Daily room).
  Future<CallModel> startCall({required String chatId, String type = 'video'}) async {
    final existing = await _client
        .from('calls')
        .select()
        .eq('chat_id', chatId)
        .inFilter('status', ['ringing', 'active'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      return CallModel.fromJson(existing);
    }

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

  /// Called the moment a device actually opens the call screen. Nothing
  /// else ever moves a call out of 'ringing', so without this the
  /// "X is calling…" banner (and the caller's own screen) would say
  /// "calling" forever even after someone picks up.
  Future<void> markActive(String callId) async {
    await _client.from('calls').update({'status': 'active'}).eq('id', callId).eq('status', 'ringing');
  }

  /// Ends the call for everyone — tears down the Daily room and marks the
  /// row 'ended', which every open CallScreen is watching for (see
  /// [watchCall]) so their screens close themselves rather than sitting on
  /// a dead room.
  Future<void> endCall(String callId) async {
    await _client.functions.invoke('end-call', body: {'call_id': callId});
  }

  /// Live view of every call for the family — the app filters this down
  /// to "is there a call I can join that I didn't start" for the incoming
  /// -call banner.
  Stream<List<CallModel>> callsStream(String familyId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(CallModel.fromJson).toList());
  }

  /// Single-call live view, so an open CallScreen notices when someone
  /// else ends the call and can close itself.
  Stream<CallModel?> watchCall(String callId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((rows) => rows.isEmpty ? null : CallModel.fromJson(rows.first));
  }
}

final callsRepositoryProvider = Provider<CallsRepository>((ref) => CallsRepository(supabase));

/// Calls a person has declined on *this device*. A decline only silences
/// the banner for them — it must not end the call for the caller or for
/// anyone else who wants to join, so it's tracked client-side rather than
/// by mutating the shared `calls` row.
class DismissedCalls extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void dismiss(String callId) => state = {...state, callId};
}

final dismissedCallsProvider = NotifierProvider<DismissedCalls, Set<String>>(DismissedCalls.new);
