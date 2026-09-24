import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:isar/isar.dart';
import '../database/schemas/account.dart';
import '../database/schemas/category.dart';
import '../database/schemas/transaction.dart';
import '../database/schemas/transfer.dart';
import '../database/schemas/goal.dart';
import '../database/schemas/goal_transaction.dart';
import '../database/schemas/budget.dart';

class BackupService {
  final Isar isar;

  BackupService(this.isar);

  // ==========================================
  // ENCRYPTION HELPERS
  // ==========================================

  enc.Key _deriveKey(String passphrase) {
    final bytes = sha256.convert(utf8.encode(passphrase)).bytes;
    return enc.Key(Uint8List.fromList(bytes));
  }

  String _encrypt(String plainText, String passphrase) {
    final key = _deriveKey(passphrase);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt('SBJK_VALID:$plainText', iv: iv);
    return '${iv.base64}\$${encrypted.base64}';
  }

  String _decrypt(String encryptedString, String passphrase) {
    final parts = encryptedString.split('\$');
    if (parts.length != 2) {
      throw const FormatException('Format file backup tidak valid.');
    }
    
    final iv = enc.IV.fromBase64(parts[0]);
    final encryptedText = parts[1];
    
    final key = _deriveKey(passphrase);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    final decrypted = encrypter.decrypt(
      enc.Encrypted.fromBase64(encryptedText),
      iv: iv,
    );
    
    if (!decrypted.startsWith('SBJK_VALID:')) {
      throw const FormatException('Kata sandi salah.');
    }
    
    return decrypted.substring('SBJK_VALID:'.length);
  }

  // ==========================================
  // EXPORT BACKUP
  // ==========================================

