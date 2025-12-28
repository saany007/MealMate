import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/settlement_report_model.dart';
import '../models/expense_model.dart';
import '../models/attendance_model.dart';
import '../models/meal_system_model.dart';

class SettlementService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  List<SettlementReportModel> _reports = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<SettlementReportModel> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ==================== LOAD SETTLEMENT REPORTS ====================

  Future<void> loadSettlementReports(String systemId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final QuerySnapshot snapshot = await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .orderBy('month', descending: true)
          .limit(12) // Last 12 months
          .get();

      _reports = snapshot.docs
          .map((doc) => SettlementReportModel.fromDocument(doc))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load settlement reports: ${e.toString()}';
      notifyListeners();
    }
  }

  // ==================== GENERATE MONTHLY REPORT ====================

  Future<SettlementReportModel?> generateMonthlyReport({
    required String systemId,
    required DateTime month,
    required MealSystemModel mealSystem,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Set to first day of month
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      // Fetch expenses for the month
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
          .get();

      final expenses = expensesSnapshot.docs
          .map((doc) => ExpenseModel.fromDocument(doc))
          .toList();

      // Fetch attendance for the month
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('daily')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: _formatDate(firstDay))
          .where(FieldPath.documentId, isLessThanOrEqualTo: _formatDate(lastDay))
          .get();

      // Calculate total meals and member-wise meal counts
      Map<String, int> memberMealCounts = {};
      int totalMeals = 0;

      for (var doc in attendanceSnapshot.docs) {
        final date = doc.id;
        final data = doc.data();

        // Count meals for each meal type (breakfast, lunch, dinner)
        for (var mealType in ['breakfast', 'lunch', 'dinner']) {
          if (data[mealType] != null) {
            final mealData = data[mealType] as Map<String, dynamic>;
            for (var userId in mealData.keys) {
              final attendance = mealData[userId];
              if (attendance['status'] == 'yes') {
                memberMealCounts[userId] = (memberMealCounts[userId] ?? 0) + 1;
                totalMeals++;
              }
            }
          }
        }
      }

      // Calculate total expenses
      double totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);

      // Calculate cost per meal
      double costPerMeal = totalMeals > 0 ? totalExpenses / totalMeals : 0.0;

      // Calculate member-wise paid amounts
      Map<String, double> memberPaidAmounts = {};
      for (var expense in expenses) {
        memberPaidAmounts[expense.paidBy] = 
            (memberPaidAmounts[expense.paidBy] ?? 0) + expense.amount;
      }

      // Calculate category breakdown
      Map<String, double> categoryBreakdown = {};
      for (var expense in expenses) {
        categoryBreakdown[expense.category] = 
            (categoryBreakdown[expense.category] ?? 0) + expense.amount;
      }

      // Find most expensive trip
      String? mostExpensiveTrip;
      double maxExpense = 0;
      for (var expense in expenses) {
        if (expense.amount > maxExpense) {
          maxExpense = expense.amount;
          mostExpensiveTrip = '${expense.paidByName} - ${expense.amount.toStringAsFixed(2)} BDT';
        }
      }

      // Count cooking times (would need cooking rotation data)
      Map<String, int> cookingCounts = {};

      // Create member settlements
      Map<String, MemberSettlement> memberSettlements = {};
      
      for (var entry in mealSystem.members.entries) {
        final userId = entry.key;
        final memberInfo = entry.value;
        
        final mealsEaten = memberMealCounts[userId] ?? 0;
        final totalOwed = mealsEaten * costPerMeal;
        final totalPaid = memberPaidAmounts[userId] ?? 0.0;
        final netBalance = totalPaid - totalOwed;

        memberSettlements[userId] = MemberSettlement(
          userId: userId,
          userName: memberInfo.name,
          mealsEaten: mealsEaten,
          totalOwed: totalOwed,
          totalPaid: totalPaid,
          netBalance: netBalance,
          timesCooked: cookingCounts[userId] ?? 0,
        );
      }

      // Create report
      final reportId = _uuid.v4();
      final report = SettlementReportModel(
        reportId: reportId,
        systemId: systemId,
        month: firstDay,
        generatedDate: DateTime.now(),
        totalExpenses: totalExpenses,
        totalMeals: totalMeals,
        costPerMeal: costPerMeal,
        memberSettlements: memberSettlements,
        expenseIds: expenses.map((e) => e.expenseId).toList(),
        categoryBreakdown: categoryBreakdown,
        mostExpensiveTrip: mostExpensiveTrip,
        status: SettlementStatus.draft,
      );

      // Save to Firestore
      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .set(report.toMap());

      _reports.insert(0, report);
      _isLoading = false;
      notifyListeners();

      return report;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to generate report: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // ==================== FINALIZE REPORT ====================

  Future<bool> finalizeReport(String systemId, String reportId) async {
    try {
      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .update({
        'status': SettlementStatus.finalized,
      });

      final index = _reports.indexWhere((r) => r.reportId == reportId);
      if (index != -1) {
        _reports[index] = SettlementReportModel.fromMap({
          ..._reports[index].toMap(),
          'status': SettlementStatus.finalized,
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to finalize report: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== MARK AS PAID ====================

  Future<bool> markReportAsPaid(String systemId, String reportId) async {
    try {
      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .update({
        'status': SettlementStatus.paid,
      });

      final index = _reports.indexWhere((r) => r.reportId == reportId);
      if (index != -1) {
        _reports[index] = SettlementReportModel.fromMap({
          ..._reports[index].toMap(),
          'status': SettlementStatus.paid,
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to mark as paid: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== ADD PAYMENT RECORD ====================

  Future<bool> addPaymentRecord({
    required String systemId,
    required String reportId,
    required String userId,
    required double amount,
    required String method,
    String? transactionId,
  }) async {
    try {
      final paymentId = _uuid.v4();
      final payment = PaymentRecord(
        paymentId: paymentId,
        amount: amount,
        date: DateTime.now(),
        method: method,
        transactionId: transactionId,
        status: 'completed',
      );

      // Get the report
      final reportDoc = await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .get();

      if (!reportDoc.exists) return false;

      final report = SettlementReportModel.fromDocument(reportDoc);
      
      // Update member settlement
      final memberSettlement = report.memberSettlements[userId];
      if (memberSettlement == null) return false;

      final updatedPayments = [...memberSettlement.payments, payment];
      final updatedSettlement = MemberSettlement(
        userId: memberSettlement.userId,
        userName: memberSettlement.userName,
        mealsEaten: memberSettlement.mealsEaten,
        totalOwed: memberSettlement.totalOwed,
        totalPaid: memberSettlement.totalPaid,
        netBalance: memberSettlement.netBalance,
        timesCooked: memberSettlement.timesCooked,
        payments: updatedPayments,
      );

      // Update in Firestore
      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .update({
        'memberSettlements.$userId': updatedSettlement.toMap(),
      });

      // Update local list
      final index = _reports.indexWhere((r) => r.reportId == reportId);
      if (index != -1) {
        final updatedSettlements = Map<String, MemberSettlement>.from(
          _reports[index].memberSettlements,
        );
        updatedSettlements[userId] = updatedSettlement;

        _reports[index] = SettlementReportModel(
          reportId: _reports[index].reportId,
          systemId: _reports[index].systemId,
          month: _reports[index].month,
          generatedDate: _reports[index].generatedDate,
          totalExpenses: _reports[index].totalExpenses,
          totalMeals: _reports[index].totalMeals,
          costPerMeal: _reports[index].costPerMeal,
          memberSettlements: updatedSettlements,
          expenseIds: _reports[index].expenseIds,
          categoryBreakdown: _reports[index].categoryBreakdown,
          mostExpensiveTrip: _reports[index].mostExpensiveTrip,
          mostActiveCook: _reports[index].mostActiveCook,
          status: _reports[index].status,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add payment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== DELETE REPORT ====================

  Future<bool> deleteReport(String systemId, String reportId) async {
    try {
      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .delete();

      _reports.removeWhere((r) => r.reportId == reportId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete report: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== CALCULATE SETTLEMENT TRANSACTIONS ====================

  List<SettlementTransaction> calculateSettlementTransactions(
    SettlementReportModel report,
  ) {
    List<SettlementTransaction> transactions = [];

    // Get members who owe and who should receive
    final debtors = report.membersWhoOwe.toList();
    final creditors = report.membersToReceive.toList();

    int i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final debtAmount = debtor.absoluteBalance;
      final creditAmount = creditor.absoluteBalance;

      final settleAmount = debtAmount < creditAmount ? debtAmount : creditAmount;

      transactions.add(SettlementTransaction(
        fromUserId: debtor.userId,
        fromUserName: debtor.userName,
        toUserId: creditor.userId,
        toUserName: creditor.userName,
        amount: settleAmount,
      ));

      if (debtAmount < creditAmount) {
        i++;
      } else if (debtAmount > creditAmount) {
        j++;
      } else {
        i++;
        j++;
      }
    }

    return transactions;
  }

  // ==================== STREAM REPORTS ====================

  Stream<List<SettlementReportModel>> streamSettlementReports(String systemId) {
    return _firestore
        .collection('settlementReports')
        .doc(systemId)
        .collection('reports')
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SettlementReportModel.fromDocument(doc))
          .toList();
    });
  }

  // ==================== GET REPORT BY MONTH ====================

  Future<SettlementReportModel?> getReportByMonth(
    String systemId,
    DateTime month,
  ) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
      
      final querySnapshot = await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .where('month', isEqualTo: Timestamp.fromDate(firstDay))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return SettlementReportModel.fromDocument(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      _errorMessage = 'Failed to get report: ${e.toString()}';
      return null;
    }
  }

  // ==================== CALCULATE STATISTICS ====================

  ReportStatistics calculateStatistics(SettlementReportModel report) {
    final daysInMonth = DateTime(
      report.month.year,
      report.month.month + 1,
      0,
    ).day;

    final avgExpensePerDay = report.totalExpenses / daysInMonth;
    final avgMealsPerDay = report.totalMeals / daysInMonth;

    // Find highest expense category
    String highestCategory = 'groceries';
    double highestAmount = 0;

    for (var entry in report.categoryBreakdown.entries) {
      if (entry.value > highestAmount) {
        highestAmount = entry.value;
        highestCategory = entry.key;
      }
    }

    return ReportStatistics(
      averageExpensePerDay: avgExpensePerDay,
      averageMealsPerDay: avgMealsPerDay,
      highestExpenseCategory: highestCategory,
      highestCategoryAmount: highestAmount,
      totalShoppingTrips: 0, // Would need shopping trip data
      averageShoppingAmount: 0,
    );
  }

  // ==================== HELPER METHODS ====================

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ==================== CLEAR DATA ====================

  void clearData() {
    _reports = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}