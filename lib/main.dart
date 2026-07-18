import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/app_lock_service.dart';
import 'core/network/supabase_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backendReady = await initSupabase();
  if (!backendReady) {
    runApp(const BackendNotConfiguredApp());
    return;
  }
  runApp(const ProviderScope(child: IpalibosApp()));
}

/// Shown when the build carries no Supabase credentials (preview deploys):
/// brand splash + setup note instead of a crash on load.
class BackendNotConfiguredApp extends StatelessWidget {
  const BackendNotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Ipalibos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          final colors = context.appColors;
          return Scaffold(
            backgroundColor: colors.emerald900,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_moon_outlined, color: colors.gold500, size: 72),
                    const SizedBox(height: 16),
                    Text('The Ipalibos',
                        style: context.appTypography.headline.copyWith(color: colors.ivory)),
                    const SizedBox(height: 8),
                    Text(
                      'Your Family. Organised. Safe. Connected.',
                      textAlign: TextAlign.center,
                      style: context.appTypography.body
                          .copyWith(color: colors.ivory.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Preview build — the family backend isn\'t connected yet.\n'
                      'Rebuild with SUPABASE_URL and SUPABASE_ANON_KEY to go live.',
                      textAlign: TextAlign.center,
                      style: context.appTypography.small
                          .copyWith(color: colors.ivory.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class IpalibosApp extends ConsumerStatefulWidget {
  const IpalibosApp({super.key});

  @override
  ConsumerState<IpalibosApp> createState() => _IpalibosAppState();
}

class _IpalibosAppState extends ConsumerState<IpalibosApp> {
  @override
  void initState() {
    super.initState();
    // Engage the PIN/biometric gate at cold start if one is configured.
    Future.microtask(
        () => ref.read(appLockStateProvider.notifier).lockIfConfigured());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'The Ipalibos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
