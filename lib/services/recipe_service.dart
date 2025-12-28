import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/recipe_model.dart';

class RecipeService extends ChangeNotifier {
  static const String _apiKey = 'e391a902f58c42c0a3c757e407d4a8a5';
  static const String _baseUrl = 'https://api.spoonacular.com/recipes';

  bool _isLoading = false;
  String? _errorMessage;
  List<RecipeModel> _searchResults = [];
  RecipeModel? _currentRecipe;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<RecipeModel> get searchResults => _searchResults;
  RecipeModel? get currentRecipe => _currentRecipe;

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

  // Search recipes with filters
  Future<List<RecipeModel>> searchRecipes({
    RecipeSearchFilters? filters,
    String? query,
    int? number,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final queryParams = filters?.toQueryParameters() ?? {};
      if (query != null) {
        queryParams['query'] = query;
      }
      if (number != null) {
        queryParams['number'] = number.toString();
      }
      queryParams['apiKey'] = _apiKey;
      queryParams['addRecipeInformation'] = 'true';
      queryParams['fillIngredients'] = 'true';

      final uri = Uri.parse('$_baseUrl/complexSearch')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        _searchResults = results
            .map((recipe) => RecipeModel.fromJson(recipe))
            .toList();

        _setLoading(false);
        return _searchResults;
      } else if (response.statusCode == 402) {
        throw Exception(
            'API quota exceeded. Please check your Spoonacular API plan.');
      } else {
        throw Exception(
            'Failed to search recipes. Status: ${response.statusCode}');
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to search recipes: $e');
      return [];
    }
  }

