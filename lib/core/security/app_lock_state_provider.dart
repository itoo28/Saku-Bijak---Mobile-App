import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'security_service.dart';
import '../providers.dart';

enum AppLockState {
  onboarding,
  setupPin,
  locked,
  authorized
}

class AppLockStateNotifier extends StateNotifier<AppLockState> {
  final SecurityService _securityService;
  
  AppLockStateNotifier(this._securityService) : super(AppLockState.locked) {
    initialize();
  }

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _onboardingCompleteKey = 'onboarding_complete';

  Future<void> initialize() async {
    final onboardingDone = await _storage.read(key: _onboardingCompleteKey) == 'true';
    if (!onboardingDone) {
      state = AppLockState.onboarding;
      return;
    }

    final pinSet = await _securityService.isPinSet();
    if (!pinSet) {
      state = AppLockState.setupPin;
      return;
    }

    final isLockEnabled = await _securityService.isLockEnabled();
    if (!isLockEnabled) {
      state = AppLockState.authorized;
      return;
    }

    // App starts locked by default if lock is enabled and PIN is set
    state = AppLockState.locked;
  }

  Future<void> completeOnboarding() async {
    await _storage.write(key: _onboardingCompleteKey, value: 'true');
    final pinSet = await _securityService.isPinSet();
    if (pinSet) {
      state = AppLockState.locked;
    } else {
      state = AppLockState.setupPin;
    }
  }

  Future<void> completePinSetup(String pin) async {
    await _securityService.setPin(pin);
    await _securityService.setLockEnabled(true);
    state = AppLockState.authorized;
  }

  void unlock() {
    state = AppLockState.authorized;
    _securityService.updateLastInteraction();
  }

  void lock() {
    state = AppLockState.locked;
  }
}

final appLockStateProvider = StateNotifierProvider<AppLockStateNotifier, AppLockState>((ref) {
  final sec = ref.watch(securityServiceProvider);
  return AppLockStateNotifier(sec);
});
