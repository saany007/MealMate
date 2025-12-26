import 'package:cloud_firestore/cloud_firestore.dart';

class GroceryItemModel {
  final String itemId;
  final String name;
  final double quantity;
  final String unit; // kg, liter, piece, etc.
  final double estimatedCost;
  final String category; // vegetables, meat, spices, dairy, etc.
  final bool isUrgent;
  final bool isOptional;
  final bool isChecked;
  final String addedBy;
  final DateTime addedDate;

  GroceryItemModel({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.estimatedCost,
    required this.category,
    this.isUrgent = false,
    this.isOptional = false,
    this.isChecked = false,
    required this.addedBy,
    required this.addedDate,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'estimatedCost': estimatedCost,
      'category': category,
      'isUrgent': isUrgent,
      'isOptional': isOptional,
      'isChecked': isChecked,
      'addedBy': addedBy,
      'addedDate': Timestamp.fromDate(addedDate),
    };
  }

  // Create from Map
  factory GroceryItemModel.fromMap(Map<String, dynamic> map) {
    return GroceryItemModel(
      itemId: map['itemId'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'piece',
      estimatedCost: (map['estimatedCost'] ?? 0).toDouble(),
      category: map['category'] ?? 'other',
      isUrgent: map['isUrgent'] ?? false,
      isOptional: map['isOptional'] ?? false,
      isChecked: map['isChecked'] ?? false,
      addedBy: map['addedBy'] ?? '',
      addedDate: (map['addedDate'] as Timestamp).toDate(),
    );
  }

  // Create from DocumentSnapshot
  factory GroceryItemModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroceryItemModel.fromMap(data);
  }

  // Copy with updated fields
  GroceryItemModel copyWith({
    String? itemId,
    String? name,
    double? quantity,
    String? unit,
    double? estimatedCost,
    String? category,
    bool? isUrgent,
    bool? isOptional,
    bool? isChecked,
    String? addedBy,
    DateTime? addedDate,
  }) {
    return GroceryItemModel(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      category: category ?? this.category,
      isUrgent: isUrgent ?? this.isUrgent,
      isOptional: isOptional ?? this.isOptional,
      isChecked: isChecked ?? this.isChecked,
      addedBy: addedBy ?? this.addedBy,
      addedDate: addedDate ?? this.addedDate,
    );
  }

  @override
  String toString() {
    return 'GroceryItemModel(name: $name, qty: $quantity $unit, cost: $estimatedCost BDT)';
  }
}

// Category constants
class GroceryCategory {
  static const String vegetables = 'vegetables';
  static const String fruits = 'fruits';
  static const String meat = 'meat';
  static const String fish = 'fish';
  static const String dairy = 'dairy';
  static const String grains = 'grains';
  static const String spices = 'spices';
  static const String beverages = 'beverages';
  static const String snacks = 'snacks';
  static const String other = 'other';

  static List<String> get all => [
    vegetables,
    fruits,
    meat,
    fish,
    dairy,
    grains,
    spices,
    beverages,
    snacks,
    other,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case vegetables:
        return 'Vegetables';
      case fruits:
        return 'Fruits';
      case meat:
        return 'Meat';
      case fish:
        return 'Fish';
      case dairy:
        return 'Dairy';
      case grains:
        return 'Grains';
      case spices:
        return 'Spices';
      case beverages:
        return 'Beverages';
      case snacks:
        return 'Snacks';
      default:
        return 'Other';
    }
  }

  static String getEmoji(String category) {
    switch (category) {
      case vegetables:
        return '🥬';
      case fruits:
        return '🍎';
      case meat:
        return '🍖';
      case fish:
        return '🐟';
      case dairy:
        return '🥛';
      case grains:
        return '🌾';
      case spices:
        return '🌶️';
      case beverages:
        return '☕';
      case snacks:
        return '🍿';
      default:
        return '📦';
    }
  }
}

// Unit constants
class GroceryUnit {
  static const String kg = 'kg';
  static const String gram = 'gram';
  static const String liter = 'liter';
  static const String ml = 'ml';
  static const String piece = 'piece';
  static const String dozen = 'dozen';
  static const String packet = 'packet';
  static const String bundle = 'bundle';

  static List<String> get all => [
    kg,
    gram,
    liter,
    ml,
    piece,
    dozen,
    packet,
    bundle,
  ];
}