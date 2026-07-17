import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';
import 'app_user.dart';
import 'auth_repository.dart';
import 'family.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(supabase);
});

/// Raw Supabase auth state stream (signed in / signed out / token refresh).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// The current `public.users` row for the signed-in auth user, or null if
/// signed out or if they've authenticated but not yet completed family
/// setup (no row yet). This is what the whole app should read to know
/// "who is using the app and what family/role are they" — never read
/// `Supabase.instance.client.auth.currentUser` directly outside core/auth.
final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  // Re-runs whenever auth state changes (sign in/out).
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).fetchCurrentAppUser();
});

final currentFamilyProvider = FutureProvider<Family?>((ref) async {
  final appUser = await ref.watch(currentAppUserProvider.future);
  if (appUser?.familyId == null) return null;
  return ref.watch(authRepositoryProvider).fetchFamily(appUser!.familyId!);
});

/// Everyone in the caller's family (RLS already scopes the query — the
/// filter here is belt-and-braces, not the security boundary).
final familyMembersProvider = FutureProvider<List<AppUser>>((ref) async {
  final appUser = await ref.watch(currentAppUserProvider.future);
  if (appUser?.familyId == null) return const [];
  final rows = await supabase.from('users').select().eq('family_id', appUser!.familyId!);
  return (rows as List).map((r) => AppUser.fromJson(r as Map<String, dynamic>)).toList();
});
