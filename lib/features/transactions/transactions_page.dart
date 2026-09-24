import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/schemas/transaction.dart' as schema;
import '../../core/database/schemas/transfer.dart';

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
    final transactionsAsync = ref.watch(transactionsProvider);
    final transfersAsync = ref.watch(transfersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.lightTextSecondary,
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
          _buildAllList(ref),
          // Incomes
          _buildFilteredList(ref, transactionsAsync, 'income'),
          // Expenses
          _buildFilteredList(ref, transactionsAsync, 'expense'),
          // Transfers
          _buildTransfersList(ref, transfersAsync),
        ],
      ),
    );
  }

  Widget _buildAllList(WidgetRef ref) {
    final mergedAsync = ref.watch(mergedTransactionsProvider);

    return mergedAsync.when(
      data: (merged) {
        if (merged.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: merged.length,
          itemBuilder: (context, index) {
            final item = merged[index];
            if (item is schema.Transaction) {
              return _buildTransactionItem(context, ref, item);
            } else {
              return _buildTransferItem(context, ref, item as Transfer);
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
  ) {
    return txnsAsync.when(
      data: (txns) {
        final filtered = txns.where((t) => t.type == type).toList();
        if (filtered.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _buildTransactionItem(context, ref, filtered[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Gagal memuat transaksi.')),
    );
  }

  Widget _buildTransfersList(
    WidgetRef ref,
    AsyncValue<List<Transfer>> transfersAsync,
  ) {
    return transfersAsync.when(
      data: (transfers) {
        if (transfers.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: transfers.length,
          itemBuilder: (context, index) =>
              _buildTransferItem(context, ref, transfers[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Gagal memuat riwayat transfer.')),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_outlined,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada riwayat transaksi.',
            style: TextStyle(fontSize: 15, color: AppTheme.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    WidgetRef ref,
    schema.Transaction t,
  ) {
    final isIncome = t.type == 'income';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoryAsync = ref.watch(categoryByIdProvider(t.categoryId));
    final accountAsync = ref.watch(accountByIdProvider(t.accountId));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2454) : Colors.grey.shade100,
        ),
      ),
      child: InkWell(
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountAsync.value?.name ?? 'Memuat...',
                    style: const TextStyle(
                      color: AppTheme.lightTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (t.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t.note,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
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
                Text(
                  '${isIncome ? '+' : '-'}${CurrencyFormatter.format(t.amount)}',
                  style: TextStyle(
                    color: isIncome
                        ? AppTheme.secondaryColor
                        : AppTheme.expenseColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.date.day}/${t.date.month}/${t.date.year}',
                  style: const TextStyle(
                    color: AppTheme.lightTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferItem(BuildContext context, WidgetRef ref, Transfer t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fromAccountAsync = ref.watch(accountByIdProvider(t.fromAccountId));
    final toAccountAsync = ref.watch(accountByIdProvider(t.toAccountId));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2454) : Colors.grey.shade100,
        ),
      ),
      child: InkWell(
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
                  const Text(
                    'Perpindahan Dana (Transfer)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fromAccountAsync.value?.name ?? 'Memuat...'} → ${toAccountAsync.value?.name ?? 'Memuat...'}',
                    style: const TextStyle(
                      color: AppTheme.lightTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (t.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t.note,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
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
                Text(
                  CurrencyFormatter.format(t.amount),
                  style: const TextStyle(
                    color: AppTheme.infoColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.date.day}/${t.date.month}/${t.date.year}',
                  style: const TextStyle(
                    color: AppTheme.lightTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
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
