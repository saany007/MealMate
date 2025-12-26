import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/attendance_model.dart';
import 'attendance_service.dart';

class ExpenseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AttendanceService _attendanceService = AttendanceService();
  final Uuid _uuid = const Uuid();

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Set error message
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Add a new expense
  Future<bool> addExpense({
    required String systemId,
    required double amount,
    required String paidBy,
    required String paidByName,
    required String category,
    required DateTime date,
    String? receiptURL,
    String splitMethod = SplitMethod.mealBased,
    List<String>? relatedMeals,
    String? description,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final expenseId = _uuid.v4();
      final expense = ExpenseModel(
        expenseId: expenseId,
        systemId: systemId,
        amount: amount,
        paidBy: paidBy,
        paidByName: paidByName,
        category: category,
        date: date,
        receiptURL: receiptURL,
        splitMethod: splitMethod,
        relatedMeals: relatedMeals,
        description: description,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .doc(expenseId)
          .set(expense.toMap());

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to add expense: $e');
      return false;
    }
  }

  // Get expenses for a date range
  Future<List<ExpenseModel>> getExpenses({
    required String systemId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .orderBy('date', descending: true);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.limit(limit).get();

      return querySnapshot.docs
          .map((doc) => ExpenseModel.fromDocument(doc))
          .toList();
    } catch (e) {
      _setError('Failed to get expenses: $e');
      return [];
    }
  }

  // Stream expenses for a month
  Stream<List<ExpenseModel>> streamMonthlyExpenses({
    required String systemId,
    required DateTime month,
  }) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    return _firestore
        .collection('expenses')
        .doc(systemId)
        .collection('records')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ExpenseModel.fromDocument(doc)).toList();
    });
  }

  // Calculate monthly expense summary
  Future<ExpenseSummary> calculateMonthlySummary({
    required String systemId,
    required DateTime month,
    required Map<String, String> memberNames, // userId -> name mapping
  }) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      // Get expenses for the month
      final expenses = await getExpenses(
        systemId: systemId,
        startDate: firstDay,
        endDate: lastDay,
        limit: 1000,
      );

      // Calculate total expenses
      final totalExpenses = expenses.fold<double>(
        0.0,
        (sum, expense) => sum + expense.amount,
      );

      // Get attendance data for the month
      final attendanceList = await _attendanceService.getAttendanceRange(
        systemId: systemId,
        startDate: firstDay,
        endDate: lastDay,
      );

      // Calculate total meals eaten by each member
      final Map<String, int> memberMealCounts = {};
      int totalMeals = 0;

      for (var attendance in attendanceList) {
        for (var userId in memberNames.keys) {
          memberMealCounts[userId] = memberMealCounts[userId] ?? 0;

          // Count breakfast
          if (attendance.breakfast[userId]?.status == AttendanceStatus.yes) {
            memberMealCounts[userId] = memberMealCounts[userId]! + 1;
            totalMeals++;
          }

          // Count lunch
          if (attendance.lunch[userId]?.status == AttendanceStatus.yes) {
            memberMealCounts[userId] = memberMealCounts[userId]! + 1;
            totalMeals++;
          }

          // Count dinner
          if (attendance.dinner[userId]?.status == AttendanceStatus.yes) {
            memberMealCounts[userId] = memberMealCounts[userId]! + 1;
            totalMeals++;
          }
        }
      }

      // Calculate cost per meal
      final costPerMeal = totalMeals > 0 ? totalExpenses / totalMeals : 0.0;

      // Calculate how much each member paid
      final Map<String, double> memberPayments = {};
      for (var expense in expenses) {
        memberPayments[expense.paidBy] = 
            (memberPayments[expense.paidBy] ?? 0.0) + expense.amount;
      }

      // Calculate member balances
      final Map<String, MemberBalance> memberBalances = {};
      for (var userId in memberNames.keys) {
        final mealsEaten = memberMealCounts[userId] ?? 0;
        final totalOwed = mealsEaten * costPerMeal;
        final totalPaid = memberPayments[userId] ?? 0.0;

        memberBalances[userId] = MemberBalance(
          userId: userId,
          userName: memberNames[userId]!,
          totalPaid: totalPaid,
          totalOwed: totalOwed,
          mealsEaten: mealsEaten,
        );
      }

      return ExpenseSummary(
        systemId: systemId,
        month: month,
        totalExpenses: totalExpenses,
        totalMeals: totalMeals,
        costPerMeal: costPerMeal,
        memberBalances: memberBalances,
        expenses: expenses,
      );
    } catch (e) {
      _setError('Failed to calculate summary: $e');
      return ExpenseSummary(
        systemId: systemId,
        month: month,
        totalExpenses: 0.0,
        totalMeals: 0,
        costPerMeal: 0.0,
        memberBalances: {},
        expenses: [],
      );
    }
  }

  // Calculate settlement transactions (who should pay whom)
  List<PaymentTransaction> calculateSettlementTransactions(
    ExpenseSummary summary,
  ) {
    final List<PaymentTransaction> transactions = [];

    // Get lists of people who owe and who should receive
    final debtors = summary.membersWhoOwe.toList();
    final creditors = summary.membersToReceive.toList();

    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      // Amount debtor owes (absolute value)
      final debtAmount = debtor.absoluteBalance;
      // Amount creditor should receive
      final creditAmount = creditor.absoluteBalance;

      // Settle the smaller amount
      final settlementAmount = debtAmount < creditAmount ? debtAmount : creditAmount;

      transactions.add(PaymentTransaction(
        from: debtor.userId,
        fromName: debtor.userName,
        to: creditor.userId,
        toName: creditor.userName,
        amount: settlementAmount,
      ));

      // Update remaining balances
      if (debtAmount < creditAmount) {
        // Debtor fully settled, move to next debtor
        debtorIndex++;
      } else if (debtAmount > creditAmount) {
        // Creditor fully paid, move to next creditor
        creditorIndex++;
      } else {
        // Both settled, move to next pair
        debtorIndex++;
        creditorIndex++;
      }
    }

    return transactions;
  }

  // Update expense
  Future<bool> updateExpense({
    required String systemId,
    required String expenseId,
    double? amount,
    String? category,
    String? description,
    String? receiptURL,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (amount != null) updates['amount'] = amount;
      if (category != null) updates['category'] = category;
      if (description != null) updates['description'] = description;
      if (receiptURL != null) updates['receiptURL'] = receiptURL;

      if (updates.isEmpty) return true;

      await _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .doc(expenseId)
          .update(updates);

      return true;
    } catch (e) {
      _setError('Failed to update expense: $e');
      return false;
    }
  }

  // Delete expense
  Future<bool> deleteExpense({
    required String systemId,
    required String expenseId,
  }) async {
    try {
      await _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .doc(expenseId)
          .delete();

      return true;
    } catch (e) {
      _setError('Failed to delete expense: $e');
      return false;
    }
  }

  // Get expense by ID
  Future<ExpenseModel?> getExpenseById({
    required String systemId,
    required String expenseId,
  }) async {
    try {
      final doc = await _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .doc(expenseId)
          .get();

      if (doc.exists) {
        return ExpenseModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      _setError('Failed to get expense: $e');
      return null;
    }
  }

  // Get total expenses for a period
  Future<double> getTotalExpenses({
    required String systemId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final expenses = await getExpenses(
        systemId: systemId,
        startDate: startDate,
        endDate: endDate,
      );

      return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
    } catch (e) {
      return 0.0;
    }
  }

  // Get expenses by category
  Future<Map<String, double>> getExpensesByCategory({
    required String systemId,
    required DateTime month,
  }) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      final expenses = await getExpenses(
        systemId: systemId,
        startDate: firstDay,
        endDate: lastDay,
      );

      final Map<String, double> categoryTotals = {};
      for (var expense in expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0.0) + expense.amount;
      }

      return categoryTotals;
    } catch (e) {
      return {};
    }
  }
}