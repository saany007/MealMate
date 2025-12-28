import 'package:cloud_firestore/cloud_firestore.dart';

class MealPreferenceModel {
  final String userId;
  final String userName;
  final String dietaryType; // vegetarian, vegan, non-veg, pescatarian
  final List<String> allergies; // nuts, dairy, gluten, seafood, etc.
  final List<String> dislikes; // specific ingredients to avoid
  final String spiceTolerance; // mild, medium, spicy
  final List<String> favoriteDishes;
  final List<String> cuisinePreferences; // bengali, indian, chinese, etc.
  final bool avoidOnion;
  final bool avoidGarlic;
  final String? additionalNotes;
  final DateTime lastUpdated;

  MealPreferenceModel({
    required this.userId,
    required this.userName,
    this.dietaryType = DietaryType.nonVeg,
    this.allergies = const [],
    this.dislikes = const [],
    this.spiceTolerance = SpiceTolerance.medium,
    this.favoriteDishes = const [],
    this.cuisinePreferences = const [],
    this.avoidOnion = false,
    this.avoidGarlic = false,
    this.additionalNotes,
    required this.lastUpdated,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'dietaryType': dietaryType,
      'allergies': allergies,
      'dislikes': dislikes,
      'spiceTolerance': spiceTolerance,
      'favoriteDishes': favoriteDishes,
      'cuisinePreferences': cuisinePreferences,
      'avoidOnion': avoidOnion,
      'avoidGarlic': avoidGarlic,
      'additionalNotes': additionalNotes,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  // Create from Map
  factory MealPreferenceModel.fromMap(Map<String, dynamic> map) {
    return MealPreferenceModel(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      dietaryType: map['dietaryType'] ?? DietaryType.nonVeg,
      allergies: map['allergies'] != null 
          ? List<String>.from(map['allergies']) 
          : [],
      dislikes: map['dislikes'] != null 
          ? List<String>.from(map['dislikes']) 
          : [],
      spiceTolerance: map['spiceTolerance'] ?? SpiceTolerance.medium,
      favoriteDishes: map['favoriteDishes'] != null 
          ? List<String>.from(map['favoriteDishes']) 
          : [],
      cuisinePreferences: map['cuisinePreferences'] != null 
          ? List<String>.from(map['cuisinePreferences']) 
          : [],
      avoidOnion: map['avoidOnion'] ?? false,
      avoidGarlic: map['avoidGarlic'] ?? false,
      additionalNotes: map['additionalNotes'],
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  // Create from DocumentSnapshot
  factory MealPreferenceModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPreferenceModel.fromMap(data);
  }

  // Copy with updated fields
  MealPreferenceModel copyWith({
    String? userId,
    String? userName,
    String? dietaryType,
    List<String>? allergies,
    List<String>? dislikes,
    String? spiceTolerance,
    List<String>? favoriteDishes,
    List<String>? cuisinePreferences,
    bool? avoidOnion,
    bool? avoidGarlic,
    String? additionalNotes,
    DateTime? lastUpdated,
  }) {
    return MealPreferenceModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      dietaryType: dietaryType ?? this.dietaryType,
      allergies: allergies ?? this.allergies,
      dislikes: dislikes ?? this.dislikes,
      spiceTolerance: spiceTolerance ?? this.spiceTolerance,
      favoriteDishes: favoriteDishes ?? this.favoriteDishes,
      cuisinePreferences: cuisinePreferences ?? this.cuisinePreferences,
      avoidOnion: avoidOnion ?? this.avoidOnion,
      avoidGarlic: avoidGarlic ?? this.avoidGarlic,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Check if user is vegetarian
  bool get isVegetarian => dietaryType == DietaryType.vegetarian;

  // Check if user is vegan
  bool get isVegan => dietaryType == DietaryType.vegan;

  // Check if user has allergies
  bool get hasAllergies => allergies.isNotEmpty;

  // Check if user has dislikes
  bool get hasDislikes => dislikes.isNotEmpty;

  // Get all restrictions (allergies + dislikes)
  List<String> get allRestrictions => [...allergies, ...dislikes];

  // Check if a dish is suitable for this user
  bool isDishSuitable(List<String> ingredients) {
    // Check allergies first (critical)
    for (var allergen in allergies) {
      if (ingredients.any((i) => i.toLowerCase().contains(allergen.toLowerCase()))) {
        return false;
      }
    }

    // Check dietary type
    if (isVegetarian || isVegan) {
      final nonVegKeywords = ['chicken', 'meat', 'fish', 'beef', 'mutton', 'egg', 'prawn', 'shrimp'];
      if (ingredients.any((i) => nonVegKeywords.any((keyword) => i.toLowerCase().contains(keyword)))) {
        return false;
      }
    }

    if (isVegan) {
      final nonVeganKeywords = ['milk', 'dairy', 'cheese', 'butter', 'ghee', 'paneer', 'cream'];
      if (ingredients.any((i) => nonVeganKeywords.any((keyword) => i.toLowerCase().contains(keyword)))) {
        return false;
      }
    }

    // Check onion/garlic preferences
    if (avoidOnion && ingredients.any((i) => i.toLowerCase().contains('onion'))) {
      return false;
    }
    if (avoidGarlic && ingredients.any((i) => i.toLowerCase().contains('garlic'))) {
      return false;
    }

    return true;
  }

  @override
  String toString() {
    return 'MealPreferenceModel(user: $userName, dietary: $dietaryType, allergies: ${allergies.length}, dislikes: ${dislikes.length})';
  }
}

// Dietary type constants
class DietaryType {
  static const String vegetarian = 'vegetarian';
  static const String vegan = 'vegan';
  static const String nonVeg = 'non-veg';
  static const String pescatarian = 'pescatarian';

  static List<String> get all => [vegetarian, vegan, nonVeg, pescatarian];

  static String getDisplayName(String type) {
    switch (type) {
      case vegetarian:
        return 'Vegetarian';
      case vegan:
        return 'Vegan';
      case nonVeg:
        return 'Non-Vegetarian';
      case pescatarian:
        return 'Pescatarian';
      default:
        return 'Unknown';
    }
  }

  static String getEmoji(String type) {
    switch (type) {
      case vegetarian:
        return '🥗';
      case vegan:
        return '🌱';
      case nonVeg:
        return '🍖';
      case pescatarian:
        return '🐟';
      default:
        return '🍽️';
    }
  }

  static String getDescription(String type) {
    switch (type) {
      case vegetarian:
        return 'No meat or fish, but includes dairy and eggs';
      case vegan:
        return 'No animal products whatsoever';
      case nonVeg:
        return 'Includes all types of food';
      case pescatarian:
        return 'Fish and seafood, but no other meat';
      default:
        return '';
    }
  }
}

// Spice tolerance constants
class SpiceTolerance {
  static const String mild = 'mild';
  static const String medium = 'medium';
  static const String spicy = 'spicy';

  static List<String> get all => [mild, medium, spicy];

  static String getDisplayName(String tolerance) {
    switch (tolerance) {
      case mild:
        return 'Mild (Low Spice)';
      case medium:
        return 'Medium (Moderate Spice)';
      case spicy:
        return 'Spicy (Hot!)';
      default:
        return 'Unknown';
    }
  }

  static String getEmoji(String tolerance) {
    switch (tolerance) {
      case mild:
        return '😊';
      case medium:
        return '🌶️';
      case spicy:
        return '🔥';
      default:
        return '❓';
    }
  }
}

// Common allergens
class CommonAllergens {
  static const String nuts = 'nuts';
  static const String dairy = 'dairy';
  static const String gluten = 'gluten';
  static const String seafood = 'seafood';
  static const String eggs = 'eggs';
  static const String soy = 'soy';
  static const String peanuts = 'peanuts';
  static const String shellfish = 'shellfish';

  static List<String> get all => [
    nuts,
    dairy,
    gluten,
    seafood,
    eggs,
    soy,
    peanuts,
    shellfish,
  ];

  static String getDisplayName(String allergen) {
    return allergen[0].toUpperCase() + allergen.substring(1);
  }
}

// Common dislikes
class CommonDislikes {
  static const String mushrooms = 'mushrooms';
  static const String eggplant = 'eggplant';
  static const String broccoli = 'broccoli';
  static const String cauliflower = 'cauliflower';
  static const String bitterGourd = 'bitter gourd';
  static const String okra = 'okra';
  static const String spinach = 'spinach';
  static const String pumpkin = 'pumpkin';

  static List<String> get all => [
    mushrooms,
    eggplant,
    broccoli,
    cauliflower,
    bitterGourd,
    okra,
    spinach,
    pumpkin,
  ];
}

// Cuisine types
class CuisineType {
  static const String bengali = 'Bengali';
  static const String indian = 'Indian';
  static const String chinese = 'Chinese';
  static const String italian = 'Italian';
  static const String mexican = 'Mexican';
  static const String thai = 'Thai';
  static const String continental = 'Continental';
  static const String fastFood = 'Fast Food';

  static List<String> get all => [
    bengali,
    indian,
    chinese,
    italian,
    mexican,
    thai,
    continental,
    fastFood,
  ];
}

// Group compatibility analyzer
class GroupCompatibility {
  final int totalMembers;
  final int vegetarianCount;
  final int veganCount;
  final int nonVegCount;
  final int pescatarianCount;
  final Map<String, int> commonAllergies;
  final Map<String, int> commonDislikes;
  final List<String> conflictingPreferences;
  final List<String> safeDishes; // Dishes that work for everyone

  GroupCompatibility({
    required this.totalMembers,
    required this.vegetarianCount,
    required this.veganCount,
    required this.nonVegCount,
    required this.pescatarianCount,
    required this.commonAllergies,
    required this.commonDislikes,
    required this.conflictingPreferences,
    required this.safeDishes,
  });

  // Check if group is compatible
  bool get isCompatible => conflictingPreferences.isEmpty;

  // Get majority dietary type
  String get majorityDietaryType {
    final counts = {
      'vegetarian': vegetarianCount,
      'vegan': veganCount,
      'non-veg': nonVegCount,
      'pescatarian': pescatarianCount,
    };
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // Get percentage of vegetarians
  double get vegetarianPercentage => 
      totalMembers > 0 ? (vegetarianCount / totalMembers) * 100 : 0;

  // Should prioritize vegetarian meals
  bool get shouldPrioritizeVegetarian => vegetarianPercentage >= 50;

  @override
  String toString() {
    return 'GroupCompatibility(members: $totalMembers, veg: $vegetarianCount, nonVeg: $nonVegCount, compatible: $isCompatible)';
  }
}