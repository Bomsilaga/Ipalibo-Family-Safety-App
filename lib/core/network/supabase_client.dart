import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project credentials, injected at build time via `--dart-define`
/// (see docs/03-architecture.md §6). Never commit real values here.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

/// Initializes the Supabase client once at app startup.
///
/// Call from `main()` before `runApp`. All feature repositories read the
/// client via [supabase], never by constructing their own.
Future<void> initSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase is not configured. Run with '
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
}

/// The shared Supabase client. Every feature repository calls this instead
/// of holding its own reference or constructing a new `SupabaseClient`.
SupabaseClient get supabase => Supabase.instance.client;
