import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Device-local app lock (product spec §4): PIN for children on shared
/// devices, biometric (Face ID / fingerprint) as a second factor on top of
/// an already-valid session. This gates *opening the app*, it does not
/// replace the Supabase session token (docs/03-architecture.md §2).
///
/// The PIN never leaves the device: it's salted, SHA-256 hashed, and kept
/// in the platform keystore via flutter_secure_storage.
class AppLockService {
  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _pinHashKey = 'app_lock_pin_hash';
  static const _pinSaltKey = 'app_lock_pin_salt';
  static const _biometricsKey = 'app_lock_biometrics_enabled';

  /// Salted SHA-256; pure and static so it's unit-testable without the
  /// keystore.
  static String hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  static bool isValidPin(String pin) => RegExp(r'^\d{4,8}$').hasMatch(pin);

  Future<bool> get isPinSet async => await _storage.read(key: _pinHashKey) != null;

  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must be 4-8 digits');
    }
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hashPin(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    if (storedHash == null || salt == null) return false;
    return hashPin(pin, salt) == storedHash;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _biometricsKey);
  }

  Future<bool> get biometricsEnabled async =>
      await _storage.read(key: _biometricsKey) == 'true';

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricsKey, value: '$enabled');
  }

  Future<bool> get biometricsAvailable async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock The Ipalibos',
      );
    } catch (_) {
      return false;
    }
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

/// Whether the app is currently locked. Starts true when a PIN is set;
/// the lock screen flips it to false after a successful PIN or biometric.
class AppLockState extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> lockIfConfigured() async {
    final service = ref.read(appLockServiceProvider);
    if (await service.isPinSet) state = true;
  }

  void unlock() => state = false;
}

final appLockStateProvider = NotifierProvider<AppLockState, bool>(AppLockState.new);
