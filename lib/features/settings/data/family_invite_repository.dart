import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';

/// "Registration flow ... create family (name, avatar) or accept an invite"
/// (docs/01-product-spec.md §4). Invites never let a client insert
/// themselves into an existing family directly — RLS only allows the
/// *first* member of a family to insert their own `users` row
/// (docs/06-deviations.md "founder bootstrap"). Instead a parent creates a
/// `family_invites` row (this repository), shares the plaintext code
/// out-of-band, and the invitee redeems it through the `accept-invite`
/// Edge Function, which validates the code against `token_hash` server-side.
class FamilyInviteRepository {
  FamilyInviteRepository(this._client);

  final SupabaseClient _client;

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

  String _generateCode() {
    final rand = Random.secure();
    return List.generate(8, (_) => _codeChars[rand.nextInt(_codeChars.length)]).join();
  }

  /// Creates a pending invite and returns the plaintext code to share —
  /// only `sha256(code)` is ever stored, so this is the only chance to
  /// see it.
  Future<String> createInvite({
    required String familyId,
    required String invitedBy,
    required String role,
    String? email,
  }) async {
    final code = _generateCode();
    final tokenHash = sha256.convert(utf8.encode(code)).toString();
    await _client.from('family_invites').insert({
      'family_id': familyId,
      'invited_by': invitedBy,
      'role': role,
      'token_hash': tokenHash,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return code;
  }

  /// Redeems an invite code for the signed-in (but not-yet-onboarded)
  /// caller, via the service-role `accept-invite` function.
  Future<void> acceptInvite({
    required String code,
    required String displayName,
    String? avatarColor,
  }) async {
    final response = await _client.functions.invoke('accept-invite', body: {
      'token': code.trim(),
      'display_name': displayName,
      if (avatarColor != null) 'avatar_color': avatarColor,
    });
    if (response.status != 200) {
      final data = response.data;
      final message =
          data is Map && data['error'] != null ? '${data['error']}' : 'Invite code not accepted (${response.status}).';
      throw StateError(message);
    }
  }
}

final familyInviteRepositoryProvider = Provider<FamilyInviteRepository>((ref) {
  return FamilyInviteRepository(supabase);
});
