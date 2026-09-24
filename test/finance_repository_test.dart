import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late Isar isar;
  late FinanceRepository repo;
  late Directory tempDir;

  setUpAll(() async {
    // Initialize Isar core binaries for testing
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('saku_bijak_test');
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
      name: 'test_db_${DateTime.now().millisecondsSinceEpoch}',
    );
    repo = FinanceRepository(isar);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FinanceRepository Unit Tests', () {
    test('1. Pengeluaran melebihi available balance', () async {
      // Setup: create account & category
      final account = Account()
        ..uuid = 'acc-1'
        ..name = 'Tunai'
        ..accountType = 'cash'
        ..balance = 1000000 // 1.000.000
        ..currency = 'IDR'
        ..icon = 'money'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final category = Category()
        ..uuid = 'cat-1'
        ..name = 'Makanan'
        ..type = 'expense'
        ..icon = 'restaurant'
        ..colorValue = 0xFFFFFFFF
        ..isCustom = false;

      await repo.saveAccount(account);
      await repo.saveCategory(category);

      final txn = Transaction()
        ..uuid = 'txn-1'
        ..type = 'expense'
        ..amount = 1500000 // 1.500.000 (exceeds 1.000.000)
        ..accountId = account.id
        ..categoryId = category.id
        ..date = DateTime.now()
        ..note = 'Makan mewah'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      // Test Case A: Rejected by default
      expect(
        () => repo.saveTransaction(txn),
        throwsA(isA<StateError>()),
      );

      // Test Case B: Allowed with forceNegative = true
      await repo.saveTransaction(txn, forceNegative: true);
      
      final updatedAccount = await repo.getAccount(account.id);
      expect(updatedAccount?.balance, -500000); // balance becomes -500.000
    });

    test('2. Goal Deposit & Withdrawal (Locked & Available Balance)', () async {
      final account = Account()
        ..uuid = 'acc-1'
        ..name = 'BCA'
        ..accountType = 'bank'
        ..balance = 1000000
        ..currency = 'IDR'
        ..icon = 'bank'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final goal = Goal()
        ..uuid = 'goal-1'
        ..name = 'Laptop'
        ..targetAmount = 5000000
        ..description = 'Beli laptop baru'
        ..status = 'active'
        ..createdAt = DateTime.now();

      await repo.saveAccount(account);
      await repo.saveGoal(goal);

      // Case A: Deposit 300.000
      final depositTxn = GoalTransaction()
        ..uuid = 'gt-1'
        ..goalId = goal.id
        ..accountId = account.id
        ..type = 'deposit'
        ..amount = 300000
        ..date = DateTime.now();

      await repo.saveGoalTransaction(depositTxn);

      expect(await repo.getLockedBalance(account.id), 300000);
      expect(await repo.getAvailableBalance(account.id), 700000);
      
      // Total balance in account table remains unchanged
      final accState1 = await repo.getAccount(account.id);
      expect(accState1?.balance, 1000000);

      // Case B: Withdraw 100.000
      final withdrawTxn = GoalTransaction()
        ..uuid = 'gt-2'
        ..goalId = goal.id
        ..accountId = account.id
        ..type = 'withdrawal'
        ..amount = 100000
        ..date = DateTime.now();

      await repo.saveGoalTransaction(withdrawTxn);

      expect(await repo.getLockedBalance(account.id), 200000);
      expect(await repo.getAvailableBalance(account.id), 800000);

      final accState2 = await repo.getAccount(account.id);
      expect(accState2?.balance, 1000000);
    });

    test('3. Transfer antar akun (Pengecekan Konsistensi Saldo)', () async {
      final accA = Account()
        ..uuid = 'acc-a'
        ..name = 'Dompet A'
        ..accountType = 'cash'
        ..balance = 1000000
        ..currency = 'IDR'
        ..icon = 'wallet'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final accB = Account()
        ..uuid = 'acc-b'
        ..name = 'Dompet B'
        ..accountType = 'cash'
        ..balance = 500000
        ..currency = 'IDR'
        ..icon = 'wallet'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await repo.saveAccount(accA);
      await repo.saveAccount(accB);

      final transfer = Transfer()
        ..uuid = 'tr-1'
        ..fromAccountId = accA.id
        ..toAccountId = accB.id
        ..amount = 300000
        ..date = DateTime.now()
        ..note = 'Kirim uang jajan';

      await repo.saveTransfer(transfer);

      final updatedA = await repo.getAccount(accA.id);
      final updatedB = await repo.getAccount(accB.id);

      expect(updatedA?.balance, 700000);
      expect(updatedB?.balance, 800000);
      
      // Total sum of balances remains unchanged (1.500.000)
      expect(updatedA!.balance + updatedB!.balance, 1500000);
    });

    test('4. Agregasi currentAmount Goal dan Soft-delete', () async {
      final account = Account()
        ..uuid = 'acc-1'
        ..name = 'Kas'
        ..accountType = 'cash'
        ..balance = 1000000
        ..currency = 'IDR'
        ..icon = 'money'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final goal = Goal()
        ..uuid = 'goal-1'
        ..name = 'Target Liburan'
        ..targetAmount = 2000000
        ..description = ''
        ..status = 'active'
        ..createdAt = DateTime.now();

      await repo.saveAccount(account);
      await repo.saveGoal(goal);

      // Deposit 1: 500.000
      final dep1 = GoalTransaction()
        ..uuid = 'dep-1'
        ..goalId = goal.id
        ..accountId = account.id
        ..type = 'deposit'
        ..amount = 500000
        ..date = DateTime.now();
      await repo.saveGoalTransaction(dep1);

      // Deposit 2: 300.000
      final dep2 = GoalTransaction()
        ..uuid = 'dep-2'
        ..goalId = goal.id
        ..accountId = account.id
        ..type = 'deposit'
        ..amount = 300000
        ..date = DateTime.now();
      await repo.saveGoalTransaction(dep2);

      // Withdrawal 1: 200.000
      final w1 = GoalTransaction()
        ..uuid = 'w-1'
        ..goalId = goal.id
        ..accountId = account.id
        ..type = 'withdrawal'
        ..amount = 200000
        ..date = DateTime.now();
      await repo.saveGoalTransaction(w1);

      // Current progress is 500.000 + 300.000 - 200.000 = 600.000
      expect(await repo.getGoalProgressAmount(goal.id), 600000);

      // Soft delete deposit 2 (300.000)
      await repo.softDeleteGoalTransaction(dep2.id);

      // Current progress becomes 500.000 - 200.000 = 300.000
      expect(await repo.getGoalProgressAmount(goal.id), 300000);
    });

    test('5. Backup & Restore Round-Trip', () async {
      // 1. Setup seed data
      final account = Account()
        ..uuid = 'acc-1'
        ..name = 'Tunai'
        ..accountType = 'cash'
        ..balance = 1000000
        ..currency = 'IDR'
        ..icon = 'money'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final category = Category()
        ..uuid = 'cat-1'
        ..name = 'Gaji'
        ..type = 'income'
        ..icon = 'payments'
        ..colorValue = 0xFFFFFFFF
        ..isCustom = false;

      await repo.saveAccount(account);
      await repo.saveCategory(category);

      final txn = Transaction()
        ..uuid = 'txn-1'
        ..type = 'income'
        ..amount = 200000
        ..accountId = account.id
        ..categoryId = category.id
        ..date = DateTime.now()
        ..note = 'Uang saku'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await repo.saveTransaction(txn);

      // 2. Export Backup
      final backupService = BackupService(isar);
      const passphrase = 'test_passphrase_123';
      final backupContent = await backupService.exportBackup(passphrase);

      expect(backupContent.isNotEmpty, true);

      // 3. Clear database (Simulated inside restore, but let's check)
      // 4. Restore Backup
      await backupService.importRestore(backupContent, passphrase);

      // 5. Verify restored items
      final restoredAccounts = await repo.getAccounts();
      final restoredTransactions = await repo.getTransactions();

      expect(restoredAccounts.length, 1);
      expect(restoredAccounts.first.name, 'Tunai');
      expect(restoredAccounts.first.balance, 1200000); // 1.000.000 initial + 200.000 income

      expect(restoredTransactions.length, 1);
      expect(restoredTransactions.first.amount, 200000);
      expect(restoredTransactions.first.note, 'Uang saku');
    });
  });
}
