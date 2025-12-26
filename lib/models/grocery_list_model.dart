import 'package:cloud_firestore/cloud_firestore.dart';
import 'grocery_item_model.dart';

class GroceryListModel {
  final String listId;
  final String systemId;
  final String status; // "active" or "completed"
  final String createdBy;
  final String? assignedTo;
  final String? assignedToName;
  final double totalCost;
  final DateTime createdDate;
  final DateTime? completedDate;
  final String? receiptURL;
  final Map<String, GroceryItemModel> items;

  GroceryListModel({
    required this.listId,
    required this.systemId,
    required this.status,
    required this.createdBy,
    this.assignedTo,
    this.assignedToName,
    this.totalCost = 0.0,
    required this.createdDate,
    this.completedDate,
    this.receiptURL,
    required this.items,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'listId': listId,
      'systemId': systemId,
      'status': status,
      'createdBy': createdBy,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'totalCost': totalCost,
      'createdDate': Timestamp.fromDate(createdDate),
      'completedDate': completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'receiptURL': receiptURL,
      'items': items.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  // Create from Map
  factory GroceryListModel.fromMap(Map<String, dynamic> map) {
    Map<String, GroceryItemModel> itemsMap = {};
    if (map['items'] != null) {
      (map['items'] as Map<String, dynamic>).forEach((key, value) {
        itemsMap[key] = GroceryItemModel.fromMap(value);
      });
    }

    return GroceryListModel(
      listId: map['listId'] ?? '',
      systemId: map['systemId'] ?? '',
      status: map['status'] ?? 'active',
      createdBy: map['createdBy'] ?? '',
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'],
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      completedDate: map['completedDate'] != null 
          ? (map['completedDate'] as Timestamp).toDate() 
          : null,
      receiptURL: map['receiptURL'],
      items: itemsMap,
    );
  }

  // Create from DocumentSnapshot
  factory GroceryListModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroceryListModel.fromMap(data);
  }

  // Copy with updated fields
  GroceryListModel copyWith({
    String? listId,
    String? systemId,
    String? status,
    String? createdBy,
    String? assignedTo,
    String? assignedToName,
    double? totalCost,
    DateTime? createdDate,
    DateTime? completedDate,
    String? receiptURL,
    Map<String, GroceryItemModel>? items,
  }) {
    return GroceryListModel(
      listId: listId ?? this.listId,
      systemId: systemId ?? this.systemId,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      totalCost: totalCost ?? this.totalCost,
      createdDate: createdDate ?? this.createdDate,
      completedDate: completedDate ?? this.completedDate,
      receiptURL: receiptURL ?? this.receiptURL,
      items: items ?? this.items,
    );
  }

  // Get total items count
  int get itemCount => items.length;

  // Get checked items count
  int get checkedItemCount => items.values.where((item) => item.isChecked).length;

  // Get unchecked items count
  int get uncheckedItemCount => items.values.where((item) => !item.isChecked).length;

  // Get urgent items count
  int get urgentItemCount => items.values.where((item) => item.isUrgent).length;

  // Calculate actual total cost
  double calculateTotalCost() {
    return items.values.fold(0.0, (sum, item) => sum + item.estimatedCost);
  }

  // Check if list is completed
  bool get isCompleted => status == 'completed';

  // Check if all items are checked
  bool get allItemsChecked => items.isNotEmpty && uncheckedItemCount == 0;

  // Get progress percentage
  double get progressPercentage {
    if (items.isEmpty) return 0.0;
    return (checkedItemCount / itemCount) * 100;
  }

  @override
  String toString() {
    return 'GroceryListModel(listId: $listId, items: ${items.length}, status: $status)';
  }
}

// Status constants
class GroceryListStatus {
  static const String active = 'active';
  static const String completed = 'completed';
}