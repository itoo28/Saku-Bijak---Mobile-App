import 'package:isar/isar.dart';

part 'account.g.dart';

@collection
class Account {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late String name;
  late String accountType; // cash, bank, e-wallet
  late int balance; // total balance (available + locked)
  late String currency; // default: IDR
  late String icon; // icon name or code point
  late int colorValue; // Hex color tag
  bool isArchived = false;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  DateTime? deletedAt;
}
