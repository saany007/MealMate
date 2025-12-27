import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItemModel {
  final String itemId;
  final String systemId;
  final String name;
  final double quantity;
  final String unit; // kg, liter, piece, etc.
  final String category; // grains, vegetables, meat, dairy, spices, etc.
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final double lowStockThreshold;
  final String? location; // fridge, pantry, freezer
  final String? barcode;
  final double? estimatedCost;
  final String addedBy;
  final DateTime addedDate;
  final DateTime? lastUsedDate;
  final String? notes;

  InventoryItemModel({
    required this.itemId,
    required this.systemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.purchaseDate,
    this.expiryDate,
    this.lowStockThreshold = 0.0,
    this.location,
    this.barcode,
    this.estimatedCost,
    required this.addedBy,
    required this.addedDate,
    this.lastUsedDate,
    this.notes,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'systemId': systemId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'lowStockThreshold': lowStockThreshold,
      'location': location,
      'barcode': barcode,
      'estimatedCost': estimatedCost,
      'addedBy': addedBy,
      'addedDate': Timestamp.fromDate(addedDate),
      'lastUsedDate': lastUsedDate != null ? Timestamp.fromDate(lastUsedDate!) : null,
      'notes': notes,
    };
  }

  // Create from Map
  factory InventoryItemModel.fromMap(Map<String, dynamic> map) {
    return InventoryItemModel(
      itemId: map['itemId'] ?? '',
      systemId: map['systemId'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'piece',
      category: map['category'] ?? InventoryCategory.other,
      purchaseDate: (map['purchaseDate'] as Timestamp).toDate(),
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
      lowStockThreshold: (map['lowStockThreshold'] ?? 0).toDouble(),
      location: map['location'],
      barcode: map['barcode'],
      estimatedCost: map['estimatedCost']?.toDouble(),
      addedBy: map['addedBy'] ?? '',
      addedDate: (map['addedDate'] as Timestamp).toDate(),
      lastUsedDate: map['lastUsedDate'] != null
          ? (map['lastUsedDate'] as Timestamp).toDate()
          : null,
      notes: map['notes'],
    );
  }

  // Create from DocumentSnapshot
  factory InventoryItemModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItemModel.fromMap(data);
  }

  // Copy with updated fields
  InventoryItemModel copyWith({
    String? itemId,
    String? systemId,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    double? lowStockThreshold,
    String? location,
    String? barcode,
    double? estimatedCost,
    String? addedBy,
    DateTime? addedDate,
    DateTime? lastUsedDate,
    String? notes,
  }) {
    return InventoryItemModel(
      itemId: itemId ?? this.itemId,
      systemId: systemId ?? this.systemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      location: location ?? this.location,
      barcode: barcode ?? this.barcode,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      addedBy: addedBy ?? this.addedBy,
      addedDate: addedDate ?? this.addedDate,
      lastUsedDate: lastUsedDate ?? this.lastUsedDate,
      notes: notes ?? this.notes,
    );
  }

  // Check if item is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  // Check if item is expiring soon (within 7 days)
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 7;
  }

  // Days until expiry
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  // Check if stock is low
  bool get isLowStock {
    return quantity <= lowStockThreshold && lowStockThreshold > 0;
  }

  // Check if item is out of stock
  bool get isOutOfStock {
    return quantity <= 0;
  }

  // Get stock status
  InventoryStockStatus get stockStatus {
    if (isOutOfStock) return InventoryStockStatus.outOfStock;
    if (isLowStock) return InventoryStockStatus.low;
    return InventoryStockStatus.sufficient;
  }

  // Get expiry status
  InventoryExpiryStatus get expiryStatus {
    if (expiryDate == null) return InventoryExpiryStatus.noExpiry;
    if (isExpired) return InventoryExpiryStatus.expired;
    if (isExpiringSoon) return InventoryExpiryStatus.expiringSoon;
    return InventoryExpiryStatus.fresh;
  }

  // Get status color
  String get statusColor {
    if (isExpired || isOutOfStock) return 'red';
    if (isExpiringSoon || isLowStock) return 'orange';
    return 'green';
  }

  @override
  String toString() {
    return 'InventoryItemModel(name: $name, qty: $quantity $unit, category: $category)';
  }
}

