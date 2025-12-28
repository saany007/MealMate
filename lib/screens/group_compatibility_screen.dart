import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/meal_preference_service.dart';
import '../services/meal_system_service.dart';
import '../models/meal_preference_model.dart';

class GroupCompatibilityScreen extends StatefulWidget {
  const GroupCompatibilityScreen({super.key});

  @override
  State<GroupCompatibilityScreen> createState() => _GroupCompatibilityScreenState();
}

class _GroupCompatibilityScreenState extends State<GroupCompatibilityScreen> {
  GroupCompatibility? _compatibility;

  @override
  void initState() {
    super.initState();
    _analyzeCompatibility();
  }

  void _analyzeCompatibility() {
    final preferenceService = Provider.of<MealPreferenceService>(context, listen: false);
    final systemService = Provider.of<MealSystemService>(context, listen: false);

    if (systemService.currentMealSystem != null) {
      setState(() {
        _compatibility = preferenceService.analyzeGroupCompatibility(
          mealSystem: systemService.currentMealSystem!,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferenceService = Provider.of<MealPreferenceService>(context);
    final systemService = Provider.of<MealSystemService>(context);

    if (_compatibility == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Group Compatibility'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Group Compatibility'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compatibility Overview Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      _compatibility!.isCompatible 
                          ? Icons.check_circle 
                          : Icons.warning,
                      size: 64,
                      color: _compatibility!.isCompatible 
                          ? Colors.green 
                          : Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _compatibility!.isCompatible 
                          ? 'Group is Compatible' 
                          : 'Mixed Preferences',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _compatibility!.isCompatible 
                            ? Colors.green 
                            : Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_compatibility!.totalMembers} members',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dietary Breakdown Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dietary Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DietaryBar(
                      icon: '🥗',
                      label: 'Vegetarian',
                      count: _compatibility!.vegetarianCount,
                      total: _compatibility!.totalMembers,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _DietaryBar(
                      icon: '🌱',
                      label: 'Vegan',
                      count: _compatibility!.veganCount,
                      total: _compatibility!.totalMembers,
                      color: Colors.lightGreen,
                    ),
                    const SizedBox(height: 12),
                    _DietaryBar(
                      icon: '🍖',
                      label: 'Non-Vegetarian',
                      count: _compatibility!.nonVegCount,
                      total: _compatibility!.totalMembers,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _DietaryBar(
                      icon: '🐟',
                      label: 'Pescatarian',
                      count: _compatibility!.pescatarianCount,
                      total: _compatibility!.totalMembers,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Majority Type: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DietaryType.getDisplayName(_compatibility!.majorityDietaryType),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Conflicts Card
            if (_compatibility!.conflictingPreferences.isNotEmpty) ...[
              Card(
                elevation: 2,
                color: Colors.orange[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Important Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._compatibility!.conflictingPreferences.map((conflict) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(
                                  conflict,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Common Allergies Card
            if (_compatibility!.commonAllergies.isNotEmpty) ...[
              Card(
                elevation: 2,
                color: Colors.red[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Common Allergies (Avoid)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _compatibility!.commonAllergies.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.key} (${entry.value} ${entry.value == 1 ? "person" : "people"})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[900],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Common Dislikes Card
            if (_compatibility!.commonDislikes.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.thumb_down, color: Colors.orange, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Common Dislikes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _compatibility!.commonDislikes.entries.take(10).map((entry) {
                          return Chip(
                            label: Text('${entry.key} (${entry.value})'),
                            backgroundColor: Colors.orange[50],
                            labelStyle: const TextStyle(fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Suggested Safe Dishes Card
            if (_compatibility!.safeDishes.isNotEmpty) ...[
              Card(
                elevation: 2,
                color: Colors.green[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.restaurant_menu, color: Colors.green, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Suggested Safe Dishes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'These dishes work well for your group',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._compatibility!.safeDishes.map((dish) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, 
                                  size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dish,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Compromise Meal Suggestions
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Compromise Meal Ideas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...preferenceService.suggestCompromiseMeals(
                      mealSystem: systemService.currentMealSystem!,
                    ).map((meal) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 ', style: TextStyle(fontSize: 16)),
                            Expanded(
                              child: Text(
                                meal,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recommendations Card
            Card(
              elevation: 2,
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: Colors.blue, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Tips for Your Group',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_compatibility!.shouldPrioritizeVegetarian)
                      _TipItem(
                        icon: Icons.check,
                        text: 'Consider cooking vegetarian meals more often (${_compatibility!.vegetarianPercentage.toStringAsFixed(0)}% of group is vegetarian)',
                      )
                    else
                      _TipItem(
                        icon: Icons.check,
                        text: 'Mixed preferences detected. Consider preparing separate veg/non-veg options',
                      ),
                    const SizedBox(height: 8),
                    _TipItem(
                      icon: Icons.check,
                      text: 'Always announce dishes in advance to avoid allergen issues',
                    ),
                    const SizedBox(height: 8),
                    _TipItem(
                      icon: Icons.check,
                      text: 'Keep common allergens separate during cooking',
                    ),
                    if (_compatibility!.veganCount > 0) ...[
                      const SizedBox(height: 8),
                      _TipItem(
                        icon: Icons.info,
                        text: 'Group has vegan members - avoid dairy, eggs, and all animal products in shared dishes',
                      ),
                    ],
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

class _DietaryBar extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final int total;
  final Color color;

  const _DietaryBar({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total) : 0.0;
    final percentText = (percentage * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count ($percentText%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[900],
            ),
          ),
        ),
      ],
    );
  }
}