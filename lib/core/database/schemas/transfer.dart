import 'package:isar/isar.dart';

part 'transfer.g.dart';

@collection
class Transfer {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late int fromAccountId;

  @Index()
  late int toAccountId;

  late int amount;
  late DateTime date;
  late String note;
  DateTime createdAt = DateTime.now();
  DateTime? deletedAt;
}
