import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/data/calls_repository.dart';
import '../../features/chat/domain/call_model.dart';
import '../../features/chat/presentation/call_screen.dart';
import '../auth/app_user.dart';
import '../auth/auth_providers.dart';
import '../theme/app_theme.dart';

const _tabPaths = ['/home', '/calendar', '/tasks', '/chat', '/family', '/more'];

/// Bottom tab bar shell: Home · Calendar · Tasks · Chat · Family · More
/// (docs/04-design-system.md "Mobile navigation"). Also owns the
/// family-wide incoming-call banner — calls are family-scoped, not
/// chat-scoped, so this listens regardless of which tab is open.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      body: Column(
        children: [
          if (me?.familyId != null) _IncomingCallListener(familyId: me!.familyId!, me: me),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// Every screen reachable from the More menu (Live Location, Rewards,
/// Reports, Unlock Requests, Notifications, Daily Briefing, Family
/// Settings, Security, Switch Profile, SOS) and task detail sit outside
/// the StatefulShellRoute — they're one-off destinations, not tabs with
/// their own persistent nav stack. Without this wrapper they rendered
/// full-screen with no way back to another tab except the OS back
/// button/gesture. Wraps them in the same bottom nav bar, with taps
/// switching straight to that tab (deliberately exits the current
/// stack, same as tapping a tab from anywhere else in the app).
class SecondaryScreenShell extends ConsumerWidget {
  const SecondaryScreenShell({super.key, required this.child, this.highlightedTabIndex = 5});

  final Widget child;
  final int highlightedTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      body: Column(
        children: [
          if (me?.familyId != null) _IncomingCallListener(familyId: me!.familyId!, me: me),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: highlightedTabIndex,
        onTap: (index) => context.go(_tabPaths[index]),
      ),
    );
  }
}

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Long-press anywhere on the tab bar = fast SOS entry, reachable in
    // one motion from any tab (docs/04-design-system.md "Mobile
    // navigation").
    return GestureDetector(
      onLongPress: () => GoRouter.of(context).push('/sos'),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            activeIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom_outlined),
            activeIcon: Icon(Icons.family_restroom),
            label: 'Family',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
        selectedItemColor: colors.emerald900,
        unselectedItemColor: colors.gray[5],
      ),
    );
  }
}

class _IncomingCallListener extends ConsumerWidget {
  const _IncomingCallListener({required this.familyId, required this.me});

  final String familyId;
  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider);
    final dismissed = ref.watch(dismissedCallsProvider);
    return StreamBuilder<List<CallModel>>(
      stream: ref.watch(callsRepositoryProvider).callsStream(familyId),
      builder: (context, snapshot) {
        final calls = snapshot.data ?? const <CallModel>[];
        // isJoinable (ringing OR active) rather than just ringing: a
        // group call already in progress should still be joinable by
        // family members who weren't there when it started, same as
        // WhatsApp group calls.
        final joinable = calls
            .where((c) => c.isJoinable && c.createdBy != me.id && !dismissed.contains(c.id))
            .toList();
        if (joinable.isEmpty) return const SizedBox();
        final call = joinable.first;
        final members = membersAsync.value ?? const <AppUser>[];
        final callerMatches = members.where((m) => m.id == call.createdBy);
        final callerName = callerMatches.isNotEmpty ? callerMatches.first.displayName : 'Someone';
        return IncomingCallBanner(
          callId: call.id,
          roomUrl: call.roomUrl,
          callerName: callerName,
          isVideo: call.isVideo,
          isActive: call.isActive,
        );
      },
    );
  }
}
