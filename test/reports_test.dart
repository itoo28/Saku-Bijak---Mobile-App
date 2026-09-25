import 'package:flutter_test/flutter_test.dart';
import 'package:saku_bijak/core/database/schemas/transaction.dart';

void main() {
  group('Reports Logic & Date Filtering Tests', () {
    test('1. Weekly date range spans exactly Monday 00:00 to Sunday 23:59:59.999', () {
      final sampleWednesday = DateTime(2026, 9, 23, 14, 30); // Wednesday
      final startOfWeek = sampleWednesday.subtract(Duration(days: sampleWednesday.weekday - 1));
      final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final weekEnd = weekStart.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));

      expect(weekStart.weekday, DateTime.monday);
      expect(weekStart.year, 2026);
      expect(weekStart.month, 9);
      expect(weekStart.day, 21);

      expect(weekEnd.weekday, DateTime.sunday);
      expect(weekEnd.day, 27);
      expect(weekEnd.hour, 23);
      expect(weekEnd.minute, 59);
      expect(weekEnd.second, 59);
    });

    test('2. Monthly date range spans from 1st day to last day of month', () {
      final sampleDate = DateTime(2026, 9, 15);
      final monthStart = DateTime(sampleDate.year, sampleDate.month, 1);
      final monthEnd = DateTime(sampleDate.year, sampleDate.month + 1, 1).subtract(const Duration(milliseconds: 1));

      expect(monthStart.day, 1);
      expect(monthEnd.day, 30); // September has 30 days
      expect(monthEnd.hour, 23);
      expect(monthEnd.minute, 59);
    });

    test('3. Filters transactions correctly by date interval and transaction type', () {
      final t1 = Transaction()
        ..amount = 100000
        ..type = 'expense'
        ..date = DateTime(2026, 9, 22, 10, 0); // inside week 21-27 Sept

      final t2 = Transaction()
        ..amount = 250000
        ..type = 'income'
        ..date = DateTime(2026, 9, 24, 15, 0); // inside week 21-27 Sept

      final t3 = Transaction()
        ..amount = 50000
        ..type = 'expense'
        ..date = DateTime(2026, 9, 10, 10, 0); // outside week (prior week)

      final list = [t1, t2, t3];
      final weekStart = DateTime(2026, 9, 21);
      final weekEnd = DateTime(2026, 9, 27, 23, 59, 59, 999);

      final weeklyItems = list.where((t) {
        return t.date.isAfter(weekStart.subtract(const Duration(milliseconds: 1))) &&
               t.date.isBefore(weekEnd.add(const Duration(milliseconds: 1)));
      }).toList();

      expect(weeklyItems.length, 2);
      expect(weeklyItems.contains(t1), isTrue);
      expect(weeklyItems.contains(t2), isTrue);
      expect(weeklyItems.contains(t3), isFalse);

      final weeklyExpenses = weeklyItems.where((t) => t.type == 'expense').toList();
      final weeklyIncome = weeklyItems.where((t) => t.type == 'income').toList();

      expect(weeklyExpenses.length, 1);
      expect(weeklyExpenses.first.amount, 100000);
      expect(weeklyIncome.length, 1);
      expect(weeklyIncome.first.amount, 250000);
    });

    test('4. Grouping by category aggregates totals and percentage calculation accurately', () {
      const catFood = 1;
      const catTransport = 2;

      final transactions = [
        Transaction()..amount = 70000..categoryId = catFood..type = 'expense',
        Transaction()..amount = 30000..categoryId = catFood..type = 'expense',
        Transaction()..amount = 100000..categoryId = catTransport..type = 'expense',
      ];

      final Map<int?, double> grouped = {};
      for (final t in transactions) {
        grouped[t.categoryId] = (grouped[t.categoryId] ?? 0) + t.amount;
      }

      final totalExpense = grouped.values.fold<double>(0, (sum, val) => sum + val);
      expect(totalExpense, 200000);

      final foodShare = (grouped[catFood]! / totalExpense) * 100;
      final transportShare = (grouped[catTransport]! / totalExpense) * 100;

      expect(foodShare, 50.0);
      expect(transportShare, 50.0);
    });
  });
}
