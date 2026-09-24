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

    test('6. Edit Transaksi (Pembaruan nominal dan penyesuaian saldo)', () async {
      final account = Account()
        ..uuid = 'acc-edit-1'
        ..name = 'BCA'
        ..accountType = 'bank'
        ..balance = 1000000
        ..currency = 'IDR'
        ..icon = 'account_balance'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final category = Category()
        ..uuid = 'cat-edit-1'
        ..name = 'Belanja'
        ..type = 'expense'
        ..icon = 'shopping_bag'
        ..colorValue = 0xFFFFFFFF
        ..isCustom = false;

      await repo.saveAccount(account);
      await repo.saveCategory(category);

      // Create initial expense: 200.000 -> balance becomes 800.000
      final txn = Transaction()
        ..uuid = 'txn-edit-1'
        ..type = 'expense'
        ..amount = 200000
        ..accountId = account.id
        ..categoryId = category.id
        ..date = DateTime.now()
        ..note = 'Belanja baju'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await repo.saveTransaction(txn);
      var acc = await repo.getAccount(account.id);
      expect(acc?.balance, 800000);

      // Edit transaction: change amount to 350.000 (an increase of 150.000)
      final editedTxn = Transaction()
        ..id = txn.id
        ..uuid = txn.uuid
        ..type = 'expense'
        ..amount = 350000
        ..accountId = account.id
        ..categoryId = category.id
        ..date = txn.date
        ..note = 'Belanja baju & celana'
        ..createdAt = txn.createdAt
        ..updatedAt = DateTime.now();

      await repo.saveTransaction(editedTxn);

      acc = await repo.getAccount(account.id);
      expect(acc?.balance, 650000); // 1.000.000 - 350.000 = 650.000

      final txns = await repo.getTransactions();
      expect(txns.length, 1);
      expect(txns.first.amount, 350000);
      expect(txns.first.note, 'Belanja baju & celana');
    });

    test('7. Edit Transfer (Pembaruan nominal transfer dan penyesuaian kedua akun)', () async {
      final acc1 = Account()
        ..uuid = 'acc-trf-1'
        ..name = 'Bank Asal'
        ..accountType = 'bank'
        ..balance = 1000000
        ..currency = 'IDR'
        ..icon = 'account_balance'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final acc2 = Account()
        ..uuid = 'acc-trf-2'
        ..name = 'Bank Tujuan'
        ..accountType = 'bank'
        ..balance = 500000
        ..currency = 'IDR'
        ..icon = 'account_balance'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await repo.saveAccount(acc1);
      await repo.saveAccount(acc2);

      // Transfer 300.000: acc1 becomes 700.000, acc2 becomes 800.000
      final trf = Transfer()
        ..uuid = 'trf-1'
        ..fromAccountId = acc1.id
        ..toAccountId = acc2.id
        ..amount = 300000
        ..date = DateTime.now()
        ..note = 'Transfer awal'
        ..createdAt = DateTime.now();

      await repo.saveTransfer(trf);

      var a1 = await repo.getAccount(acc1.id);
      var a2 = await repo.getAccount(acc2.id);
      expect(a1?.balance, 700000);
      expect(a2?.balance, 800000);

      // Edit transfer: change amount to 400.000 (100.000 more)
      final editedTrf = Transfer()
        ..id = trf.id
        ..uuid = trf.uuid
        ..fromAccountId = acc1.id
        ..toAccountId = acc2.id
        ..amount = 400000
        ..date = trf.date
        ..note = 'Transfer direvisi'
        ..createdAt = trf.createdAt;

      await repo.saveTransfer(editedTrf);

      a1 = await repo.getAccount(acc1.id);
      a2 = await repo.getAccount(acc2.id);
      expect(a1?.balance, 600000); // 1.000.000 - 400.000 = 600.000
      expect(a2?.balance, 900000); // 500.000 + 400.000 = 900.000

      final trfs = await repo.getTransfers();
      expect(trfs.length, 1);
      expect(trfs.first.amount, 400000);
      expect(trfs.first.note, 'Transfer direvisi');
    });

    test('8. Validasi Penarikan Goal (Withdrawal melebihi saldo terkunci pada akun terkait ditolak)', () async {
      final account1 = Account()
        ..uuid = 'acc-gw-1'
        ..name = 'BCA'
        ..accountType = 'bank'
        ..balance = 1000000
        ..currency = 'IDR'
        ..icon = 'account_balance'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final account2 = Account()
        ..uuid = 'acc-gw-2'
        ..name = 'Tunai'
        ..accountType = 'cash'
        ..balance = 500000
        ..currency = 'IDR'
        ..icon = 'payments'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await repo.saveAccount(account1);
      await repo.saveAccount(account2);

      final goal = Goal()
        ..uuid = 'goal-gw-1'
        ..name = 'Kamera'
        ..targetAmount = 5000000
        ..description = 'Tabungan beli kamera'
        ..status = 'active'
        ..createdAt = DateTime.now();

      await repo.saveGoal(goal);

      // Deposit 400.000 from account1
      final dep = GoalTransaction()
        ..uuid = 'gt-dep-1'
        ..goalId = goal.id
        ..accountId = account1.id
        ..type = 'deposit'
        ..amount = 400000
        ..date = DateTime.now();
      await repo.saveGoalTransaction(dep);

      // Attempt withdrawal from account2 (which has 0 locked) -> rejected
      final invalidWithdrawal = GoalTransaction()
        ..uuid = 'gt-wd-invalid'
        ..goalId = goal.id
        ..accountId = account2.id
        ..type = 'withdrawal'
        ..amount = 100000
        ..date = DateTime.now();

      expect(
        () => repo.saveGoalTransaction(invalidWithdrawal),
        throwsA(isA<StateError>()),
      );

      // Valid withdrawal from account1 for 200.000 -> accepted
      final validWithdrawal = GoalTransaction()
        ..uuid = 'gt-wd-valid'
        ..goalId = goal.id
        ..accountId = account1.id
        ..type = 'withdrawal'
        ..amount = 200000
        ..date = DateTime.now();
      await repo.saveGoalTransaction(validWithdrawal);

      final remainingLocked = await repo.getLockedBalance(account1.id);
      expect(remainingLocked, 200000);
      final goalProgress = await repo.getGoalProgressAmount(goal.id);
      expect(goalProgress, 200000);
    });

    test('9. Pencegahan Duplikasi Budget Aktif per Kategori pada Bulan yang Sama', () async {
      final category = Category()
        ..uuid = 'cat-bgt-1'
        ..name = 'Makanan'
        ..type = 'expense'
        ..icon = 'restaurant'
        ..colorValue = 0xFFFFFFFF
        ..isCustom = false;
      await repo.saveCategory(category);

      final now = DateTime.now();
      final budget1 = Budget()
        ..uuid = 'bgt-uniq-1'
        ..categoryId = category.id
        ..amountLimit = 1000000
        ..period = DateTime(now.year, now.month, 1)
        ..createdAt = now;
      await repo.saveBudget(budget1);

      // Save a second budget for same category and month with new limit
      final budget2 = Budget()
        ..uuid = 'bgt-uniq-2'
        ..categoryId = category.id
        ..amountLimit = 1500000
        ..period = DateTime(now.year, now.month, 15)
        ..createdAt = now;
      await repo.saveBudget(budget2);

      final budgets = await repo.getBudgets(now);
      expect(budgets.length, 1); // Not duplicated
      expect(budgets.first.amountLimit, 1500000); // Updated to 1.500.000
    });

    test('10. Soft-delete Akun dengan Goal Transactions tetap diarsipkan (tidak terhapus permanen)', () async {
      final account = Account()
        ..uuid = 'acc-arch-1'
        ..name = 'Rekening Tabungan'
        ..accountType = 'bank'
        ..balance = 2000000
        ..currency = 'IDR'
        ..icon = 'account_balance'
        ..colorValue = 0xFFFFFFFF
        ..isArchived = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await repo.saveAccount(account);

      final goal = Goal()
        ..uuid = 'goal-arch-1'
        ..name = 'Emergency Fund'
        ..targetAmount = 10000000
        ..description = 'Dana darurat'
        ..status = 'active'
        ..createdAt = DateTime.now();
      await repo.saveGoal(goal);

      final dep = GoalTransaction()
        ..uuid = 'gt-arch-1'
        ..goalId = goal.id
        ..accountId = account.id
        ..type = 'deposit'
        ..amount = 500000
        ..date = DateTime.now();
      await repo.saveGoalTransaction(dep);

      // Attempt soft-delete account
      await repo.softDeleteAccount(account.id);

      final checkAcc = await repo.getAccount(account.id);
      expect(checkAcc?.isArchived, true);
      expect(checkAcc?.deletedAt, isNull); // Archived, not deleted
    });
  });
}
