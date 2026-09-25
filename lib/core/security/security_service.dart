import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();

  static const _pinKey = 'security_pin';
  static const _lockEnabledKey = 'security_lock_enabled';
  static const _biometricEnabledKey = 'security_biometric_enabled';
  static const _lastInteractionKey = 'security_last_interaction';

  Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (pin.length == 6) {
      await _storage.write(key: _pinKey, value: pin);
      await setLockEnabled(true);
    } else {
      throw ArgumentError('PIN must be 6 digits');
    }
  }

  Future<bool> verifyPin(String inputPin) async {
    final savedPin = await _storage.read(key: _pinKey);
    return savedPin == inputPin;
  }

  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
    await setLockEnabled(false);
    await setBiometricsEnabled(false);
  }

  Future<bool> isLockEnabled() async {
    final val = await _storage.read(key: _lockEnabledKey);
    return val == 'true';
  }

  Future<void> setLockEnabled(bool enabled) async {
    await _storage.write(key: _lockEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!isSupported || !canCheck) return false;
      
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;
    try {
      final canBio = await canUseBiometrics();
      if (!canBio) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Konfirmasi biometrik untuk membuka Saku Bijak',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // Auto-lock helper methods
  Future<void> updateLastInteraction() async {
    final nowStr = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _lastInteractionKey, value: nowStr);
  }

  Future<bool> shouldLock() async {
    final enabled = await isLockEnabled();
    if (!enabled) return false;

    final lastInteractionStr = await _storage.read(key: _lastInteractionKey);
    if (lastInteractionStr == null) return true; // Lock if no history

    final lastInteraction = int.tryParse(lastInteractionStr) ?? 0;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastInteraction;
    
    // Auto-lock if backgrounded/idle for more than 1 minute (60,000 ms)
    return elapsedMs > 60000;
  }
}
