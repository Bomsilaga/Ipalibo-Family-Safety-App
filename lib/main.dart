import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/app_lock_service.dart';
import 'core/network/supabase_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ProviderScope(child: IpalibosApp()));
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
