import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/grocery_list_model.dart';
import '../models/grocery_item_model.dart';
import '../models/recipe_model.dart'; 
import 'database_service.dart';
import 'recipe_service.dart';
import 'inventory_service.dart';

class GroceryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  GroceryListModel? _currentList;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  GroceryListModel? get currentList => _currentList;
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

  // Create a new grocery list
  Future<GroceryListModel?> createGroceryList({
    required String systemId,
    required String createdBy,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final listId = _uuid.v4();
      final newList = GroceryListModel(
        listId: listId,
        systemId: systemId,
        status: GroceryListStatus.active, // FIX: Removed .name
        createdBy: createdBy,
        createdDate: DateTime.now(),
        items: {},
      );

      await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .doc(listId)
          .set(newList.toMap());

      _currentList = newList;
      _setLoading(false);
      return newList;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create grocery list: $e');
      return null;
    }
  }

  // Get active grocery list for a system
  Future<GroceryListModel?> getActiveList(String systemId) async {
    try {
      _setLoading(true);

      final querySnapshot = await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .where('status', isEqualTo: GroceryListStatus.active) // FIX: Removed .name
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _currentList = GroceryListModel.fromDocument(querySnapshot.docs.first);
        _setLoading(false);
        return _currentList;
      }

      _setLoading(false);
      return null;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to get grocery list: $e');
      return null;
    }
  }

  // Stream active grocery list
  Stream<GroceryListModel?> streamActiveList(String systemId) {
    return _firestore
        .collection('groceryLists')
        .doc(systemId)
        .collection('lists')
        .where('status', isEqualTo: GroceryListStatus.active) // FIX: Removed .name
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _currentList = GroceryListModel.fromDocument(snapshot.docs.first);
        return _currentList;
      }
      return null;
    });
  }

  // Add item to grocery list
  Future<bool> addItem({
    required String systemId,
    required String listId,
    required String name,
    required double quantity,
    required String unit,
    required double estimatedCost,
    required String category,
    required String addedBy,
    bool isUrgent = false,
    bool isOptional = false,
  }) async {
    try {
      final itemId = _uuid.v4();
      final newItem = GroceryItemModel(
        itemId: itemId,
        name: name,
        quantity: quantity,
        unit: unit,
        estimatedCost: estimatedCost,
        category: category,
        isUrgent: isUrgent,
        isOptional: isOptional,
        addedBy: addedBy,
        addedDate: DateTime.now(),
      );

      // FIX: Use set with merge and REMOVE .name from status
      await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .doc(listId)
          .set({
        'items': {
          itemId: newItem.toMap()
        },
        'systemId': systemId, 
        'status': GroceryListStatus.active, // FIX: Removed .name
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      _setError('Failed to add item: $e');
      print("Add Item Error: $e"); 
      return false;
    }
  }

  // Update item in grocery list
  Future<bool> updateItem({
    required String systemId,
    required String listId,
    required String itemId,
    String? name,
    double? quantity,
    String? unit,
    double? estimatedCost,
    String? category,
    bool? isUrgent,
    bool? isOptional,
    bool? isChecked,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (name != null) updates['items.$itemId.name'] = name;
      if (quantity != null) updates['items.$itemId.quantity'] = quantity;
      if (unit != null) updates['items.$itemId.unit'] = unit;
      if (estimatedCost != null) updates['items.$itemId.estimatedCost'] = estimatedCost;
      if (category != null) updates['items.$itemId.category'] = category;
      if (isUrgent != null) updates['items.$itemId.isUrgent'] = isUrgent;
      if (isOptional != null) updates['items.$itemId.isOptional'] = isOptional;
      if (isChecked != null) updates['items.$itemId.isChecked'] = isChecked;

      if (updates.isEmpty) return true;

      await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .doc(listId)
          .update(updates);

      return true;
    } catch (e) {
      _setError('Failed to update item: $e');
      return false;
    }
  }

  // Toggle item checked status
  Future<bool> toggleItemChecked({
    required String systemId,
    required String listId,
    required String itemId,
    required bool isChecked,
  }) async {
    return updateItem(
      systemId: systemId,
      listId: listId,
      itemId: itemId,
      isChecked: isChecked,
    );
  }

  // Delete item from grocery list
  Future<bool> deleteItem({
    required String systemId,
    required String listId,
    required String itemId,
  }) async {
    try {
      await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .doc(listId)
          .update({
        'items.$itemId': FieldValue.delete(),
      });

      return true;
    } catch (e) {
      _setError('Failed to delete item: $e');
      return false;
    }
  }

  // Assign list to a member
  Future<bool> assignList({
    required String systemId,
    required String listId,
    required String assignedTo,
    required String assignedToName,
  }) async {
    try {
      await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .doc(listId)
          .update({
        'assignedTo': assignedTo,
        'assignedToName': assignedToName,
      });

      return true;
    } catch (e) {
      _setError('Failed to assign list: $e');
      return false;
    }
  }

  // Complete grocery list
  Future<bool> completeList({
    required String systemId,
    required String listId,
    double? totalCost,
    String? receiptURL,
  }) async {
    try {
      final updates = {
        'status': GroceryListStatus.completed, // FIX: Removed .name
        'completedDate': Timestamp.fromDate(DateTime.now()),
      };

      if (totalCost != null) updates['totalCost'] = totalCost;
      if (receiptURL != null) updates['receiptURL'] = receiptURL;

      await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .doc(listId)
          .update(updates);

      return true;
    } catch (e) {
      _setError('Failed to complete list: $e');
      return false;
    }
  }

  // Get completed lists (history)
  Future<List<GroceryListModel>> getCompletedLists(
    String systemId, {
    int limit = 10,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .where('status', isEqualTo: GroceryListStatus.completed) // FIX: Removed .name
          .orderBy('completedDate', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => GroceryListModel.fromDocument(doc))
          .toList();
    } catch (e) {
      _setError('Failed to get completed lists: $e');
      return [];
    }
  }

  // Delete grocery list
  Future<bool> deleteList({
    required String systemId,
    required String listId,
  }) async {
    try {
      await _firestore
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists')
          .doc(listId)
          .delete();

      if (_currentList?.listId == listId) {
        _currentList = null;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to delete list: $e');
      return false;
    }
  }

  // Clear current list
  void clearCurrentList() {
    _currentList = null;
    notifyListeners();
  }

  // Calculate total cost of current list
  double calculateTotalCost() {
    if (_currentList == null) return 0.0;
    return _currentList!.calculateTotalCost();
  }

  // Get items by category
  Map<String, List<GroceryItemModel>> getItemsByCategory() {
    if (_currentList == null) return {};

    final Map<String, List<GroceryItemModel>> categorized = {};
    
    for (var item in _currentList!.items.values) {
      if (!categorized.containsKey(item.category)) {
        categorized[item.category] = [];
      }
      categorized[item.category]!.add(item);
    }

    return categorized;
  }

  // Get urgent items
  List<GroceryItemModel> getUrgentItems() {
    if (_currentList == null) return [];
    return _currentList!.items.values
        .where((item) => item.isUrgent && !item.isChecked)
        .toList();
  }

  // Get unchecked items
  List<GroceryItemModel> getUncheckedItems() {
    if (_currentList == null) return [];
    return _currentList!.items.values
        .where((item) => !item.isChecked)
        .toList();
  }


  // ==================== AUTO-GENERATE GROCERY LIST ====================

  // FIX: Changed return type to Future<int>
  Future<int> autoGenerateGroceryList({
    required String systemId,
    required String userId,
    required DatabaseService databaseService,
    required RecipeService recipeService,
    required InventoryService inventoryService,
    int days = 7,
  }) async {
    int itemsAddedCount = 0; // Initialize counter
    try {
      _setLoading(true);
      print("--- STARTING AUTO-GENERATE ---");
      
      // 1. Fetch meals for the next X days
      final startDate = DateTime.now();
      final endDate = startDate.add(Duration(days: days));
      
      final meals = await databaseService.getDailyMealsForRange(systemId, startDate, endDate);
      print("Found ${meals.length} days with meals.");
      
      if (meals.isEmpty) {
        _setLoading(false);
        return 0;
      }

      // 2. Extract unique menu strings
      final Set<String> menus = {};
      for (var day in meals) {
        if (day.breakfast.menu != null && day.breakfast.menu!.isNotEmpty) menus.add(day.breakfast.menu!);
        if (day.lunch.menu != null && day.lunch.menu!.isNotEmpty) menus.add(day.lunch.menu!);
        if (day.dinner.menu != null && day.dinner.menu!.isNotEmpty) menus.add(day.dinner.menu!);
      }
      print("Unique menus found: $menus");
      
      // 3. Collect required ingredients
      final Map<String, double> neededIngredients = {};
      final Map<String, String> ingredientUnits = {};
      final Map<String, String> ingredientCategories = {};

      for (var menu in menus) {
        if (menu.toLowerCase() == 'tbd') continue;

        // Try to find ingredients
        final ingredients = await recipeService.getIngredientsForMenu(menu);
        print("Menu '$menu' has ${ingredients.length} ingredients.");
        
        for (var ing in ingredients) {
          final name = ing.name.toLowerCase();
          neededIngredients[name] = (neededIngredients[name] ?? 0) + ing.amount;
          ingredientUnits[name] = ing.unit;
          ingredientCategories[name] = ing.aisle ?? 'Other';
        }
      }

      // 4. Fetch current inventory to compare
      await inventoryService.getItems(systemId); 
      final inventoryItems = inventoryService.items;
      print("Inventory has ${inventoryItems.length} items to check against.");

      // 5. Subtract inventory from needed
      for (var invItem in inventoryItems) {
        final name = invItem.name.toLowerCase();
        if (neededIngredients.containsKey(name)) {
          final needed = neededIngredients[name]!;
          final remaining = needed - invItem.quantity;
          
          if (remaining <= 0) {
             neededIngredients.remove(name);
          } else {
             neededIngredients[name] = remaining;
          }
        }
      }

      print("Final items needed to buy: ${neededIngredients.length}");

      // 6. Add remaining needed items to Grocery List
      if (neededIngredients.isNotEmpty) {
        
        // Find existing list first
        String targetListId;
        
        final existingQuery = await _firestore
            .collection('groceryLists')
            .doc(systemId)
            .collection('lists')
            .where('status', isEqualTo: GroceryListStatus.active) // FIX: Removed .name
            .limit(1)
            .get();

        if (existingQuery.docs.isNotEmpty) {
          targetListId = existingQuery.docs.first.id;
          print("Found existing list ID: $targetListId");
        } else {
          print("No existing list found, creating new one...");
          final newList = await createGroceryList(systemId: systemId, createdBy: userId);
          if (newList == null) throw Exception("Could not create list");
          targetListId = newList.listId;
        }
        
        // Batch add items
        for (var entry in neededIngredients.entries) {
          final name = entry.key;
          final qty = entry.value;
          final unit = ingredientUnits[name] ?? 'unit';
          final categoryRaw = ingredientCategories[name] ?? 'Other';
          
          String category = GroceryCategory.other;
          if (categoryRaw.contains('Produce')) category = GroceryCategory.vegetables;
          else if (categoryRaw.contains('Meat')) category = GroceryCategory.meat;
          else if (categoryRaw.contains('Milk') || categoryRaw.contains('Cheese')) category = GroceryCategory.dairy;
          else if (categoryRaw.contains('Spices')) category = GroceryCategory.spices;

          final displayName = name[0].toUpperCase() + name.substring(1);
          
          await addItem(
            systemId: systemId,
            listId: targetListId, 
            name: displayName,
            quantity: double.parse(qty.toStringAsFixed(1)),
            unit: unit,
            estimatedCost: 0,
            category: category,
            addedBy: userId,
            isOptional: false,
          );
          itemsAddedCount++;
        }
      }

    } catch (e) {
      print("AUTO-GEN ERROR: $e");
      _setError('Failed to auto-generate list: $e');
    } finally {
      _setLoading(false);
    }
    
    // FIX: Ensure the int is returned
    return itemsAddedCount;
  }
}