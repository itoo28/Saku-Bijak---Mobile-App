import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../finance_providers.dart';
import '../providers.dart';
import '../database/schemas/transaction.dart';
import '../database/schemas/goal_transaction.dart';

final financialHealthScoreProvider = FutureProvider<int>((ref) async {
  // Watch transactions, budgets, goals to recalculate on updates
  ref.watch(transactionsProvider);
  ref.watch(budgetsProvider);
  ref.watch(goalsProvider);

  final repo = ref.watch(financeRepositoryProvider);
  
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // 1. Fetch current month income & expense
  final txns = await repo.getTransactionsBetween(startOfMonth, endOfMonth);

  int income = 0;
  int expense = 0;
  for (var t in txns) {
    if (t.type == 'income') {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }

  // Factor A: Savings Rate (30 points)
  // Formula: (Income - Expense) / Income
  double savingsRateScore = 0;
  if (income > 0) {
    final savings = income - expense;
    if (savings > 0) {
      final rate = savings / income;
      // 30% savings rate gives full 30 points
      savingsRateScore = (rate / 0.3) * 30;
      if (savingsRateScore > 30) savingsRateScore = 30;
    }
  } else if (expense == 0) {
    // No activity: neutral starting score
    savingsRateScore = 15;
  }

  // Factor B: Budget Adherence (30 points)
  final budgets = await repo.getBudgets(now);
  double budgetScore = 30; // Start with full points

  if (budgets.isNotEmpty) {
    double budgetDeduction = 0;
    for (var b in budgets) {
      final spent = await repo.getCategorySpendingForMonth(b.categoryId, now);
      if (spent > b.amountLimit) {
        final overspentRatio = (spent - b.amountLimit) / b.amountLimit;
        // Deduct based on how much they overspent
        budgetDeduction += overspentRatio * (30 / budgets.length);
      }
    }
    budgetScore = 30 - budgetDeduction;
    if (budgetScore < 0) budgetScore = 0;
  } else {
    // No budgets set: default to neutral 15 points
    budgetScore = 15;
  }

  // Factor C: Goal Saving Activity (20 points)
  final goals = await repo.getGoals();
  double goalScore = 0;
  if (goals.isNotEmpty) {
    // Check if there is any goal transaction (deposit) this month
    final allGoalTxns = await repo.getAllGoalTransactions();
    final goalTxns = allGoalTxns
        .where((t) =>
            t.type == 'deposit' &&
            t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(seconds: 1))))
        .length;

    if (goalTxns > 0) {
      goalScore = 20; // Active saver
    } else {
      goalScore = 5; // Has goals but not saving this month
    }
  } else {
    // No goals set: get 10 points if they are saving generally (savingsRate > 0)
    if (savingsRateScore > 15) {
      goalScore = 10;
    }
  }

  // Factor D: Spending Trend vs Last Month (20 points)
  final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
  final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

  final lastMonthAllTxns =
      await repo.getTransactionsBetween(startOfLastMonth, endOfLastMonth);
  final lastMonthTxns =
      lastMonthAllTxns.where((t) => t.type == 'expense').toList();

  final lastMonthExpense = lastMonthTxns.fold(0, (sum, t) => sum + t.amount);
  double trendScore = 20;

  if (lastMonthExpense > 0) {
    if (expense <= lastMonthExpense) {
      trendScore = 20; // Spent less or equal
    } else {
      final increaseRatio = (expense - lastMonthExpense) / lastMonthExpense;
      trendScore = 20 - (increaseRatio * 50); // Deduct rapidly if spending spikes
      if (trendScore < 0) trendScore = 0;
    }
  } else {
    // No history for last month: default to neutral 15 points
    trendScore = 15;
  }

  final finalScore = (savingsRateScore + budgetScore + goalScore + trendScore).round();
  return finalScore.clamp(0, 100);
});
