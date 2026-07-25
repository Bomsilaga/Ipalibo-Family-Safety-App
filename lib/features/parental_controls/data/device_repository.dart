import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/device_model.dart';

/// Device registration and heartbeat.
///
/// The product ask was "a child shouldn't be able to uninstall the app".
/// No app can enforce that on iOS, and enforcing it on Android needs
/// device-owner provisioning that a consumer family app shouldn't require
/// (docs/06-deviations.md). What this does instead is make removal
/// *visible*: every install checks in, and a parent sees when one stops.
/// That also catches the cases blocking never could — phone switched off,
/// permissions revoked, app force-stopped, phone left at a friend's.
class DeviceRepository {
  DeviceRepository(this._client, this._storage);

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

  static const _installIdKey = 'ipalibos_install_id';

  /// A stable id for this install, minted once and kept in secure
  /// storage. Deliberately not a hardware identifier: those are
  /// restricted on both stores and are exactly the kind of data
  /// minimisation problem CLAUDE.md flags for child accounts. A random
  /// id per install tells us "same app on the same phone" and nothing
  /// more — and it resets on reinstall, which is the signal we want
  /// anyway.
  Future<String> installId() async {
    final existing = await _storage.read(key: _installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _installIdKey, value: id);
    return id;
  }

  String get _os {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'web',
    };
  }

  /// Best-effort friendly name ("Ada's iPhone", "Pixel 7"). Never fatal —
  /// a device with no name still needs to check in.
  Future<String?> _deviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await info.webBrowserInfo;
        return web.browserName.name;
      }
      return switch (defaultTargetPlatform) {
        TargetPlatform.iOS => (await info.iosInfo).name,
        TargetPlatform.android => (await info.androidInfo).model,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  Future<String?> _appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return null;
    }
  }

  /// Records "this install is alive, now". Called on sign-in and every
  /// time the app comes back to the foreground.
  ///
  /// Failures are swallowed on purpose: a heartbeat that throws would
  /// surface as an error banner on an unrelated screen, and a missed beat
  /// is self-correcting — the next resume writes a fresh timestamp.
  Future<void> heartbeat({required String userId, required String familyId}) async {
    try {
      await _client.from('devices').upsert({
        'user_id': userId,
        'family_id': familyId,
        'install_id': await installId(),
        'os': _os,
        'app_version': await _appVersion(),
        'device_name': await _deviceName(),
        'last_sync_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,install_id');
    } catch (_) {
      // Intentionally silent — see above.
    }
  }

  /// Every device in the family, live (RLS: a child sees only their own,
  /// a parent sees all).
  Stream<List<FamilyDevice>> familyDevices(String familyId) {
    return _client
        .from('devices')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .map((rows) => rows.map(FamilyDevice.fromJson).toList());
  }

  Stream<List<UninstallProtection>> protections(String familyId) {
    return _client
        .from('device_restrictions')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .map((rows) => rows
            .where((r) => r['restriction_type'] == UninstallProtection.restrictionType)
            .map(UninstallProtection.fromJson)
            .toList());
  }

  /// Parent confirms they've completed the OS-level lockdown on a child's
  /// device. Stored as an attestation — the app cannot verify it, and
  /// shouldn't pretend to.
  Future<void> confirmProtection({
    required String familyId,
    required String childId,
    required String parentId,
    required String platform,
    required String method,
  }) async {
    final existing = await _client
        .from('device_restrictions')
        .select('id')
        .eq('child_id', childId)
        .eq('restriction_type', UninstallProtection.restrictionType)
        .maybeSingle();
    final config = {
      'platform': platform,
      'method': method,
      'confirmed_by': parentId,
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (existing == null) {
      await _client.from('device_restrictions').insert({
        'family_id': familyId,
        'child_id': childId,
        'restriction_type': UninstallProtection.restrictionType,
        'config': config,
        'active': true,
      });
    } else {
      await _client
          .from('device_restrictions')
          .update({'config': config, 'active': true}).eq('id', existing['id'] as String);
    }
    await _client.from('audit_log').insert({
      'family_id': familyId,
      'actor_id': parentId,
      'action': 'uninstall_protection_confirmed',
      'target_type': 'user',
      'target_id': childId,
      'metadata': {'platform': platform, 'method': method},
    });
  }

  Future<void> clearProtection({
    required String childId,
    required String familyId,
    required String parentId,
  }) async {
    await _client
        .from('device_restrictions')
        .update({'active': false})
        .eq('child_id', childId)
        .eq('restriction_type', UninstallProtection.restrictionType);
    await _client.from('audit_log').insert({
      'family_id': familyId,
      'actor_id': parentId,
      'action': 'uninstall_protection_cleared',
      'target_type': 'user',
      'target_id': childId,
    });
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(supabase, const FlutterSecureStorage());
});

final familyDevicesProvider = StreamProvider<List<FamilyDevice>>((ref) async* {
  final me = await ref.watch(currentAppUserProvider.future);
  if (me?.familyId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(deviceRepositoryProvider).familyDevices(me!.familyId!);
});

final uninstallProtectionsProvider = StreamProvider<List<UninstallProtection>>((ref) async* {
  final me = await ref.watch(currentAppUserProvider.future);
  if (me?.familyId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(deviceRepositoryProvider).protections(me!.familyId!);
});
