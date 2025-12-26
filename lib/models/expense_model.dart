import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String expenseId;
  final String systemId;
  final double amount;
  final String paidBy;
  final String paidByName;
  final String category; // groceries, utilities, gas, etc.
  final DateTime date;
  final String? receiptURL;
  final String splitMethod; // "equal" or "mealBased"
  final List<String>? relatedMeals; // For meal-based splitting
  final String? description;
  final DateTime createdAt;

  ExpenseModel({
    required this.expenseId,
    required this.systemId,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    required this.category,
    required this.date,
    this.receiptURL,
    this.splitMethod = 'mealBased',
    this.relatedMeals,
    this.description,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'systemId': systemId,
      'amount': amount,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'category': category,
      'date': Timestamp.fromDate(date),
      'receiptURL': receiptURL,
      'splitMethod': splitMethod,
      'relatedMeals': relatedMeals,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Map
  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      expenseId: map['expenseId'] ?? '',
      systemId: map['systemId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paidBy: map['paidBy'] ?? '',
      paidByName: map['paidByName'] ?? '',
      category: map['category'] ?? ExpenseCategory.groceries,
      date: (map['date'] as Timestamp).toDate(),
      receiptURL: map['receiptURL'],
      splitMethod: map['splitMethod'] ?? 'mealBased',
      relatedMeals: map['relatedMeals'] != null 
          ? List<String>.from(map['relatedMeals']) 
          : null,
      description: map['description'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Create from DocumentSnapshot
  factory ExpenseModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel.fromMap(data);
  }

  // Copy with updated fields
  ExpenseModel copyWith({
    String? expenseId,
    String? systemId,
    double? amount,
    String? paidBy,
    String? paidByName,
    String? category,
    DateTime? date,
    String? receiptURL,
    String? splitMethod,
    List<String>? relatedMeals,
    String? description,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      systemId: systemId ?? this.systemId,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      paidByName: paidByName ?? this.paidByName,
      category: category ?? this.category,
      date: date ?? this.date,
      receiptURL: receiptURL ?? this.receiptURL,
      splitMethod: splitMethod ?? this.splitMethod,
      relatedMeals: relatedMeals ?? this.relatedMeals,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ExpenseModel(amount: $amount BDT, category: $category, paidBy: $paidByName)';
  }
}

// Expense category constants
class ExpenseCategory {
  static const String groceries = 'groceries';
  static const String utilities = 'utilities';
  static const String gas = 'gas';
  static const String maintenance = 'maintenance';
  static const String other = 'other';

  static List<String> get all => [
    groceries,
    utilities,
    gas,
    maintenance,
    other,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case groceries:
        return 'Groceries';
      case utilities:
        return 'Utilities';
      case gas:
        return 'Gas';
      case maintenance:
        return 'Maintenance';
      default:
        return 'Other';
    }
  }

  static String getEmoji(String category) {
    switch (category) {
      case groceries:
        return '🛒';
      case utilities:
        return '💡';
      case gas:
        return '🔥';
      case maintenance:
        return '🔧';
      default:
        return '💰';
    }
  }
}

// Split method constants
class SplitMethod {
  static const String equal = 'equal';
  static const String mealBased = 'mealBased';
}

// Member balance calculation
class MemberBalance {
  final String userId;
  final String userName;
  final double totalPaid;
  final double totalOwed;
  final int mealsEaten;

  MemberBalance({
    required this.userId,
    required this.userName,
    required this.totalPaid,
    required this.totalOwed,
    required this.mealsEaten,
  });

  // Net balance (positive = should receive, negative = should pay)
  double get netBalance => totalPaid - totalOwed;

  // Is this person owed money?
  bool get isOwed => netBalance > 0;

  // Absolute balance amount
  double get absoluteBalance => netBalance.abs();

  @override
  String toString() {
    return 'MemberBalance(user: $userName, paid: $totalPaid, owed: $totalOwed, net: ${netBalance.toStringAsFixed(2)})';
  }
}

// Monthly expense summary
class ExpenseSummary {
  final String systemId;
  final DateTime month;
  final double totalExpenses;
  final int totalMeals;
  final double costPerMeal;
  final Map<String, MemberBalance> memberBalances;
  final List<ExpenseModel> expenses;

  ExpenseSummary({
    required this.systemId,
    required this.month,
    required this.totalExpenses,
    required this.totalMeals,
    required this.costPerMeal,
    required this.memberBalances,
    required this.expenses,
  });

  // Get members who owe money
  List<MemberBalance> get membersWhoOwe {
    return memberBalances.values
        .where((b) => b.netBalance < 0)
        .toList()
      ..sort((a, b) => a.netBalance.compareTo(b.netBalance));
  }

  // Get members who should receive money
  List<MemberBalance> get membersToReceive {
    return memberBalances.values
        .where((b) => b.netBalance > 0)
        .toList()
      ..sort((a, b) => b.netBalance.compareTo(a.netBalance));
  }

  // Get expenses by category
  Map<String, double> get expensesByCategory {
    final Map<String, double> categoryTotals = {};
    for (var expense in expenses) {
      categoryTotals[expense.category] = 
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }
    return categoryTotals;
  }

  @override
  String toString() {
    return 'ExpenseSummary(total: $totalExpenses BDT, meals: $totalMeals, perMeal: ${costPerMeal.toStringAsFixed(2)} BDT)';
  }
}

// Payment transaction (for settling balances)
class PaymentTransaction {
  final String from;
  final String fromName;
  final String to;
  final String toName;
  final double amount;

  PaymentTransaction({
    required this.from,
    required this.fromName,
    required this.to,
    required this.toName,
    required this.amount,
  });

  @override
  String toString() {
    return '$fromName pays $toName ${amount.toStringAsFixed(2)} BDT';
  }
}