import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import 'schemas/account.dart';
import 'schemas/category.dart';
import 'schemas/transaction.dart';
import 'schemas/transfer.dart';
import 'schemas/goal.dart';
import 'schemas/goal_transaction.dart';
import 'schemas/budget.dart';

class FinanceRepository {
  final Isar? isar;
  final _uuid = const Uuid();

  // In-Memory collections for Web / testing
  final List<Account> _inMemAccounts = [];
  final List<Category> _inMemCategories = [];
  final List<Transaction> _inMemTransactions = [];
  final List<Transfer> _inMemTransfers = [];
  final List<Goal> _inMemGoals = [];
  final List<GoalTransaction> _inMemGoalTransactions = [];
  final List<Budget> _inMemBudgets = [];
  int _nextInMemId = 100;

  FinanceRepository(this.isar);

  factory FinanceRepository.inMemory() {
    final repo = FinanceRepository(null);
    repo._initInMemoryDemoData();
    return repo;
  }

  void _initInMemoryDemoData() {
    final now = DateTime.now();

    // Default categories
    _inMemCategories.addAll([
      Category()..id = 1..uuid = 'cat-inc-1'..name = 'Gaji'..type = 'income'..icon = 'payments'..colorValue = 0xFF4CAF50..isCustom = false,
      Category()..id = 2..uuid = 'cat-inc-2'..name = 'Bonus'..type = 'income'..icon = 'card_giftcard'..colorValue = 0xFFFF9800..isCustom = false,
      Category()..id = 3..uuid = 'cat-inc-3'..name = 'Freelance'..type = 'income'..icon = 'work'..colorValue = 0xFF2196F3..isCustom = false,
      Category()..id = 4..uuid = 'cat-inc-4'..name = 'Hadiah'..type = 'income'..icon = 'celebration'..colorValue = 0xFFE91E63..isCustom = false,
      Category()..id = 5..uuid = 'cat-inc-5'..name = 'Lain-lain'..type = 'income'..icon = 'more_horiz'..colorValue = 0xFF9E9E9E..isCustom = false,
      Category()..id = 6..uuid = 'cat-exp-1'..name = 'Makanan'..type = 'expense'..icon = 'restaurant'..colorValue = 0xFFFF5722..isCustom = false,
      Category()..id = 7..uuid = 'cat-exp-2'..name = 'Transportasi'..type = 'expense'..icon = 'directions_car'..colorValue = 0xFF03A9F4..isCustom = false,
      Category()..id = 8..uuid = 'cat-exp-3'..name = 'Belanja'..type = 'expense'..icon = 'shopping_bag'..colorValue = 0xFF9C27B0..isCustom = false,
      Category()..id = 9..uuid = 'cat-exp-4'..name = 'Tagihan & Utilitas'..type = 'expense'..icon = 'receipt_long'..colorValue = 0xFFF44336..isCustom = false,
      Category()..id = 10..uuid = 'cat-exp-5'..name = 'Hiburan'..type = 'expense'..icon = 'sports_esports'..colorValue = 0xFF673AB7..isCustom = false,
      Category()..id = 11..uuid = 'cat-exp-6'..name = 'Pendidikan'..type = 'expense'..icon = 'school'..colorValue = 0xFF3F51B5..isCustom = false,
      Category()..id = 12..uuid = 'cat-exp-7'..name = 'Kesehatan'..type = 'expense'..icon = 'medical_services'..colorValue = 0xFF009688..isCustom = false,
      Category()..id = 13..uuid = 'cat-exp-8'..name = 'Lain-lain'..type = 'expense'..icon = 'more_horiz'..colorValue = 0xFF607D8B..isCustom = false,
    ]);

    // Demo Accounts
    final bca = Account()
      ..id = 1
      ..uuid = 'acc-bca'
      ..name = 'BCA Utama'
      ..accountType = 'bank'
      ..balance = 15000000
      ..currency = 'IDR'
      ..icon = 'account_balance'
      ..colorValue = 0xFF1976D2
      ..isArchived = false
      ..createdAt = now.subtract(const Duration(days: 30))
      ..updatedAt = now;

    final tunai = Account()
      ..id = 2
      ..uuid = 'acc-cash'
      ..name = 'Dompet Tunai'
      ..accountType = 'cash'
      ..balance = 1500000
      ..currency = 'IDR'
      ..icon = 'payments'
      ..colorValue = 0xFF43A047
      ..isArchived = false
      ..createdAt = now.subtract(const Duration(days: 30))
      ..updatedAt = now;

    final gopay = Account()
      ..id = 3
      ..uuid = 'acc-gopay'
      ..name = 'GoPay'
      ..accountType = 'ewallet'
      ..balance = 750000
      ..currency = 'IDR'
      ..icon = 'wallet'
      ..colorValue = 0xFF00ACC1
      ..isArchived = false
      ..createdAt = now.subtract(const Duration(days: 30))
      ..updatedAt = now;

    _inMemAccounts.addAll([bca, tunai, gopay]);

    // Demo Goals
    final laptopGoal = Goal()
      ..id = 1
      ..uuid = 'goal-laptop'
      ..name = 'Laptop ASUS Gaming'
      ..targetAmount = 15000000
      ..status = 'active'
      ..deadline = now.add(const Duration(days: 90))
      ..description = 'Tabungan untuk upgrade laptop kerja'
      ..createdAt = now.subtract(const Duration(days: 20));

    final daruratGoal = Goal()
      ..id = 2
      ..uuid = 'goal-darurat'
      ..name = 'Dana Darurat'
      ..targetAmount = 10000000
      ..status = 'active'
      ..description = 'Dana siaga 3-6 bulan'
      ..createdAt = now.subtract(const Duration(days: 15));

    _inMemGoals.addAll([laptopGoal, daruratGoal]);

    // Demo Goal Transactions (Locked Savings)
    _inMemGoalTransactions.addAll([
      GoalTransaction()
        ..id = 1
        ..uuid = 'gtxn-1'
        ..goalId = 1
        ..accountId = 1 // BCA
        ..type = 'deposit'
        ..amount = 4500000
        ..date = now.subtract(const Duration(days: 10))
        ..createdAt = now.subtract(const Duration(days: 10)),
      GoalTransaction()
        ..id = 2
        ..uuid = 'gtxn-2'
        ..goalId = 2
        ..accountId = 2 // Tunai
        ..type = 'deposit'
        ..amount = 1000000
        ..date = now.subtract(const Duration(days: 8))
        ..createdAt = now.subtract(const Duration(days: 8)),
    ]);

    // Demo Transactions
    _inMemTransactions.addAll([
      Transaction()
        ..id = 1
        ..uuid = 'txn-1'
        ..type = 'income'
        ..amount = 15000000
        ..accountId = 1
        ..categoryId = 1 // Gaji
        ..note = 'Gaji Bulanan'
        ..date = now.subtract(const Duration(days: 7))
        ..createdAt = now.subtract(const Duration(days: 7))
        ..updatedAt = now,
      Transaction()
        ..id = 2
        ..uuid = 'txn-2'
        ..type = 'expense'
        ..amount = 450000
        ..accountId = 3 // GoPay
        ..categoryId = 8 // Belanja
        ..note = 'Belanja Bulanan Supermarket'
        ..date = now.subtract(const Duration(days: 3))
        ..createdAt = now.subtract(const Duration(days: 3))
        ..updatedAt = now,
      Transaction()
        ..id = 3
        ..uuid = 'txn-3'
        ..type = 'expense'
        ..amount = 85000
        ..accountId = 2 // Tunai
        ..categoryId = 6 // Makanan
        ..note = 'Makan Siang Bersama Tim'
        ..date = now.subtract(const Duration(days: 1))
        ..createdAt = now.subtract(const Duration(days: 1))
        ..updatedAt = now,
      Transaction()
        ..id = 4
        ..uuid = 'txn-4'
        ..type = 'expense'
        ..amount = 35000
        ..accountId = 3 // GoPay
        ..categoryId = 7 // Transportasi
        ..note = 'Ongkos Grab'
        ..date = now
        ..createdAt = now
        ..updatedAt = now,
    ]);

    // Demo Transfer
    _inMemTransfers.add(
      Transfer()
        ..id = 1
        ..uuid = 'trf-1'
        ..fromAccountId = 1
        ..toAccountId = 3
        ..amount = 500000
        ..note = 'Top up GoPay dari BCA'
        ..date = now.subtract(const Duration(days: 2))
        ..createdAt = now.subtract(const Duration(days: 2)),
    );

    // Demo Budgets
    _inMemBudgets.addAll([
      Budget()
        ..id = 1
        ..uuid = 'bgt-1'
        ..categoryId = 6 // Makanan
        ..amountLimit = 2500000
        ..period = DateTime(now.year, now.month, 1)
        ..createdAt = now,
      Budget()
        ..id = 2
        ..uuid = 'bgt-2'
        ..categoryId = 8 // Belanja
        ..amountLimit = 1500000
        ..period = DateTime(now.year, now.month, 1)
        ..createdAt = now,
    ]);
  }

