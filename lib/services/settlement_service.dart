import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

// MODELS
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

  // Set loading state
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
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

  // ==================== LOAD SETTLEMENT REPORTS ====================

  Future<void> loadSettlementReports(String systemId) async {
    try {
      _setLoading(true);
      _setError(null);

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

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _setError('Failed to load reports: $e');
    }
  }

  // ==================== GENERATE REPORT ====================

  Future<SettlementReportModel?> generateMonthlyReport({
    required String systemId,
    required DateTime month,
    MealSystemModel? mealSystem, 
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Define start and end of the month
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      String formatDateForQuery(DateTime d) => 
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      // 1. Fetch Expenses
      final expenseSnapshot = await _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      // 2. Fetch Attendance
      var attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('days')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: formatDateForQuery(startOfMonth))
          .where(FieldPath.documentId, isLessThanOrEqualTo: formatDateForQuery(endOfMonth))
          .get();

      // --- CALCULATIONS START ---

      double totalExpenses = 0.0;
      Map<String, double> categoryBreakdown = {};
      Map<String, double> paidByMember = {}; 
      List<String> expenseIds = [];

      // Process Expenses using ExpenseModel
      for (var doc in expenseSnapshot.docs) {
        final expense = ExpenseModel.fromDocument(doc);

        totalExpenses += expense.amount;
        expenseIds.add(expense.expenseId);

        categoryBreakdown[expense.category] = (categoryBreakdown[expense.category] ?? 0.0) + expense.amount;

        if (expense.paidBy.isNotEmpty) {
          paidByMember[expense.paidBy] = (paidByMember[expense.paidBy] ?? 0.0) + expense.amount;
        }
      }

      // Process Attendance using AttendanceModel
      int totalMeals = 0;
      Map<String, int> mealsEatenByMember = {};

      for (var doc in attendanceSnapshot.docs) {
        final dailyRecord = AttendanceModel.fromMap(doc.id, doc.data());
        
        void countMeals(Map<String, MealAttendance> slot) {
          slot.forEach((uid, attendance) {
            if (attendance.status == AttendanceStatus.yes) {
              mealsEatenByMember[uid] = (mealsEatenByMember[uid] ?? 0) + 1;
              totalMeals++;
            }
          });
        }

        countMeals(dailyRecord.breakfast);
        countMeals(dailyRecord.lunch);
        countMeals(dailyRecord.dinner);
      }

      double costPerMeal = totalMeals > 0 ? totalExpenses / totalMeals : 0.0;

      // Build Member Settlements
      Map<String, MemberSettlement> memberSettlements = {};
      Set<String> allUserIds = {...paidByMember.keys, ...mealsEatenByMember.keys};
      
      // Resolve User Names
      Map<String, String> userNames = {};
      if (mealSystem != null) {
         mealSystem.members.forEach((uid, memberInfo) {
           userNames[uid] = memberInfo.name;
         });
      } else {
        final systemDoc = await _firestore.collection('mealSystems').doc(systemId).get();
        if (systemDoc.exists) {
          final systemData = systemDoc.data()!;
          if (systemData['members'] != null) {
            (systemData['members'] as Map<String, dynamic>).forEach((uid, mData) {
              userNames[uid] = mData['name'] ?? 'Unknown';
            });
          }
        }
      }

      for (var uid in allUserIds) {
        int meals = mealsEatenByMember[uid] ?? 0;
        double paid = paidByMember[uid] ?? 0.0;
        
        double totalOwed = meals * costPerMeal; 
        double netBalance = totalOwed - paid; 

        memberSettlements[uid] = MemberSettlement(
          userId: uid,
          userName: userNames[uid] ?? 'Member',
          mealsEaten: meals,
          totalOwed: totalOwed,
          totalPaid: paid,
          netBalance: netBalance,
          timesCooked: 0,
          payments: [],
        );
      }

      // --- CALCULATIONS END ---

      final reportId = _uuid.v4();
      final newReport = SettlementReportModel(
        reportId: reportId,
        systemId: systemId,
        month: startOfMonth,
        generatedDate: DateTime.now(),
        totalExpenses: totalExpenses,
        totalMeals: totalMeals,
        costPerMeal: costPerMeal,
        memberSettlements: memberSettlements,
        expenseIds: expenseIds,
        categoryBreakdown: categoryBreakdown,
        mostExpensiveTrip: null,
        mostActiveCook: null,
        status: 'draft',
      );

      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .set(newReport.toMap());

      _reports.insert(0, newReport);
      
      _setLoading(false);
      return newReport;

    } catch (e) {
      _setLoading(false);
      _setError('Failed to generate report: $e');
      return null;
    }
  }

  // ==================== FINALIZE REPORT ====================
  Future<bool> finalizeReport(String systemId, String reportId) async {
    return await updateReportStatus(systemId, reportId, 'finalized');
  }

  // ==================== UPDATE REPORT STATUS ====================

  Future<bool> updateReportStatus(String systemId, String reportId, String status) async {
    try {
      _setLoading(true);
      
      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .update({'status': status});

      final index = _reports.indexWhere((r) => r.reportId == reportId);
      if (index != -1) {
        final old = _reports[index];
        _reports[index] = SettlementReportModel(
          reportId: old.reportId,
          systemId: old.systemId,
          month: old.month,
          generatedDate: old.generatedDate,
          totalExpenses: old.totalExpenses,
          totalMeals: old.totalMeals,
          costPerMeal: old.costPerMeal,
          memberSettlements: old.memberSettlements,
          expenseIds: old.expenseIds,
          categoryBreakdown: old.categoryBreakdown,
          mostExpensiveTrip: old.mostExpensiveTrip,
          mostActiveCook: old.mostActiveCook,
          status: status, 
        );
        notifyListeners();
      }

      if (status == 'finalized') {
        await _createNotification(
          systemId,
          'Monthly Report Ready',
          'The settlement report has been finalized. Please check your dues.',
        );
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to update status: $e');
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
    return await markMemberAsPaid(systemId, reportId, userId, amount, method, transactionId);
  }

  Future<bool> markMemberAsPaid(
    String systemId, 
    String reportId, 
    String userId, 
    double amount,
    String method,
    String? transactionId,
  ) async {
    try {
      _setLoading(true);

      final reportIndex = _reports.indexWhere((r) => r.reportId == reportId);
      if (reportIndex == -1) return false;
      
      final report = _reports[reportIndex];
      final memberSettlement = report.memberSettlements[userId];
      
      if (memberSettlement == null) return false;

      final paymentId = _uuid.v4();
      
      // Use PaymentRecord from imported model
      final payment = PaymentRecord(
        paymentId: paymentId,
        amount: amount,
        date: DateTime.now(),
        method: method,
        transactionId: transactionId,
      );

      // Add to list
      List<PaymentRecord> currentPayments = List.from(memberSettlement.payments);
      currentPayments.add(payment);

      final updatedSettlement = MemberSettlement(
        userId: memberSettlement.userId,
        userName: memberSettlement.userName,
        mealsEaten: memberSettlement.mealsEaten,
        totalOwed: memberSettlement.totalOwed,
        totalPaid: memberSettlement.totalPaid + amount,
        netBalance: memberSettlement.netBalance - amount,
        timesCooked: memberSettlement.timesCooked,
        payments: currentPayments,
      );

      // Save Payment Record
      await _firestore
          .collection('payments')
          .doc(systemId)
          .collection('report_payments')
          .doc(paymentId)
          .set(payment.toMap());

      // Update Report
      Map<String, dynamic> updatedMembersMap = {};
      report.memberSettlements.forEach((key, value) {
        if (key == userId) {
          updatedMembersMap[key] = updatedSettlement.toMap();
        } else {
          updatedMembersMap[key] = value.toMap();
        }
      });

      await _firestore
          .collection('settlementReports')
          .doc(systemId)
          .collection('reports')
          .doc(reportId)
          .update({'memberSettlements': updatedMembersMap});

      // Update Local State
      Map<String, MemberSettlement> newSettlements = Map.from(report.memberSettlements);
      newSettlements[userId] = updatedSettlement;
      
      _reports[reportIndex] = SettlementReportModel(
        reportId: report.reportId,
        systemId: report.systemId,
        month: report.month,
        generatedDate: report.generatedDate,
        totalExpenses: report.totalExpenses,
        totalMeals: report.totalMeals,
        costPerMeal: report.costPerMeal,
        memberSettlements: newSettlements,
        expenseIds: report.expenseIds,
        categoryBreakdown: report.categoryBreakdown,
        mostExpensiveTrip: report.mostExpensiveTrip,
        mostActiveCook: report.mostActiveCook,
        status: report.status,
      );
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to mark payment: $e');
      return false;
    }
  }

  // ==================== CALCULATE SETTLEMENT TRANSACTIONS ====================
  // Generates the "Who pays Whom" list (Simplified Algorithm)
  List<SettlementTransaction> calculateSettlementTransactions(SettlementReportModel report) {
    List<SettlementTransaction> transactions = [];
    
    // 1. Separate debtors (owe money) and creditors (receive money)
    List<MemberSettlement> debtors = [];
    List<MemberSettlement> creditors = [];

    report.memberSettlements.forEach((_, member) {
      if (member.netBalance > 0.1) { // Positive balance = Owe
        debtors.add(member);
      } else if (member.netBalance < -0.1) { // Negative balance = Receive
        creditors.add(member);
      }
    });

    // Sort by amount (descending) to settle largest debts first
    debtors.sort((a, b) => b.netBalance.compareTo(a.netBalance));
    creditors.sort((a, b) => a.netBalance.compareTo(b.netBalance)); // Most negative first

    int debtorIdx = 0;
    int creditorIdx = 0;

    // Use mutable tracking for calculation
    List<double> debtorAmounts = debtors.map((d) => d.netBalance).toList();
    List<double> creditorAmounts = creditors.map((c) => c.netBalance.abs()).toList();

    while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
      double amount = 0;
      double debt = debtorAmounts[debtorIdx];
      double credit = creditorAmounts[creditorIdx];

      if (debt < credit) {
        amount = debt;
        creditorAmounts[creditorIdx] -= amount;
        debtorAmounts[debtorIdx] = 0;
        debtorIdx++;
      } else {
        amount = credit;
        debtorAmounts[debtorIdx] -= amount;
        creditorAmounts[creditorIdx] = 0;
        creditorIdx++;
      }

      if (amount > 0.01) {
        transactions.add(SettlementTransaction(
          fromUserId: debtors[debtorIdx > 0 && debtorAmounts[debtorIdx-1] == 0 ? debtorIdx-1 : debtorIdx].userId,
          fromUserName: debtors[debtorIdx > 0 && debtorAmounts[debtorIdx-1] == 0 ? debtorIdx-1 : debtorIdx].userName,
          toUserId: creditors[creditorIdx > 0 && creditorAmounts[creditorIdx-1] == 0 ? creditorIdx-1 : creditorIdx].userId,
          toUserName: creditors[creditorIdx > 0 && creditorAmounts[creditorIdx-1] == 0 ? creditorIdx-1 : creditorIdx].userName,
          amount: amount,
        ));
      }
    }

    return transactions;
  }

  // ==================== SEND REMINDERS ====================

  Future<bool> sendReminders(String systemId, String reportId) async {
    try {
      final report = _reports.firstWhere((r) => r.reportId == reportId);
      
      List<String> usersToRemind = [];
      report.memberSettlements.forEach((uid, settlement) {
        if (settlement.netBalance > 10) { 
          usersToRemind.add(uid);
        }
      });

      if (usersToRemind.isEmpty) return true;

      await _createNotification(
        systemId, 
        'Payment Reminder', 
        'Reminder sent to ${usersToRemind.length} members to clear their dues.'
      );

      return true;
    } catch (e) {
      _setError('Failed to send reminders: $e');
      return false;
    }
  }

  // ==================== CALCULATE STATISTICS ====================

  ReportStatistics calculateStatistics(SettlementReportModel report) {
    final daysInMonth = DateTime(report.month.year, report.month.month + 1, 0).day;

    final avgExpensePerDay = report.totalExpenses / daysInMonth;
    final avgMealsPerDay = report.totalMeals / daysInMonth;

    String highestCategory = 'None';
    double highestAmount = 0;

    if (report.categoryBreakdown.isNotEmpty) {
      report.categoryBreakdown.forEach((key, value) {
        if (value > highestAmount) {
          highestAmount = value;
          highestCategory = key;
        }
      });
    }

    return ReportStatistics(
      averageExpensePerDay: avgExpensePerDay,
      averageMealsPerDay: avgMealsPerDay,
      highestExpenseCategory: highestCategory,
      highestCategoryAmount: highestAmount,
      totalShoppingTrips: 0, 
      averageShoppingAmount: 0, 
    );
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
      _setError('Failed to delete report: $e');
      return false;
    }
  }

  // ==================== HELPER METHODS ====================

  Future<void> _createNotification(String systemId, String title, String body) async {
    try {
      await _firestore.collection('notifications').add({
        'systemId': systemId,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Failed to create notification: $e');
    }
  }
}