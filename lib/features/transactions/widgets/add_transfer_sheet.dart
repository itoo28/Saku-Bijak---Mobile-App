import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/finance_providers.dart';
import '../../../core/database/schemas/transfer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';

class AddTransferSheet extends ConsumerStatefulWidget {
  final Transfer? transfer;

  const AddTransferSheet({super.key, this.transfer});

  @override
  ConsumerState<AddTransferSheet> createState() => _AddTransferSheetState();
}

class _AddTransferSheetState extends ConsumerState<AddTransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int? _fromAccountId;
  int? _toAccountId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.transfer != null) {
      final t = widget.transfer!;
      _amountController.text = CurrencyFormatter.format(t.amount);
      _noteController.text = t.note;
      _fromAccountId = t.fromAccountId;
      _toAccountId = t.toAccountId;
      _selectedDate = t.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() ||
        _fromAccountId == null ||
        _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua kolom wajib.')),
      );
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun asal dan tujuan tidak boleh sama.')),
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

    final isEdit = widget.transfer != null;
    final transfer = Transfer()
      ..id = isEdit ? widget.transfer!.id : 0
      ..uuid = isEdit ? widget.transfer!.uuid : ''
      ..fromAccountId = _fromAccountId!
      ..toAccountId = _toAccountId!
      ..amount = amount
      ..date = _selectedDate
      ..note = _noteController.text
      ..createdAt = isEdit ? widget.transfer!.createdAt : DateTime.now();

    try {
      if (isEdit) {
        await ref.read(transfersProvider.notifier).updateTransfer(transfer);
      } else {
        await ref.read(transfersProvider.notifier).addTransfer(transfer);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('SALDO_KURANG')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo akun asal tidak mencukupi untuk transfer ini.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan transfer: $e')),
        );
      }
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
          color: isDark ? AppTheme.darkCard : Colors.white,
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
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.transfer != null
                    ? 'Edit Transfer Saldo'
                    : 'Perpindahan Dana (Transfer)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
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
                  labelText: 'Nominal Transfer (Rp)',
                  hintText: 'Masukkan jumlah uang',
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Nominal wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // From Account
              accountsAsync.when(
                data: (accounts) {
                  final activeAccounts = accounts
                      .where((a) => !a.isArchived || a.id == _fromAccountId)
                      .toList();
                  return DropdownButtonFormField<int>(
                    initialValue: _fromAccountId,
                    dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'Dari Akun (Sumber)',
                      prefixIcon: Icon(Icons.logout_outlined),
                    ),
                    items: activeAccounts.map((a) {
                      return DropdownMenuItem<int>(
                        value: a.id,
                        child: Text(a.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _fromAccountId = val;
                      });
                    },
                    validator: (val) =>
                        val == null ? 'Akun asal wajib dipilih' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Gagal memuat akun asal'),
              ),
              const SizedBox(height: 16),
              // To Account
              accountsAsync.when(
                data: (accounts) {
                  final activeAccounts = accounts
                      .where((a) => !a.isArchived || a.id == _toAccountId)
                      .toList();
                  return DropdownButtonFormField<int>(
                    initialValue: _toAccountId,
                    dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'Ke Akun (Tujuan)',
                      prefixIcon: Icon(Icons.login_outlined),
                    ),
                    items: activeAccounts.map((a) {
                      return DropdownMenuItem<int>(
                        value: a.id,
                        child: Text(a.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _toAccountId = val;
                      });
                    },
                    validator: (val) =>
                        val == null ? 'Akun tujuan wajib dipilih' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Gagal memuat akun tujuan'),
              ),
              const SizedBox(height: 16),
              // Date picker field
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Transfer',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Note field
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Tambahkan keterangan transfer',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
              ),
              const SizedBox(height: 24),
              // Submit button
              ElevatedButton(
                onPressed: _submit,
                child: Text(
                  widget.transfer != null
                      ? 'Perbarui Transfer'
                      : 'Simpan Transfer',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
