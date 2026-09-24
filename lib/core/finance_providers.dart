import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'database/finance_repository.dart';
import 'database/schemas/account.dart';
import 'database/schemas/category.dart';
import 'database/schemas/transaction.dart';
import 'database/schemas/transfer.dart';
import 'database/schemas/goal.dart';
import 'database/schemas/goal_transaction.dart';
import 'database/schemas/budget.dart';
import 'providers.dart';

// ==========================================
// ACCOUNTS PROVIDER
// ==========================================
class AccountsNotifier extends StateNotifier<AsyncValue<List<Account>>> {
  final FinanceRepository _repo;
  AccountsNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getAccounts();
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addAccount(
    String name,
    String type,
    int balance,
    String icon,
    int colorValue,
  ) async {
    final account = Account()
      ..uuid = ''
      ..name = name
      ..accountType = type
      ..balance = balance
      ..currency = 'IDR'
      ..icon = icon
      ..colorValue = colorValue
      ..isArchived = false
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await _repo.saveAccount(account);
    await refresh();
  }

  Future<void> updateAccount(Account account) async {
    account.updatedAt = DateTime.now();
    await _repo.saveAccount(account);
    await refresh();
  }

  Future<void> deleteAccount(int id) async {
    await _repo.softDeleteAccount(id);
    await refresh();
  }
}

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, AsyncValue<List<Account>>>((ref) {
      final repo = ref.watch(financeRepositoryProvider);
      return AccountsNotifier(repo);
    });

// Helper provider to fetch single account balances (available and locked)
final accountBalancesProvider = FutureProvider.family<Map<String, int>, int>((
  ref,
  accountId,
) async {
  final repo = ref.watch(financeRepositoryProvider);
  // Watch accounts and goals to recalculate when they change
  ref.watch(accountsProvider);
  ref.watch(goalsProvider);

  final locked = await repo.getLockedBalance(accountId);
  final available = await repo.getAvailableBalance(accountId);
  final account = await repo.getAccount(accountId);

  return {
    'total': account?.balance ?? 0,
    'locked': locked,
    'available': available,
  };
});

// Helper provider for total locked balance across all active accounts
final totalLockedBalanceProvider = FutureProvider<int>((ref) async {
  final accountsAsync = ref.watch(accountsProvider);
  final repo = ref.watch(financeRepositoryProvider);
  ref.watch(goalsProvider);

  final accounts = accountsAsync.value ?? [];
  int sum = 0;
  for (var acc in accounts) {
    if (!acc.isArchived) {
      sum += await repo.getLockedBalance(acc.id);
    }
  }
  return sum;
});