  // ==========================================
  // ACCOUNT OPERATIONS
  // ==========================================

  Future<List<Account>> getAccounts() async {
    if (isar != null) {
      return await isar!.accounts
          .where()
          .filter()
          .deletedAtIsNull()
          .sortByCreatedAtDesc()
          .findAll();
    }
    final list = _inMemAccounts.where((a) => a.deletedAt == null).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Account?> getAccount(int id) async {
    if (isar != null) {
      return await isar!.accounts.get(id);
    }
    return _inMemAccounts.where((a) => a.id == id).firstOrNull;
  }

  Future<void> saveAccount(Account account) async {
    if (account.uuid.isEmpty) {
      account.uuid = _uuid.v4();
    }
    if (account.balance < 0 && (account.id == Isar.autoIncrement || account.id == 0)) {
      throw ArgumentError('Saldo awal tidak boleh negatif.');
    }

    if (isar != null) {
      await isar!.writeTxn(() async {
        await isar!.accounts.put(account);
      });
      return;
    }

    if (account.id == Isar.autoIncrement || account.id == 0) {
      account.id = _nextInMemId++;
      _inMemAccounts.add(account);
    } else {
      final idx = _inMemAccounts.indexWhere((a) => a.id == account.id);
      if (idx >= 0) {
        _inMemAccounts[idx] = account;
      } else {
        _inMemAccounts.add(account);
      }
    }
  }

  Future<void> softDeleteAccount(int id) async {
    if (isar != null) {
      final account = await isar!.accounts.get(id);
      if (account == null) return;

      final transactionCount = await isar!.transactions
          .where()
          .filter()
          .accountIdEqualTo(id)
          .deletedAtIsNull()
          .count();

      final transferCount = await isar!.transfers
          .where()
          .filter()
          .fromAccountIdEqualTo(id)
          .or()
          .toAccountIdEqualTo(id)
          .and()
          .deletedAtIsNull()
          .count();

      await isar!.writeTxn(() async {
        if (transactionCount > 0 || transferCount > 0) {
          account.isArchived = true;
          account.updatedAt = DateTime.now();
          await isar!.accounts.put(account);
        } else {
          account.deletedAt = DateTime.now();
          account.updatedAt = DateTime.now();
          await isar!.accounts.put(account);
        }
      });
      return;
    }

    final account = await getAccount(id);
    if (account == null) return;

    final hasTxns = _inMemTransactions.any((t) => t.accountId == id && t.deletedAt == null);
    final hasTrfs = _inMemTransfers.any((t) => (t.fromAccountId == id || t.toAccountId == id) && t.deletedAt == null);

    if (hasTxns || hasTrfs) {
      account.isArchived = true;
      account.updatedAt = DateTime.now();
    } else {
      account.deletedAt = DateTime.now();
      account.updatedAt = DateTime.now();
    }
  }

  Future<int> getLockedBalance(int accountId) async {
    if (isar != null) {
      final goalTxns = await isar!.goalTransactions
          .where()
          .filter()
          .accountIdEqualTo(accountId)
          .deletedAtIsNull()
          .findAll();

      int totalLocked = 0;
      for (var txn in goalTxns) {
        if (txn.type == 'deposit') {
          totalLocked += txn.amount;
        } else if (txn.type == 'withdrawal') {
          totalLocked -= txn.amount;
        }
      }
      return totalLocked >= 0 ? totalLocked : 0;
    }

    final goalTxns = _inMemGoalTransactions.where((t) => t.accountId == accountId && t.deletedAt == null);
    int totalLocked = 0;
    for (var txn in goalTxns) {
      if (txn.type == 'deposit') {
        totalLocked += txn.amount;
      } else if (txn.type == 'withdrawal') {
        totalLocked -= txn.amount;
      }
    }
    return totalLocked >= 0 ? totalLocked : 0;
  }

  Future<int> getAvailableBalance(int accountId) async {
    final account = await getAccount(accountId);
    if (account == null) return 0;
    final locked = await getLockedBalance(accountId);
    return account.balance - locked;
  }

  // ==========================================
  // TRANSACTION OPERATIONS (Income / Expense)
  // ==========================================

  Future<List<Transaction>> getTransactions({String? type, int? accountId, int? categoryId}) async {
    if (isar != null) {
      var query = isar!.transactions.filter().deletedAtIsNull();
      if (type != null) {
        query = query.typeEqualTo(type);
      }
      if (accountId != null) {
        query = query.accountIdEqualTo(accountId);
      }
      if (categoryId != null) {
        query = query.categoryIdEqualTo(categoryId);
      }
      return await query.sortByDateDesc().findAll();
    }

    var list = _inMemTransactions.where((t) => t.deletedAt == null).toList();
    if (type != null) {
      list = list.where((t) => t.type == type).toList();
    }
    if (accountId != null) {
      list = list.where((t) => t.accountId == accountId).toList();
    }
    if (categoryId != null) {
      list = list.where((t) => t.categoryId == categoryId).toList();
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveTransaction(Transaction transaction, {bool forceNegative = false}) async {
    if (transaction.uuid.isEmpty) {
      transaction.uuid = _uuid.v4();
    }

    final account = await getAccount(transaction.accountId);
    if (account == null) throw ArgumentError('Akun tidak ditemukan.');

    if (transaction.type == 'expense') {
      final available = await getAvailableBalance(transaction.accountId);
      int previousAmount = 0;
      if (transaction.id != Isar.autoIncrement && transaction.id != 0) {
        final existing = isar != null
            ? await isar!.transactions.get(transaction.id)
            : _inMemTransactions.where((t) => t.id == transaction.id).firstOrNull;
        if (existing != null && existing.deletedAt == null && existing.accountId == transaction.accountId) {
          previousAmount = existing.amount;
        }
      }

      final netAmount = transaction.amount - previousAmount;
      if (netAmount > available && !forceNegative) {
        throw StateError('SALDO_KURANG');
      }
    }

    if (isar != null) {
      await isar!.writeTxn(() async {
        if (transaction.id != Isar.autoIncrement && transaction.id != 0) {
          final oldTxn = await isar!.transactions.get(transaction.id);
          if (oldTxn != null && oldTxn.deletedAt == null) {
            final oldAccount = await isar!.accounts.get(oldTxn.accountId);
            if (oldAccount != null) {
              if (oldTxn.type == 'income') {
                oldAccount.balance -= oldTxn.amount;
              } else {
                oldAccount.balance += oldTxn.amount;
              }
              await isar!.accounts.put(oldAccount);
            }
          }
        }

        if (transaction.type == 'income') {
          account.balance += transaction.amount;
        } else {
          account.balance -= transaction.amount;
        }
        account.updatedAt = DateTime.now();

        await isar!.accounts.put(account);
        await isar!.transactions.put(transaction);
      });
      return;
    }

    // In-memory logic
    if (transaction.id != Isar.autoIncrement && transaction.id != 0) {
      final oldTxn = _inMemTransactions.where((t) => t.id == transaction.id).firstOrNull;
      if (oldTxn != null && oldTxn.deletedAt == null) {
        final oldAccount = await getAccount(oldTxn.accountId);
        if (oldAccount != null) {
          if (oldTxn.type == 'income') {
            oldAccount.balance -= oldTxn.amount;
          } else {
            oldAccount.balance += oldTxn.amount;
          }
        }
      }
    }

    if (transaction.type == 'income') {
      account.balance += transaction.amount;
    } else {
      account.balance -= transaction.amount;
    }
    account.updatedAt = DateTime.now();

    if (transaction.id == Isar.autoIncrement || transaction.id == 0) {
      transaction.id = _nextInMemId++;
      _inMemTransactions.add(transaction);
    } else {
      final idx = _inMemTransactions.indexWhere((t) => t.id == transaction.id);
      if (idx >= 0) {
        _inMemTransactions[idx] = transaction;
      } else {
        _inMemTransactions.add(transaction);
      }
    }
  }

  Future<void> softDeleteTransaction(int id) async {
    if (isar != null) {
      final txn = await isar!.transactions.get(id);
      if (txn == null || txn.deletedAt != null) return;

      final account = await isar!.accounts.get(txn.accountId);
      if (account != null) {
        await isar!.writeTxn(() async {
          if (txn.type == 'income') {
            account.balance -= txn.amount;
          } else {
            account.balance += txn.amount;
          }
          account.updatedAt = DateTime.now();
          await isar!.accounts.put(account);

          txn.deletedAt = DateTime.now();
          txn.updatedAt = DateTime.now();
          await isar!.transactions.put(txn);
        });
      }
      return;
    }

    final txn = _inMemTransactions.where((t) => t.id == id).firstOrNull;
    if (txn == null || txn.deletedAt != null) return;
    final account = await getAccount(txn.accountId);
    if (account != null) {
      if (txn.type == 'income') {
        account.balance -= txn.amount;
      } else {
        account.balance += txn.amount;
      }
      account.updatedAt = DateTime.now();
    }
    txn.deletedAt = DateTime.now();
    txn.updatedAt = DateTime.now();
  }

  // ==========================================
  // TRANSFER OPERATIONS
  // ==========================================

  Future<List<Transfer>> getTransfers() async {
    if (isar != null) {
      return await isar!.transfers
          .where()
          .filter()
          .deletedAtIsNull()
          .sortByDateDesc()
          .findAll();
    }
    final list = _inMemTransfers.where((t) => t.deletedAt == null).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveTransfer(Transfer transfer) async {
    if (transfer.uuid.isEmpty) {
      transfer.uuid = _uuid.v4();
    }
    if (transfer.fromAccountId == transfer.toAccountId) {
      throw ArgumentError('Akun asal dan tujuan tidak boleh sama.');
    }

    final fromAcc = await getAccount(transfer.fromAccountId);
    final toAcc = await getAccount(transfer.toAccountId);
    if (fromAcc == null || toAcc == null) {
      throw ArgumentError('Akun asal atau tujuan tidak ditemukan.');
    }

    final available = await getAvailableBalance(transfer.fromAccountId);
    int previousAmount = 0;
    if (transfer.id != Isar.autoIncrement && transfer.id != 0) {
      final existing = isar != null
          ? await isar!.transfers.get(transfer.id)
          : _inMemTransfers.where((t) => t.id == transfer.id).firstOrNull;
      if (existing != null && existing.deletedAt == null && existing.fromAccountId == transfer.fromAccountId) {
        previousAmount = existing.amount;
      }
    }

    final netDebit = transfer.amount - previousAmount;
    if (netDebit > available) {
      throw StateError('SALDO_KURANG');
    }

    if (isar != null) {
      await isar!.writeTxn(() async {
        if (transfer.id != Isar.autoIncrement && transfer.id != 0) {
          final oldTrf = await isar!.transfers.get(transfer.id);
          if (oldTrf != null && oldTrf.deletedAt == null) {
            final oldFrom = await isar!.accounts.get(oldTrf.fromAccountId);
            final oldTo = await isar!.accounts.get(oldTrf.toAccountId);
            if (oldFrom != null) {
              oldFrom.balance += oldTrf.amount;
              await isar!.accounts.put(oldFrom);
            }
            if (oldTo != null) {
              oldTo.balance -= oldTrf.amount;
              await isar!.accounts.put(oldTo);
            }
          }
        }

        fromAcc.balance -= transfer.amount;
        toAcc.balance += transfer.amount;
        fromAcc.updatedAt = DateTime.now();
        toAcc.updatedAt = DateTime.now();

        await isar!.accounts.put(fromAcc);
        await isar!.accounts.put(toAcc);
        await isar!.transfers.put(transfer);
      });
      return;
    }

    // In-memory logic
    if (transfer.id != Isar.autoIncrement && transfer.id != 0) {
      final oldTrf = _inMemTransfers.where((t) => t.id == transfer.id).firstOrNull;
      if (oldTrf != null && oldTrf.deletedAt == null) {
        final oldFrom = await getAccount(oldTrf.fromAccountId);
        final oldTo = await getAccount(oldTrf.toAccountId);
        if (oldFrom != null) oldFrom.balance += oldTrf.amount;
        if (oldTo != null) oldTo.balance -= oldTrf.amount;
      }
    }

    fromAcc.balance -= transfer.amount;
    toAcc.balance += transfer.amount;
    fromAcc.updatedAt = DateTime.now();
    toAcc.updatedAt = DateTime.now();

    if (transfer.id == Isar.autoIncrement || transfer.id == 0) {
      transfer.id = _nextInMemId++;
      _inMemTransfers.add(transfer);
    } else {
      final idx = _inMemTransfers.indexWhere((t) => t.id == transfer.id);
      if (idx >= 0) {
        _inMemTransfers[idx] = transfer;
      } else {
        _inMemTransfers.add(transfer);
      }
    }
  }

  Future<void> softDeleteTransfer(int id) async {
    if (isar != null) {
      final trf = await isar!.transfers.get(id);
      if (trf == null || trf.deletedAt != null) return;

      final fromAcc = await isar!.accounts.get(trf.fromAccountId);
      final toAcc = await isar!.accounts.get(trf.toAccountId);

      await isar!.writeTxn(() async {
        if (fromAcc != null) {
          fromAcc.balance += trf.amount;
          await isar!.accounts.put(fromAcc);
        }
        if (toAcc != null) {
          toAcc.balance -= trf.amount;
          await isar!.accounts.put(toAcc);
        }

        trf.deletedAt = DateTime.now();
        await isar!.transfers.put(trf);
      });
      return;
    }

    final trf = _inMemTransfers.where((t) => t.id == id).firstOrNull;
    if (trf == null || trf.deletedAt != null) return;
    final fromAcc = await getAccount(trf.fromAccountId);
    final toAcc = await getAccount(trf.toAccountId);
    if (fromAcc != null) fromAcc.balance += trf.amount;
    if (toAcc != null) toAcc.balance -= trf.amount;
    trf.deletedAt = DateTime.now();
  }

  // ==========================================
  // GOAL OPERATIONS
  // ==========================================

  Future<List<Goal>> getGoals() async {
    if (isar != null) {
      return await isar!.goals
          .where()
          .filter()
          .deletedAtIsNull()
          .sortByCreatedAtDesc()
          .findAll();
    }
    final list = _inMemGoals.where((g) => g.deletedAt == null).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Goal?> getGoal(int id) async {
    if (isar != null) {
      return await isar!.goals.get(id);
    }
    return _inMemGoals.where((g) => g.id == id).firstOrNull;
  }

  Future<void> saveGoal(Goal goal) async {
    if (goal.uuid.isEmpty) {
      goal.uuid = _uuid.v4();
    }
    if (goal.targetAmount <= 0) {
      throw ArgumentError('Target tabungan harus lebih besar dari 0.');
    }

    if (isar != null) {
      await isar!.writeTxn(() async {
        await isar!.goals.put(goal);
      });
      return;
    }

    if (goal.id == Isar.autoIncrement || goal.id == 0) {
      goal.id = _nextInMemId++;
      _inMemGoals.add(goal);
    } else {
      final idx = _inMemGoals.indexWhere((g) => g.id == goal.id);
      if (idx >= 0) {
        _inMemGoals[idx] = goal;
      } else {
        _inMemGoals.add(goal);
      }
    }
  }

  Future<int> getGoalProgressAmount(int goalId) async {
    if (isar != null) {
      final goalTxns = await isar!.goalTransactions
          .where()
          .filter()
          .goalIdEqualTo(goalId)
          .deletedAtIsNull()
          .findAll();

      int sum = 0;
      for (var txn in goalTxns) {
        if (txn.type == 'deposit') {
          sum += txn.amount;
        } else if (txn.type == 'withdrawal') {
          sum -= txn.amount;
        }
      }
      return sum >= 0 ? sum : 0;
    }

    final goalTxns = _inMemGoalTransactions.where((t) => t.goalId == goalId && t.deletedAt == null);
    int sum = 0;
    for (var txn in goalTxns) {
      if (txn.type == 'deposit') {
        sum += txn.amount;
      } else if (txn.type == 'withdrawal') {
        sum -= txn.amount;
      }
    }
    return sum >= 0 ? sum : 0;
  }

  Future<int> getLockedBalanceForGoalAndAccount(int goalId, int accountId) async {
    if (isar != null) {
      final goalTxns = await isar!.goalTransactions
          .where()
          .filter()
          .goalIdEqualTo(goalId)
          .and()
          .accountIdEqualTo(accountId)
          .and()
          .deletedAtIsNull()
          .findAll();

      int sum = 0;
      for (var txn in goalTxns) {
        if (txn.type == 'deposit') {
          sum += txn.amount;
        } else if (txn.type == 'withdrawal') {
          sum -= txn.amount;
        }
      }
      return sum >= 0 ? sum : 0;
    }

    final goalTxns = _inMemGoalTransactions.where((t) =>
        t.goalId == goalId &&
        t.accountId == accountId &&
        t.deletedAt == null);

    int sum = 0;
    for (var txn in goalTxns) {
      if (txn.type == 'deposit') {
        sum += txn.amount;
      } else if (txn.type == 'withdrawal') {
        sum -= txn.amount;
      }
    }
    return sum >= 0 ? sum : 0;
  }

  Future<void> softDeleteGoal(int id) async {
    final currentAmount = await getGoalProgressAmount(id);
    if (currentAmount > 0) {
      throw StateError('GOAL_HAS_BALANCE');
    }

    if (isar != null) {
      final goal = await isar!.goals.get(id);
      if (goal == null) return;
      await isar!.writeTxn(() async {
        goal.deletedAt = DateTime.now();
        await isar!.goals.put(goal);
      });
      return;
    }

    final goal = await getGoal(id);
    if (goal != null) {
      goal.deletedAt = DateTime.now();
    }
  }

  Future<void> saveGoalTransaction(GoalTransaction txn) async {
    if (txn.uuid.isEmpty) {
      txn.uuid = _uuid.v4();
    }
    if (txn.amount <= 0) {
      throw ArgumentError('Nominal harus lebih dari 0.');
    }

    final goal = await getGoal(txn.goalId);
    if (goal == null) throw ArgumentError('Goal tidak ditemukan.');

    if (txn.type == 'deposit') {
      final available = await getAvailableBalance(txn.accountId);
      if (txn.amount > available) {
        throw StateError('SALDO_KURANG');
      }
    } else if (txn.type == 'withdrawal') {
      final currentProgress = await getGoalProgressAmount(txn.goalId);
      if (txn.amount > currentProgress) {
        throw StateError('NOMINAL_MELEBIHI_SALDO_GOAL');
      }
    }

    if (isar != null) {
      await isar!.writeTxn(() async {
        await isar!.goalTransactions.put(txn);
        final newProgress = await getGoalProgressAmount(txn.goalId);
        if (newProgress >= goal.targetAmount) {
          goal.status = 'completed';
          await isar!.goals.put(goal);
        } else if (goal.status == 'completed' && newProgress < goal.targetAmount) {
          goal.status = 'active';
          await isar!.goals.put(goal);
        }
      });
      return;
    }

    if (txn.id == Isar.autoIncrement || txn.id == 0) {
      txn.id = _nextInMemId++;
      _inMemGoalTransactions.add(txn);
    } else {
      final idx = _inMemGoalTransactions.indexWhere((t) => t.id == txn.id);
      if (idx >= 0) {
        _inMemGoalTransactions[idx] = txn;
      } else {
        _inMemGoalTransactions.add(txn);
      }
    }

    final newProgress = await getGoalProgressAmount(txn.goalId);
    if (newProgress >= goal.targetAmount) {
      goal.status = 'completed';
    } else if (goal.status == 'completed' && newProgress < goal.targetAmount) {
      goal.status = 'active';
    }
  }

  Future<void> softDeleteGoalTransaction(int id) async {
    if (isar != null) {
      final txn = await isar!.goalTransactions.get(id);
      if (txn == null) return;
      await isar!.writeTxn(() async {
        txn.deletedAt = DateTime.now();
        await isar!.goalTransactions.put(txn);
      });
      return;
    }

    final txn = _inMemGoalTransactions.where((t) => t.id == id).firstOrNull;
    if (txn != null) {
      txn.deletedAt = DateTime.now();
    }
  }

  // ==========================================
  // BUDGET OPERATIONS
  // ==========================================

  Future<List<Budget>> getBudgets(DateTime month) async {
    if (isar != null) {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      return await isar!.budgets
          .where()
          .filter()
          .deletedAtIsNull()
          .periodBetween(start, end)
          .findAll();
    }

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return _inMemBudgets
        .where((b) => b.deletedAt == null && b.period.isAfter(start.subtract(const Duration(seconds: 1))) && b.period.isBefore(end.add(const Duration(seconds: 1))))
        .toList();
  }

  Future<void> saveBudget(Budget budget) async {
    if (budget.uuid.isEmpty) {
      budget.uuid = _uuid.v4();
    }
    if (budget.amountLimit <= 0) {
      throw ArgumentError('Limit budget harus lebih besar dari 0.');
    }

    if (isar != null) {
      await isar!.writeTxn(() async {
        await isar!.budgets.put(budget);
      });
      return;
    }

    if (budget.id == Isar.autoIncrement || budget.id == 0) {
      budget.id = _nextInMemId++;
      _inMemBudgets.add(budget);
    } else {
      final idx = _inMemBudgets.indexWhere((b) => b.id == budget.id);
      if (idx >= 0) {
        _inMemBudgets[idx] = budget;
      } else {
        _inMemBudgets.add(budget);
      }
    }
  }

  Future<void> softDeleteBudget(int id) async {
    if (isar != null) {
      final budget = await isar!.budgets.get(id);
      if (budget == null) return;

      await isar!.writeTxn(() async {
        budget.deletedAt = DateTime.now();
        await isar!.budgets.put(budget);
      });
      return;
    }

    final b = _inMemBudgets.where((b) => b.id == id).firstOrNull;
    if (b != null) b.deletedAt = DateTime.now();
  }

  Future<int> getCategorySpendingForMonth(int categoryId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    if (isar != null) {
      final txns = await isar!.transactions
          .where()
          .filter()
          .categoryIdEqualTo(categoryId)
          .and()
          .typeEqualTo('expense')
          .and()
          .dateBetween(start, end)
          .and()
          .deletedAtIsNull()
          .findAll();

      return txns.fold<int>(0, (sum, t) => sum + t.amount);
    }

    final txns = _inMemTransactions.where((t) =>
        t.categoryId == categoryId &&
        t.type == 'expense' &&
        t.deletedAt == null &&
        t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(end.add(const Duration(seconds: 1))));

    return txns.fold<int>(0, (sum, t) => sum + t.amount);
  }

  // ==========================================
  // CATEGORIES OPERATIONS
  // ==========================================

  Future<List<Category>> getCategories(String type) async {
    if (isar != null) {
      return await isar!.categorys
          .where()
          .filter()
          .typeEqualTo(type)
          .and()
          .deletedAtIsNull()
          .findAll();
    }
    return _inMemCategories.where((c) => c.deletedAt == null && c.type == type).toList();
  }

  Future<Category?> getCategory(int id) async {
    if (isar != null) {
      return await isar!.categorys.get(id);
    }
    return _inMemCategories.where((c) => c.id == id).firstOrNull;
  }

  Future<void> saveCategory(Category category) async {
    if (category.uuid.isEmpty) {
      category.uuid = _uuid.v4();
    }
    if (isar != null) {
      await isar!.writeTxn(() async {
        await isar!.categorys.put(category);
      });
      return;
    }

    if (category.id == Isar.autoIncrement || category.id == 0) {
      category.id = _nextInMemId++;
      _inMemCategories.add(category);
    } else {
      final idx = _inMemCategories.indexWhere((c) => c.id == category.id);
      if (idx >= 0) {
        _inMemCategories[idx] = category;
      } else {
        _inMemCategories.add(category);
      }
    }
  }

  Future<void> softDeleteCategory(int id) async {
    if (isar != null) {
      final cat = await isar!.categorys.get(id);
      if (cat == null) return;

      final txnCheck = await isar!.transactions
          .where()
          .filter()
          .categoryIdEqualTo(id)
          .deletedAtIsNull()
          .count();

      final budgetCheck = await isar!.budgets
          .where()
          .filter()
          .categoryIdEqualTo(id)
          .deletedAtIsNull()
          .count();

      if (txnCheck > 0 || budgetCheck > 0) {
        throw StateError('Kategori masih digunakan dalam transaksi atau anggaran.');
      }

      await isar!.writeTxn(() async {
        cat.deletedAt = DateTime.now();
        await isar!.categorys.put(cat);
      });
      return;
    }

    final cat = await getCategory(id);
    if (cat == null) return;
    final hasTxn = _inMemTransactions.any((t) => t.categoryId == id && t.deletedAt == null);
    final hasBgt = _inMemBudgets.any((b) => b.categoryId == id && b.deletedAt == null);
    if (hasTxn || hasBgt) {
      throw StateError('Kategori masih digunakan dalam transaksi atau anggaran.');
    }
    cat.deletedAt = DateTime.now();
  }

  // ==========================================
  // HELPER METHODS FOR AGGREGATES & RESET
  // ==========================================

  Future<List<GoalTransaction>> getGoalTransactionsForGoal(int goalId) async {
    if (isar != null) {
      return await isar!.goalTransactions
          .filter()
          .goalIdEqualTo(goalId)
          .deletedAtIsNull()
          .sortByDateDesc()
          .findAll();
    }
    final list = _inMemGoalTransactions.where((t) => t.goalId == goalId && t.deletedAt == null).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<GoalTransaction>> getGoalDepositsForGoal(int goalId) async {
    if (isar != null) {
      return await isar!.goalTransactions
          .filter()
          .goalIdEqualTo(goalId)
          .typeEqualTo('deposit')
          .deletedAtIsNull()
          .findAll();
    }
    return _inMemGoalTransactions.where((t) => t.goalId == goalId && t.type == 'deposit' && t.deletedAt == null).toList();
  }

  Future<List<Transaction>> getTransactionsBetween(DateTime start, DateTime end) async {
    if (isar != null) {
      return await isar!.transactions
          .filter()
          .deletedAtIsNull()
          .dateBetween(start, end)
          .findAll();
    }
    return _inMemTransactions.where((t) =>
        t.deletedAt == null &&
        t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
  }

  Future<List<GoalTransaction>> getAllGoalTransactions() async {
    if (isar != null) {
      return await isar!.goalTransactions
          .filter()
          .deletedAtIsNull()
          .findAll();
    }
    return _inMemGoalTransactions.where((t) => t.deletedAt == null).toList();
  }

  Future<void> clearAllData() async {
    if (isar != null) {
      await isar!.writeTxn(() async {
        await isar!.accounts.clear();
        await isar!.categorys.clear();
        await isar!.transactions.clear();
        await isar!.transfers.clear();
        await isar!.goals.clear();
        await isar!.goalTransactions.clear();
        await isar!.budgets.clear();
      });
      return;
    }
    _inMemAccounts.clear();
    _inMemCategories.clear();
    _inMemTransactions.clear();
    _inMemTransfers.clear();
    _inMemGoals.clear();
    _inMemGoalTransactions.clear();
    _inMemBudgets.clear();
  }
}
