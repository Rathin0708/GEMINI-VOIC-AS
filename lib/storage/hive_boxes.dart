import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/expense_model.dart';

class HiveBoxes {
  static const String expensesBoxName = 'expenses';

  static Box<ExpenseModel> getExpensesBox() =>
      Hive.box<ExpenseModel>(expensesBoxName);

  // Open all Hive boxes
  static Future<void> openBoxes() async {
    try {
      await Hive.openBox<ExpenseModel>(expensesBoxName);
    } catch (e) {
      // Re-try with clear on error
      if (kDebugMode) {
        print('Error opening Hive box: $e');
        print('Trying to recover by clearing corrupted data');
      }
      await Hive.deleteBoxFromDisk(expensesBoxName);
      await Hive.openBox<ExpenseModel>(expensesBoxName);
    }
  }

  // Add an expense to the box
  static Future<bool> addExpense(ExpenseModel expense) async {
    try {
      final box = getExpensesBox();
      await box.add(expense);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error adding expense: $e');
      return false;
    }
  }

  // Get all expenses sorted by date (newest first)
  static List<ExpenseModel> getAllExpenses() {
    try {
      final box = getExpensesBox();
      final expenses = box.values.toList();
      expenses.sort((a, b) => b.date.compareTo(a.date));
      return expenses;
    } catch (e) {
      if (kDebugMode) print('Error getting expenses: $e');
      return [];
    }
  }

  // Get total amount spent
  static double getTotalAmount() {
    try {
      final box = getExpensesBox();
      final expenses = box.values.toList();
      return expenses.fold(0, (sum, expense) => sum + expense.amount);
    } catch (e) {
      if (kDebugMode) print('Error calculating total: $e');
      return 0.0;
    }
  }

  // Delete an expense by index
  static Future<bool> deleteExpense(int index) async {
    try {
      final box = getExpensesBox();
      await box.deleteAt(index);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting expense: $e');
      return false;
    }
  }

  // Clear all expenses
  static Future<bool> clearAllExpenses() async {
    try {
      final box = getExpensesBox();
      await box.clear();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error clearing expenses: $e');
      return false;
    }
  }
}