// ==========================================
// TRANSACTIONS PROVIDER
// ==========================================
class TransactionsNotifier
    extends StateNotifier<AsyncValue<List<Transaction>>> {
  final FinanceRepository _repo;
  final Ref _ref;

  TransactionsNotifier(this._repo, this._ref)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getTransactions();
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addTransaction(
    Transaction txn, {
    bool forceNegative = false,
  }) async {
    txn.createdAt = DateTime.now();
    txn.updatedAt = DateTime.now();
    await _repo.saveTransaction(txn, forceNegative: forceNegative);

    // Invalidate related states to keep everything reactive
    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.invalidate(budgetsProvider);
  }

  Future<void> updateTransaction(
    Transaction txn, {
    bool forceNegative = false,
  }) async {
    txn.updatedAt = DateTime.now();
    await _repo.saveTransaction(txn, forceNegative: forceNegative);

    // Invalidate related states to keep everything reactive
    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.invalidate(budgetsProvider);
  }

  Future<void> deleteTransaction(int id) async {
    await _repo.softDeleteTransaction(id);

    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.invalidate(budgetsProvider);
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<List<Transaction>>>((
      ref,
    ) {
      final repo = ref.watch(financeRepositoryProvider);
      return TransactionsNotifier(repo, ref);
    });

// ==========================================
// TRANSFERS PROVIDER
// ==========================================
class TransfersNotifier extends StateNotifier<AsyncValue<List<Transfer>>> {
  final FinanceRepository _repo;
  final Ref _ref;

  TransfersNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getTransfers();
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addTransfer(Transfer transfer) async {
    transfer.createdAt = DateTime.now();
    await _repo.saveTransfer(transfer);

    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
  }

  Future<void> updateTransfer(Transfer transfer) async {
    await _repo.saveTransfer(transfer);

    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
  }

  Future<void> deleteTransfer(int id) async {
    await _repo.softDeleteTransfer(id);

    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
  }
}

final transfersProvider =
    StateNotifierProvider<TransfersNotifier, AsyncValue<List<Transfer>>>((ref) {
      final repo = ref.watch(financeRepositoryProvider);
      return TransfersNotifier(repo, ref);
    });

// ==========================================
// GOALS PROVIDER
// ==========================================
class GoalsNotifier extends StateNotifier<AsyncValue<List<Goal>>> {
  final FinanceRepository _repo;
  final Ref _ref;

  GoalsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getGoals();
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addGoal(
    String name,
    int targetAmount,
    DateTime? deadline,
    String description,
  ) async {
    final goal = Goal()
      ..uuid = ''
      ..name = name
      ..targetAmount = targetAmount
      ..deadline = deadline
      ..description = description
      ..status = 'active'
      ..createdAt = DateTime.now();

    await _repo.saveGoal(goal);
    await refresh();
  }

  Future<void> updateGoal(Goal goal) async {
    await _repo.saveGoal(goal);
    await refresh();
  }

  Future<void> deleteGoal(int id) async {
    await _repo.softDeleteGoal(id);
    await refresh();
  }

  Future<void> makeGoalTransaction(GoalTransaction txn) async {
    txn.createdAt = DateTime.now();
    await _repo.saveGoalTransaction(txn);

    // Invalidate dependencies
    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.invalidate(goalProgressProvider(txn.goalId));
    _ref.invalidate(goalAverageDepositProvider(txn.goalId));
  }

  Future<void> deleteGoalTransaction(int id, int goalId) async {
    await _repo.softDeleteGoalTransaction(id);

    await refresh();
    _ref.read(accountsProvider.notifier).refresh();
    _ref.invalidate(goalProgressProvider(goalId));
    _ref.invalidate(goalAverageDepositProvider(goalId));
  }
}

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, AsyncValue<List<Goal>>>((ref) {
      final repo = ref.watch(financeRepositoryProvider);
      return GoalsNotifier(repo, ref);
    });

// Derived goal details
final goalProgressProvider = FutureProvider.family<int, int>((
  ref,
  goalId,
) async {
  final repo = ref.watch(financeRepositoryProvider);
  return await repo.getGoalProgressAmount(goalId);
});

final goalTransactionsProvider =
    FutureProvider.family<List<GoalTransaction>, int>((ref, goalId) async {
      final repo = ref.watch(financeRepositoryProvider);
      ref.watch(goalsProvider); // React to goals provider changes
      return await repo.getGoalTransactionsForGoal(goalId);
    });

// Calculate average deposit per month for a goal to predict completion
final goalAverageDepositProvider = FutureProvider.family<int, int>((
  ref,
  goalId,
) async {
  final repo = ref.watch(financeRepositoryProvider);
  final txns = await repo.getGoalDepositsForGoal(goalId);

  if (txns.isEmpty) return 0;

  // Calculate average deposit. If all deposits happen on same day, default to average deposit amount overall
  final dates = txns.map((t) => t.date).toList();
  final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
  final maxDate = dates.reduce((a, b) => a.isAfter(b) ? a : b);

  final daysDiff = maxDate.difference(minDate).inDays;
  final totalAmount = txns.fold(0, (sum, t) => sum + t.amount);

  if (daysDiff <= 30) {
    // If savings history is less than a month, treat as single month rate
    return totalAmount;
  }

  final months = daysDiff / 30.0;
  if (months <= 0) return totalAmount;
  final result = (totalAmount / months).round();
  return (result.isFinite && !result.isNaN) ? result : totalAmount;
});

// Derived provider for pre-sorted merged transactions and transfers
final mergedTransactionsProvider = Provider<AsyncValue<List<dynamic>>>((ref) {
  final txnsAsync = ref.watch(transactionsProvider);
  final transfersAsync = ref.watch(transfersProvider);

  if (txnsAsync.isLoading || transfersAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (txnsAsync.hasError) {
    return AsyncValue.error(txnsAsync.error!, txnsAsync.stackTrace!);
  }
  if (transfersAsync.hasError) {
    return AsyncValue.error(transfersAsync.error!, transfersAsync.stackTrace!);
  }

  final txns = txnsAsync.value ?? [];
  final transfers = transfersAsync.value ?? [];

  final List<dynamic> merged = [...txns, ...transfers];
  merged.sort((a, b) {
    final dateA = a is Transaction ? a.date : (a as Transfer).date;
    final dateB = b is Transaction ? b.date : (b as Transfer).date;
    return dateB.compareTo(dateA);
  });

  return AsyncValue.data(merged);
});


// ==========================================
// BUDGETS PROVIDER
// ==========================================
class BudgetsNotifier extends StateNotifier<AsyncValue<List<Budget>>> {
  final FinanceRepository _repo;
  DateTime _currentMonth;

  BudgetsNotifier(this._repo)
    : _currentMonth = DateTime.now(),
      super(const AsyncValue.loading()) {
    refresh();
  }

  DateTime get currentMonth => _currentMonth;

  void changeMonth(DateTime month) {
    _currentMonth = month;
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getBudgets(_currentMonth);
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addBudget(int categoryId, int amountLimit) async {
    final budget = Budget()
      ..uuid = ''
      ..categoryId = categoryId
      ..amountLimit = amountLimit
      ..period = _currentMonth
      ..createdAt = DateTime.now();

    await _repo.saveBudget(budget);
    await refresh();
  }

  Future<void> deleteBudget(int id) async {
    await _repo.softDeleteBudget(id);
    await refresh();
  }
}

final budgetsProvider =
    StateNotifierProvider<BudgetsNotifier, AsyncValue<List<Budget>>>((ref) {
      final repo = ref.watch(financeRepositoryProvider);
      return BudgetsNotifier(repo);
    });

// Spending per category in selected month
final budgetUsageProvider = FutureProvider.family<int, int>((
  ref,
  categoryId,
) async {
  final repo = ref.watch(financeRepositoryProvider);
  final currentMonth = ref.watch(budgetsProvider.notifier).currentMonth;
  // Invalidate when transactions update
  ref.watch(transactionsProvider);

  return await repo.getCategorySpendingForMonth(categoryId, currentMonth);
});

// ==========================================
// CATEGORIES PROVIDERS
// ==========================================
final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return await repo.getCategories('income');
});

final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return await repo.getCategories('expense');
});

final accountByIdProvider = FutureProvider.family<Account?, int>((
  ref,
  accountId,
) async {
  final repo = ref.watch(financeRepositoryProvider);
  ref.watch(accountsProvider);
  return await repo.getAccount(accountId);
});

final categoryByIdProvider = FutureProvider.family<Category?, int>((
  ref,
  categoryId,
) async {
  final repo = ref.watch(financeRepositoryProvider);
  ref.watch(incomeCategoriesProvider);
  ref.watch(expenseCategoriesProvider);
  return await repo.getCategory(categoryId);
});
