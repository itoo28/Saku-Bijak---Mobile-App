import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'schemas/account.dart';
import 'schemas/category.dart';
import 'schemas/transaction.dart';
import 'schemas/transfer.dart';
import 'schemas/goal.dart';
import 'schemas/goal_transaction.dart';
import 'schemas/budget.dart';

class DatabaseService {
  late final Isar isar;

  Future<void> init() async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    
    // We use a custom sub-directory to ensure Isar isolates its data properly
    final dbDir = dir.path;
    
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    
    // Read or generate encryption key
    String? keyHex = await secureStorage.read(key: 'isar_db_key');
    Uint8List encryptionKey;
    if (keyHex == null) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      encryptionKey = Uint8List.fromList(values);
      await secureStorage.write(key: 'isar_db_key', value: base64Url.encode(encryptionKey));
    } else {
      encryptionKey = base64Url.decode(keyHex);
    }

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
      directory: dbDir,
      name: 'saku_bijak_db',
    );

    // Seed default categories if they don't exist
    await _seedCategories();
  }

  Future<void> _seedCategories() async {
    final categoryCount = await isar.categorys.filter().deletedAtIsNull().count();
    if (categoryCount == 0) {
      final defaultCategories = [
        // Income categories
        Category()
          ..uuid = 'default-inc-salary'
          ..name = 'Gaji'
          ..type = 'income'
          ..icon = 'payments'
          ..colorValue = 0xFF4CAF50
          ..isCustom = false,
        Category()
          ..uuid = 'default-inc-bonus'
          ..name = 'Bonus'
          ..type = 'income'
          ..icon = 'card_giftcard'
          ..colorValue = 0xFFFF9800
          ..isCustom = false,
        Category()
          ..uuid = 'default-inc-freelance'
          ..name = 'Freelance'
          ..type = 'income'
          ..icon = 'work'
          ..colorValue = 0xFF2196F3
          ..isCustom = false,
        Category()
          ..uuid = 'default-inc-gift'
          ..name = 'Hadiah'
          ..type = 'income'
          ..icon = 'celebration'
          ..colorValue = 0xFFE91E63
          ..isCustom = false,
        Category()
          ..uuid = 'default-inc-other'
          ..name = 'Lain-lain'
          ..type = 'income'
          ..icon = 'more_horiz'
          ..colorValue = 0xFF9E9E9E
          ..isCustom = false,

        // Expense categories
        Category()
          ..uuid = 'default-exp-food'
          ..name = 'Makanan'
          ..type = 'expense'
          ..icon = 'restaurant'
          ..colorValue = 0xFFFF5722
          ..isCustom = false,
        Category()
          ..uuid = 'default-exp-transport'
          ..name = 'Transportasi'
          ..type = 'expense'
          ..icon = 'directions_car'
          ..colorValue = 0xFF03A9F4
          ..isCustom = false,
        Category()
          ..uuid = 'default-exp-shopping'
          ..name = 'Belanja'
          ..type = 'expense'
          ..icon = 'shopping_bag'
          ..colorValue = 0xFF9C27B0
          ..isCustom = false,
        Category()
          ..uuid = 'default-exp-bills'
          ..name = 'Tagihan & Utilitas'
          ..type = 'expense'
          ..icon = 'receipt_long'
          ..colorValue = 0xFFF44336
          ..isCustom = false,
        Category()
          ..uuid = 'default-exp-entertainment'
          ..name = 'Hiburan'
          ..type = 'expense'
          ..icon = 'sports_esports'
          ..colorValue = 0xFF673AB7
          ..isCustom = false,
        Category()
          ..uuid = 'default-exp-education'
          ..name = 'Pendidikan'
          ..type = 'expense'
          ..icon = 'school'
          ..colorValue = 0xFF3F51B5
          ..isCustom = false,
        Category()
          ..uuid = 'default-exp-health'
          ..name = 'Kesehatan'
          ..type = 'expense'
          ..icon = 'medical_services'
          ..colorValue = 0xFF009688
          ..isCustom = false,
        Category()
          ..uuid = 'default-exp-other'
          ..name = 'Lain-lain'
          ..type = 'expense'
          ..icon = 'more_horiz'
          ..colorValue = 0xFF607D8B
          ..isCustom = false,
      ];

      await isar.writeTxn(() async {
        await isar.categorys.putAll(defaultCategories);
      });
    }
  }
}
