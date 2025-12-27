import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/inventory_item_model.dart';

class InventoryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  List<InventoryItemModel> _items = [];
  InventoryStatistics? _statistics;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<InventoryItemModel> get items => _items;
  InventoryStatistics? get statistics => _statistics;
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

  // Add inventory item
  Future<bool> addItem({
    required String systemId,
    required String name,
    required double quantity,
    required String unit,
    required String category,
    required DateTime purchaseDate,
    DateTime? expiryDate,
    double? lowStockThreshold,
    String? location,
    String? barcode,
    double? estimatedCost,
    required String addedBy,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final itemId = _uuid.v4();
      final item = InventoryItemModel(
        itemId: itemId,
        systemId: systemId,
        name: name,
        quantity: quantity,
        unit: unit,
        category: category,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        lowStockThreshold: lowStockThreshold ?? 0.0,
        location: location,
        barcode: barcode,
        estimatedCost: estimatedCost,
        addedBy: addedBy,
        addedDate: DateTime.now(),
        notes: notes,
      );

      await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .doc(itemId)
          .set(item.toMap());

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to add item: $e');
      return false;
    }
  }

  // Get all inventory items
  Future<List<InventoryItemModel>> getItems(String systemId) async {
    try {
      _setLoading(true);

      final querySnapshot = await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .orderBy('name')
          .get();

      _items = querySnapshot.docs
          .map((doc) => InventoryItemModel.fromDocument(doc))
          .toList();

      _statistics = InventoryStatistics.fromItems(_items);
      _setLoading(false);
      return _items;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to get items: $e');
      return [];
    }
  }

  // Stream inventory items
  Stream<List<InventoryItemModel>> streamItems(String systemId) {
    return _firestore
        .collection('inventory')
        .doc(systemId)
        .collection('items')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      _items = snapshot.docs
          .map((doc) => InventoryItemModel.fromDocument(doc))
          .toList();
      _statistics = InventoryStatistics.fromItems(_items);
      return _items;
    });
  }

  // Update inventory item
  Future<bool> updateItem({
    required String systemId,
    required String itemId,
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
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (quantity != null) updates['quantity'] = quantity;
      if (unit != null) updates['unit'] = unit;
      if (category != null) updates['category'] = category;
      if (purchaseDate != null) {
        updates['purchaseDate'] = Timestamp.fromDate(purchaseDate);
      }
      if (expiryDate != null) {
        updates['expiryDate'] = Timestamp.fromDate(expiryDate);
      }
      if (lowStockThreshold != null) {
        updates['lowStockThreshold'] = lowStockThreshold;
      }
      if (location != null) updates['location'] = location;
      if (barcode != null) updates['barcode'] = barcode;
      if (estimatedCost != null) updates['estimatedCost'] = estimatedCost;
      if (notes != null) updates['notes'] = notes;

      if (updates.isEmpty) return true;

      await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .doc(itemId)
          .update(updates);

      return true;
    } catch (e) {
      _setError('Failed to update item: $e');
      return false;
    }
  }

  // Update item quantity (increment/decrement)
  Future<bool> updateQuantity({
    required String systemId,
    required String itemId,
    required double amount,
    bool increment = true,
  }) async {
    try {
      final itemDoc = await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .doc(itemId)
          .get();

      if (!itemDoc.exists) {
        _setError('Item not found');
        return false;
      }

      final item = InventoryItemModel.fromDocument(itemDoc);
      final newQuantity = increment
          ? item.quantity + amount
          : (item.quantity - amount).clamp(0.0, double.infinity);

      await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .doc(itemId)
          .update({
        'quantity': newQuantity,
        'lastUsedDate': increment ? null : Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      _setError('Failed to update quantity: $e');
      return false;
    }
  }

  // Delete inventory item
  Future<bool> deleteItem({
    required String systemId,
    required String itemId,
  }) async {
    try {
      await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .doc(itemId)
          .delete();

      return true;
    } catch (e) {
      _setError('Failed to delete item: $e');
      return false;
    }
  }

  // Get item by ID
  Future<InventoryItemModel?> getItemById({
    required String systemId,
    required String itemId,
  }) async {
    try {
      final doc = await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .doc(itemId)
          .get();

      if (doc.exists) {
        return InventoryItemModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      _setError('Failed to get item: $e');
      return null;
    }
  }

  // Search items by name
  Future<List<InventoryItemModel>> searchItems({
    required String systemId,
    required String query,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return querySnapshot.docs
          .map((doc) => InventoryItemModel.fromDocument(doc))
          .toList();
    } catch (e) {
      _setError('Failed to search items: $e');
      return [];
    }
  }

  // Get items by category
  List<InventoryItemModel> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  // Get items by location
  List<InventoryItemModel> getItemsByLocation(String location) {
    return _items.where((item) => item.location == location).toList();
  }

  // Get low stock items
  List<InventoryItemModel> getLowStockItems() {
    return _items.where((item) => item.isLowStock).toList();
  }

  // Get out of stock items
  List<InventoryItemModel> getOutOfStockItems() {
    return _items.where((item) => item.isOutOfStock).toList();
  }

  // Get expiring items
  List<InventoryItemModel> getExpiringItems() {
    return _items.where((item) => item.isExpiringSoon).toList();
  }

  // Get expired items
  List<InventoryItemModel> getExpiredItems() {
    return _items.where((item) => item.isExpired).toList();
  }

  // Get alerts
  List<InventoryAlert> getAlerts() {
    return InventoryAlert.generateAlerts(_items);
  }

  // Filter items
  List<InventoryItemModel> filterItems(InventoryFilter filter) {
    return _items.where((item) => filter.matches(item)).toList();
  }

  // Use item (decrease quantity for cooking)
  Future<bool> useItem({
    required String systemId,
    required String itemId,
    required double amount,
  }) async {
    return updateQuantity(
      systemId: systemId,
      itemId: itemId,
      amount: amount,
      increment: false,
    );
  }

  // Restock item (increase quantity)
  Future<bool> restockItem({
    required String systemId,
    required String itemId,
    required double amount,
    DateTime? newExpiryDate,
  }) async {
    try {
      final updates = <String, dynamic>{
        'quantity': FieldValue.increment(amount),
      };

      if (newExpiryDate != null) {
        updates['expiryDate'] = Timestamp.fromDate(newExpiryDate);
      }

      await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .doc(itemId)
          .update(updates);

      return true;
    } catch (e) {
      _setError('Failed to restock item: $e');
      return false;
    }
  }

  // Check if item exists by name
  Future<InventoryItemModel?> findItemByName({
    required String systemId,
    required String name,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return InventoryItemModel.fromDocument(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get items expiring in next N days
  List<InventoryItemModel> getItemsExpiringInDays(int days) {
    final targetDate = DateTime.now().add(Duration(days: days));
    return _items.where((item) {
      if (item.expiryDate == null) return false;
      return item.expiryDate!.isBefore(targetDate) &&
          item.expiryDate!.isAfter(DateTime.now());
    }).toList();
  }

  // Get total inventory value
  double getTotalValue() {
    return _items.fold(0.0, (sum, item) {
      if (item.estimatedCost != null) {
        return sum + (item.estimatedCost! * item.quantity);
      }
      return sum;
    });
  }

  // Get category-wise statistics
  Map<String, int> getCategoryStatistics() {
    final Map<String, int> stats = {};
    for (var item in _items) {
      stats[item.category] = (stats[item.category] ?? 0) + 1;
    }
    return stats;
  }

  // Suggest items to use (expiring soon)
  List<InventoryItemModel> suggestItemsToUse() {
    final expiring = getExpiringItems();
    expiring.sort((a, b) {
      if (a.daysUntilExpiry == null) return 1;
      if (b.daysUntilExpiry == null) return -1;
      return a.daysUntilExpiry!.compareTo(b.daysUntilExpiry!);
    });
    return expiring.take(5).toList();
  }

  // Generate restock list (low stock + out of stock)
  List<InventoryItemModel> generateRestockList() {
    return _items
        .where((item) => item.isLowStock || item.isOutOfStock)
        .toList()
      ..sort((a, b) {
        if (a.isOutOfStock && !b.isOutOfStock) return -1;
        if (!a.isOutOfStock && b.isOutOfStock) return 1;
        return a.name.compareTo(b.name);
      });
  }

  // Clean up expired items (mark as removed)
  Future<int> removeExpiredItems(String systemId) async {
    try {
      final expired = getExpiredItems();
      int count = 0;

      for (var item in expired) {
        await deleteItem(systemId: systemId, itemId: item.itemId);
        count++;
      }

      return count;
    } catch (e) {
      _setError('Failed to remove expired items: $e');
      return 0;
    }
  }

  // Batch update items
  Future<bool> batchUpdateQuantities({
    required String systemId,
    required Map<String, double> updates, // itemId -> new quantity
  }) async {
    try {
      final batch = _firestore.batch();

      updates.forEach((itemId, quantity) {
        final docRef = _firestore
            .collection('inventory')
            .doc(systemId)
            .collection('items')
            .doc(itemId);

        batch.update(docRef, {
          'quantity': quantity,
          'lastUsedDate': Timestamp.fromDate(DateTime.now()),
        });
      });

      await batch.commit();
      return true;
    } catch (e) {
      _setError('Failed to batch update: $e');
      return false;
    }
  }

  // Get items grouped by category
  Map<String, List<InventoryItemModel>> getItemsGroupedByCategory() {
    final Map<String, List<InventoryItemModel>> grouped = {};

    for (var item in _items) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }

    return grouped;
  }

  // Get items grouped by location
  Map<String, List<InventoryItemModel>> getItemsGroupedByLocation() {
    final Map<String, List<InventoryItemModel>> grouped = {};

    for (var item in _items) {
      final location = item.location ?? 'Unspecified';
      if (!grouped.containsKey(location)) {
        grouped[location] = [];
      }
      grouped[location]!.add(item);
    }

    return grouped;
  }

  // Clear all items (for testing/reset)
  Future<bool> clearAllItems(String systemId) async {
    try {
      final querySnapshot = await _firestore
          .collection('inventory')
          .doc(systemId)
          .collection('items')
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _items.clear();
      _statistics = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to clear items: $e');
      return false;
    }
  }
}