// Inventory category constants
class InventoryCategory {
  static const String grains = 'grains';
  static const String vegetables = 'vegetables';
  static const String fruits = 'fruits';
  static const String meat = 'meat';
  static const String fish = 'fish';
  static const String dairy = 'dairy';
  static const String spices = 'spices';
  static const String beverages = 'beverages';
  static const String snacks = 'snacks';
  static const String condiments = 'condiments';
  static const String canned = 'canned';
  static const String frozen = 'frozen';
  static const String other = 'other';

  static List<String> get all => [
        grains,
        vegetables,
        fruits,
        meat,
        fish,
        dairy,
        spices,
        beverages,
        snacks,
        condiments,
        canned,
        frozen,
        other,
      ];

  static String getDisplayName(String category) {
    switch (category) {
      case grains:
        return 'Grains';
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
      case spices:
        return 'Spices';
      case beverages:
        return 'Beverages';
      case snacks:
        return 'Snacks';
      case condiments:
        return 'Condiments';
      case canned:
        return 'Canned';
      case frozen:
        return 'Frozen';
      default:
        return 'Other';
    }
  }

  static String getEmoji(String category) {
    switch (category) {
      case grains:
        return '🌾';
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
      case spices:
        return '🌶️';
      case beverages:
        return '☕';
      case snacks:
        return '🍿';
      case condiments:
        return '🧂';
      case canned:
        return '🥫';
      case frozen:
        return '❄️';
      default:
        return '📦';
    }
  }
}

// Unit constants
class InventoryUnit {
  static const String kg = 'kg';
  static const String gram = 'gram';
  static const String liter = 'liter';
  static const String ml = 'ml';
  static const String piece = 'piece';
  static const String dozen = 'dozen';
  static const String packet = 'packet';
  static const String bottle = 'bottle';
  static const String can = 'can';
  static const String box = 'box';

  static List<String> get all => [
        kg,
        gram,
        liter,
        ml,
        piece,
        dozen,
        packet,
        bottle,
        can,
        box,
      ];
}

// Location constants
class InventoryLocation {
  static const String fridge = 'fridge';
  static const String freezer = 'freezer';
  static const String pantry = 'pantry';
  static const String cupboard = 'cupboard';
  static const String countertop = 'countertop';

  static List<String> get all => [
        fridge,
        freezer,
        pantry,
        cupboard,
        countertop,
      ];

  static String getDisplayName(String location) {
    switch (location) {
      case fridge:
        return 'Fridge';
      case freezer:
        return 'Freezer';
      case pantry:
        return 'Pantry';
      case cupboard:
        return 'Cupboard';
      case countertop:
        return 'Countertop';
      default:
        return location;
    }
  }

  static String getEmoji(String location) {
    switch (location) {
      case fridge:
        return '🧊';
      case freezer:
        return '❄️';
      case pantry:
        return '🚪';
      case cupboard:
        return '🗄️';
      case countertop:
        return '🏠';
      default:
        return '📍';
    }
  }
}

// Stock status enum
enum InventoryStockStatus {
  sufficient,
  low,
  outOfStock,
}

// Expiry status enum
enum InventoryExpiryStatus {
  fresh,
  expiringSoon,
  expired,
  noExpiry,
}

// Inventory statistics
class InventoryStatistics {
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;
  final int expiringItems;
  final int expiredItems;
  final double totalValue;
  final Map<String, int> itemsByCategory;

  InventoryStatistics({
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.expiringItems,
    required this.expiredItems,
    required this.totalValue,
    required this.itemsByCategory,
  });

  factory InventoryStatistics.fromItems(List<InventoryItemModel> items) {
    int lowStock = 0;
    int outOfStock = 0;
    int expiring = 0;
    int expired = 0;
    double totalValue = 0.0;
    final Map<String, int> byCategory = {};

    for (var item in items) {
      if (item.isLowStock) lowStock++;
      if (item.isOutOfStock) outOfStock++;
      if (item.isExpiringSoon) expiring++;
      if (item.isExpired) expired++;
      if (item.estimatedCost != null) {
        totalValue += item.estimatedCost! * item.quantity;
      }
      
      byCategory[item.category] = (byCategory[item.category] ?? 0) + 1;
    }

    return InventoryStatistics(
      totalItems: items.length,
      lowStockItems: lowStock,
      outOfStockItems: outOfStock,
      expiringItems: expiring,
      expiredItems: expired,
      totalValue: totalValue,
      itemsByCategory: byCategory,
    );
  }

