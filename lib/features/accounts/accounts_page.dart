import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/schemas/account.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun & Dompet'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              size: 28,
              color: AppTheme.primaryColor,
            ),
            onPressed: () => _showAddEditAccountDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80,
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada akun terdaftar.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showAddEditAccountDialog(context, ref),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text('Tambah Akun'),
                  ),
                ],
              ),
            );
          }

          final activeAccounts = accounts.where((a) => !a.isArchived).toList();
          final archivedAccounts = accounts.where((a) => a.isArchived).toList();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Akun Aktif',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ...activeAccounts.map(
                (acc) => _buildAccountCard(context, ref, acc),
              ),

              if (archivedAccounts.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  'Akun Diarsipkan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...archivedAccounts.map(
                  (acc) => _buildAccountCard(context, ref, acc),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Gagal memuat daftar akun.')),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, WidgetRef ref, Account acc) {
    final balancesAsync = ref.watch(accountBalancesProvider(acc.id));
    final balances =
        balancesAsync.value ??
        {'total': acc.balance, 'locked': 0, 'available': acc.balance};

    final cardColor = Color(acc.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withBlue(255).withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAccountOptions(context, ref, acc),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getAccountIcon(acc.accountType),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          acc.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      acc.accountType.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Saldo',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(balances['total']!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tersedia',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(balances['available']!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terkunci (Goal)',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(balances['locked']!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.money;
      case 'bank':
        return Icons.account_balance;
      case 'wallet':
        return Icons.phone_android;
      default:
        return Icons.wallet;
    }
  }

  void _showAccountOptions(BuildContext context, WidgetRef ref, Account acc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
                title: Text(
                  'Edit Nama & Warna',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEditAccountDialog(context, ref, account: acc);
                },
              ),
              ListTile(
                leading: Icon(
                  acc.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
                title: Text(
                  acc.isArchived ? 'Aktifkan Kembali' : 'Arsipkan Akun',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  acc.isArchived = !acc.isArchived;
                  await ref.read(accountsProvider.notifier).updateAccount(acc);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.expenseColor,
                ),
                title: const Text(
                  'Hapus Akun',
                  style: TextStyle(color: AppTheme.expenseColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hapus Akun'),
                      content: const Text(
                        'Apakah Anda yakin ingin menghapus akun ini? Akun dengan riwayat transaksi akan diarsipkan secara otomatis, sedangkan akun kosong akan dihapus permanen.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Hapus',
                            style: TextStyle(color: AppTheme.expenseColor),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref
                        .read(accountsProvider.notifier)
                        .deleteAccount(acc.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditAccountDialog(
    BuildContext context,
    WidgetRef ref, {
    Account? account,
  }) {
    showDialog(
      context: context,
      builder: (context) => _AddEditAccountDialog(account: account),
    );
  }
}

class _AddEditAccountDialog extends ConsumerStatefulWidget {
  final Account? account;
  const _AddEditAccountDialog({this.account});

  @override
  ConsumerState<_AddEditAccountDialog> createState() =>
      _AddEditAccountDialogState();
}

class _AddEditAccountDialogState
    extends ConsumerState<_AddEditAccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _type;
  late int _colorValue;

  final List<int> _colors = const [
    0xFF7F3DFF,
    0xFF00B156,
    0xFF0077FF,
    0xFFFF9800,
    0xFFE91E63,
    0xFF673AB7,
    0xFF607D8B,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name);
    _balanceController = TextEditingController(
      text: widget.account != null ? widget.account!.balance.toString() : '',
    );
    _type = widget.account?.accountType ?? 'cash';
    _colorValue = widget.account?.colorValue ?? 0xFF7F3DFF;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text(
        widget.account == null ? 'Tambah Akun Baru' : 'Edit Akun',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Akun / Dompet',
                hintText: 'Misal: BCA Utama, Cash, Gopay',
              ),
            ),
            const SizedBox(height: 16),
            if (widget.account == null) ...[
              TextField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Saldo Awal (Rp)',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: _type,
              dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
              decoration: const InputDecoration(
                labelText: 'Jenis Akun',
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash / Tunai')),
                DropdownMenuItem(value: 'bank', child: Text('Bank')),
                DropdownMenuItem(value: 'e-wallet', child: Text('E-Wallet')),
                DropdownMenuItem(
                  value: 'investment',
                  child: Text('Investasi'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _type = val);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih Warna Tema',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((c) {
                final isSelected = _colorValue == c;
                return GestureDetector(
                  onTap: () => setState(() => _colorValue = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: isDark ? Colors.white : Colors.black,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nama akun wajib diisi.')),
              );
              return;
            }

            if (widget.account == null) {
              final balance = CurrencyFormatter.parse(
                _balanceController.text,
              );
              if (balance < 0) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saldo awal tidak boleh negatif.'),
                    ),
                  );
                }
                return;
              }
              await ref
                  .read(accountsProvider.notifier)
                  .addAccount(name, _type, balance, _type, _colorValue);
            } else {
              widget.account!.name = name;
              widget.account!.accountType = _type;
              widget.account!.colorValue = _colorValue;
              await ref
                  .read(accountsProvider.notifier)
                  .updateAccount(widget.account!);
            }

            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

