import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'supabase_client.dart';

/// Which social sign-in providers are actually turned on for this Supabase
/// project. GoTrue's `/auth/v1/settings` endpoint is public-by-design (it's
/// how every client app knows which login buttons to show) and needs only
/// the publishable key.
///
/// The Apple/Google OAuth buttons on the sign-in screen must gate on this:
/// on web, `signInWithOAuth` does a full top-level browser redirect straight
/// to Supabase before any Dart code runs, so a disabled provider surfaces
/// as Supabase's raw JSON error page — there is no client-side exception to
/// catch. Hiding the button when the provider is off is the only fix.
Future<Set<String>> fetchEnabledOAuthProviders() async {
  final uri = Uri.parse('${SupabaseConfig.url}/auth/v1/settings');
  final response = await http.get(uri, headers: {'apikey': SupabaseConfig.anonKey});
  if (response.statusCode != 200) return const {};
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final external = body['external'] as Map<String, dynamic>? ?? {};
  return external.entries.where((e) => e.value == true).map((e) => e.key).toSet();
}

final enabledOAuthProvidersProvider = FutureProvider<Set<String>>((ref) {
  return fetchEnabledOAuthProviders();
});
