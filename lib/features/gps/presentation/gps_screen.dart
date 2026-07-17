import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import '../data/gps_repository.dart';

/// Live Location per the mockup: member cards with last-updated, battery,
/// and coordinates, plus Places (safe zones) management for parents.
///
/// The full-bleed map tile requires a Google Maps API key registered per
/// platform by a human (docs/03-architecture.md §6); until that's
/// configured this screen presents the same data list-first, and the map
/// drop-in point is `_MemberTile.onTap`. See docs/06-deviations.md.
class GpsScreen extends ConsumerWidget {
  const GpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.ivory,
        appBar: AppBar(
          title: const Text('Live Location'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            tabs: [Tab(text: 'Family'), Tab(text: 'Places')],
          ),
        ),
        body: const TabBarView(children: [_FamilyTab(), _PlacesTab()]),
      ),
    );
  }
}

class _FamilyTab extends ConsumerWidget {
  const _FamilyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(latestLocationsProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final meAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      backgroundColor: context.appColors.ivory,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.appColors.gold500,
        foregroundColor: context.appColors.emerald900,
        icon: const Icon(Icons.my_location),
        label: const Text('Check in'),
        onPressed: () async {
          final me = meAsync.value;
          if (me?.familyId == null) return;
          try {
            await ref
                .read(gpsRepositoryProvider)
                .checkIn(familyId: me!.familyId!, userId: me.id);
            ref.invalidate(latestLocationsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Location shared with your family.')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
      ),
      body: membersAsync.when(
        data: (members) => locationsAsync.when(
          data: (locations) {
            if (locations.isEmpty) {
              return const EmptyState(
                icon: Icons.location_searching,
                message: 'No locations yet — tap "Check in" to share yours.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final member in members)
                  if (locations.containsKey(member.id))
                    _MemberTile(member: member, location: locations[member.id]!),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              EmptyState(icon: Icons.error_outline, message: 'Could not load locations: $error'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(icon: Icons.error_outline, message: '$error'),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.location});

  final AppUser member;
  final dynamic location;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final age = DateTime.now().difference(location.recordedAt as DateTime);
    final freshness = age.inMinutes < 1
        ? 'just now'
        : age.inHours < 1
            ? '${age.inMinutes} min ago'
            : '${age.inHours} h ago';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: MemberAvatar(user: member),
        title: Text(member.displayName),
        subtitle: Text(
          '${(location.latitude as double).toStringAsFixed(5)}, '
          '${(location.longitude as double).toStringAsFixed(5)} · $freshness',
          style: typography.mono,
        ),
        trailing: location.batteryPct != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.battery_std,
                    size: 16,
                    color: (location.batteryPct as int) < 20 ? colors.danger : colors.success,
                  ),
                  Text('${location.batteryPct}%', style: typography.caption),
                ],
              )
            : null,
      ),
    );
  }
}

class _PlacesTab extends ConsumerWidget {
  const _PlacesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(safeZonesProvider);
    final meAsync = ref.watch(currentAppUserProvider);
    final colors = context.appColors;
    final isParent = meAsync.value != null &&
        hasPermission(meAsync.value!, AppAction.disableGpsSharing);

    return Scaffold(
      backgroundColor: colors.ivory,
      floatingActionButton: isParent
          ? FloatingActionButton(
              backgroundColor: colors.gold500,
              foregroundColor: colors.emerald900,
              child: const Icon(Icons.add_location_alt_outlined),
              onPressed: () => _addZone(context, ref),
            )
          : null,
      body: zonesAsync.when(
        data: (zones) {
          if (zones.isEmpty) {
            return const EmptyState(
              icon: Icons.home_work_outlined,
              message: 'No safe zones yet — add Home, School, or Grandparents\'.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final z in zones)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Icon(Icons.place_outlined, color: colors.emerald700),
                    title: Text(z.name),
                    subtitle: Text(
                      '${z.latitude.toStringAsFixed(5)}, ${z.longitude.toStringAsFixed(5)} · ${z.radiusM} m',
                      style: context.appTypography.mono,
                    ),
                    trailing: isParent
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref.read(gpsRepositoryProvider).deleteSafeZone(z.id);
                              ref.invalidate(safeZonesProvider);
                            },
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(icon: Icons.error_outline, message: 'Could not load places: $error'),
      ),
    );
  }

  Future<void> _addZone(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New safe zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Name (e.g. Home)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('The zone is centred on your current position.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;
    final me = await ref.read(currentAppUserProvider.future);
    if (me?.familyId == null) return;
    try {
      // Centre on the parent's current position (they're usually standing
      // at "Home"/"School" when creating it); manual pin drop comes with
      // the map view.
      final loc = await ref
          .read(gpsRepositoryProvider)
          .checkIn(familyId: me!.familyId!, userId: me.id);
      await ref.read(gpsRepositoryProvider).createSafeZone(
            familyId: me.familyId!,
            createdBy: me.id,
            name: nameController.text.trim(),
            latitude: loc.latitude,
            longitude: loc.longitude,
          );
      ref.invalidate(safeZonesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