  // Get recipe by ID with full details
  Future<RecipeModel?> getRecipeById(int id) async {
    try {
      _setLoading(true);
      _setError(null);

      final uri = Uri.parse('$_baseUrl/$id/information').replace(
        queryParameters: {
          'apiKey': _apiKey,
          'includeNutrition': 'true',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentRecipe = RecipeModel.fromJson(data);
        _setLoading(false);
        return _currentRecipe;
      } else if (response.statusCode == 402) {
        throw Exception(
            'API quota exceeded. Please check your Spoonacular API plan.');
      } else {
        throw Exception(
            'Failed to get recipe. Status: ${response.statusCode}');
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to get recipe: $e');
      return null;
    }
  }

  // Find recipes by ingredients (What can I cook?)
  Future<List<RecipeModel>> findByIngredients({
    required List<String> ingredients,
    int number = 12,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final uri = Uri.parse('$_baseUrl/findByIngredients').replace(
        queryParameters: {
          'apiKey': _apiKey,
          'ingredients': ingredients.join(','),
          'number': number.toString(),
          'ranking': '2', // Maximize used ingredients
          'ignorePantry': 'true',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        // Get full details for each recipe
        final List<RecipeModel> recipes = [];
        for (var result in results) {
          final recipe = await getRecipeById(result['id']);
          if (recipe != null) {
            recipes.add(recipe);
          }
        }

        _searchResults = recipes;
        _setLoading(false);
        return recipes;
      } else if (response.statusCode == 402) {
        throw Exception(
            'API quota exceeded. Please check your Spoonacular API plan.');
      } else {
        throw Exception(
            'Failed to find recipes. Status: ${response.statusCode}');
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to find recipes by ingredients: $e');
      return [];
    }
  }

  // Get random recipes
  Future<List<RecipeModel>> getRandomRecipes({
    int number = 10,
    String? tags,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final queryParams = {
        'apiKey': _apiKey,
        'number': number.toString(),
      };

      if (tags != null) {
        queryParams['tags'] = tags;
      }

      final uri =
          Uri.parse('$_baseUrl/random').replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['recipes'] as List;

        _searchResults =
            results.map((recipe) => RecipeModel.fromJson(recipe)).toList();

        _setLoading(false);
        return _searchResults;
      } else if (response.statusCode == 402) {
        throw Exception(
            'API quota exceeded. Please check your Spoonacular API plan.');
      } else {
        throw Exception(
            'Failed to get random recipes. Status: ${response.statusCode}');
      }
    } catch (e) {
      _setLoading(false);
      _setError('Failed to get random recipes: $e');
      return [];
    }
  }

  // Get similar recipes
  Future<List<RecipeModel>> getSimilarRecipes(int recipeId,
      {int number = 4}) async {
    try {
      final uri = Uri.parse('$_baseUrl/$recipeId/similar').replace(
        queryParameters: {
          'apiKey': _apiKey,
          'number': number.toString(),
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        // Get full details for each recipe
        final List<RecipeModel> recipes = [];
        for (var result in results) {
          final recipe = await getRecipeById(result['id']);
          if (recipe != null) {
            recipes.add(recipe);
          }
        }

        return recipes;
      } else {
        return [];
      }
    } catch (e) {
      _setError('Failed to get similar recipes: $e');
      return [];
    }
  }

  // Autocomplete recipe search (for search suggestions)
  Future<List<String>> autocompleteRecipeSearch(String query,
      {int number = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/autocomplete').replace(
        queryParameters: {
          'apiKey': _apiKey,
          'query': query,
          'number': number.toString(),
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results.map((item) => item['title'] as String).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Parse ingredients from text (helpful for manual entry)
  Future<List<Ingredient>> parseIngredients(List<String> ingredientTexts,
      {int servings = 1}) async {
    try {
      final uri = Uri.parse('$_baseUrl/parseIngredients').replace(
        queryParameters: {
          'apiKey': _apiKey,
          'servings': servings.toString(),
        },
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'ingredientList': ingredientTexts.join('\n')},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results.map((ing) => Ingredient.fromJson(ing)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Get recipe nutrition widget (returns HTML widget URL)
  String getRecipeNutritionWidgetUrl(int recipeId) {
    return 'https://spoonacular.com/recipeWidgets/$recipeId/nutritionLabel?apiKey=$_apiKey';
  }

  // Get ingredient widget URL
  String getIngredientWidgetUrl(int recipeId) {
    return 'https://spoonacular.com/recipeWidgets/$recipeId/ingredientWidget?apiKey=$_apiKey';
  }

  // Extract missing ingredients from a recipe
  List<String> getMissingIngredients(
    RecipeModel recipe,
    List<String> availableIngredients,
  ) {
    if (recipe.extendedIngredients == null) return [];

    final available = availableIngredients.map((i) => i.toLowerCase()).toSet();
    final missing = <String>[];

    for (var ingredient in recipe.extendedIngredients!) {
      final name = ingredient.name.toLowerCase();
      if (!available.any((avail) => name.contains(avail) || avail.contains(name))) {
        missing.add(ingredient.name);
      }
    }

    return missing;
  }

  // Check if recipe matches dietary preferences
  bool matchesDietaryPreferences(
    RecipeModel recipe,
    List<String> preferences,
  ) {
    for (var pref in preferences) {
      final prefLower = pref.toLowerCase();

      if (prefLower == 'vegetarian' && !recipe.vegetarian) return false;
      if (prefLower == 'vegan' && !recipe.vegan) return false;
      if (prefLower.contains('gluten') && !recipe.glutenFree) return false;
      if (prefLower.contains('dairy') && !recipe.dairyFree) return false;
    }

    return true;
  }

  // Get recipe image URL with size
  String getRecipeImageUrl(String imageUrl, {String size = '636x393'}) {
    // Spoonacular image sizes: 90x90, 240x150, 312x150, 312x231, 480x360, 556x370, 636x393
    if (imageUrl.isEmpty) return '';
    return imageUrl.replaceAll('312x231', size);
  }


  // ==================== AUTO-GROCERY SUPPORT ==================== 
  // Helper to find ingredients based on a menu string (e.g. "Chicken Curry")
  // Since we store menus as Strings, we search for the best match and get its ingredients.
  Future<List<Ingredient>> getIngredientsForMenu(String menuName) async {
    if (menuName.isEmpty || menuName.toLowerCase() == 'tbd') return [];
    
    try {
      // 1. Search for the recipe
      final recipes = await searchRecipes(query: menuName, number: 1);
      
      if (recipes.isNotEmpty) {
        // 2. Get full details (ingredients are often truncated in search results)        
        final recipe = recipes.first;
        if (recipe.extendedIngredients != null && recipe.extendedIngredients!.isNotEmpty) {
          return recipe.extendedIngredients!;
        } else {
          // If not populated, fetch details
          final detailedRecipe = await getRecipeById(recipe.id);
          return detailedRecipe?.extendedIngredients ?? [];
        }
      }
      return [];
    } catch (e) {
      _setError('Error getting ingredients for menu $menuName: $e');
      return [];
    }
  }

  // Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  // Clear current recipe
  void clearCurrentRecipe() {
    _currentRecipe = null;
    notifyListeners();
  }

  // Check if API key is set
  bool isApiKeySet() {
    return _apiKey != 'YOUR_SPOONACULAR_API_KEY' && _apiKey.isNotEmpty;
  }
}