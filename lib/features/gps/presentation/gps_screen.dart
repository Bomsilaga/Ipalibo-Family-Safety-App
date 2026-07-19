import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import '../data/gps_repository.dart';
import '../domain/location_models.dart';

/// Live Location per the mockup: a map tile with member/safe-zone markers,
/// plus member cards with last-updated, battery, and place name below, and
/// Places (safe zones) management for parents.
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
            return Column(
              children: [
                _FamilyMap(members: members, locations: locations),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      for (final member in members)
                        if (locations.containsKey(member.id))
                          _MemberTile(member: member, location: locations[member.id]!),
                    ],
                  ),
                ),
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

class _FamilyMap extends StatelessWidget {
  const _FamilyMap({required this.members, required this.locations});

  final List<AppUser> members;
  final Map<String, MemberLocation> locations;

  @override
  Widget build(BuildContext context) {
    final points = locations.values.toList();
    final centerLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(centerLat, centerLng), zoom: 12),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              for (final member in members)
                if (locations.containsKey(member.id))
                  Marker(
                    markerId: MarkerId(member.id),
                    position: LatLng(
                      locations[member.id]!.latitude,
                      locations[member.id]!.longitude,
                    ),
                    infoWindow: InfoWindow(title: member.displayName),
                  ),
            },
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.location});

  final AppUser member;
  final dynamic location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final age = DateTime.now().difference(location.recordedAt as DateTime);
    final freshness = age.inMinutes < 1
        ? 'just now'
        : age.inHours < 1
            ? '${age.inMinutes} min ago'
            : '${age.inHours} h ago';
    final lat = location.latitude as double;
    final lng = location.longitude as double;
    final coords = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    final roundedKey = (
      double.parse(lat.toStringAsFixed(4)),
      double.parse(lng.toStringAsFixed(4)),
    );
    final placeAsync = ref.watch(placeNameProvider(roundedKey));
    final place = placeAsync.value;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: MemberAvatar(user: member),
        title: Text(member.displayName),
        subtitle: Text(
          '${place ?? coords} · $freshness',
          style: place != null ? typography.small : typography.mono,
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
          return Column(
            children: [
              _SafeZonesMap(zones: zones),
              Expanded(
                child: ListView(
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

class _SafeZonesMap extends StatelessWidget {
  const _SafeZonesMap({required this.zones});

  final List<SafeZone> zones;

  @override
  Widget build(BuildContext context) {
    final centerLat = zones.map((z) => z.latitude).reduce((a, b) => a + b) / zones.length;
    final centerLng = zones.map((z) => z.longitude).reduce((a, b) => a + b) / zones.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(centerLat, centerLng), zoom: 12),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              for (final z in zones)
                Marker(
                  markerId: MarkerId(z.id),
                  position: LatLng(z.latitude, z.longitude),
                  infoWindow: InfoWindow(title: z.name),
                ),
            },
            circles: {
              for (final z in zones)
                Circle(
                  circleId: CircleId(z.id),
                  center: LatLng(z.latitude, z.longitude),
                  radius: z.radiusM.toDouble(),
                  fillColor: context.appColors.emerald500.withValues(alpha: 0.15),
                  strokeColor: context.appColors.emerald700,
                  strokeWidth: 1,
                ),
            },
          ),
        ),
      ),
    );
  }
}
