import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_preference_model.dart';
import '../models/meal_system_model.dart';

class MealPreferenceService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, MealPreferenceModel> _preferences = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<String, MealPreferenceModel> get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get preference for specific user
  MealPreferenceModel? getPreferenceForUser(String userId) {
    return _preferences[userId];
  }

  // ==================== LOAD MEAL PREFERENCES ====================

  Future<void> loadMealPreferences(String systemId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final DocumentSnapshot doc = await _firestore
          .collection('mealPreferences')
          .doc(systemId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _preferences = data.map(
          (key, value) => MapEntry(
            key,
            MealPreferenceModel.fromMap(value as Map<String, dynamic>),
          ),
        );
      } else {
        _preferences = {};
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load meal preferences: ${e.toString()}';
      notifyListeners();
    }
  }

  // ==================== SAVE MEAL PREFERENCE ====================

  Future<bool> saveMealPreference({
    required String systemId,
    required String userId,
    required String userName,
    required String dietaryType,
    required List<String> allergies,
    required List<String> dislikes,
    required String spiceTolerance,
    required List<String> favoriteDishes,
    required List<String> cuisinePreferences,
    required bool avoidOnion,
    required bool avoidGarlic,
    String? additionalNotes,
  }) async {
    try {
      final preference = MealPreferenceModel(
        userId: userId,
        userName: userName,
        dietaryType: dietaryType,
        allergies: allergies,
        dislikes: dislikes,
        spiceTolerance: spiceTolerance,
        favoriteDishes: favoriteDishes,
        cuisinePreferences: cuisinePreferences,
        avoidOnion: avoidOnion,
        avoidGarlic: avoidGarlic,
        additionalNotes: additionalNotes,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection('mealPreferences')
          .doc(systemId)
          .set({
        userId: preference.toMap(),
      }, SetOptions(merge: true));

      _preferences[userId] = preference;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save meal preference: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== DELETE MEAL PREFERENCE ====================

  Future<bool> deleteMealPreference(String systemId, String userId) async {
    try {
      await _firestore
          .collection('mealPreferences')
          .doc(systemId)
          .update({
        userId: FieldValue.delete(),
      });

      _preferences.remove(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete meal preference: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== ANALYZE GROUP COMPATIBILITY ====================

  GroupCompatibility analyzeGroupCompatibility({
    required MealSystemModel mealSystem,
  }) {
    int totalMembers = mealSystem.memberCount;
    int vegetarianCount = 0;
    int veganCount = 0;
    int nonVegCount = 0;
    int pescatarianCount = 0;

    Map<String, int> allergyCount = {};
    Map<String, int> dislikeCount = {};
    List<String> conflicts = [];

    // Analyze each member's preferences
    for (var userId in mealSystem.members.keys) {
      final pref = _preferences[userId];
      if (pref == null) continue;

      // Count dietary types
      switch (pref.dietaryType) {
        case DietaryType.vegetarian:
          vegetarianCount++;
          break;
        case DietaryType.vegan:
          veganCount++;
          break;
        case DietaryType.nonVeg:
          nonVegCount++;
          break;
        case DietaryType.pescatarian:
          pescatarianCount++;
          break;
      }

      // Count allergies
      for (var allergen in pref.allergies) {
        allergyCount[allergen] = (allergyCount[allergen] ?? 0) + 1;
      }

      // Count dislikes
      for (var dislike in pref.dislikes) {
        dislikeCount[dislike] = (dislikeCount[dislike] ?? 0) + 1;
      }
    }

    // Identify conflicts
    if (vegetarianCount > 0 && nonVegCount > 0) {
      conflicts.add('Mixed vegetarian and non-vegetarian preferences');
    }
    if (veganCount > 0) {
      conflicts.add('Some members are vegan (requires special attention)');
    }

    // Identify safe dishes (considering majority)
    List<String> safeDishes = _getSafeDishes(
      vegetarianCount: vegetarianCount,
      veganCount: veganCount,
      totalMembers: totalMembers,
    );

    return GroupCompatibility(
      totalMembers: totalMembers,
      vegetarianCount: vegetarianCount,
      veganCount: veganCount,
      nonVegCount: nonVegCount,
      pescatarianCount: pescatarianCount,
      commonAllergies: allergyCount,
      commonDislikes: dislikeCount,
      conflictingPreferences: conflicts,
      safeDishes: safeDishes,
    );
  }

  // ==================== GET SAFE DISHES ====================

  List<String> _getSafeDishes({
    required int vegetarianCount,
    required int veganCount,
    required int totalMembers,
  }) {
    List<String> dishes = [];

    if (vegetarianCount == totalMembers) {
      // All vegetarian
      dishes = [
        'Dal Fry',
        'Vegetable Curry',
        'Paneer Tikka',
        'Aloo Gobi',
        'Chana Masala',
        'Mixed Vegetable Rice',
        'Palak Paneer',
      ];
    } else if (veganCount == totalMembers) {
      // All vegan
      dishes = [
        'Dal Tadka',
        'Mixed Vegetable Curry',
        'Chana Masala',
        'Aloo Gobi',
        'Vegetable Biryani',
        'Bhindi Masala',
      ];
    } else if (vegetarianCount > totalMembers / 2) {
      // Majority vegetarian - prioritize veg
      dishes = [
        'Dal Fry with Rice',
        'Vegetable Pulao',
        'Paneer Curry',
        'Mixed Vegetables',
        'Egg Curry (for non-veg)',
      ];
    } else {
      // Mixed preferences
      dishes = [
        'Chicken Biryani',
        'Fish Curry with Rice',
        'Mixed Vegetable Curry',
        'Dal with Chicken',
        'Khichuri',
      ];
    }

    return dishes;
  }

  // ==================== FILTER RECIPES BY PREFERENCES ====================

  List<Map<String, dynamic>> filterRecipesByPreferences({
    required List<Map<String, dynamic>> recipes,
    List<String>? specificUserIds,
  }) {
    List<Map<String, dynamic>> suitableRecipes = [];

    for (var recipe in recipes) {
      bool isSuitable = true;
      List<String> ingredients = List<String>.from(recipe['ingredients'] ?? []);

      // Check against all members' preferences (or specific users)
      final usersToCheck = specificUserIds ?? _preferences.keys.toList();

      for (var userId in usersToCheck) {
        final pref = _preferences[userId];
        if (pref == null) continue;

        if (!pref.isDishSuitable(ingredients)) {
          isSuitable = false;
          break;
        }
      }

      if (isSuitable) {
        suitableRecipes.add(recipe);
      }
    }

    return suitableRecipes;
  }

  // ==================== CHECK RECIPE COMPATIBILITY ====================

  Map<String, dynamic> checkRecipeCompatibility({
    required List<String> ingredients,
    required MealSystemModel mealSystem,
  }) {
    List<String> unsuitableForUsers = [];
    List<String> warnings = [];

    for (var userId in mealSystem.members.keys) {
      final pref = _preferences[userId];
      if (pref == null) continue;

      if (!pref.isDishSuitable(ingredients)) {
        unsuitableForUsers.add(pref.userName);

        // Identify specific issues
        for (var allergen in pref.allergies) {
          if (ingredients.any((i) => i.toLowerCase().contains(allergen.toLowerCase()))) {
            warnings.add('⚠️ Contains ${allergen} - ${pref.userName} is allergic');
          }
        }

        if (pref.isVegetarian || pref.isVegan) {
          final nonVegKeywords = ['chicken', 'meat', 'fish', 'beef', 'mutton', 'egg'];
          if (ingredients.any((i) => nonVegKeywords.any((k) => i.toLowerCase().contains(k)))) {
            warnings.add('🌱 Contains non-veg items - ${pref.userName} is ${pref.dietaryType}');
          }
        }
      }
    }

    return {
      'isSuitable': unsuitableForUsers.isEmpty,
      'unsuitableForUsers': unsuitableForUsers,
      'warnings': warnings,
      'compatibilityRate': 
          ((mealSystem.memberCount - unsuitableForUsers.length) / mealSystem.memberCount * 100)
              .toStringAsFixed(0),
    };
  }

  // ==================== GET DIETARY DISTRIBUTION ====================

  Map<String, int> getDietaryDistribution() {
    Map<String, int> distribution = {
      DietaryType.vegetarian: 0,
      DietaryType.vegan: 0,
      DietaryType.nonVeg: 0,
      DietaryType.pescatarian: 0,
    };

    for (var pref in _preferences.values) {
      distribution[pref.dietaryType] = (distribution[pref.dietaryType] ?? 0) + 1;
    }

    return distribution;
  }

  // ==================== GET COMMON ALLERGIES ====================

  Map<String, int> getCommonAllergies() {
    Map<String, int> allergyCount = {};

    for (var pref in _preferences.values) {
      for (var allergen in pref.allergies) {
        allergyCount[allergen] = (allergyCount[allergen] ?? 0) + 1;
      }
    }

    // Sort by frequency
    final sorted = allergyCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted);
  }

  // ==================== GET FAVORITE DISHES ====================

  Map<String, int> getFavoriteDishes() {
    Map<String, int> dishCount = {};

    for (var pref in _preferences.values) {
      for (var dish in pref.favoriteDishes) {
        dishCount[dish] = (dishCount[dish] ?? 0) + 1;
      }
    }

    // Sort by popularity
    final sorted = dishCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted);
  }

  // ==================== SUGGEST COMPROMISE MEALS ====================

  List<String> suggestCompromiseMeals({
    required MealSystemModel mealSystem,
  }) {
    final compatibility = analyzeGroupCompatibility(mealSystem: mealSystem);
    
    // If majority is vegetarian, suggest vegetarian meals
    if (compatibility.vegetarianPercentage >= 50) {
      return [
        'Mixed Dal with Rice',
        'Vegetable Biryani',
        'Paneer Curry with Roti',
        'Aloo Gobi with Paratha',
        'Khichuri with Vegetables',
      ];
    }

    // Mixed group - suggest versatile meals
    return [
      'Rice with separate Veg/Non-veg curries',
      'Khichuri (customizable toppings)',
      'Biryani (prepare both veg and non-veg)',
      'Paratha with multiple curry options',
      'Fried Rice with optional protein',
    ];
  }

  // ==================== STREAM PREFERENCES ====================

  Stream<Map<String, MealPreferenceModel>> streamMealPreferences(String systemId) {
    return _firestore
        .collection('mealPreferences')
        .doc(systemId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return {};

      final data = doc.data()!;
      return data.map(
        (key, value) => MapEntry(
          key,
          MealPreferenceModel.fromMap(value as Map<String, dynamic>),
        ),
      );
    });
  }

  // ==================== CLEAR DATA ====================

  void clearData() {
    _preferences = {};
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}