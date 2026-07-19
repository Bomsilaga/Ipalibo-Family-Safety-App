import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';
import 'app_user.dart';
import 'family.dart';
import 'user_role.dart';

/// Random-ish hex string for avatar colour defaults and other client-side
/// needs that don't require cryptographic randomness.
String _randomHex(int length) {
  const chars = '0123456789abcdef';
  final now = DateTime.now().microsecondsSinceEpoch;
  final buf = StringBuffer();
  var seed = now;
  for (var i = 0; i < length; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    buf.write(chars[seed % chars.length]);
  }
  return buf.toString();
}

/// Everything docs/01-product-spec.md §4 (Authentication & Family Setup)
/// needs: sign-in/sign-up, family creation, child-account creation, sign-out.
///
/// Feature repositories and Riverpod providers call this instead of talking
/// to [supabase] directly for anything auth-shaped.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sends a password-reset email via Supabase's built-in flow. The link
  /// lands the user back in the app (see docs/06-deviations.md for the
  /// redirect target once a dedicated reset-password screen exists).
  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<bool> signInWithApple() {
    return _client.auth.signInWithOAuth(OAuthProvider.apple);
  }

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Registration flow step 2: "create family (name, avatar) or accept an
  /// invite → set role". This covers the "create family" branch — the
  /// caller becomes the family's founding Parent. Must be called
  /// immediately after a successful sign-up, while the caller still has no
  /// `public.users` row (see the "founder bootstrap" RLS policy).
  Future<AppUser> createFamilyAndBecomeParent({
    required String familyName,
    required String displayName,
    String? avatarColor,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('createFamilyAndBecomeParent requires a signed-in user');
    }

    final familyRow = await _client
        .from('families')
        .insert({'name': familyName})
        .select()
        .single();
    final family = Family.fromJson(familyRow);

    final userRow = await _client
        .from('users')
        .insert({
          'id': authUser.id,
          'family_id': family.id,
          'role': 'parent',
          'display_name': displayName,
          'avatar_color': avatarColor ?? '#${_randomHex(6)}',
        })
        .select()
        .single();

    return AppUser.fromJson(userRow);
  }

  /// "Child creation: only a Parent can create a child account — children
  /// do not self-register." A child still needs an `auth.users` identity
  /// (public.users.id references it), which requires the service role, so
  /// this delegates to the `create-child-account` Edge Function rather than
  /// inserting directly — see supabase/functions/create-child-account.
  Future<AppUser> createChildAccount({
    required String displayName,
    String? avatarColor,
    int? birthYear,
    String? pin,
  }) async {
    final response = await _client.functions.invoke(
      'create-child-account',
      body: {
        'display_name': displayName,
        if (avatarColor != null) 'avatar_color': avatarColor,
        if (birthYear != null) 'birth_year': birthYear,
        if (pin != null) 'pin': pin,
      },
    );

    if (response.status != 200) {
      throw StateError('create-child-account failed: ${response.data}');
    }
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AppUser?> fetchCurrentAppUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    final row = await _client
        .from('users')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();
    if (row == null) return null;
    return AppUser.fromJson(row);
  }

  Future<Family?> fetchFamily(String familyId) async {
    final row = await _client
        .from('families')
        .select()
        .eq('id', familyId)
        .maybeSingle();
    if (row == null) return null;
    return Family.fromJson(row);
  }

  /// "existing Parent can promote another adult member to Parent or demote
  /// a co-parent" — the RLS trigger `enforce_users_guardrails` blocks this
  /// if it would leave the family with zero parents.
  Future<void> setRole({required String userId, required UserRole role}) async {
    await _client.from('users').update({'role': role.toStringValue()}).eq('id', userId);
  }
}
