import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/unlock_request_model.dart';

/// Unlock lifecycle client (product spec §8). Code generation/validation
/// live exclusively in the unlock-code Edge Function — this repository
/// only creates requests, lists them, and forwards generate/redeem calls.
class UnlockRepository {
  UnlockRepository(this._client);

  final SupabaseClient _client;

  Future<List<UnlockRequest>> requests() async {
    final rows = await _client
        .from('unlock_requests')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((r) => UnlockRequest.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Child taps "Request Unlock" → selects a reason (product spec §8).
  Future<UnlockRequest> requestUnlock({
    required String familyId,
    required String childId,
    required String reason,
  }) async {
    final row = await _client
        .from('unlock_requests')
        .insert({'family_id': familyId, 'child_id': childId, 'reason': reason})
        .select()
        .single();
    return UnlockRequest.fromJson(row);
  }

  /// Parent approves: Edge Function generates the one-time code and
  /// returns it exactly once for the parent to hand over.
  Future<({String code, DateTime expiresAt})> generateCode(String requestId) async {
    final response = await _client.functions.invoke(
      'unlock-code',
      body: {'action': 'generate', 'request_id': requestId},
    );
    if (response.status != 200) {
      throw StateError('generate failed: ${response.data}');
    }
    final data = response.data as Map<String, dynamic>;
    return (
      code: data['code'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String).toLocal(),
    );
  }

  /// Child redeems the code they were given.
  Future<bool> redeemCode({required String requestId, required String code}) async {
    final response = await _client.functions.invoke(
      'unlock-code',
      body: {'action': 'redeem', 'request_id': requestId, 'code': code},
    );
    if (response.status == 200) return true;
    final data = response.data;
    throw StateError(data is Map ? (data['error'] as String? ?? 'invalid code') : 'invalid code');
  }

  /// Parent declines; also server-side, because unlock_requests has no
  /// client update policy at all (tamper-proofing).
  Future<void> reject(String requestId) async {
    final response = await _client.functions.invoke(
      'unlock-code',
      body: {'action': 'reject', 'request_id': requestId},
    );
    if (response.status != 200) {
      throw StateError('reject failed: ${response.data}');
    }
  }
}

final unlockRepositoryProvider = Provider<UnlockRepository>((ref) {
  return UnlockRepository(supabase);
});

final unlockRequestsProvider = FutureProvider<List<UnlockRequest>>((ref) async {
  return ref.watch(unlockRepositoryProvider).requests();
});
