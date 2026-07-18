import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Bottom tab bar shell: Home · Calendar · Tasks · Chat · Family · More
/// (docs/04-design-system.md "Mobile navigation").
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: navigationShell,
      // Long-press anywhere on the tab bar = fast SOS entry, reachable in
      // one motion from any tab (docs/04-design-system.md "Mobile
      // navigation").
      bottomNavigationBar: GestureDetector(
        onLongPress: () => GoRouter.of(context).push('/sos'),
        child: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            activeIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom_outlined),
            activeIcon: Icon(Icons.family_restroom),
            label: 'Family',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
          selectedItemColor: colors.emerald900,
          unselectedItemColor: colors.gray[5],
        ),
      ),
    );
  }
}
