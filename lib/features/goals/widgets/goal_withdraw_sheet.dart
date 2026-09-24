import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/finance_providers.dart';
import '../../../core/providers.dart';
import '../../../core/database/schemas/goal.dart';
import '../../../core/database/schemas/goal_transaction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';

class GoalWithdrawSheet extends ConsumerStatefulWidget {
  final Goal goal;
  const GoalWithdrawSheet({super.key, required this.goal});

  @override
  ConsumerState<GoalWithdrawSheet> createState() => _GoalWithdrawSheetState();
}

class _GoalWithdrawSheetState extends ConsumerState<GoalWithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  int? _selectedAccountId;
  int _maxWithdrawable = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final accounts = ref.read(accountsProvider).value ?? [];
      final repo = ref.read(financeRepositoryProvider);
      for (var acc in accounts) {
        if (!acc.isArchived) {
          final locked = await repo.getLockedBalanceForGoalAndAccount(
            widget.goal.id,
            acc.id,
          );
          if (locked > 0 && mounted) {
            setState(() {
              _selectedAccountId = acc.id;
              _maxWithdrawable = locked;
            });
            break;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _updateMaxWithdrawable(int accountId) async {
    final repo = ref.read(financeRepositoryProvider);
    final locked = await repo.getLockedBalanceForGoalAndAccount(
      widget.goal.id,
      accountId,
    );
    setState(() {
      _maxWithdrawable = locked;
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua kolom.')),
      );
      return;
    }

    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih besar dari 0.')),
      );
      return;
    }

    if (amount > _maxWithdrawable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal melebihi batas penarikan untuk akun ini (${CurrencyFormatter.format(_maxWithdrawable)}).',
          ),
        ),
      );
      return;
    }

    final txn = GoalTransaction()
      ..uuid = ''
      ..goalId = widget.goal.id
      ..accountId = _selectedAccountId!
      ..type = 'withdrawal'
      ..amount = amount
      ..date = DateTime.now();

    try {
      await ref.read(goalsProvider.notifier).makeGoalTransaction(txn);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menarik dana: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header indicator
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tarik Dana dari: ${widget.goal.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Account Selection
              accountsAsync.when(
                data: (accounts) {
                  final activeAccounts = accounts
                      .where((a) => !a.isArchived)
                      .toList();
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Kembalikan Ke Rekening / Dompet',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: activeAccounts.map((a) {
                      return DropdownMenuItem<int>(
                        value: a.id,
                        child: Text(a.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedAccountId = val;
                        });
                        _updateMaxWithdrawable(val);
                      }
                    },
                    validator: (val) =>
                        val == null ? 'Akun tujuan wajib dipilih' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Gagal memuat daftar akun'),
              ),
              const SizedBox(height: 12),
              // Max withdrawable warning
              if (_selectedAccountId != null)
                Text(
                  'Maksimal dana yang dapat ditarik ke akun ini: ${CurrencyFormatter.format(_maxWithdrawable)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _maxWithdrawable > 0
                        ? AppTheme.secondaryColor
                        : AppTheme.expenseColor,
                  ),
                ),
              const SizedBox(height: 16),
              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Nominal Penarikan (Rp)',
                  hintText: 'Masukkan nominal',
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Nominal wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Submit button
              ElevatedButton(
                onPressed: _selectedAccountId != null && _maxWithdrawable > 0
                    ? _submit
                    : null,
                child: const Text('Tarik Dana'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
