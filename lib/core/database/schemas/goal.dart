import 'package:isar/isar.dart';

part 'goal.g.dart';

@collection
class Goal {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late String name;
  late int targetAmount;
  DateTime? deadline;
  late String description;
  late String status; // active, completed, overdue, archived
  DateTime createdAt = DateTime.now();
  DateTime? deletedAt;
}
