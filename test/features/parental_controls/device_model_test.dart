import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/features/parental_controls/domain/device_model.dart';

FamilyDevice deviceSeen(DateTime? lastSync) => FamilyDevice(
      id: 'd1',
      userId: 'u1',
      familyId: 'f1',
      lastSyncAt: lastSync,
      createdAt: DateTime.now(),
    );

void main() {
  group('FamilyDevice.isStale', () {
    test('a device that checked in minutes ago is not stale', () {
      final device = deviceSeen(DateTime.now().subtract(const Duration(minutes: 5)));
      expect(device.isStale, isFalse);
    });

    test('a phone off overnight is not yet stale — that is normal family life', () {
      final device = deviceSeen(DateTime.now().subtract(const Duration(hours: 14)));
      expect(device.isStale, isFalse);
    });

    test('a full day of silence is stale', () {
      final device = deviceSeen(DateTime.now().subtract(const Duration(hours: 25)));
      expect(device.isStale, isTrue);
    });

    test('a device that has never checked in counts as stale', () {
      expect(deviceSeen(null).isStale, isTrue);
    });
  });

  group('FamilyDevice.label', () {
    test('prefers the reported device name', () {
      final device = FamilyDevice(
        id: 'd1',
        userId: 'u1',
        familyId: 'f1',
        os: 'ios',
        deviceName: 'Ada\'s iPhone',
        createdAt: DateTime.now(),
      );
      expect(device.label, 'Ada\'s iPhone');
    });

    test('falls back to the platform when no name came through', () {
      final device = FamilyDevice(
        id: 'd1',
        userId: 'u1',
        familyId: 'f1',
        os: 'android',
        createdAt: DateTime.now(),
      );
      expect(device.label, 'Android phone');
    });
  });

  group('UninstallProtection.fromJson', () {
    test('reads platform and method out of the config blob', () {
      final protection = UninstallProtection.fromJson({
        'id': 'r1',
        'child_id': 'c1',
        'active': true,
        'config': {
          'platform': 'ios',
          'method': 'screen_time',
          'confirmed_at': '2026-07-25T10:00:00Z',
        },
      });
      expect(protection.platform, 'ios');
      expect(protection.method, 'screen_time');
      expect(protection.active, isTrue);
      expect(protection.confirmedAt, isNotNull);
    });

    test('survives a row with an empty config', () {
      final protection = UninstallProtection.fromJson({
        'id': 'r1',
        'child_id': 'c1',
        'active': false,
        'config': <String, dynamic>{},
      });
      expect(protection.platform, isNull);
      expect(protection.active, isFalse);
    });
  });
}
