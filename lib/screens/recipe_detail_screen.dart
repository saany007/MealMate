import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../services/recipe_service.dart';
import '../services/grocery_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/recipe_model.dart';
import '../widgets/custom_button.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RecipeModel? _recipe;
  bool _isLoading = true;
  int _scaledServings = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipe();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipe() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final recipeId = args['recipeId'] as int;

    final recipeService = Provider.of<RecipeService>(context, listen: false);
    final recipe = await recipeService.getRecipeById(recipeId);

    if (mounted && recipe != null) {
      setState(() {
        _recipe = recipe;
        _scaledServings = recipe.servings;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _scaleRecipe(int newServings) {
    if (_recipe == null) return;

    setState(() {
      _scaledServings = newServings;
      _recipe = _recipe!.scaleForServings(newServings);
    });
  }

  Future<void> _addToMealCalendar() async {
    if (_recipe == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;
    final userName = authService.userModel?.name;

    if (systemId == null || userId == null) {
      Fluttertoast.showToast(
        msg: 'Please join a meal system first',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Show date and meal type picker
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddToCalendarDialog(),
    );

    if (result != null) {
      final date = result['date'] as DateTime;
      final mealType = result['mealType'] as String;

      final dbService = DatabaseService();
      await dbService.volunteerToCook(
        systemId: systemId,
        date: DateFormat('yyyy-MM-dd').format(date),
        mealType: mealType,
        cookId: userId,
        cookName: userName!,
        menu: _recipe!.title,
      );

      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Added to meal calendar!',
          backgroundColor: Colors.green,
        );
      }
    }
  }

  Future<void> _addMissingIngredientsToGroceryList() async {
    if (_recipe == null || _recipe!.extendedIngredients == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final groceryService = Provider.of<GroceryService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || userId == null) {
      Fluttertoast.showToast(
        msg: 'Please join a meal system first',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Get or create active grocery list
    var list = await groceryService.getActiveList(systemId);
    if (list == null) {
      list = await groceryService.createGroceryList(
        systemId: systemId,
        createdBy: userId,
      );
    }

    if (list == null) {
      Fluttertoast.showToast(
        msg: 'Failed to create grocery list',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Add ingredients
    int addedCount = 0;
    for (var ingredient in _recipe!.extendedIngredients!) {
      final success = await groceryService.addItem(
        systemId: systemId,
        listId: list.listId,
        name: ingredient.name,
        quantity: ingredient.amount,
        unit: ingredient.unit,
        estimatedCost: 0, // User can update later
        category: ingredient.aisle ?? 'other',
        addedBy: userId,
      );

      if (success) addedCount++;
    }

    if (mounted) {
      Fluttertoast.showToast(
        msg: 'Added $addedCount ingredients to grocery list',
        backgroundColor: Colors.green,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe Details')),
        body: const Center(
          child: Text('Failed to load recipe'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              // FIX: Ensure title is readable with a background overlay
              titlePadding: EdgeInsets.zero,
              title: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  _recipe!.title,
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              centerTitle: false,
              background: _recipe!.image.isNotEmpty
                  ? Image.network(
                      _recipe!.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.restaurant, size: 64),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.restaurant, size: 64),
                    ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Quick Stats
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.timer,
                        label: 'Cook Time',
                        value: '${_recipe!.readyInMinutes} min',
                        color: Colors.orange,
                      ),
                      _StatItem(
                        icon: Icons.people,
                        label: 'Servings',
                        value: '$_scaledServings',
                        color: Colors.blue,
                      ),
                      _StatItem(
                        icon: Icons.star,
                        label: 'Difficulty',
                        value: _recipe!.difficulty,
                        color: _recipe!.difficultyColor == 'green'
                            ? Colors.green
                            : _recipe!.difficultyColor == 'orange'
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Add to Calendar',
                          onPressed: _addToMealCalendar,
                          icon: Icons.calendar_today,
                          height: 45,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Add to List',
                          onPressed: _addMissingIngredientsToGroceryList,
                          icon: Icons.shopping_cart,
                          isOutlined: true,
                          height: 45,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                    tabs: const [
                      Tab(text: 'Ingredients'),
                      Tab(text: 'Instructions'),
                      Tab(text: 'Nutrition'),
                    ],
                  ),
                ),

                // Tab Content
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIngredientsTab(),
                      _buildInstructionsTab(),
                      _buildNutritionTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    if (_recipe!.extendedIngredients == null ||
        _recipe!.extendedIngredients!.isEmpty) {
      return const Center(child: Text('No ingredients available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Serving Scaler
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Servings:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _scaledServings > 1
                    ? () => _scaleRecipe(_scaledServings - 1)
                    : null,
              ),
              Text(
                '$_scaledServings',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _scaleRecipe(_scaledServings + 1),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Ingredients List
          ...(_recipe!.extendedIngredients!.map((ingredient) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ingredient.formattedAmount,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildInstructionsTab() {
    if (_recipe!.analyzedInstructions == null ||
        _recipe!.analyzedInstructions!.isEmpty) {
      return const Center(child: Text('No instructions available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recipe!.analyzedInstructions!.length,
      itemBuilder: (context, index) {
        final step = _recipe!.analyzedInstructions![index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Number
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${step.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Step Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.step,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (step.lengthMinutes != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${step.lengthMinutes} minutes',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNutritionTab() {
    if (_recipe!.nutrition == null) {
      return const Center(child: Text('No nutrition information available'));
    }

    final nutrition = _recipe!.nutrition!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main Nutrients Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Key Nutrients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NutrientItem(
                        label: 'Calories',
                        value: nutrition.calories?.toStringAsFixed(0) ?? '-',
                        unit: 'kcal',
                        color: Colors.red,
                      ),
                      _NutrientItem(
                        label: 'Protein',
                        value: nutrition.protein?.toStringAsFixed(1) ?? '-',
                        unit: 'g',
                        color: Colors.blue,
                      ),
                      _NutrientItem(
                        label: 'Carbs',
                        value: nutrition.carbs?.toStringAsFixed(1) ?? '-',
                        unit: 'g',
                        color: Colors.orange,
                      ),
                      _NutrientItem(
                        label: 'Fat',
                        value: nutrition.fat?.toStringAsFixed(1) ?? '-',
                        unit: 'g',
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // All Nutrients
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All Nutrients',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...nutrition.nutrients.map((nutrient) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(nutrient.name),
                          Text(
                            '${nutrient.amount.toStringAsFixed(1)} ${nutrient.unit}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _NutrientItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _NutrientItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AddToCalendarDialog extends StatefulWidget {
  @override
  State<_AddToCalendarDialog> createState() => _AddToCalendarDialogState();
}

class _AddToCalendarDialogState extends State<_AddToCalendarDialog> {
  DateTime _selectedDate = DateTime.now();
  String _selectedMealType = 'lunch';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Meal Calendar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(DateFormat('EEEE, MMM d').format(_selectedDate)),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedMealType,
            decoration: const InputDecoration(
              labelText: 'Meal Type',
              prefixIcon: Icon(Icons.restaurant),
            ),
            items: const [
              DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
              DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
              DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMealType = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'date': _selectedDate,
              'mealType': _selectedMealType,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}