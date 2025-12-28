import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingTripModel {
  final String tripId;
  final String systemId;
  final String assignedTo;
  final String assignedToName;
  final DateTime assignedDate;
  final DateTime? completedDate;
  final String status; // "pending", "in_progress", "completed"
  final double totalSpent;
  final String? receiptURL;
  final List<String> itemsPurchased; // List of grocery item IDs
  final String? groceryListId; // Reference to the grocery list used
  final String reimbursementStatus; // "not_applicable", "pending", "paid"
  final String? notes;
  final DateTime createdAt;

  ShoppingTripModel({
    required this.tripId,
    required this.systemId,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedDate,
    this.completedDate,
    this.status = ShoppingTripStatus.pending,
    this.totalSpent = 0.0,
    this.receiptURL,
    this.itemsPurchased = const [],
    this.groceryListId,
    this.reimbursementStatus = ReimbursementStatus.notApplicable,
    this.notes,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'systemId': systemId,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'completedDate': completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'status': status,
      'totalSpent': totalSpent,
      'receiptURL': receiptURL,
      'itemsPurchased': itemsPurchased,
      'groceryListId': groceryListId,
      'reimbursementStatus': reimbursementStatus,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Map
  factory ShoppingTripModel.fromMap(Map<String, dynamic> map) {
    return ShoppingTripModel(
      tripId: map['tripId'] ?? '',
      systemId: map['systemId'] ?? '',
      assignedTo: map['assignedTo'] ?? '',
      assignedToName: map['assignedToName'] ?? '',
      assignedDate: (map['assignedDate'] as Timestamp).toDate(),
      completedDate: map['completedDate'] != null 
          ? (map['completedDate'] as Timestamp).toDate() 
          : null,
      status: map['status'] ?? ShoppingTripStatus.pending,
      totalSpent: (map['totalSpent'] ?? 0).toDouble(),
      receiptURL: map['receiptURL'],
      itemsPurchased: map['itemsPurchased'] != null 
          ? List<String>.from(map['itemsPurchased']) 
          : [],
      groceryListId: map['groceryListId'],
      reimbursementStatus: map['reimbursementStatus'] ?? ReimbursementStatus.notApplicable,
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Create from DocumentSnapshot
  factory ShoppingTripModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShoppingTripModel.fromMap(data);
  }

  // Copy with updated fields
  ShoppingTripModel copyWith({
    String? tripId,
    String? systemId,
    String? assignedTo,
    String? assignedToName,
    DateTime? assignedDate,
    DateTime? completedDate,
    String? status,
    double? totalSpent,
    String? receiptURL,
    List<String>? itemsPurchased,
    String? groceryListId,
    String? reimbursementStatus,
    String? notes,
    DateTime? createdAt,
  }) {
    return ShoppingTripModel(
      tripId: tripId ?? this.tripId,
      systemId: systemId ?? this.systemId,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedDate: assignedDate ?? this.assignedDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      totalSpent: totalSpent ?? this.totalSpent,
      receiptURL: receiptURL ?? this.receiptURL,
      itemsPurchased: itemsPurchased ?? this.itemsPurchased,
      groceryListId: groceryListId ?? this.groceryListId,
      reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Check if trip is completed
  bool get isCompleted => status == ShoppingTripStatus.completed;

  // Check if trip is in progress
  bool get isInProgress => status == ShoppingTripStatus.inProgress;

  // Check if trip is pending
  bool get isPending => status == ShoppingTripStatus.pending;

  // Check if reimbursement is pending
  bool get needsReimbursement => 
      reimbursementStatus == ReimbursementStatus.pending && totalSpent > 0;

  // Days since assigned
  int get daysSinceAssigned {
    return DateTime.now().difference(assignedDate).inDays;
  }

  // Shopping duration (if completed)
  Duration? get shoppingDuration {
    if (completedDate != null) {
      return completedDate!.difference(assignedDate);
    }
    return null;
  }

  @override
  String toString() {
    return 'ShoppingTripModel(tripId: $tripId, assignedTo: $assignedToName, status: $status, spent: $totalSpent BDT)';
  }
}

// Status constants
class ShoppingTripStatus {
  static const String pending = 'pending';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';

  static List<String> get all => [pending, inProgress, completed];

  static String getDisplayName(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case inProgress:
        return 'In Progress';
      case completed:
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  static String getEmoji(String status) {
    switch (status) {
      case pending:
        return '⏳';
      case inProgress:
        return '🛒';
      case completed:
        return '✅';
      default:
        return '❓';
    }
  }
}

// Reimbursement status constants
class ReimbursementStatus {
  static const String notApplicable = 'not_applicable';
  static const String pending = 'pending';
  static const String paid = 'paid';

  static List<String> get all => [notApplicable, pending, paid];

  static String getDisplayName(String status) {
    switch (status) {
      case notApplicable:
        return 'Not Applicable';
      case pending:
        return 'Pending';
      case paid:
        return 'Paid';
      default:
        return 'Unknown';
    }
  }
}

// Shopping rotation tracker
class ShoppingRotationTracker {
  final String userId;
  final String userName;
  final int totalTripsCompleted;
  final DateTime? lastShoppingDate;
  final double totalSpent;
  final List<String> preferredDays; // ["Monday", "Wednesday", etc.]

  ShoppingRotationTracker({
    required this.userId,
    required this.userName,
    this.totalTripsCompleted = 0,
    this.lastShoppingDate,
    this.totalSpent = 0.0,
    this.preferredDays = const [],
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'totalTripsCompleted': totalTripsCompleted,
      'lastShoppingDate': lastShoppingDate != null 
          ? Timestamp.fromDate(lastShoppingDate!) 
          : null,
      'totalSpent': totalSpent,
      'preferredDays': preferredDays,
    };
  }

  // Create from Map
  factory ShoppingRotationTracker.fromMap(Map<String, dynamic> map) {
    return ShoppingRotationTracker(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      totalTripsCompleted: map['totalTripsCompleted'] ?? 0,
      lastShoppingDate: map['lastShoppingDate'] != null 
          ? (map['lastShoppingDate'] as Timestamp).toDate() 
          : null,
      totalSpent: (map['totalSpent'] ?? 0).toDouble(),
      preferredDays: map['preferredDays'] != null 
          ? List<String>.from(map['preferredDays']) 
          : [],
    );
  }

  // Calculate fairness score (lower = should shop next)
  double calculateFairnessScore(int totalMembers) {
    if (totalMembers == 0) return 0;
    return totalTripsCompleted / totalMembers;
  }

  @override
  String toString() {
    return 'ShoppingRotationTracker(user: $userName, trips: $totalTripsCompleted, spent: $totalSpent BDT)';
  }
}

// Shopping trip summary
class ShoppingTripSummary {
  final int totalTrips;
  final int completedTrips;
  final int pendingTrips;
  final double totalSpent;
  final double averageSpentPerTrip;
  final Map<String, int> tripsByMember;

  ShoppingTripSummary({
    required this.totalTrips,
    required this.completedTrips,
    required this.pendingTrips,
    required this.totalSpent,
    required this.averageSpentPerTrip,
    required this.tripsByMember,
  });

  // Most active shopper
  String? get mostActiveShopper {
    if (tripsByMember.isEmpty) return null;
    return tripsByMember.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  @override
  String toString() {
    return 'ShoppingTripSummary(total: $totalTrips, completed: $completedTrips, spent: $totalSpent BDT)';
  }
}