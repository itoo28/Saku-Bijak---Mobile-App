import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/finance_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/schemas/goal.dart';
import 'widgets/add_goal_sheet.dart';
import 'widgets/goal_deposit_sheet.dart';
import 'widgets/goal_withdraw_sheet.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Menabung'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              size: 28,
              color: AppTheme.primaryColor,
            ),
            onPressed: () => _showAddGoal(context),
          ),
        ],
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.track_changes_outlined,
                    size: 80,
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada target menabung.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showAddGoal(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text('Buat Target Pertama'),
                  ),
                ],
              ),
            );
          }

          final activeGoals = goals
              .where((g) => g.status != 'archived')
              .toList();
          final archivedGoals = goals
              .where((g) => g.status == 'archived')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (activeGoals.isNotEmpty) ...[
                Text(
                  'Target Aktif',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...activeGoals.map(
                  (g) => _buildGoalCard(context, ref, g, isDark),
                ),
              ],
              if (archivedGoals.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  'Target Diarsipkan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...archivedGoals.map(
                  (g) => _buildGoalCard(context, ref, g, isDark),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Gagal memuat target menabung.')),
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    bool isDark,
  ) {
    final progressAsync = ref.watch(goalProgressProvider(goal.id));
    final progressAmount = progressAsync.value ?? 0;

    final avgAsync = ref.watch(goalAverageDepositProvider(goal.id));
    final avgMonthly = avgAsync.value ?? 0;

    final percentage = goal.targetAmount > 0
        ? (progressAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    // Prediction logic
    String predictionText = 'Belum ada riwayat menabung.';
    if (progressAmount >= goal.targetAmount) {
      predictionText = 'Target telah tercapai! 🎉';
    } else if (avgMonthly > 0) {
      final remaining = goal.targetAmount - progressAmount;
      final monthsRemaining = (remaining / avgMonthly).ceil();
      predictionText = 'Prediksi selesai: $monthsRemaining bulan lagi';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showGoalDetails(
          context,
          ref,
          goal,
          progressAmount,
          predictionText,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ),
                  _buildStatusChip(goal.status),
                ],
              ),
              const SizedBox(height: 8),
              if (goal.deadline != null)
                Text(
                  'Deadline: ${DateFormat('dd MMMM yyyy', 'id_ID').format(goal.deadline!)}',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 16),
              // Progress Text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: ${(percentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  Text(
                    '${CurrencyFormatter.format(progressAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress Bar
              LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: isDark
                    ? Colors.white12
                    : Colors.grey.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              // Prediction Text
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      predictionText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Actions buttons
              if (goal.status != 'archived')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showWithdrawGoal(context, goal),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Tarik Dana'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showDepositGoal(context, goal),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(80, 40),
                      ),
                      child: const Text(
                        'Nabung',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AppTheme.primaryColor;
    String text = 'Aktif';

    switch (status) {
      case 'completed':
        color = AppTheme.secondaryColor;
        text = 'Tercapai';
        break;
      case 'overdue':
        color = AppTheme.expenseColor;
        text = 'Terlewat';
        break;
      case 'archived':
        color = Colors.grey;
        text = 'Arsip';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAddGoal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddGoalSheet(),
    );
  }

  void _showDepositGoal(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalDepositSheet(goal: goal),
    );
  }

  void _showWithdrawGoal(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalWithdrawSheet(goal: goal),
    );
  }

  void _showGoalDetails(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    int progressAmount,
    String predictionText,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final txnsAsync = ref.watch(goalTransactionsProvider(goal.id));
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    goal.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Target: ${CurrencyFormatter.format(goal.targetAmount)} | Terkumpul: ${CurrencyFormatter.format(progressAmount)}',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            predictionText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Riwayat Tabungan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                      ),
                      if (goal.status != 'archived')
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Arsipkan Target'),
                                content: const Text(
                                  'Apakah Anda yakin ingin mengarsipkan target tabungan ini?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Batal'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      'Arsipkan',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              goal.status = 'archived';
                              await ref
                                  .read(goalsProvider.notifier)
                                  .updateGoal(goal);
                            }
                          },
                          child: const Text('Arsipkan Target'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: txnsAsync.when(
                      data: (txns) {
                        if (txns.isEmpty) {
                          return Center(
                            child: Text(
                              'Belum ada transaksi untuk target ini.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: txns.length,
                          itemBuilder: (context, index) {
                            final txn = txns[index];
                            final isDeposit = txn.type == 'deposit';

                            final accAsync = ref.watch(
                              accountByIdProvider(txn.accountId),
                            );

                            return ListTile(
                              leading: Icon(
                                isDeposit
                                    ? Icons.arrow_circle_right_outlined
                                    : Icons.arrow_circle_left_outlined,
                                color: isDeposit
                                    ? AppTheme.secondaryColor
                                    : AppTheme.expenseColor,
                              ),
                              title: Text(
                                isDeposit
                                    ? 'Setoran Tabungan'
                                    : 'Penarikan Tabungan',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                                ),
                              ),
                              subtitle: Text(
                                accAsync.value?.name ?? 'Memuat...',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isDeposit ? '+' : '-'}${CurrencyFormatter.format(txn.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDeposit
                                          ? AppTheme.secondaryColor
                                          : AppTheme.expenseColor,
                                    ),
                                  ),
                                  Text(
                                    '${txn.date.day}/${txn.date.month}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              onLongPress: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      'Hapus Transaksi Tabungan',
                                    ),
                                    content: const Text(
                                      'Apakah Anda yakin ingin menghapus transaksi tabungan ini? Saldo terkunci dan tersedia akan disesuaikan kembali.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          'Hapus',
                                          style: TextStyle(
                                            color: AppTheme.expenseColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await ref
                                        .read(goalsProvider.notifier)
                                        .deleteGoalTransaction(txn.id, goal.id);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal menghapus: $e'),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) =>
                          const Center(child: Text('Error memuat riwayat')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
