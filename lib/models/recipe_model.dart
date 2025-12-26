class RecipeModel {
  final int id;
  final String title;
  final String image;
  final int readyInMinutes;
  final int servings;
  final String? summary;
  final List<String> cuisines;
  final List<String> dishTypes;
  final List<String> diets;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool dairyFree;
  final double? pricePerServing;
  final List<Ingredient>? extendedIngredients;
  final List<InstructionStep>? analyzedInstructions;
  final NutritionInfo? nutrition;

  RecipeModel({
    required this.id,
    required this.title,
    required this.image,
    required this.readyInMinutes,
    required this.servings,
    this.summary,
    this.cuisines = const [],
    this.dishTypes = const [],
    this.diets = const [],
    this.vegetarian = false,
    this.vegan = false,
    this.glutenFree = false,
    this.dairyFree = false,
    this.pricePerServing,
    this.extendedIngredients,
    this.analyzedInstructions,
    this.nutrition,
  });

  // Create from Spoonacular API response
  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    // Parse extended ingredients
    List<Ingredient>? ingredients;
    if (json['extendedIngredients'] != null) {
      ingredients = (json['extendedIngredients'] as List)
          .map((i) => Ingredient.fromJson(i))
          .toList();
    }

    // Parse instructions
    List<InstructionStep>? instructions;
    if (json['analyzedInstructions'] != null && 
        (json['analyzedInstructions'] as List).isNotEmpty) {
      final steps = json['analyzedInstructions'][0]['steps'] as List;
      instructions = steps.map((s) => InstructionStep.fromJson(s)).toList();
    }

    // Parse nutrition
    NutritionInfo? nutrition;
    if (json['nutrition'] != null) {
      nutrition = NutritionInfo.fromJson(json['nutrition']);
    }

    return RecipeModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      readyInMinutes: json['readyInMinutes'] ?? 0,
      servings: json['servings'] ?? 1,
      summary: json['summary'],
      cuisines: json['cuisines'] != null 
          ? List<String>.from(json['cuisines']) 
          : [],
      dishTypes: json['dishTypes'] != null 
          ? List<String>.from(json['dishTypes']) 
          : [],
      diets: json['diets'] != null 
          ? List<String>.from(json['diets']) 
          : [],
      vegetarian: json['vegetarian'] ?? false,
      vegan: json['vegan'] ?? false,
      glutenFree: json['glutenFree'] ?? false,
      dairyFree: json['dairyFree'] ?? false,
      pricePerServing: json['pricePerServing']?.toDouble(),
      extendedIngredients: ingredients,
      analyzedInstructions: instructions,
      nutrition: nutrition,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'readyInMinutes': readyInMinutes,
      'servings': servings,
      'summary': summary,
      'cuisines': cuisines,
      'dishTypes': dishTypes,
      'diets': diets,
      'vegetarian': vegetarian,
      'vegan': vegan,
      'glutenFree': glutenFree,
      'dairyFree': dairyFree,
      'pricePerServing': pricePerServing,
    };
  }

  // Scale recipe for different number of servings
  RecipeModel scaleForServings(int newServings) {
    if (extendedIngredients == null) return this;

    final scaleFactor = newServings / servings;
    final scaledIngredients = extendedIngredients!
        .map((ing) => ing.scale(scaleFactor))
        .toList();

    return RecipeModel(
      id: id,
      title: title,
      image: image,
      readyInMinutes: readyInMinutes,
      servings: newServings,
      summary: summary,
      cuisines: cuisines,
      dishTypes: dishTypes,
      diets: diets,
      vegetarian: vegetarian,
      vegan: vegan,
      glutenFree: glutenFree,
      dairyFree: dairyFree,
      pricePerServing: pricePerServing,
      extendedIngredients: scaledIngredients,
      analyzedInstructions: analyzedInstructions,
      nutrition: nutrition,
    );
  }

  // Get difficulty level
  String get difficulty {
    if (readyInMinutes <= 20) return 'Easy';
    if (readyInMinutes <= 45) return 'Medium';
    return 'Hard';
  }

  // Get difficulty color
  String get difficultyColor {
    if (readyInMinutes <= 20) return 'green';
    if (readyInMinutes <= 45) return 'orange';
    return 'red';
  }

  @override
  String toString() {
    return 'RecipeModel(id: $id, title: $title, servings: $servings, time: ${readyInMinutes}min)';
  }
}

