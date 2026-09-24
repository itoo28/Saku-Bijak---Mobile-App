import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/finance_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/schemas/account.dart';
import '../../core/database/schemas/category.dart';
import '../../core/database/schemas/transaction.dart';
import '../../core/database/schemas/transfer.dart';
import '../../core/database/schemas/goal.dart';
import '../../core/database/schemas/goal_transaction.dart';
import '../../core/database/schemas/budget.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricHardwareSupported = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityPreferences();
  }

  Future<void> _loadSecurityPreferences() async {
    final security = ref.read(securityServiceProvider);
    final lockVal = await security.isLockEnabled();
    final bioVal = await security.isBiometricEnabled();
    final hardwareVal = await security.canUseBiometrics();

    setState(() {
      _lockEnabled = lockVal;
      _biometricEnabled = bioVal;
      _biometricHardwareSupported = hardwareVal;
    });
  }

  Future<void> _toggleLock(bool val) async {
    final security = ref.read(securityServiceProvider);
    if (val) {
      // Prompt PIN setup if not set yet, otherwise just toggle enabled
      final isSet = await security.isPinSet();
      if (!isSet) {
        _showPinSetupDialog();
      } else {
        await security.setLockEnabled(true);
        setState(() {
          _lockEnabled = true;
        });
      }
    } else {
      // Verification before disabling
      final verified = await _showPinVerificationDialog();
      if (verified) {
        await security.setLockEnabled(false);
        await security.setBiometricsEnabled(false);
        setState(() {
          _lockEnabled = false;
          _biometricEnabled = false;
        });
      }
    }
  }

  Future<void> _toggleBiometrics(bool val) async {
    final security = ref.read(securityServiceProvider);
    if (val) {
      final verified = await _showPinVerificationDialog();
      if (verified) {
        await security.setBiometricsEnabled(true);
        setState(() {
          _biometricEnabled = true;
        });
      }
    } else {
      await security.setBiometricsEnabled(false);
      setState(() {
        _biometricEnabled = false;
      });
    }
  }

  void _showPinSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => _PinSetupDialog(
        onSuccess: (pin) async {
          final security = ref.read(securityServiceProvider);
          await security.setPin(pin);
          if (mounted) {
            setState(() {
              _lockEnabled = true;
            });
          }
        },
      ),
    );
  }

  Future<bool> _showPinVerificationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _PinVerificationDialog(
        onVerify: (pin) async {
          final security = ref.read(securityServiceProvider);
          return await security.verifyPin(pin);
        },
      ),
    );
    return result ?? false;
  }

  // ==========================================
  // BACKUP OPERATIONS
  // ==========================================

  Future<void> _exportBackup() async {
    if (kIsWeb) {
      _showError('Ekspor cadangan file hanya didukung pada platform native (Android / Desktop).');
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _PasswordInputDialog(
        title: 'Ekspor File Cadangan',
        description:
            'Masukkan kata sandi untuk melindungi file cadangan Anda. Kata sandi ini wajib diingat untuk memulihkan data nantinya.',
        buttonText: 'Ekspor',
      ),
    );

    if (password != null && password.isNotEmpty) {
      try {
        final backupService = ref.read(backupServiceProvider);
        final payload = await backupService.exportBackup(password);

        // Save payload to a temp file
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/sakubijak_backup.sbjk');
        await file.writeAsString(payload);

        // Share file
        await Share.shareXFiles([XFile(file.path)], text: 'Saku Bijak Data Backup');

        // Record last backup time
        const storage = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );
        await storage.write(key: 'last_backup_exported', value: DateTime.now().toIso8601String());

        ref.read(notificationServiceProvider).showNotification(
              id: 99,
              title: 'Backup Berhasil',
              body: 'Data keuangan Anda telah berhasil diekspor.',
            );

        ref.invalidate(transactionsProvider); // Refresh dashboard reminder state
      } catch (e) {
        _showError('Ekspor cadangan gagal: $e');
      }
    }
  }

  Future<void> _importRestore() async {
    if (kIsWeb) {
      _showError('Impor cadangan file hanya didukung pada platform native (Android / Desktop).');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final encryptedContent = await file.readAsString();

      if (!mounted) return;

      final password = await showDialog<String>(
        context: context,
        builder: (context) => const _PasswordInputDialog(
          title: 'Pulihkan Data (Restore)',
          description:
              'Peringatan: Seluruh data keuangan saat ini akan digantikan secara penuh oleh data di dalam file cadangan.',
          buttonText: 'Pulihkan',
          isWarning: true,
        ),
      );

      if (password != null && password.isNotEmpty) {
        try {
          final backupService = ref.read(backupServiceProvider);
          await backupService.importRestore(encryptedContent, password);

          // Force refresh all state providers to update UI immediately
          ref.read(accountsProvider.notifier).refresh();
          ref.read(transactionsProvider.notifier).refresh();
          ref.read(transfersProvider.notifier).refresh();
          ref.read(goalsProvider.notifier).refresh();
          ref.invalidate(budgetsProvider);

          ref.read(notificationServiceProvider).showNotification(
                id: 100,
                title: 'Data Berhasil Dipulihkan',
                body: 'Seluruh aset, target, dan riwayat transaksi telah dikembalikan.',
              );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pemulihan data berhasil!')),
            );
          }
        } catch (e) {
          _showError('Pemulihan gagal: Pastikan kata sandi benar.');
        }
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _resetAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Seluruh Data'),
        content: const Text(
          'TINDAKAN INI TIDAK DAPAT DIBATALKAN. Seluruh data keuangan Anda (akun, transaksi, target, budget) akan dihapus secara permanen dari perangkat.',
          style: TextStyle(color: AppTheme.expenseColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Semua', style: TextStyle(color: AppTheme.expenseColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(financeRepositoryProvider);
      await repo.clearAllData();

      // Clear lock preferences
      final security = ref.read(securityServiceProvider);
      await security.deletePin();

      // Refresh providers
      ref.read(accountsProvider.notifier).refresh();
      ref.read(transactionsProvider.notifier).refresh();
      ref.read(transfersProvider.notifier).refresh();
      ref.read(goalsProvider.notifier).refresh();
      ref.invalidate(budgetsProvider);

      if (mounted) {
        setState(() {
          _lockEnabled = false;
          _biometricEnabled = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua data keuangan telah direset.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Theme settings
          const Text('Tampilan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.lightTextSecondary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                // ignore: deprecated_member_use
                RadioListTile<ThemeMode>(
                  title: const Text('Ikuti Sistem OS'),
                  value: ThemeMode.system,
                  // ignore: deprecated_member_use
                  groupValue: currentThemeMode,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
                // ignore: deprecated_member_use
                RadioListTile<ThemeMode>(
                  title: const Text('Mode Terang'),
                  value: ThemeMode.light,
                  // ignore: deprecated_member_use
                  groupValue: currentThemeMode,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
                // ignore: deprecated_member_use
                RadioListTile<ThemeMode>(
                  title: const Text('Mode Gelap'),
                  value: ThemeMode.dark,
                  // ignore: deprecated_member_use
                  groupValue: currentThemeMode,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Security settings
          const Text('Keamanan Lokal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.lightTextSecondary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Kunci Aplikasi (PIN)'),
                  subtitle: const Text('Minta PIN 6-digit setiap kali aplikasi dibuka'),
                  value: _lockEnabled,
                  onChanged: _toggleLock,
                ),
                if (_lockEnabled && _biometricHardwareSupported)
                  SwitchListTile(
                    title: const Text('Autentikasi Biometrik'),
                    subtitle: const Text('Gunakan Sidik Jari / Face ID jika tersedia'),
                    value: _biometricEnabled,
                    onChanged: _toggleBiometrics,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Backup & Restore
          const Text('Cadangan & Pemulihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.lightTextSecondary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryColor),
                  title: const Text('Ekspor Cadangan (Backup)'),
                  subtitle: const Text('Simpan dan amankan seluruh data Anda ke file eksternal'),
                  onTap: _exportBackup,
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined, color: AppTheme.secondaryColor),
                  title: const Text('Impor Cadangan (Restore)'),
                  subtitle: const Text('Pulihkan data dari file cadangan Saku Bijak'),
                  onTap: _importRestore,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Reset Data
          const Text('Zona Bahaya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.lightTextSecondary)),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.expenseColor.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.expenseColor),
              title: const Text('Reset Semua Data', style: TextStyle(color: AppTheme.expenseColor, fontWeight: FontWeight.bold)),
              subtitle: const Text('Hapus seluruh akun, transaksi, dan data keamanan dari perangkat ini'),
              onTap: _resetAllData,
            ),
          ),
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  final Future<void> Function(String pin) onSuccess;
  const _PinSetupDialog({required this.onSuccess});

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat PIN Baru'),
      content: TextField(
        controller: _pinController,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'PIN 6-Digit',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            final pin = _pinController.text;
            if (pin.length == 6) {
              await widget.onSuccess(pin);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _PinVerificationDialog extends StatefulWidget {
  final Future<bool> Function(String pin) onVerify;
  const _PinVerificationDialog({required this.onVerify});

  @override
  State<_PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<_PinVerificationDialog> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi Keamanan'),
      content: TextField(
        controller: _pinController,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'Masukkan PIN Anda',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            final ok = await widget.onVerify(_pinController.text);
            if (context.mounted) Navigator.pop(context, ok);
          },
          child: const Text('Verifikasi'),
        ),
      ],
    );
  }
}

class _PasswordInputDialog extends StatefulWidget {
  final String title;
  final String description;
  final String buttonText;
  final bool isWarning;

  const _PasswordInputDialog({
    required this.title,
    required this.description,
    required this.buttonText,
    this.isWarning = false,
  });

  @override
  State<_PasswordInputDialog> createState() => _PasswordInputDialogState();
}

class _PasswordInputDialogState extends State<_PasswordInputDialog> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 12,
              color: widget.isWarning
                  ? AppTheme.expenseColor
                  : AppTheme.lightTextSecondary,
              fontWeight:
                  widget.isWarning ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Kata Sandi'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
          ),
          child: Text(widget.buttonText),
        ),
      ],
    );
  }
}

