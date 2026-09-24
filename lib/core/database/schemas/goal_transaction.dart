import 'package:isar/isar.dart';

part 'goal_transaction.g.dart';

@collection
class GoalTransaction {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late int goalId;

  @Index()
  late int accountId;

  late String type; // deposit, withdrawal
  late int amount;
  late DateTime date;
  DateTime createdAt = DateTime.now();
  DateTime? deletedAt;
}
