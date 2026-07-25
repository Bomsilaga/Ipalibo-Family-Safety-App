import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import '../data/device_repository.dart';
import '../domain/device_model.dart';

/// Device protection (product spec §8 "Parental Controls").
///
/// The honest version of "a child can't uninstall the app". Two halves:
///
///   1. **Set it up where it actually works** — the delete-protection
///      switch lives in iOS Screen Time and Android Family Link, not in
///      any app. This screen walks a parent through it step by step and
///      records that they did.
///   2. **Notice when a device goes quiet** — because no software can
///      truly guarantee (1) holds, every install checks in, and a device
///      that stops is surfaced here. That also covers what blocking never
///      could: phone off, app force-stopped, permissions revoked.
///
/// See docs/06-deviations.md "Uninstall protection" for why the app
/// doesn't attempt OS-level enforcement itself.
class DeviceProtectionScreen extends ConsumerWidget {
  const DeviceProtectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final meAsync = ref.watch(currentAppUserProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final devicesAsync = ref.watch(familyDevicesProvider);
    final protectionsAsync = ref.watch(uninstallProtectionsProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Device protection')),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(icon: Icons.error_outline, message: '$error'),
        data: (me) {
          if (me == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              message: 'Sign in to manage device protection.',
            );
          }
          if (!hasPermission(me, AppAction.manageScreenTime)) {
            return const EmptyState(
              icon: Icons.lock_outline,
              message: 'Only a parent can manage device protection.',
            );
          }
          final members = membersAsync.value ?? const <AppUser>[];
          final devices = devicesAsync.value ?? const <FamilyDevice>[];
          final protections = protectionsAsync.value ?? const <UninstallProtection>[];
          final children = members.where((m) => m.role == UserRole.child).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _HowThisWorksCard(),
              const SizedBox(height: AppSpacing.lg),
              if (children.isEmpty)
                const EmptyState(
                  icon: Icons.child_care_outlined,
                  message: 'No children in the family yet — invite them from the Family tab.',
                )
              else
                for (final child in children)
                  _ChildProtectionCard(
                    parent: me,
                    child: child,
                    devices: devices.where((d) => d.userId == child.id).toList(),
                    protection: protections
                        .where((p) => p.childId == child.id && p.active)
                        .firstOrNull,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _HowThisWorksCard extends StatelessWidget {
  const _HowThisWorksCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Card(
      color: colors.emerald900,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: colors.gold500),
                const SizedBox(width: AppSpacing.sm),
                Text('How this works',
                    style: typography.subtitle.copyWith(color: colors.ivory)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Phones don\'t let an app stop itself being deleted — that switch '
              'belongs to the phone\'s own parental controls. So we do two things: '
              'walk you through turning it on where it actually works, and tell you '
              'if a phone stops checking in.',
              style: typography.small.copyWith(color: colors.ivory.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildProtectionCard extends ConsumerWidget {
  const _ChildProtectionCard({
    required this.parent,
    required this.child,
    required this.devices,
    required this.protection,
  });

  final AppUser parent;
  final AppUser child;
  final List<FamilyDevice> devices;
  final UninstallProtection? protection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final isProtected = protection != null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(user: child),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.displayName, style: typography.subtitle),
                      Text(
                        isProtected
                            ? 'Delete protection set up${protection!.platform != null ? ' · ${_platformLabel(protection!.platform!)}' : ''}'
                            : 'Delete protection not set up',
                        style: typography.small.copyWith(
                          color: isProtected ? colors.success : colors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isProtected ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
                  color: isProtected ? colors.success : colors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Devices', style: typography.caption.copyWith(color: colors.gray[6])),
            const SizedBox(height: AppSpacing.xs),
            if (devices.isEmpty)
              Text(
                'No device has checked in yet. It appears here once ${child.displayName} '
                'opens the app on their phone.',
                style: typography.small.copyWith(color: colors.gray[6]),
              )
            else
              for (final device in devices) _DeviceRow(device: device, child: child),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (isProtected)
                  TextButton(
                    onPressed: () => ref.read(deviceRepositoryProvider).clearProtection(
                          childId: child.id,
                          familyId: parent.familyId!,
                          parentId: parent.id,
                        ),
                    child: const Text('Mark as off'),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _openGuide(context, ref),
                  child: Text(isProtected ? 'Review steps' : 'Set up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _platformLabel(String platform) =>
      platform == 'ios' ? 'iPhone / iPad' : 'Android';

  Future<void> _openGuide(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LockdownGuideSheet(parent: parent, child: child),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.child});

  final FamilyDevice device;
  final AppUser child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final stale = device.isStale;
    final seen = device.lastSyncAt;
    final since = seen == null ? null : DateTime.now().difference(seen);
    final seenLabel = since == null
        ? 'never checked in'
        : since.inMinutes < 2
            ? 'just now'
            : since.inHours < 1
                ? '${since.inMinutes} min ago'
                : since.inDays < 1
                    ? '${since.inHours} h ago'
                    : '${since.inDays} d ago';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            stale ? Icons.phonelink_erase_outlined : Icons.smartphone_outlined,
            size: 18,
            color: stale ? colors.danger : colors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.label, style: typography.body),
                Text(
                  stale
                      // Named as a possibility, not an accusation: a flat
                      // battery and a deleted app look identical from here,
                      // and telling a parent their kid deleted the app when
                      // the phone was just off is worse than saying nothing.
                      ? 'Last seen $seenLabel — the app may have been removed, '
                          'or the phone is off'
                      : 'Checked in $seenLabel',
                  style: typography.caption
                      .copyWith(color: stale ? colors.danger : colors.gray[6]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step-by-step OS lockdown instructions. Written out in full rather than
/// deep-linking into Settings: the deep-link schemes for these panes are
/// undocumented, differ per OS version, and silently no-op when they
/// change — a parent following stale steps that go nowhere is worse than
/// one reading accurate ones.
class _LockdownGuideSheet extends ConsumerStatefulWidget {
  const _LockdownGuideSheet({required this.parent, required this.child});

  final AppUser parent;
  final AppUser child;

  @override
  ConsumerState<_LockdownGuideSheet> createState() => _LockdownGuideSheetState();
}

class _LockdownGuideSheetState extends ConsumerState<_LockdownGuideSheet> {
  String _platform = 'ios';
  bool _saving = false;

  static const _iosSteps = [
    'On your child\'s iPhone or iPad, open Settings → Screen Time.',
    'If it\'s off, tap Turn On Screen Time and choose "This is My Child\'s iPhone".',
    'Set a Screen Time passcode your child doesn\'t know — this is what makes the rest stick.',
    'Go to Content & Privacy Restrictions and turn it on.',
    'Tap iTunes & App Store Purchases → Deleting Apps → Don\'t Allow.',
    'Back in Content & Privacy Restrictions, tap Location Services → lock it so the setting can\'t be changed.',
    'Check it worked: press and hold The Ipalibos on the Home Screen — there should be no Remove App option.',
  ];

  static const _androidSteps = [
    'Install Google Family Link on your own phone and on your child\'s phone.',
    'In Family Link, link your child\'s Google account to yours and finish setup on their device.',
    'On your child\'s phone, open Settings → Apps → The Ipalibos → and note it\'s managed by Family Link.',
    'In Family Link on your phone, open your child\'s device → Apps, find The Ipalibos and set it to Always allowed.',
    'In Family Link, turn on the setting that requires your approval to install or remove apps.',
    'On the child\'s phone, set a screen lock only they and you know, so Settings can\'t be reached by anyone else.',
    'Check it worked: try to uninstall The Ipalibos on their phone — it should ask for a parent approval.',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final steps = _platform == 'ios' ? _iosSteps : _androidSteps;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Stop ${widget.child.displayName} deleting the app',
              style: typography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These steps happen on your child\'s phone, in the phone\'s own settings. '
            'Nothing here is something the app can switch on for you.',
            style: typography.small.copyWith(color: colors.gray[6]),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ios', label: Text('iPhone / iPad')),
              ButtonSegment(value: 'android', label: Text('Android')),
            ],
            selected: {_platform},
            onSelectionChanged: (s) => setState(() => _platform = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: colors.emerald700,
                    child: Text('${i + 1}',
                        style: typography.caption.copyWith(color: colors.white)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(steps[i], style: typography.body)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            color: colors.gray[1],
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _platform == 'ios'
                    ? 'Worth knowing: a child who knows the Screen Time passcode can undo '
                        'this, and erasing the whole phone clears it. That\'s why we also '
                        'tell you when a device stops checking in.'
                    : 'Worth knowing: Family Link can be removed if your child knows your '
                        'Google password, and a factory reset clears it. That\'s why we also '
                        'tell you when a device stops checking in.',
                style: typography.small.copyWith(color: colors.gray[7]),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _saving ? null : _confirm,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('I\'ve done this'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      await ref.read(deviceRepositoryProvider).confirmProtection(
            familyId: widget.parent.familyId!,
            childId: widget.child.id,
            parentId: widget.parent.id,
            platform: _platform,
            method: _platform == 'ios' ? 'screen_time' : 'family_link',
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