// Ingredient model
class Ingredient {
  final int id;
  final String name;
  final String original;
  final double amount;
  final String unit;
  final String? image;
  final String? aisle;
  final String? consistency;

  Ingredient({
    required this.id,
    required this.name,
    required this.original,
    required this.amount,
    required this.unit,
    this.image,
    this.aisle,
    this.consistency,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['nameClean'] ?? '',
      original: json['original'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      image: json['image'],
      aisle: json['aisle'],
      consistency: json['consistency'],
    );
  }

  // Scale ingredient amount
  Ingredient scale(double factor) {
    return Ingredient(
      id: id,
      name: name,
      original: original,
      amount: amount * factor,
      unit: unit,
      image: image,
      aisle: aisle,
      consistency: consistency,
    );
  }

  // Get formatted amount string
  String get formattedAmount {
    if (amount == amount.roundToDouble()) {
      return '${amount.toInt()} $unit';
    }
    return '${amount.toStringAsFixed(1)} $unit';
  }

  @override
  String toString() {
    return '$formattedAmount $name';
  }
}

// Instruction step model
class InstructionStep {
  final int number;
  final String step;
  final List<IngredientReference> ingredients;
  final List<Equipment> equipment;
  final int? lengthMinutes;

  InstructionStep({
    required this.number,
    required this.step,
    this.ingredients = const [],
    this.equipment = const [],
    this.lengthMinutes,
  });

  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    List<IngredientReference> ingredients = [];
    if (json['ingredients'] != null) {
      ingredients = (json['ingredients'] as List)
          .map((i) => IngredientReference.fromJson(i))
          .toList();
    }

    List<Equipment> equipment = [];
    if (json['equipment'] != null) {
      equipment = (json['equipment'] as List)
          .map((e) => Equipment.fromJson(e))
          .toList();
    }

    int? lengthMinutes;
    if (json['length'] != null && json['length']['number'] != null) {
      lengthMinutes = json['length']['number'];
    }

    return InstructionStep(
      number: json['number'] ?? 0,
      step: json['step'] ?? '',
      ingredients: ingredients,
      equipment: equipment,
      lengthMinutes: lengthMinutes,
    );
  }
}

// Ingredient reference in steps
class IngredientReference {
  final int id;
  final String name;
  final String? image;

  IngredientReference({
    required this.id,
    required this.name,
    this.image,
  });

  factory IngredientReference.fromJson(Map<String, dynamic> json) {
    return IngredientReference(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'],
    );
  }
}

// Equipment model
class Equipment {
  final int id;
  final String name;
  final String? image;

  Equipment({
    required this.id,
    required this.name,
    this.image,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'],
    );
  }
}

