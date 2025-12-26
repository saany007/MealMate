import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';
import '../models/recipe_model.dart';
import '../widgets/custom_button.dart';

class RecipeBrowserScreen extends StatefulWidget {
  const RecipeBrowserScreen({super.key});

  @override
  State<RecipeBrowserScreen> createState() => _RecipeBrowserScreenState();
}

class _RecipeBrowserScreenState extends State<RecipeBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  // Filters
  String? _selectedCuisine;
  String? _selectedDiet;
  String? _selectedType;
  String _selectedTime = 'Any time';

  bool _showFilters = false;
  List<String> _availableIngredients = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRandomRecipes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRandomRecipes() async {
    final recipeService = Provider.of<RecipeService>(context, listen: false);
    
    if (!recipeService.isApiKeySet()) {
      _showApiKeyWarning();
      return;
    }

    await recipeService.getRandomRecipes(number: 12);
  }

  void _showApiKeyWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('API Key Required'),
          ],
        ),
        content: const Text(
          'Please add your Spoonacular API key in the recipe_service.dart file.\n\n'
          'Get a free API key from:\nhttps://spoonacular.com/food-api',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty && _selectedCuisine == null && _selectedDiet == null) {
      Fluttertoast.showToast(
        msg: 'Please enter a search term or select filters',
        backgroundColor: Colors.orange,
      );
      return;
    }

    final recipeService = Provider.of<RecipeService>(context, listen: false);
    
    if (!recipeService.isApiKeySet()) {
      _showApiKeyWarning();
      return;
    }

    final filters = RecipeSearchFilters(
      query: query.isEmpty ? null : query,
      cuisine: _selectedCuisine,
      diet: _selectedDiet,
      type: _selectedType,
      maxReadyTime: RecipeFilterOptions.getMaxReadyTime(_selectedTime),
      number: 20,
    );

    await recipeService.searchRecipes(filters: filters);
  }

  Future<void> _searchByIngredients() async {
    if (_availableIngredients.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please add some ingredients first',
        backgroundColor: Colors.orange,
      );
      _showAddIngredientsDialog();
      return;
    }

    final recipeService = Provider.of<RecipeService>(context, listen: false);
    
    if (!recipeService.isApiKeySet()) {
      _showApiKeyWarning();
      return;
    }

    await recipeService.findByIngredients(
      ingredients: _availableIngredients,
      number: 15,
    );
  }

  void _showAddIngredientsDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Ingredients'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., chicken, rice, tomatoes',
                labelText: 'Ingredient name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            if (_availableIngredients.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Current ingredients:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIngredients.map((ing) {
                  return Chip(
                    label: Text(ing),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _availableIngredients.remove(ing);
                      });
                      Navigator.pop(context);
                      _showAddIngredientsDialog();
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _availableIngredients.add(controller.text.trim());
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedCuisine = null;
      _selectedDiet = null;
      _selectedType = null;
      _selectedTime = 'Any time';
      _searchController.clear();
      _availableIngredients.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Recipe Browser'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Search'),
            Tab(text: 'By Ingredients'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildSearchTab(),
          _buildByIngredientsTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Consumer<RecipeService>(
      builder: (context, recipeService, child) {
        if (recipeService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (recipeService.searchResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No recipes found'),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Load Random Recipes',
                  onPressed: _loadRandomRecipes,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadRandomRecipes,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: recipeService.searchResults.length,
            itemBuilder: (context, index) {
              final recipe = recipeService.searchResults[index];
              return _RecipeCard(recipe: recipe);
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search recipes...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _handleSearch(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_list_off : Icons.filter_list,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                  ),
                ],
              ),
              if (_showFilters) ...[
                const SizedBox(height: 16),
                _buildFilters(),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Search',
                      onPressed: _handleSearch,
                      icon: Icons.search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CustomButton(
                    text: 'Clear',
                    onPressed: _clearFilters,
                    isOutlined: true,
                    width: 100,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: Consumer<RecipeService>(
            builder: (context, recipeService, child) {
              if (recipeService.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (recipeService.searchResults.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No recipes found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try different search terms or filters',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: recipeService.searchResults.length,
                itemBuilder: (context, index) {
                  final recipe = recipeService.searchResults[index];
                  return _RecipeCard(recipe: recipe);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildByIngredientsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What can you cook with these ingredients?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_availableIngredients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_shopping_cart, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No ingredients added yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIngredients.map((ing) {
                    return Chip(
                      label: Text(ing),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _availableIngredients.remove(ing);
                        });
                      },
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Add Ingredients',
                      onPressed: _showAddIngredientsDialog,
                      icon: Icons.add,
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: 'Find Recipes',
                      onPressed: _searchByIngredients,
                      icon: Icons.search,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<RecipeService>(
            builder: (context, recipeService, child) {
              if (recipeService.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (recipeService.searchResults.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Add ingredients to find recipes',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: recipeService.searchResults.length,
                itemBuilder: (context, index) {
                  final recipe = recipeService.searchResults[index];
                  return _RecipeCard(recipe: recipe);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cuisine
        DropdownButtonFormField<String>(
          value: _selectedCuisine,
          decoration: const InputDecoration(
            labelText: 'Cuisine',
            prefixIcon: Icon(Icons.public),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Any')),
            ...RecipeFilterOptions.cuisines.map((cuisine) {
              return DropdownMenuItem(value: cuisine, child: Text(cuisine));
            }),
          ],
          onChanged: (value) => setState(() => _selectedCuisine = value),
        ),
        const SizedBox(height: 12),

        // Diet
        DropdownButtonFormField<String>(
          value: _selectedDiet,
          decoration: const InputDecoration(
            labelText: 'Diet',
            prefixIcon: Icon(Icons.eco),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Any')),
            ...RecipeFilterOptions.diets.map((diet) {
              return DropdownMenuItem(value: diet, child: Text(diet));
            }),
          ],
          onChanged: (value) => setState(() => _selectedDiet = value),
        ),
        const SizedBox(height: 12),

        // Meal Type
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: const InputDecoration(
            labelText: 'Meal Type',
            prefixIcon: Icon(Icons.restaurant),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Any')),
            ...RecipeFilterOptions.mealTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }),
          ],
          onChanged: (value) => setState(() => _selectedType = value),
        ),
        const SizedBox(height: 12),

        // Cooking Time
        DropdownButtonFormField<String>(
          value: _selectedTime,
          decoration: const InputDecoration(
            labelText: 'Cooking Time',
            prefixIcon: Icon(Icons.timer),
          ),
          items: RecipeFilterOptions.cookingTimes.map((time) {
            return DropdownMenuItem(value: time, child: Text(time));
          }).toList(),
          onChanged: (value) => setState(() => _selectedTime = value!),
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeModel recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/recipe-detail',
            arguments: {'recipeId': recipe.id},
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: recipe.image.isNotEmpty
                      ? Image.network(
                          recipe.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.restaurant, size: 48),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.restaurant, size: 48),
                        ),
                ),
                // Time badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.readyInMinutes}m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Recipe Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.servings}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: recipe.difficultyColor == 'green'
                                ? Colors.green.withOpacity(0.1)
                                : recipe.difficultyColor == 'orange'
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recipe.difficulty,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: recipe.difficultyColor == 'green'
                                  ? Colors.green[700]
                                  : recipe.difficultyColor == 'orange'
                                      ? Colors.orange[700]
                                      : Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}