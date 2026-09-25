import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/schemas/transaction.dart' as schema;
import '../../core/database/schemas/transfer.dart';
import 'widgets/add_transaction_sheet.dart';
import 'widgets/add_transfer_sheet.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transactionsAsync = ref.watch(transactionsProvider);
    final transfersAsync = ref.watch(transfersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: isDark ? const Color(0xFF9F75FF) : AppTheme.primaryColor,
          unselectedLabelColor:
              isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          dividerColor:
              isDark ? const Color(0xFF2C2454) : Colors.grey.shade200,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Masuk'),
            Tab(text: 'Keluar'),
            Tab(text: 'Transfer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All
          _buildAllList(ref, isDark),
          // Incomes
          _buildFilteredList(ref, transactionsAsync, 'income', isDark),
          // Expenses
          _buildFilteredList(ref, transactionsAsync, 'expense', isDark),
          // Transfers
          _buildTransfersList(ref, transfersAsync, isDark),
        ],
      ),
    );
  }

  Widget _buildAllList(WidgetRef ref, bool isDark) {
    final mergedAsync = ref.watch(mergedTransactionsProvider);

    return mergedAsync.when(
      data: (merged) {
        if (merged.isEmpty) return _buildEmptyState(isDark);

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: merged.length,
          itemBuilder: (context, index) {
            final item = merged[index];
            if (item is schema.Transaction) {
              return _buildTransactionItem(context, ref, item, isDark);
            } else {
              return _buildTransferItem(context, ref, item as Transfer, isDark);
            }
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Gagal memuat riwayat.')),
    );
  }

  Widget _buildFilteredList(
    WidgetRef ref,
    AsyncValue<List<schema.Transaction>> txnsAsync,
    String type,
    bool isDark,
  ) {
    return txnsAsync.when(
      data: (txns) {
        final filtered = txns.where((t) => t.type == type).toList();
        if (filtered.isEmpty) return _buildEmptyState(isDark);

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _buildTransactionItem(context, ref, filtered[index], isDark),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Gagal memuat transaksi.')),
    );
  }

  Widget _buildTransfersList(
    WidgetRef ref,
    AsyncValue<List<Transfer>> transfersAsync,
    bool isDark,
  ) {
    return transfersAsync.when(
      data: (transfers) {
        if (transfers.isEmpty) return _buildEmptyState(isDark);

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: transfers.length,
          itemBuilder: (context, index) =>
              _buildTransferItem(context, ref, transfers[index], isDark),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Gagal memuat riwayat transfer.')),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada riwayat transaksi.',
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    WidgetRef ref,
    schema.Transaction t,
    bool isDark,
  ) {
    final isIncome = t.type == 'income';

    final categoryAsync = ref.watch(categoryByIdProvider(t.categoryId));
    final accountAsync = ref.watch(accountByIdProvider(t.accountId));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2454) : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editTransaction(context, t),
        onLongPress: () => _confirmDeleteTransaction(context, ref, t.id),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    (isIncome ? AppTheme.secondaryColor : AppTheme.expenseColor)
                        .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome
                    ? AppTheme.secondaryColor
                    : AppTheme.expenseColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryAsync.value?.name ?? 'Memuat...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountAsync.value?.name ?? 'Memuat...',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (t.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t.note,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${isIncome ? '+' : '-'}${CurrencyFormatter.format(t.amount)}',
                    style: TextStyle(
                      color: isIncome
                          ? AppTheme.secondaryColor
                          : AppTheme.expenseColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.date.day}/${t.date.month}/${t.date.year}',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Edit Transaksi',
              onPressed: () => _editTransaction(context, t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferItem(
    BuildContext context,
    WidgetRef ref,
    Transfer t,
    bool isDark,
  ) {
    final fromAccountAsync = ref.watch(accountByIdProvider(t.fromAccountId));
    final toAccountAsync = ref.watch(accountByIdProvider(t.toAccountId));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2454) : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editTransfer(context, t),
        onLongPress: () => _confirmDeleteTransfer(context, ref, t.id),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_outlined,
                color: AppTheme.infoColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perpindahan Dana (Transfer)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fromAccountAsync.value?.name ?? 'Memuat...'} → ${toAccountAsync.value?.name ?? 'Memuat...'}',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (t.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t.note,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    CurrencyFormatter.format(t.amount),
                    style: const TextStyle(
                      color: AppTheme.infoColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.date.day}/${t.date.month}/${t.date.year}',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Edit Transfer',
              onPressed: () => _editTransfer(context, t),
            ),
          ],
        ),
      ),
    );
  }

  void _editTransaction(BuildContext context, schema.Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        type: transaction.type,
        transaction: transaction,
      ),
    );
  }

  void _editTransfer(BuildContext context, Transfer transfer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransferSheet(
        transfer: transfer,
      ),
    );
  }

  void _confirmDeleteTransaction(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus catatan transaksi ini? Saldo akun terkait akan disesuaikan kembali.',
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
      await ref.read(transactionsProvider.notifier).deleteTransaction(id);
    }
  }

  void _confirmDeleteTransfer(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transfer'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus catatan transfer ini? Saldo kedua akun terkait akan disesuaikan kembali.',
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
      await ref.read(transfersProvider.notifier).deleteTransfer(id);
    }
  }
}
