import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/core/auth/app_lock_service.dart';

void main() {
  group('AppLockService.hashPin', () {
    test('same pin + same salt is deterministic', () {
      expect(AppLockService.hashPin('1234', 'saltA'), AppLockService.hashPin('1234', 'saltA'));
    });

    test('different salt produces a different hash for the same pin', () {
      expect(
        AppLockService.hashPin('1234', 'saltA'),
        isNot(AppLockService.hashPin('1234', 'saltB')),
      );
    });

    test('hash is not the pin itself', () {
      final hash = AppLockService.hashPin('1234', 'saltA');
      expect(hash, isNot(contains('1234')));
      expect(hash.length, 64); // SHA-256 hex
    });
  });

  group('AppLockService.isValidPin', () {
    test('accepts 4-8 digit pins', () {
      expect(AppLockService.isValidPin('1234'), isTrue);
      expect(AppLockService.isValidPin('12345678'), isTrue);
    });

    test('rejects short, long, and non-numeric pins', () {
      expect(AppLockService.isValidPin('123'), isFalse);
      expect(AppLockService.isValidPin('123456789'), isFalse);
      expect(AppLockService.isValidPin('12a4'), isFalse);
      expect(AppLockService.isValidPin(''), isFalse);
    });
  });
}