// Nutrition information
class NutritionInfo {
  final List<Nutrient> nutrients;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  NutritionInfo({
    required this.nutrients,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    List<Nutrient> nutrients = [];
    if (json['nutrients'] != null) {
      nutrients = (json['nutrients'] as List)
          .map((n) => Nutrient.fromJson(n))
          .toList();
    }

    // Extract key nutrients
    double? calories;
    double? protein;
    double? carbs;
    double? fat;

    for (var nutrient in nutrients) {
      if (nutrient.name == 'Calories') calories = nutrient.amount;
      if (nutrient.name == 'Protein') protein = nutrient.amount;
      if (nutrient.name == 'Carbohydrates') carbs = nutrient.amount;
      if (nutrient.name == 'Fat') fat = nutrient.amount;
    }

    return NutritionInfo(
      nutrients: nutrients,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }
}

// Nutrient model
class Nutrient {
  final String name;
  final double amount;
  final String unit;
  final double? percentOfDailyNeeds;

  Nutrient({
    required this.name,
    required this.amount,
    required this.unit,
    this.percentOfDailyNeeds,
  });

  factory Nutrient.fromJson(Map<String, dynamic> json) {
    return Nutrient(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      percentOfDailyNeeds: json['percentOfDailyNeeds']?.toDouble(),
    );
  }
}

// Recipe search filters
class RecipeSearchFilters {
  final String? query;
  final String? cuisine;
  final String? diet;
  final String? type;
  final int? maxReadyTime;
  final List<String>? includeIngredients;
  final List<String>? excludeIngredients;
  final bool? vegetarian;
  final bool? vegan;
  final bool? glutenFree;
  final bool? dairyFree;
  final int? number;
  final int? offset;

  RecipeSearchFilters({
    this.query,
    this.cuisine,
    this.diet,
    this.type,
    this.maxReadyTime,
    this.includeIngredients,
    this.excludeIngredients,
    this.vegetarian,
    this.vegan,
    this.glutenFree,
    this.dairyFree,
    this.number = 12,
    this.offset = 0,
  });

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};

    if (query != null && query!.isNotEmpty) params['query'] = query!;
    if (cuisine != null) params['cuisine'] = cuisine!;
    if (diet != null) params['diet'] = diet!;
    if (type != null) params['type'] = type!;
    if (maxReadyTime != null) params['maxReadyTime'] = maxReadyTime.toString();
    if (includeIngredients != null && includeIngredients!.isNotEmpty) {
      params['includeIngredients'] = includeIngredients!.join(',');
    }
    if (excludeIngredients != null && excludeIngredients!.isNotEmpty) {
      params['excludeIngredients'] = excludeIngredients!.join(',');
    }
    if (vegetarian != null) params['vegetarian'] = vegetarian.toString();
    if (vegan != null) params['vegan'] = vegan.toString();
    if (glutenFree != null) params['glutenFree'] = glutenFree.toString();
    if (dairyFree != null) params['dairyFree'] = dairyFree.toString();
    if (number != null) params['number'] = number.toString();
    if (offset != null) params['offset'] = offset.toString();

    return params;
  }
}

// Recipe filter options
class RecipeFilterOptions {
  static const List<String> cuisines = [
    'African', 'Asian', 'American', 'British', 'Cajun', 'Caribbean',
    'Chinese', 'Eastern European', 'European', 'French', 'German',
    'Greek', 'Indian', 'Irish', 'Italian', 'Japanese', 'Jewish',
    'Korean', 'Latin American', 'Mediterranean', 'Mexican', 'Middle Eastern',
    'Nordic', 'Southern', 'Spanish', 'Thai', 'Vietnamese',
  ];

  static const List<String> diets = [
    'Gluten Free', 'Ketogenic', 'Vegetarian', 'Lacto-Vegetarian',
    'Ovo-Vegetarian', 'Vegan', 'Pescetarian', 'Paleo', 'Primal', 'Whole30',
  ];

  static const List<String> mealTypes = [
    'Main Course', 'Side Dish', 'Dessert', 'Appetizer', 'Salad',
    'Bread', 'Breakfast', 'Soup', 'Beverage', 'Sauce', 'Marinade',
    'Fingerfood', 'Snack', 'Drink',
  ];

  static const List<String> cookingTimes = [
    'Under 15 minutes',
    'Under 30 minutes',
    'Under 45 minutes',
    'Under 60 minutes',
    'Any time',
  ];

  static int? getMaxReadyTime(String timeOption) {
    switch (timeOption) {
      case 'Under 15 minutes':
        return 15;
      case 'Under 30 minutes':
        return 30;
      case 'Under 45 minutes':
        return 45;
      case 'Under 60 minutes':
        return 60;
      default:
        return null;
    }
  }
}