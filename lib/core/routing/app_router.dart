import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../auth/presentation/family_setup_screen.dart';
import '../auth/presentation/sign_in_screen.dart';
import '../auth/presentation/splash_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/gps/presentation/gps_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/settings/presentation/family_members_screen.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import 'app_shell.dart';
import 'router_refresh_stream.dart';

/// go_router config with deep-link-ready named routes and a bottom-nav
/// shell (docs/03-architecture.md §5, docs/05-build-sequence.md Module 1).
/// Push-notification deep links (e.g. a reminder → a specific task) resolve
/// through these same route paths once Module 4 (Notifications) lands.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: RouterRefreshStream(authRepository.onAuthStateChange),
    redirect: (context, state) {
      final isSignedIn = authRepository.currentSession != null;
      final goingToAuth = state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/family-setup' ||
          state.matchedLocation == '/splash';

      if (!isSignedIn && !goingToAuth) return '/sign-in';
      if (isSignedIn && state.matchedLocation == '/splash') return '/home';
      if (isSignedIn && state.matchedLocation == '/sign-in') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/family-setup', builder: (context, state) => const FamilySetupScreen()),
      GoRoute(path: '/gps', builder: (context, state) => const GpsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/family', builder: (context, state) => const FamilyMembersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
          ]),
        ],
      ),
    ],
  );
});
