import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/finance_providers.dart';
import '../../../core/providers.dart';
import '../../../core/database/schemas/goal.dart';
import '../../../core/database/schemas/goal_transaction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';

class GoalDepositSheet extends ConsumerStatefulWidget {
  final Goal goal;
  const GoalDepositSheet({super.key, required this.goal});

  @override
  ConsumerState<GoalDepositSheet> createState() => _GoalDepositSheetState();
}

class _GoalDepositSheetState extends ConsumerState<GoalDepositSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  int? _selectedAccountId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap pilih akun sumber dana.')),
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

    // Verify source account available balance
    final repo = ref.read(financeRepositoryProvider);
    final available = await repo.getAvailableBalance(_selectedAccountId!);
    if (!mounted) return;
    if (amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo yang tersedia di akun ini tidak mencukupi.'),
        ),
      );
      return;
    }

    final txn = GoalTransaction()
      ..uuid = ''
      ..goalId = widget.goal.id
      ..accountId = _selectedAccountId!
      ..type = 'deposit'
      ..amount = amount
      ..date = DateTime.now();

    try {
      await ref.read(goalsProvider.notifier).makeGoalTransaction(txn);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menabung: $e')));
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
                'Nabung untuk: ${widget.goal.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Jumlah Setoran Tabungan (Rp)',
                  hintText: 'Masukkan nominal',
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Nominal wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Source Account
              accountsAsync.when(
                data: (accounts) {
                  final activeAccounts = accounts
                      .where((a) => !a.isArchived)
                      .toList();
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Sumber Dana (Akun)',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: activeAccounts.map((a) {
                      return DropdownMenuItem<int>(
                        value: a.id,
                        child: Text(a.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedAccountId = val;
                      });
                    },
                    validator: (val) =>
                        val == null ? 'Akun asal wajib dipilih' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Gagal memuat akun sumber'),
              ),
              const SizedBox(height: 24),
              // Submit button
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Simpan Tabungan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