  @override
  String toString() {
    return 'InventoryStatistics(total: $totalItems, lowStock: $lowStockItems, expiring: $expiringItems)';
  }
}

// Inventory alert
class InventoryAlert {
  final String itemId;
  final String itemName;
  final InventoryAlertType type;
  final String message;
  final DateTime createdAt;

  InventoryAlert({
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  String get typeEmoji {
    switch (type) {
      case InventoryAlertType.lowStock:
        return '⚠️';
      case InventoryAlertType.outOfStock:
        return '🚫';
      case InventoryAlertType.expiringSoon:
        return '⏰';
      case InventoryAlertType.expired:
        return '❌';
    }
  }

  String get typeColor {
    switch (type) {
      case InventoryAlertType.lowStock:
        return 'orange';
      case InventoryAlertType.outOfStock:
        return 'red';
      case InventoryAlertType.expiringSoon:
        return 'orange';
      case InventoryAlertType.expired:
        return 'red';
    }
  }

  static List<InventoryAlert> generateAlerts(List<InventoryItemModel> items) {
    final List<InventoryAlert> alerts = [];

    for (var item in items) {
      if (item.isExpired) {
        alerts.add(InventoryAlert(
          itemId: item.itemId,
          itemName: item.name,
          type: InventoryAlertType.expired,
          message: '${item.name} has expired',
          createdAt: DateTime.now(),
        ));
      } else if (item.isExpiringSoon) {
        alerts.add(InventoryAlert(
          itemId: item.itemId,
          itemName: item.name,
          type: InventoryAlertType.expiringSoon,
          message: '${item.name} expires in ${item.daysUntilExpiry} days',
          createdAt: DateTime.now(),
        ));
      }

      if (item.isOutOfStock) {
        alerts.add(InventoryAlert(
          itemId: item.itemId,
          itemName: item.name,
          type: InventoryAlertType.outOfStock,
          message: '${item.name} is out of stock',
          createdAt: DateTime.now(),
        ));
      } else if (item.isLowStock) {
        alerts.add(InventoryAlert(
          itemId: item.itemId,
          itemName: item.name,
          type: InventoryAlertType.lowStock,
          message: '${item.name} is running low (${item.quantity} ${item.unit} left)',
          createdAt: DateTime.now(),
        ));
      }
    }

    return alerts;
  }

  @override
  String toString() {
    return 'InventoryAlert(type: $type, item: $itemName)';
  }
}

// Alert type enum
enum InventoryAlertType {
  lowStock,
  outOfStock,
  expiringSoon,
  expired,
}

// Inventory filter options
class InventoryFilter {
  final String? category;
  final String? location;
  final InventoryStockStatus? stockStatus;
  final InventoryExpiryStatus? expiryStatus;

  InventoryFilter({
    this.category,
    this.location,
    this.stockStatus,
    this.expiryStatus,
  });

  bool matches(InventoryItemModel item) {
    if (category != null && item.category != category) return false;
    if (location != null && item.location != location) return false;
    if (stockStatus != null && item.stockStatus != stockStatus) return false;
    if (expiryStatus != null && item.expiryStatus != expiryStatus) return false;
    return true;
  }

  bool get hasActiveFilters {
    return category != null ||
        location != null ||
        stockStatus != null ||
        expiryStatus != null;
  }

  InventoryFilter copyWith({
    String? category,
    String? location,
    InventoryStockStatus? stockStatus,
    InventoryExpiryStatus? expiryStatus,
    bool clearCategory = false,
    bool clearLocation = false,
    bool clearStockStatus = false,
    bool clearExpiryStatus = false,
  }) {
    return InventoryFilter(
      category: clearCategory ? null : (category ?? this.category),
      location: clearLocation ? null : (location ?? this.location),
      stockStatus: clearStockStatus ? null : (stockStatus ?? this.stockStatus),
      expiryStatus: clearExpiryStatus ? null : (expiryStatus ?? this.expiryStatus),
    );
  }
}