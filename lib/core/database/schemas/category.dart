import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late String name;
  late String type; // income, expense
  late String icon; // icon identifier
  late int colorValue; // Hex color
  late bool isCustom;
  DateTime? deletedAt;
}
