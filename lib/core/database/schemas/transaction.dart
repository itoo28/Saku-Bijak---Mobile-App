import 'package:isar/isar.dart';

part 'transaction.g.dart';

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late String type; // income, expense
  late int amount;

  @Index()
  late int categoryId;

  @Index()
  late int accountId;

  late DateTime date;
  late String note;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  DateTime? deletedAt;
}
