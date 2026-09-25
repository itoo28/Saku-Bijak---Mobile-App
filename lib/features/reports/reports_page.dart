import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/finance_providers.dart';
import '../../core/database/schemas/transaction.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';

enum ReportPeriod { weekly, monthly }

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportPeriod _period = ReportPeriod.weekly;
  DateTime _anchorDate = DateTime.now();
  String _transactionType = 'expense'; // 'expense' or 'income'
  int _touchedPieIndex = -1;
  int? _expandedCategoryId;

  // Week calculation helper (Monday 00:00:00 to Sunday 23:59:59)
  DateTime get _startOfWeek {
    final monday = _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  DateTime get _endOfWeek {
    final sunday = _startOfWeek.add(const Duration(days: 6));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
  }

  // Month calculation helper (1st to last day of month)
  DateTime get _startOfMonth {
    return DateTime(_anchorDate.year, _anchorDate.month, 1);
  }

  DateTime get _endOfMonth {
    final nextMonth = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
    return nextMonth.subtract(const Duration(milliseconds: 1));
  }

  DateTime get _currentStartDate =>
      _period == ReportPeriod.weekly ? _startOfWeek : _startOfMonth;

  DateTime get _currentEndDate =>
      _period == ReportPeriod.weekly ? _endOfWeek : _endOfMonth;

  void _previousPeriod() {
    setState(() {
      _touchedPieIndex = -1;
      _expandedCategoryId = null;
      if (_period == ReportPeriod.weekly) {
        _anchorDate = _anchorDate.subtract(const Duration(days: 7));
      } else {
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month - 1, 1);
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      _touchedPieIndex = -1;
      _expandedCategoryId = null;
      if (_period == ReportPeriod.weekly) {
        _anchorDate = _anchorDate.add(const Duration(days: 7));
      } else {
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
      }
    });
  }

  void _jumpToToday() {
    setState(() {
      _touchedPieIndex = -1;
      _expandedCategoryId = null;
      _anchorDate = DateTime.now();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _touchedPieIndex = -1;
        _expandedCategoryId = null;
        _anchorDate = picked;
      });
    }
  }

  String _formatPeriodLabel() {
    if (_period == ReportPeriod.weekly) {
      final startStr = DateFormat('dd MMM', 'id_ID').format(_startOfWeek);
      final endStr = DateFormat('dd MMM yyyy', 'id_ID').format(_endOfWeek);
      return '$startStr - $endStr';
    } else {
      return DateFormat('MMMM yyyy', 'id_ID').format(_startOfMonth);
    }
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    if (_period == ReportPeriod.weekly) {
      final thisMon = now.subtract(Duration(days: now.weekday - 1));
      return thisMon.year == _startOfWeek.year &&
          thisMon.month == _startOfWeek.month &&
          thisMon.day == _startOfWeek.day;
    } else {
      return now.year == _startOfMonth.year && now.month == _startOfMonth.month;
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'payments':
        return Icons.payments_outlined;
      case 'card_giftcard':
        return Icons.card_giftcard_outlined;
      case 'work':
        return Icons.work_outline;
      case 'celebration':
        return Icons.celebration_outlined;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car_outlined;
      case 'shopping_bag':
        return Icons.shopping_bag_outlined;
      case 'receipt_long':
        return Icons.receipt_long_outlined;
      case 'sports_esports':
        return Icons.sports_esports_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2454) : Colors.grey.shade200;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Analisis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Pilih Tanggal',
            onPressed: _pickDate,
          ),
          if (!_isCurrentPeriod())
            TextButton(
              onPressed: _jumpToToday,
              child: Text(
                _period == ReportPeriod.weekly ? 'Mgg Ini' : 'Bln Ini',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
      body: transactionsAsync.when(
        data: (allTxns) {
          final categories = categoriesAsync.value ?? [];
          final categoryMap = {for (var c in categories) c.id: c};

          // Filter transactions within period
          final periodTxns = allTxns.where((t) {
            if (t.deletedAt != null) return false;
            return t.date.isAfter(_currentStartDate.subtract(const Duration(seconds: 1))) &&
                t.date.isBefore(_currentEndDate.add(const Duration(seconds: 1)));
          }).toList();

          final expenseTxns = periodTxns.where((t) => t.type == 'expense').toList();
          final incomeTxns = periodTxns.where((t) => t.type == 'income').toList();

          final totalExpense = expenseTxns.fold<int>(0, (sum, t) => sum + t.amount);
          final totalIncome = incomeTxns.fold<int>(0, (sum, t) => sum + t.amount);
          final netBalance = totalIncome - totalExpense;

          final activeTxns = _transactionType == 'expense' ? expenseTxns : incomeTxns;
          final activeTotal = _transactionType == 'expense' ? totalExpense : totalIncome;

          // Aggregate by category
          final Map<int, List<Transaction>> catGroups = {};
          for (var t in activeTxns) {
            catGroups.putIfAbsent(t.categoryId, () => []).add(t);
          }

          final List<_CategoryStat> categoryStats = catGroups.entries.map((e) {
            final cat = categoryMap[e.key];
            final amount = e.value.fold<int>(0, (sum, t) => sum + t.amount);
            final pct = activeTotal > 0 ? (amount / activeTotal) * 100 : 0.0;
            return _CategoryStat(
              categoryId: e.key,
              categoryName: cat?.name ?? 'Kategori #${e.key}',
              icon: cat?.icon ?? 'more_horiz',
              color: Color(cat?.colorValue ?? 0xFF7F3DFF),
              totalAmount: amount,
              percentage: pct,
              transactions: e.value..sort((a, b) => b.date.compareTo(a.date)),
            );
          }).toList();

          // Sort by highest amount
          categoryStats.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Period Selector (Mingguan / Bulanan)
              _buildPeriodToggle(isDark),
              const SizedBox(height: 12),

              // 2. Period Navigation Bar
              _buildPeriodNavigator(textPrimary, textSecondary, cardBg, borderColor),
              const SizedBox(height: 16),

              // 3. Financial Summary Card (Pemasukan, Pengeluaran, Arus Kas)
              _buildSummaryCard(
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                netBalance: netBalance,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 20),

              // 4. Type Selector (Pengeluaran vs Pemasukan)
              _buildTypeSelector(isDark),
              const SizedBox(height: 20),

              if (categoryStats.isEmpty) ...[
                // Empty state
                _buildEmptyState(isDark, cardBg, borderColor, textSecondary),
              ] else ...[
                // 5. Donut Chart (Distribusi Kategori)
                _buildDonutChartCard(
                  stats: categoryStats,
                  totalAmount: activeTotal,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 20),

                // 6. Bar Chart (Tren Waktu)
                _buildBarChartCard(
                  periodTxns: activeTxns,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 24),

                // 7. Category Breakdown List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _transactionType == 'expense'
                          ? 'Arah Pengeluaran (${categoryStats.length} Kategori)'
                          : 'Sumber Pemasukan (${categoryStats.length} Kategori)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...categoryStats.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final stat = entry.value;
                  return _buildCategoryItem(
                    rank: rank,
                    stat: stat,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                }),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Gagal memuat data: $err')),
      ),
    );
  }

  // ==========================================
  // WIDGET: Period Toggle (Mingguan vs Bulanan)
  // ==========================================
  Widget _buildPeriodToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_period != ReportPeriod.weekly) {
                  setState(() {
                    _period = ReportPeriod.weekly;
                    _touchedPieIndex = -1;
                    _expandedCategoryId = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _period == ReportPeriod.weekly
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Mingguan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _period == ReportPeriod.weekly
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_period != ReportPeriod.monthly) {
                  setState(() {
                    _period = ReportPeriod.monthly;
                    _touchedPieIndex = -1;
                    _expandedCategoryId = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _period == ReportPeriod.monthly
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Bulanan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _period == ReportPeriod.monthly
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: Period Navigator (< Label >)
  // ==========================================
  Widget _buildPeriodNavigator(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: _previousPeriod,
            tooltip: 'Periode Sebelumnya',
          ),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatPeriodLabel(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                ),
                if (_isCurrentPeriod()) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _period == ReportPeriod.weekly ? 'Minggu Berjalan' : 'Bulan Berjalan',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: _nextPeriod,
            tooltip: 'Periode Selanjutnya',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: Financial Summary Card
  // ==========================================
  Widget _buildSummaryCard({
    required int totalIncome,
    required int totalExpense,
    required int netBalance,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isSurplus = netBalance >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  title: 'Total Pemasukan',
                  amount: totalIncome,
                  color: AppTheme.secondaryColor,
                  icon: Icons.arrow_downward_rounded,
                  isDark: isDark,
                  textSecondary: textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryBox(
                  title: 'Total Pengeluaran',
                  amount: totalExpense,
                  color: AppTheme.expenseColor,
                  icon: Icons.arrow_upward_rounded,
                  isDark: isDark,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (isSurplus ? AppTheme.secondaryColor : AppTheme.expenseColor)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: isSurplus ? AppTheme.secondaryColor : AppTheme.expenseColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Arus Kas Bersih',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${isSurplus ? '+' : ''}${CurrencyFormatter.format(netBalance)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSurplus ? AppTheme.secondaryColor : AppTheme.expenseColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required int amount,
    required Color color,
    required IconData icon,
    required bool isDark,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: Type Selector (Pengeluaran vs Pemasukan)
  // ==========================================
  Widget _buildTypeSelector(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _transactionType = 'expense';
                _touchedPieIndex = -1;
                _expandedCategoryId = null;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _transactionType == 'expense'
                    ? AppTheme.expenseColor
                    : (isDark ? AppTheme.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _transactionType == 'expense'
                      ? AppTheme.expenseColor
                      : (isDark ? const Color(0xFF2C2454) : Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    size: 18,
                    color: _transactionType == 'expense'
                        ? Colors.white
                        : AppTheme.expenseColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pengeluaran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _transactionType == 'expense'
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _transactionType = 'income';
                _touchedPieIndex = -1;
                _expandedCategoryId = null;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _transactionType == 'income'
                    ? AppTheme.secondaryColor
                    : (isDark ? AppTheme.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _transactionType == 'income'
                      ? AppTheme.secondaryColor
                      : (isDark ? const Color(0xFF2C2454) : Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 18,
                    color: _transactionType == 'income'
                        ? Colors.white
                        : AppTheme.secondaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pemasukan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _transactionType == 'income'
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // WIDGET: Donut Chart Card
  // ==========================================
  Widget _buildDonutChartCard({
    required List<_CategoryStat> stats,
    required int totalAmount,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final touchedStat = _touchedPieIndex >= 0 && _touchedPieIndex < stats.length
        ? stats[_touchedPieIndex]
        : null;

    final centerLabel = touchedStat != null
        ? touchedStat.categoryName
        : (_transactionType == 'expense' ? 'Total Keluar' : 'Total Masuk');

    final centerValue = touchedStat != null
        ? CurrencyFormatter.format(touchedStat.totalAmount)
        : CurrencyFormatter.format(totalAmount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_large_rounded,
                color: _transactionType == 'expense'
                    ? AppTheme.expenseColor
                    : AppTheme.secondaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Proporsi Kategori',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex =
                              pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 58,
                    sections: stats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final stat = entry.value;
                      final isTouched = i == _touchedPieIndex;
                      final radius = isTouched ? 38.0 : 30.0;

                      return PieChartSectionData(
                        color: stat.color,
                        value: stat.totalAmount.toDouble(),
                        title: stat.percentage >= 7.0
                            ? '${stat.percentage.toStringAsFixed(0)}%'
                            : '',
                        radius: radius,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          centerValue,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (touchedStat != null)
                      Text(
                        '${touchedStat.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: touchedStat.color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ketuk bagian grafik donat untuk melihat detail kategori.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: Bar Chart Card (Tren Waktu)
  // ==========================================
  Widget _buildBarChartCard({
    required List<Transaction> periodTxns,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isWeekly = _period == ReportPeriod.weekly;

    // Calculate bars
    List<String> labels = [];
    List<double> values = [];

    if (isWeekly) {
      labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      values = List.generate(7, (index) {
        final dayDate = _startOfWeek.add(Duration(days: index));
        final dayTxns = periodTxns.where((t) =>
            t.date.year == dayDate.year &&
            t.date.month == dayDate.month &&
            t.date.day == dayDate.day);
        return dayTxns.fold<double>(0.0, (sum, t) => sum + t.amount);
      });
    } else {
      // Monthly: split into 4 or 5 weeks
      final totalDays = _endOfMonth.day;
      final weekCount = (totalDays / 7).ceil();
      labels = List.generate(weekCount, (i) => 'Mgg ${i + 1}');
      values = List.generate(weekCount, (i) {
        final startDay = (i * 7) + 1;
        final endDay = ((i + 1) * 7) > totalDays ? totalDays : ((i + 1) * 7);
        final weekTxns = periodTxns.where(
          (t) => t.date.day >= startDay && t.date.day <= endDay,
        );
        return weekTxns.fold<double>(0.0, (sum, t) => sum + t.amount);
      });
    }

    final maxVal = values.isNotEmpty
        ? values.reduce((a, b) => a > b ? a : b)
        : 0.0;
    final chartMaxY = maxVal > 0 ? maxVal * 1.25 : 100000.0;

    final primaryBarColor = _transactionType == 'expense'
        ? AppTheme.expenseColor
        : AppTheme.secondaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: primaryBarColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isWeekly ? 'Tren Harian (Senin - Minggu)' : 'Tren Mingguan (Bulan Ini)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF2C2454) : Colors.black87,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = labels[group.x.toInt()];
                      final formattedVal = CurrencyFormatter.format(rod.toY.toInt());
                      return BarTooltipItem(
                        '$label\n$formattedVal',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[idx],
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: values.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final val = entry.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: val > 0
                            ? primaryBarColor
                            : primaryBarColor.withValues(alpha: 0.15),
                        width: isWeekly ? 18 : 26,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: Category Breakdown Item (Expandable)
  // ==========================================
  Widget _buildCategoryItem({
    required int rank,
    required _CategoryStat stat,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isExpanded = _expandedCategoryId == stat.categoryId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? stat.color.withValues(alpha: 0.5) : borderColor,
          width: isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedCategoryId = isExpanded ? null : stat.categoryId;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Rank indicator badge
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: stat.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: stat.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Category icon in colored box
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: stat.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(stat.icon),
                          color: stat.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Category title & count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.categoryName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stat.transactions.length} transaksi • ${stat.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Amount & Expand icon
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyFormatter.format(stat.totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Mini progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (stat.percentage / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(stat.color),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded transaction details
          if (isExpanded) ...[
            Divider(height: 1, color: borderColor),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: stat.color.withValues(alpha: 0.03),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat Transaksi (${stat.categoryName})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: stat.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...stat.transactions.map((txn) {
                    final dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(txn.date);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  txn.note.isNotEmpty ? txn.note : stat.categoryName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.format(txn.amount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: Empty State
  // ==========================================
  Widget _buildEmptyState(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 36,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Transaksi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada data ${_transactionType == 'expense' ? 'pengeluaran' : 'pemasukan'} pada periode ${_formatPeriodLabel()}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CategoryStat {
  final int categoryId;
  final String categoryName;
  final String icon;
  final Color color;
  final int totalAmount;
  final double percentage;
  final List<Transaction> transactions;

  _CategoryStat({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.totalAmount,
    required this.percentage,
    required this.transactions,
  });
}
