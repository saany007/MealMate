import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementReportModel {
  final String reportId;
  final String systemId;
  final DateTime month; // First day of the month
  final DateTime generatedDate;
  final double totalExpenses;
  final int totalMeals;
  final double costPerMeal;
  final Map<String, MemberSettlement> memberSettlements;
  final List<String> expenseIds; // References to expense records
  final Map<String, double> categoryBreakdown; // groceries, utilities, etc.
  final String? mostExpensiveTrip;
  final String? mostActiveCook;
  final String status; // "draft", "finalized", "paid"

  SettlementReportModel({
    required this.reportId,
    required this.systemId,
    required this.month,
    required this.generatedDate,
    required this.totalExpenses,
    required this.totalMeals,
    required this.costPerMeal,
    required this.memberSettlements,
    required this.expenseIds,
    required this.categoryBreakdown,
    this.mostExpensiveTrip,
    this.mostActiveCook,
    this.status = 'draft',
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'systemId': systemId,
      'month': Timestamp.fromDate(month),
      'generatedDate': Timestamp.fromDate(generatedDate),
      'totalExpenses': totalExpenses,
      'totalMeals': totalMeals,
      'costPerMeal': costPerMeal,
      'memberSettlements': memberSettlements.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'expenseIds': expenseIds,
      'categoryBreakdown': categoryBreakdown,
      'mostExpensiveTrip': mostExpensiveTrip,
      'mostActiveCook': mostActiveCook,
      'status': status,
    };
  }

  // Create from Map
  factory SettlementReportModel.fromMap(Map<String, dynamic> map) {
    return SettlementReportModel(
      reportId: map['reportId'] ?? '',
      systemId: map['systemId'] ?? '',
      month: (map['month'] as Timestamp).toDate(),
      generatedDate: (map['generatedDate'] as Timestamp).toDate(),
      totalExpenses: (map['totalExpenses'] ?? 0).toDouble(),
      totalMeals: map['totalMeals'] ?? 0,
      costPerMeal: (map['costPerMeal'] ?? 0).toDouble(),
      memberSettlements: (map['memberSettlements'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          MemberSettlement.fromMap(value as Map<String, dynamic>),
        ),
      ),
      expenseIds: List<String>.from(map['expenseIds'] ?? []),
      categoryBreakdown: (map['categoryBreakdown'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      mostExpensiveTrip: map['mostExpensiveTrip'],
      mostActiveCook: map['mostActiveCook'],
      status: map['status'] ?? 'draft',
    );
  }

  // Create from DocumentSnapshot
  factory SettlementReportModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SettlementReportModel.fromMap(data);
  }

  // Get members who owe money
  List<MemberSettlement> get membersWhoOwe {
    return memberSettlements.values
        .where((m) => m.netBalance < 0)
        .toList()
      ..sort((a, b) => a.netBalance.compareTo(b.netBalance));
  }

  // Get members who should receive money
  List<MemberSettlement> get membersToReceive {
    return memberSettlements.values
        .where((m) => m.netBalance > 0)
        .toList()
      ..sort((a, b) => b.netBalance.compareTo(a.netBalance));
  }

  // Get balanced members
  List<MemberSettlement> get balancedMembers {
    return memberSettlements.values
        .where((m) => m.netBalance.abs() < 1) // Less than 1 BDT
        .toList();
  }

  // Check if report is finalized
  bool get isFinalized => status == 'finalized';

  // Check if all payments are completed
  bool get isFullyPaid => status == 'paid';

  @override
  String toString() {
    return 'SettlementReportModel(month: $month, total: $totalExpenses BDT, meals: $totalMeals)';
  }
}

class MemberSettlement {
  final String userId;
  final String userName;
  final int mealsEaten;
  final double totalOwed; // Based on meals eaten
  final double totalPaid; // What they actually paid
  final double netBalance; // totalPaid - totalOwed (positive = should receive)
  final int timesCooked;
  final List<PaymentRecord> payments; // Payments made toward settlement

  MemberSettlement({
    required this.userId,
    required this.userName,
    required this.mealsEaten,
    required this.totalOwed,
    required this.totalPaid,
    required this.netBalance,
    this.timesCooked = 0,
    this.payments = const [],
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'mealsEaten': mealsEaten,
      'totalOwed': totalOwed,
      'totalPaid': totalPaid,
      'netBalance': netBalance,
      'timesCooked': timesCooked,
      'payments': payments.map((p) => p.toMap()).toList(),
    };
  }

  // Create from Map
  factory MemberSettlement.fromMap(Map<String, dynamic> map) {
    return MemberSettlement(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      mealsEaten: map['mealsEaten'] ?? 0,
      totalOwed: (map['totalOwed'] ?? 0).toDouble(),
      totalPaid: (map['totalPaid'] ?? 0).toDouble(),
      netBalance: (map['netBalance'] ?? 0).toDouble(),
      timesCooked: map['timesCooked'] ?? 0,
      payments: map['payments'] != null
          ? (map['payments'] as List)
              .map((p) => PaymentRecord.fromMap(p as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  // Check if member owes money
  bool get owes => netBalance < 0;

  // Check if member should receive money
  bool get shouldReceive => netBalance > 0;

  // Check if member is balanced
  bool get isBalanced => netBalance.abs() < 1;

  // Get absolute balance
  double get absoluteBalance => netBalance.abs();

  // Calculate payment completion percentage
  double get paymentCompletionRate {
    if (totalOwed <= 0) return 100;
    final paid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    return (paid / totalOwed * 100).clamp(0, 100);
  }

  @override
  String toString() {
    return 'MemberSettlement(user: $userName, meals: $mealsEaten, owed: $totalOwed, paid: $totalPaid, net: $netBalance)';
  }
}

class PaymentRecord {
  final String paymentId;
  final double amount;
  final DateTime date;
  final String method; // bkash, nagad, cash, etc.
  final String? transactionId;
  final String status; // pending, completed, failed

  PaymentRecord({
    required this.paymentId,
    required this.amount,
    required this.date,
    required this.method,
    this.transactionId,
    this.status = 'completed',
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'method': method,
      'transactionId': transactionId,
      'status': status,
    };
  }

  // Create from Map
  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      paymentId: map['paymentId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      method: map['method'] ?? 'cash',
      transactionId: map['transactionId'],
      status: map['status'] ?? 'completed',
    );
  }

  @override
  String toString() {
    return 'PaymentRecord(amount: $amount BDT, method: $method, date: $date)';
  }
}

// Settlement status constants
class SettlementStatus {
  static const String draft = 'draft';
  static const String finalized = 'finalized';
  static const String paid = 'paid';

  static List<String> get all => [draft, finalized, paid];

  static String getDisplayName(String status) {
    switch (status) {
      case draft:
        return 'Draft';
      case finalized:
        return 'Finalized';
      case paid:
        return 'Paid';
      default:
        return 'Unknown';
    }
  }

  static String getEmoji(String status) {
    switch (status) {
      case draft:
        return '📝';
      case finalized:
        return '✅';
      case paid:
        return '💰';
      default:
        return '❓';
    }
  }
}

// Payment method constants
class PaymentMethod {
  static const String bkash = 'bkash';
  static const String nagad = 'nagad';
  static const String cash = 'cash';
  static const String bankTransfer = 'bank_transfer';
  static const String other = 'other';

  static List<String> get all => [bkash, nagad, cash, bankTransfer, other];

  static String getDisplayName(String method) {
    switch (method) {
      case bkash:
        return 'bKash';
      case nagad:
        return 'Nagad';
      case cash:
        return 'Cash';
      case bankTransfer:
        return 'Bank Transfer';
      case other:
        return 'Other';
      default:
        return 'Unknown';
    }
  }

  static String getEmoji(String method) {
    switch (method) {
      case bkash:
        return '📱';
      case nagad:
        return '📲';
      case cash:
        return '💵';
      case bankTransfer:
        return '🏦';
      case other:
        return '💳';
      default:
        return '💰';
    }
  }
}

// Transaction for settling balances
class SettlementTransaction {
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;

  SettlementTransaction({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
  });

  @override
  String toString() {
    return '$fromUserName pays $toUserName ${amount.toStringAsFixed(2)} BDT';
  }
}

// Report summary statistics
class ReportStatistics {
  final double averageExpensePerDay;
  final double averageMealsPerDay;
  final String highestExpenseCategory;
  final double highestCategoryAmount;
  final int totalShoppingTrips;
  final double averageShoppingAmount;

  ReportStatistics({
    required this.averageExpensePerDay,
    required this.averageMealsPerDay,
    required this.highestExpenseCategory,
    required this.highestCategoryAmount,
    required this.totalShoppingTrips,
    required this.averageShoppingAmount,
  });

  @override
  String toString() {
    return 'ReportStatistics(avgExpense/day: $averageExpensePerDay BDT, avgMeals/day: $averageMealsPerDay)';
  }
}