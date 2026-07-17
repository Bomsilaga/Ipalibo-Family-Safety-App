import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// Bottom-nav "More" tab: surfaces GPS, Rewards, Reports, Settings, SOS
/// to avoid an overcrowded tab bar (docs/04-design-system.md "Mobile
/// navigation"). SOS also gets a persistent, faster entry point elsewhere
/// once Module 8 lands — this menu is the baseline reachable path.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final items = <_MoreItem>[
      _MoreItem('Daily Briefing', Icons.wb_sunny_outlined, '/briefing'),
      _MoreItem('Live Location', Icons.map_outlined, '/gps'),
      _MoreItem('Rewards', Icons.emoji_events_outlined, '/rewards'),
      _MoreItem('Reports', Icons.bar_chart_outlined, '/reports'),
      _MoreItem('Unlock Requests', Icons.lock_open_outlined, '/unlock-requests'),
      _MoreItem('Notifications', Icons.notifications_none_outlined, '/notifications'),
      _MoreItem('Family Settings', Icons.settings_outlined, '/family-settings'),
    ];

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: Icon(item.icon, color: colors.emerald700),
                title: Text(item.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: item.route == null ? null : () => context.push(item.route!),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Card(
            color: colors.danger.withValues(alpha: 0.08),
            child: ListTile(
              leading: Icon(Icons.sos_outlined, color: colors.danger),
              title: Text('Emergency SOS', style: TextStyle(color: colors.danger, fontWeight: FontWeight.w600)),
              onTap: () => context.push('/sos'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/sign-in');
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String? route;
}
