import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/notifications_repository.dart';

final _inboxProvider = FutureProvider<List<AppNotification>>((ref) async {
  final me = await ref.watch(currentAppUserProvider.future);
  if (me == null) return const [];
  return ref.watch(notificationsRepositoryProvider).inbox(me.id);
});

/// Persistent notification inbox — everything ever sent, independent of
/// whether the OS notification was dismissed (product spec §7).
class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  static const _categoryIcons = {
    'appointment': Icons.calendar_today_outlined,
    'chore': Icons.cleaning_services_outlined,
    'homework': Icons.menu_book_outlined,
    'reading': Icons.auto_stories_outlined,
    'unlock_request': Icons.lock_open_outlined,
    'gps_alert': Icons.location_on_outlined,
    'chat': Icons.chat_bubble_outline,
    'announcement': Icons.campaign_outlined,
    'emergency': Icons.sos_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final inboxAsync = ref.watch(_inboxProvider);
    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Notifications')),
      body: inboxAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_outlined,
              message: 'Nothing here yet — reminders and alerts will collect here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              final isEmergency = n.category == 'emergency';
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                color: isEmergency ? colors.danger.withValues(alpha: 0.08) : null,
                child: ListTile(
                  leading: Icon(
                    _categoryIcons[n.category] ?? Icons.notifications_outlined,
                    color: isEmergency ? colors.danger : colors.emerald700,
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isUnread ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: n.isUnread
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: colors.emerald500),
                        )
                      : null,
                  onTap: () async {
                    await ref.read(notificationsRepositoryProvider).markRead(n.id);
                    ref.invalidate(_inboxProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(icon: Icons.error_outline, message: 'Could not load inbox: $error'),
      ),
    );
  }
}
