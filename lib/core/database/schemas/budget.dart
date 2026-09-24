import 'package:isar/isar.dart';

part 'budget.g.dart';

@collection
class Budget {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late int categoryId;

  late int amountLimit;
  late DateTime period; // month representation, e.g., 2026-07-01 00:00:00.000Z
  DateTime createdAt = DateTime.now();
  DateTime? deletedAt;
}
