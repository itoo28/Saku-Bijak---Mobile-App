import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/app_lock_state_provider.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  String _pin = '';
  String _errorMessage = '';
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    // Wait for frame rendering to avoid layout conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final security = ref.read(securityServiceProvider);
      final enabled = await security.isBiometricEnabled();
      if (!mounted) return;
      setState(() {
        _bioEnabled = enabled;
      });

      if (enabled) {
        _authenticateBiometric();
      }
    });
  }

  Future<void> _authenticateBiometric() async {
    final security = ref.read(securityServiceProvider);
    final success = await security.authenticateWithBiometrics();
    if (success) {
      ref.read(appLockStateProvider.notifier).unlock();
    }
  }

  void _onKeyPress(String val) {
    setState(() {
      _errorMessage = '';
      if (_pin.length < 6) {
        _pin += val;
      }
      
      if (_pin.length == 6) {
        _verifyPin();
      }
    });
  }

  Future<void> _verifyPin() async {
    final security = ref.read(securityServiceProvider);
    final match = await security.verifyPin(_pin);
    if (match) {
      ref.read(appLockStateProvider.notifier).unlock();
    } else {
      setState(() {
        _pin = '';
        _errorMessage = 'PIN Salah';
      });
    }
  }

  void _onBackspace() {
    setState(() {
      _errorMessage = '';
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Widget _buildDot(int index) {
    final active = index < _pin.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: active ? null : Border.all(color: Colors.grey.shade400, width: 1),
      ),
    );
  }

  Widget _buildKey(String value) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.5,
        child: InkWell(
          onTap: () => _onKeyPress(value),
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Masukkan PIN Anda',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 24),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) => _buildDot(index)),
            ),
            const SizedBox(height: 16),
            // Error Message
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: AppTheme.expenseColor, fontWeight: FontWeight.bold),
              ),
            const Spacer(),
            // Numeric Keyboard
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildKey('1'),
                      _buildKey('2'),
                      _buildKey('3'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildKey('4'),
                      _buildKey('5'),
                      _buildKey('6'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildKey('7'),
                      _buildKey('8'),
                      _buildKey('9'),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1.5,
                          child: InkWell(
                            onTap: _bioEnabled ? _authenticateBiometric : null,
                            borderRadius: BorderRadius.circular(40),
                            child: Center(
                              child: _bioEnabled
                                  ? const Icon(Icons.fingerprint, size: 36, color: AppTheme.primaryColor)
                                  : const SizedBox(),
                            ),
                          ),
                        ),
                      ),
                      _buildKey('0'),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1.5,
                          child: InkWell(
                            onTap: _onBackspace,
                            borderRadius: BorderRadius.circular(40),
                            child: const Center(
                              child: Icon(Icons.backspace_outlined, size: 28),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