  Future<String> exportBackup(String passphrase) async {
    // Get all records (including soft-deleted for backup integrity)
    final accounts = await isar.accounts.where().findAll();
    final categories = await isar.categorys.where().findAll();
    final transactions = await isar.transactions.where().findAll();
    final transfers = await isar.transfers.where().findAll();
    final goals = await isar.goals.where().findAll();
    final goalTxns = await isar.goalTransactions.where().findAll();
    final budgets = await isar.budgets.where().findAll();

    // Map account and category IDs to UUIDs for reference
    final accountMap = {for (var a in accounts) a.id: a.uuid};
    final categoryMap = {for (var c in categories) c.id: c.uuid};
    final goalMap = {for (var g in goals) g.id: g.uuid};

    final backupMap = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => {
        'uuid': a.uuid,
        'name': a.name,
        'accountType': a.accountType,
        'balance': a.balance,
        'currency': a.currency,
        'icon': a.icon,
        'colorValue': a.colorValue,
        'isArchived': a.isArchived,
        'createdAt': a.createdAt.toIso8601String(),
        'updatedAt': a.updatedAt.toIso8601String(),
        'deletedAt': a.deletedAt?.toIso8601String(),
      }).toList(),
      'categories': categories.map((c) => {
        'uuid': c.uuid,
        'name': c.name,
        'type': c.type,
        'icon': c.icon,
        'colorValue': c.colorValue,
        'isCustom': c.isCustom,
        'deletedAt': c.deletedAt?.toIso8601String(),
      }).toList(),
      'transactions': transactions.map((t) => {
        'uuid': t.uuid,
        'type': t.type,
        'amount': t.amount,
        'categoryUuid': categoryMap[t.categoryId] ?? '',
        'accountUuid': accountMap[t.accountId] ?? '',
        'date': t.date.toIso8601String(),
        'note': t.note,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
        'deletedAt': t.deletedAt?.toIso8601String(),
      }).toList(),
      'transfers': transfers.map((t) => {
        'uuid': t.uuid,
        'fromAccountUuid': accountMap[t.fromAccountId] ?? '',
        'toAccountUuid': accountMap[t.toAccountId] ?? '',
        'amount': t.amount,
        'date': t.date.toIso8601String(),
        'note': t.note,
        'createdAt': t.createdAt.toIso8601String(),
        'deletedAt': t.deletedAt?.toIso8601String(),
      }).toList(),
      'goals': goals.map((g) => {
        'uuid': g.uuid,
        'name': g.name,
        'targetAmount': g.targetAmount,
        'deadline': g.deadline?.toIso8601String(),
        'description': g.description,
        'status': g.status,
        'createdAt': g.createdAt.toIso8601String(),
        'deletedAt': g.deletedAt?.toIso8601String(),
      }).toList(),
      'goalTransactions': goalTxns.map((gt) => {
        'uuid': gt.uuid,
        'goalUuid': goalMap[gt.goalId] ?? '',
        'accountUuid': accountMap[gt.accountId] ?? '',
        'type': gt.type,
        'amount': gt.amount,
        'date': gt.date.toIso8601String(),
        'createdAt': gt.createdAt.toIso8601String(),
        'deletedAt': gt.deletedAt?.toIso8601String(),
      }).toList(),
      'budgets': budgets.map((b) => {
        'uuid': b.uuid,
        'categoryUuid': categoryMap[b.categoryId] ?? '',
        'amountLimit': b.amountLimit,
        'period': b.period.toIso8601String(),
        'createdAt': b.createdAt.toIso8601String(),
        'deletedAt': b.deletedAt?.toIso8601String(),
      }).toList(),
    };

    final jsonStr = jsonEncode(backupMap);
    return _encrypt(jsonStr, passphrase);
  }

  // ==========================================
  // IMPORT RESTORE
  // ==========================================

  Future<void> importRestore(String encryptedData, String passphrase) async {
    final jsonStr = _decrypt(encryptedData, passphrase);
    final backupMap = jsonDecode(jsonStr) as Map<String, dynamic>;

    if (backupMap['version'] != 1) {
      throw const FormatException('Versi backup tidak didukung.');
    }

    final rawAccounts = backupMap['accounts'] as List<dynamic>;
    final rawCategories = backupMap['categories'] as List<dynamic>;
    final rawTransactions = backupMap['transactions'] as List<dynamic>;
    final rawTransfers = backupMap['transfers'] as List<dynamic>;
    final rawGoals = backupMap['goals'] as List<dynamic>;
    final rawGoalTxns = backupMap['goalTransactions'] as List<dynamic>;
    final rawBudgets = backupMap['budgets'] as List<dynamic>;

    await isar.writeTxn(() async {
      // Clear database collections
      await isar.accounts.clear();
      await isar.categorys.clear();
      await isar.transactions.clear();
      await isar.transfers.clear();
      await isar.goals.clear();
      await isar.goalTransactions.clear();
      await isar.budgets.clear();

      // Maps to track new auto-increment IDs mapped from backup UUIDs
      final accountUuidToId = <String, int>{};
      final categoryUuidToId = <String, int>{};
      final goalUuidToId = <String, int>{};

      // 1. Restore Categories
      for (var c in rawCategories) {
        final category = Category()
          ..uuid = c['uuid']
          ..name = c['name']
          ..type = c['type']
          ..icon = c['icon']
          ..colorValue = c['colorValue']
          ..isCustom = c['isCustom']
          ..deletedAt = c['deletedAt'] != null ? DateTime.parse(c['deletedAt']) : null;
        
        final id = await isar.categorys.put(category);
        categoryUuidToId[category.uuid] = id;
      }

      // 2. Restore Accounts
      for (var a in rawAccounts) {
        final account = Account()
          ..uuid = a['uuid']
          ..name = a['name']
          ..accountType = a['accountType']
          ..balance = a['balance']
          ..currency = a['currency']
          ..icon = a['icon']
          ..colorValue = a['colorValue']
          ..isArchived = a['isArchived']
          ..createdAt = DateTime.parse(a['createdAt'])
          ..updatedAt = DateTime.parse(a['updatedAt'])
          ..deletedAt = a['deletedAt'] != null ? DateTime.parse(a['deletedAt']) : null;

        final id = await isar.accounts.put(account);
        accountUuidToId[account.uuid] = id;
      }

      // 3. Restore Goals
      for (var g in rawGoals) {
        final goal = Goal()
          ..uuid = g['uuid']
          ..name = g['name']
          ..targetAmount = g['targetAmount']
          ..deadline = g['deadline'] != null ? DateTime.parse(g['deadline']) : null;
        
        // Isar requires all properties initialized, handle ones with potential updates
        goal.description = g['description'] ?? '';
        goal.status = g['status'] ?? 'active';
        goal.createdAt = DateTime.parse(g['createdAt']);
        goal.deletedAt = g['deletedAt'] != null ? DateTime.parse(g['deletedAt']) : null;

        final id = await isar.goals.put(goal);
        goalUuidToId[goal.uuid] = id;
      }

      // 4. Restore Transactions
      for (var t in rawTransactions) {
        final categoryId = categoryUuidToId[t['categoryUuid']];
        final accountId = accountUuidToId[t['accountUuid']];
        if (categoryId == null || accountId == null) continue; // Orphaned transaction

        final txn = Transaction()
          ..uuid = t['uuid']
          ..type = t['type']
          ..amount = t['amount']
          ..categoryId = categoryId
          ..accountId = accountId
          ..date = DateTime.parse(t['date'])
          ..note = t['note'] ?? ''
          ..createdAt = DateTime.parse(t['createdAt'])
          ..updatedAt = DateTime.parse(t['updatedAt'])
          ..deletedAt = t['deletedAt'] != null ? DateTime.parse(t['deletedAt']) : null;

        await isar.transactions.put(txn);
      }

      // 5. Restore Transfers
      for (var t in rawTransfers) {
        final fromId = accountUuidToId[t['fromAccountUuid']];
        final toId = accountUuidToId[t['toAccountUuid']];
        if (fromId == null || toId == null) continue;

        final transfer = Transfer()
          ..uuid = t['uuid']
          ..fromAccountId = fromId
          ..toAccountId = toId
          ..amount = t['amount']
          ..date = DateTime.parse(t['date'])
          ..note = t['note'] ?? ''
          ..createdAt = DateTime.parse(t['createdAt'])
          ..deletedAt = t['deletedAt'] != null ? DateTime.parse(t['deletedAt']) : null;

        await isar.transfers.put(transfer);
      }

      // 6. Restore GoalTransactions
      for (var gt in rawGoalTxns) {
        final goalId = goalUuidToId[gt['goalUuid']];
        final accountId = accountUuidToId[gt['accountUuid']];
        if (goalId == null || accountId == null) continue;

        final goalTxn = GoalTransaction()
          ..uuid = gt['uuid']
          ..goalId = goalId
          ..accountId = accountId
          ..type = gt['type']
          ..amount = gt['amount']
          ..date = DateTime.parse(gt['date'])
          ..createdAt = DateTime.parse(gt['createdAt'])
          ..deletedAt = gt['deletedAt'] != null ? DateTime.parse(gt['deletedAt']) : null;

        await isar.goalTransactions.put(goalTxn);
      }

      // 7. Restore Budgets
      for (var b in rawBudgets) {
        final categoryId = categoryUuidToId[b['categoryUuid']];
        if (categoryId == null) continue;

        final budget = Budget()
          ..uuid = b['uuid']
          ..categoryId = categoryId
          ..amountLimit = b['amountLimit']
          ..period = DateTime.parse(b['period'])
          ..createdAt = DateTime.parse(b['createdAt'])
          ..deletedAt = b['deletedAt'] != null ? DateTime.parse(b['deletedAt']) : null;

        await isar.budgets.put(budget);
      }
    });
  }
}
