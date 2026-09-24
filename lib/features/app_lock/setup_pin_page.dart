import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/app_lock_state_provider.dart';
import '../../core/theme/app_theme.dart';

class SetupPinPage extends ConsumerStatefulWidget {
  const SetupPinPage({super.key});

  @override
  ConsumerState<SetupPinPage> createState() => _SetupPinPageState();
}

class _SetupPinPageState extends ConsumerState<SetupPinPage> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';

  void _onKeyPress(String val) {
    setState(() {
      _errorMessage = '';
      if (_pin.length < 6) {
        _pin += val;
      }
      
      if (_pin.length == 6) {
        if (!_isConfirming) {
          // Switch to confirmation step
          _confirmPin = _pin;
          _pin = '';
          _isConfirming = true;
        } else {
          // Verify
          if (_pin == _confirmPin) {
            // Success! Save PIN
            ref.read(appLockStateProvider.notifier).completePinSetup(_pin);
          } else {
            // Failed
            _pin = '';
            _errorMessage = 'PIN tidak cocok. Silakan ulangi.';
          }
        }
      }
    });
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
            const SizedBox(height: 48),
            Text(
              _isConfirming ? 'Konfirmasi PIN Anda' : 'Buat PIN Keamanan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConfirming
                  ? 'Masukkan PIN 6-digit sekali lagi'
                  : 'PIN ini akan digunakan untuk mengunci aplikasi Anda',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const Spacer(),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) => _buildDot(index)),
            ),
            const SizedBox(height: 24),
            // Error Message
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: AppTheme.expenseColor, fontWeight: FontWeight.w600),
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
                      const Expanded(child: SizedBox()),
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
