import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:saku_bijak/core/database/finance_repository.dart';
import 'package:saku_bijak/core/database/schemas/account.dart';
import 'package:saku_bijak/core/database/schemas/category.dart';
import 'package:saku_bijak/core/database/schemas/transaction.dart';
import 'package:saku_bijak/core/database/schemas/transfer.dart';
import 'package:saku_bijak/core/database/schemas/goal.dart';
import 'package:saku_bijak/core/database/schemas/goal_transaction.dart';
import 'package:saku_bijak/core/database/schemas/budget.dart';
import 'package:saku_bijak/core/utils/backup_service.dart';
import 'package:saku_bijak/core/security/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  late Isar isar;
  late FinanceRepository repo;
  late Directory tempDir;

  Account createAccount({
    required String uuid,
    required String name,
    required String type,
    required int balance,
  }) {
    return Account()
      ..uuid = uuid
      ..name = name
      ..accountType = type
      ..balance = balance
      ..currency = 'IDR'
      ..icon = 'account_balance'
      ..colorValue = 0xFF0077FF
      ..isArchived = false
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  Goal createGoal({
    required String uuid,
    required String name,
    required int targetAmount,
  }) {
    return Goal()
      ..uuid = uuid
      ..name = name
      ..targetAmount = targetAmount
      ..description = ''
      ..status = 'active'
      ..createdAt = DateTime.now();
  }

  Transaction createTransaction({
    required String uuid,
    required String type,
    required int amount,
    required int accountId,
    required int categoryId,
    String note = '',
  }) {
    return Transaction()
      ..uuid = uuid
      ..type = type
      ..amount = amount
      ..accountId = accountId
      ..categoryId = categoryId
      ..date = DateTime.now()
      ..note = note
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }

  Transfer createTransfer({
    required String uuid,
    required int fromAccountId,
    required int toAccountId,
    required int amount,
    String note = '',
  }) {
    return Transfer()
      ..uuid = uuid
      ..fromAccountId = fromAccountId
      ..toAccountId = toAccountId
      ..amount = amount
      ..date = DateTime.now()
      ..note = note
      ..createdAt = DateTime.now();
  }

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('saku_bijak_user_test');
    isar = await Isar.open(
      [
        AccountSchema,
        CategorySchema,
        TransactionSchema,
        TransferSchema,
        GoalSchema,
        GoalTransactionSchema,
        BudgetSchema,
      ],
      directory: tempDir.path,
      name: 'user_scenario_db_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = FinanceRepository(isar);

    // Seed default categories
    final defaultCategories = [
      Category()..uuid = 'inc-1'..name = 'Gaji'..type = 'income'..icon = 'payments'..colorValue = 0xFF4CAF50..isCustom = false,
      Category()..uuid = 'inc-2'..name = 'Bonus'..type = 'income'..icon = 'card_giftcard'..colorValue = 0xFFFF9800..isCustom = false,
      Category()..uuid = 'inc-3'..name = 'Freelance'..type = 'income'..icon = 'work'..colorValue = 0xFF2196F3..isCustom = false,
      Category()..uuid = 'exp-1'..name = 'Makanan'..type = 'expense'..icon = 'restaurant'..colorValue = 0xFFFF5722..isCustom = false,
      Category()..uuid = 'exp-2'..name = 'Transportasi'..type = 'expense'..icon = 'directions_car'..colorValue = 0xFF03A9F4..isCustom = false,
      Category()..uuid = 'exp-3'..name = 'Belanja'..type = 'expense'..icon = 'shopping_bag'..colorValue = 0xFF9C27B0..isCustom = false,
    ];
    await isar.writeTxn(() async {
      await isar.categorys.putAll(defaultCategories);
    });
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('QA User Scenario Testing Suite (Saku Bijak PRD v2.0)', () {
    test('Scenario 1: First-Time User Launch & Default Categories Seeding', () async {
      final incomeCategories = await repo.getCategories('income');
      final expenseCategories = await repo.getCategories('expense');
      
      expect(incomeCategories.isNotEmpty, true, reason: 'Kategori default income harus di-seed');
      expect(expenseCategories.isNotEmpty, true, reason: 'Kategori default expense harus di-seed');
      
      expect(incomeCategories.map((c) => c.name), containsAll(['Gaji', 'Bonus', 'Freelance']));
      expect(expenseCategories.map((c) => c.name), containsAll(['Makanan', 'Transportasi', 'Belanja']));
    });

    test('Scenario 2: Multi-Account Management (Create Bank, Cash, E-Wallet)', () async {
      final acc1 = createAccount(uuid: 'acc-1', name: 'BCA Utama', type: 'bank', balance: 10000000);
      await repo.saveAccount(acc1);

      final acc2 = createAccount(uuid: 'acc-2', name: 'Uang Tunai Dompet', type: 'cash', balance: 2000000);
      await repo.saveAccount(acc2);

      final acc3 = createAccount(uuid: 'acc-3', name: 'Gopay', type: 'e-wallet', balance: 500000);
      await repo.saveAccount(acc3);

      expect(acc1.id > 0, true);
      expect(acc2.id > 0, true);
      expect(acc3.id > 0, true);

      // Verify balances
      final accounts = await repo.getAccounts();
      expect(accounts.length, 3);
      final totalAssets = accounts.fold<int>(0, (sum, a) => sum + a.balance);
      expect(totalAssets, 12500000, reason: 'Total aset harus berjumlah Rp 12.500.000');

      // Edit Account Name
      acc1.name = 'BCA Digital';
      await repo.saveAccount(acc1);

      final updatedBca = (await repo.getAccounts()).firstWhere((a) => a.id == acc1.id);
      expect(updatedBca.name, 'BCA Digital');
    });

    test('Scenario 3: Income & Expense Recording with Balance Protection', () async {
      final acc = createAccount(uuid: 'acc-bca', name: 'BCA Digital', type: 'bank', balance: 10000000);
      await repo.saveAccount(acc);

      final incomeCategories = await repo.getCategories('income');
      final salaryCategory = incomeCategories.firstWhere((c) => c.name.contains('Gaji'));
      final expenseCategories = await repo.getCategories('expense');
      final foodCategory = expenseCategories.firstWhere((c) => c.name.contains('Makanan'));

      // Record Income Rp 5.000.000
      await repo.saveTransaction(
        createTransaction(
          uuid: 'txn-1',
          type: 'income',
          amount: 5000000,
          accountId: acc.id,
          categoryId: salaryCategory.id,
          note: 'Gaji Bulan Ini',
        ),
      );

      var available = await repo.getAvailableBalance(acc.id);
      expect(available, 15000000, reason: 'Pemasukan Rp5.000.000 membuat saldo menjadi Rp15.000.000');

      // Record Expense Rp 3.000.000
      await repo.saveTransaction(
        createTransaction(
          uuid: 'txn-2',
          type: 'expense',
          amount: 3000000,
          accountId: acc.id,
          categoryId: foodCategory.id,
          note: 'Belanja Bulanan',
        ),
      );

      available = await repo.getAvailableBalance(acc.id);
      expect(available, 12000000, reason: 'Pengeluaran Rp3.000.000 mengurangi saldo menjadi Rp12.000.000');

      // Expense exceeding available balance without force -> expect Exception
      expect(
        () async => repo.saveTransaction(
          createTransaction(
            uuid: 'txn-3',
            type: 'expense',
            amount: 20000000,
            accountId: acc.id,
            categoryId: foodCategory.id,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // Force negative expense when explicitly confirmed by user
      await repo.saveTransaction(
        createTransaction(
          uuid: 'txn-4',
          type: 'expense',
          amount: 20000000,
          accountId: acc.id,
          categoryId: foodCategory.id,
        ),
        forceNegative: true,
      );

      available = await repo.getAvailableBalance(acc.id);
      expect(available, -8000000, reason: 'Pengeluaran paksa menjadikan saldo negatif Rp -8.000.000');
    });

    test('Scenario 4: Inter-Account Transfer Balance Integrity', () async {
      final fromAcc = createAccount(uuid: 'acc-from', name: 'BCA Utama', type: 'bank', balance: 10000000);
      await repo.saveAccount(fromAcc);

      final toAcc = createAccount(uuid: 'acc-to', name: 'Gopay', type: 'e-wallet', balance: 1000000);
      await repo.saveAccount(toAcc);

      // Transfer Rp 3.000.000 from BCA to Gopay
      await repo.saveTransfer(
        Transfer()
          ..uuid = 'trf-1'
          ..fromAccountId = fromAcc.id
          ..toAccountId = toAcc.id
          ..amount = 3000000
          ..date = DateTime.now()
          ..note = 'Top Up Gopay',
      );

      final fromBal = await repo.getAvailableBalance(fromAcc.id);
      final toBal = await repo.getAvailableBalance(toAcc.id);

      expect(fromBal, 7000000, reason: 'BCA tersisa Rp7.000.000');
      expect(toBal, 4000000, reason: 'Gopay bertambah menjadi Rp4.000.000');
      expect(fromBal + toBal, 11000000, reason: 'Total saldo kedua akun tetap Rp11.000.000 (tidak bocor)');
    });

    test('Scenario 5: Goal Saving & Locked Balance Isolation', () async {
      final acc = createAccount(uuid: 'acc-bca', name: 'BCA Digital', type: 'bank', balance: 10000000);
      await repo.saveAccount(acc);

      final goal = createGoal(
        uuid: 'goal-laptop',
        name: 'Laptop Gaming',
        targetAmount: 12000000,
      );
      await repo.saveGoal(goal);

      // Deposit Rp 4.000.000 into Goal
      await repo.saveGoalTransaction(
        GoalTransaction()
          ..uuid = 'gtxn-1'
          ..goalId = goal.id
          ..accountId = acc.id
          ..type = 'deposit'
          ..amount = 4000000
          ..date = DateTime.now(),
      );

      final goalProgress = await repo.getGoalProgressAmount(goal.id);
      expect(goalProgress, 4000000, reason: 'Progres goal adalah Rp4.000.000');

      final locked = await repo.getLockedBalance(acc.id);
      final available = await repo.getAvailableBalance(acc.id);
      final total = (await repo.getAccount(acc.id))!.balance;

      expect(total, 10000000, reason: 'Total saldo fisik tetap Rp10.000.000');
      expect(locked, 4000000, reason: 'Saldo terkunci Rp4.000.000');
      expect(available, 6000000, reason: 'Saldo tersedia tinggal Rp6.000.000');

      // Attempt normal expense of Rp 7.000.000 -> Should fail because available is 6.000.000!
      final expenseCategories = await repo.getCategories('expense');
      final foodCat = expenseCategories.first;

      expect(
        () async => repo.saveTransaction(
          createTransaction(
            uuid: 'txn-fail',
            type: 'expense',
            amount: 7000000,
            accountId: acc.id,
            categoryId: foodCat.id,
          ),
        ),
        throwsA(isA<StateError>()),
        reason: 'Dana terkunci goal melindungi dari pengeluaran biasa!',
      );

      // Withdraw Rp 1.000.000 back from Goal to Account
      await repo.saveGoalTransaction(
        GoalTransaction()
          ..uuid = 'gtxn-2'
          ..goalId = goal.id
          ..accountId = acc.id
          ..type = 'withdrawal'
          ..amount = 1000000
          ..date = DateTime.now(),
      );

      final updatedProgress = await repo.getGoalProgressAmount(goal.id);
      final updatedAvailable = await repo.getAvailableBalance(acc.id);

      expect(updatedProgress, 3000000, reason: 'Progres goal berkurang menjadi Rp3.000.000');
      expect(updatedAvailable, 7000000, reason: 'Saldo tersedia bertambah menjadi Rp7.000.000');
    });

    test('Scenario 6: Budget Management & Monthly Spending Tracking', () async {
      final expenseCategories = await repo.getCategories('expense');
      final foodCat = expenseCategories.first;
      final now = DateTime.now();

      final budget = Budget()
        ..uuid = 'bgt-1'
        ..categoryId = foodCat.id
        ..amountLimit = 1500000
        ..period = now
        ..createdAt = now;

      await repo.saveBudget(budget);
      expect(budget.id > 0, true);

      final budgets = await repo.getBudgets(now);
      expect(budgets.length, 1);
      expect(budgets.first.amountLimit, 1500000);

      // Soft delete budget
      await repo.softDeleteBudget(budget.id);
      final remainingBudgets = await repo.getBudgets(now);
      expect(remainingBudgets.isEmpty, true);
    });

    test('Scenario 7: Backup & Restore Encrypted Payload Round-Trip', () async {
      // 1. Create original state
      final acc = createAccount(uuid: 'acc-orig', name: 'Mandiri Syariah', type: 'bank', balance: 25000000);
      await repo.saveAccount(acc);

      final incomeCategories = await repo.getCategories('income');
      final salaryCat = incomeCategories.first;

      await repo.saveTransaction(
        createTransaction(
          uuid: 'txn-orig',
          type: 'income',
          amount: 15000000,
          accountId: acc.id,
          categoryId: salaryCat.id,
          note: 'Bonus Tahunan',
        ),
      );

      final goal = createGoal(
        uuid: 'goal-orig',
        name: 'Rumah Impian',
        targetAmount: 500000000,
      );
      await repo.saveGoal(goal);

      await repo.saveGoalTransaction(
        GoalTransaction()
          ..uuid = 'gtxn-orig'
          ..goalId = goal.id
          ..accountId = acc.id
          ..type = 'deposit'
          ..amount = 10000000
          ..date = DateTime.now(),
      );

      // 2. Export Backup
      final backupService = BackupService(isar);
      const passphrase = 'SuperSecretKey2026!';
      final encryptedPayload = await backupService.exportBackup(passphrase);

      expect(encryptedPayload.isNotEmpty, true);

      // 3. Clear database completely
      await isar.writeTxn(() async {
        await isar.accounts.clear();
        await isar.transactions.clear();
        await isar.goals.clear();
        await isar.goalTransactions.clear();
      });

      expect((await repo.getAccounts()).isEmpty, true);
      expect((await repo.getGoals()).isEmpty, true);

      // 4. Restore Backup
      await backupService.importRestore(encryptedPayload, passphrase);

      // 5. Assert 100% Data Integrity
      final restoredAccounts = await repo.getAccounts();
      expect(restoredAccounts.length, 1);
      expect(restoredAccounts.first.name, 'Mandiri Syariah');
      expect(restoredAccounts.first.balance, 40000000); // 25.000.000 initial + 15.000.000 income

      final restoredGoals = await repo.getGoals();
      expect(restoredGoals.length, 1);
      expect(restoredGoals.first.name, 'Rumah Impian');

      final restoredGoalProgress = await repo.getGoalProgressAmount(restoredGoals.first.id);
      expect(restoredGoalProgress, 10000000);
    });

    test('Scenario 8: Security PIN Management & Hash Verification', () async {
      final security = SecurityService();
      
      // Set PIN
      await security.setPin('123456');
      expect(await security.isPinSet(), true);

      // Verify PIN
      expect(await security.verifyPin('123456'), true);
      expect(await security.verifyPin('999999'), false);

      // Delete PIN
      await security.deletePin();
      expect(await security.isPinSet(), false);
    });
  });
}
