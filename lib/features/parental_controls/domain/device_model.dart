/// Mirrors `public.devices` (docs/02-data-model.md "Foundation").
///
/// One row per app install per user. The row exists so a parent can see
/// that a child's phone is still checking in — see [FamilyDevice.isStale]
/// and docs/06-deviations.md "Uninstall protection".
class FamilyDevice {
  const FamilyDevice({
    required this.id,
    required this.userId,
    required this.familyId,
    this.installId,
    this.os,
    this.appVersion,
    this.deviceName,
    this.lastSyncAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? familyId;
  final String? installId;
  final String? os;
  final String? appVersion;
  final String? deviceName;
  final DateTime? lastSyncAt;
  final DateTime createdAt;

  /// How long a device may stay quiet before a parent should be told.
  ///
  /// Deliberately generous: a phone that's off overnight, on a plane, or
  /// out of signal all day is normal family life, and an alert that cries
  /// wolf is one a parent learns to ignore. A full day of silence from a
  /// device that was previously checking in is not normal.
  static const staleAfter = Duration(hours: 24);

  bool get isStale {
    final seen = lastSyncAt;
    if (seen == null) return true;
    return DateTime.now().difference(seen) > staleAfter;
  }

  /// "iPhone 14 · iOS", falling back gracefully when the platform gave us
  /// nothing useful.
  String get label {
    final name = deviceName;
    if (name != null && name.isNotEmpty) return name;
    return switch (os) {
      'ios' => 'iPhone or iPad',
      'android' => 'Android phone',
      'web' => 'Web browser',
      _ => 'Unknown device',
    };
  }

  factory FamilyDevice.fromJson(Map<String, dynamic> json) => FamilyDevice(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        familyId: json['family_id'] as String?,
        installId: json['install_id'] as String?,
        os: json['os'] as String?,
        appVersion: json['app_version'] as String?,
        deviceName: json['device_name'] as String?,
        lastSyncAt: json['last_sync_at'] == null
            ? null
            : DateTime.parse(json['last_sync_at'] as String).toLocal(),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

/// A parent's record that OS-level delete protection was set up on a
/// child's device. Mirrors a `public.device_restrictions` row with
/// `restriction_type = 'uninstall_protection'`.
///
/// This is an attestation, not enforcement — the actual switch lives in
/// iOS Screen Time or Android Family Link, where no app can reach it.
class UninstallProtection {
  const UninstallProtection({
    required this.id,
    required this.childId,
    required this.active,
    this.platform,
    this.method,
    this.confirmedAt,
  });

  final String id;
  final String childId;
  final bool active;
  final String? platform;
  final String? method;
  final DateTime? confirmedAt;

  static const restrictionType = 'uninstall_protection';

  factory UninstallProtection.fromJson(Map<String, dynamic> json) {
    final config = (json['config'] as Map<String, dynamic>?) ?? const {};
    return UninstallProtection(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      active: json['active'] as bool? ?? false,
      platform: config['platform'] as String?,
      method: config['method'] as String?,
      confirmedAt: config['confirmed_at'] == null
          ? null
          : DateTime.tryParse(config['confirmed_at'] as String)?.toLocal(),
    );
  }
}
