import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/meal_preference_service.dart';
import '../services/auth_service.dart';
import '../models/meal_preference_model.dart';

class EditMealPreferenceScreen extends StatefulWidget {
  final MealPreferenceModel? existingPreference;

  const EditMealPreferenceScreen({super.key, this.existingPreference});

  @override
  State<EditMealPreferenceScreen> createState() => _EditMealPreferenceScreenState();
}

class _EditMealPreferenceScreenState extends State<EditMealPreferenceScreen> {
  late String _selectedDietaryType;
  late String _selectedSpiceTolerance;
  late Set<String> _selectedAllergies;
  late Set<String> _selectedDislikes;
  late List<String> _favoriteDishes;
  late Set<String> _selectedCuisines;
  late bool _avoidOnion;
  late bool _avoidGarlic;
  final TextEditingController _additionalNotesController = TextEditingController();
  final TextEditingController _dishController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingPreference != null) {
      final pref = widget.existingPreference!;
      _selectedDietaryType = pref.dietaryType;
      _selectedSpiceTolerance = pref.spiceTolerance;
      _selectedAllergies = Set.from(pref.allergies);
      _selectedDislikes = Set.from(pref.dislikes);
      _favoriteDishes = List.from(pref.favoriteDishes);
      _selectedCuisines = Set.from(pref.cuisinePreferences);
      _avoidOnion = pref.avoidOnion;
      _avoidGarlic = pref.avoidGarlic;
      _additionalNotesController.text = pref.additionalNotes ?? '';
    } else {
      _selectedDietaryType = DietaryType.nonVeg;
      _selectedSpiceTolerance = SpiceTolerance.medium;
      _selectedAllergies = {};
      _selectedDislikes = {};
      _favoriteDishes = [];
      _selectedCuisines = {};
      _avoidOnion = false;
      _avoidGarlic = false;
    }
  }

  @override
  void dispose() {
    _additionalNotesController.dispose();
    _dishController.dispose();
    super.dispose();
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final preferenceService = Provider.of<MealPreferenceService>(context, listen: false);

    final success = await preferenceService.saveMealPreference(
      systemId: authService.userModel!.currentMealSystemId!,
      userId: authService.userModel!.userId,
      userName: authService.userModel!.name,
      dietaryType: _selectedDietaryType,
      allergies: _selectedAllergies.toList(),
      dislikes: _selectedDislikes.toList(),
      spiceTolerance: _selectedSpiceTolerance,
      favoriteDishes: _favoriteDishes,
      cuisinePreferences: _selectedCuisines.toList(),
      avoidOnion: _avoidOnion,
      avoidGarlic: _avoidGarlic,
      additionalNotes: _additionalNotesController.text.trim().isEmpty 
          ? null 
          : _additionalNotesController.text.trim(),
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preferences'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addFavoriteDish() {
    final dish = _dishController.text.trim();
    if (dish.isNotEmpty && !_favoriteDishes.contains(dish)) {
      setState(() {
        _favoriteDishes.add(dish);
        _dishController.clear();
      });
    }
  }

  void _removeFavoriteDish(String dish) {
    setState(() {
      _favoriteDishes.remove(dish);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.existingPreference == null 
            ? 'Set Preferences' 
            : 'Edit Preferences'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dietary Type Section
            _SectionCard(
              title: 'Dietary Type',
              icon: Icons.restaurant,
              child: Column(
                children: DietaryType.all.map((type) {
                  return RadioListTile<String>(
                    value: type,
                    groupValue: _selectedDietaryType,
                    onChanged: (value) {
                      setState(() {
                        _selectedDietaryType = value!;
                      });
                    },
                    title: Row(
                      children: [
                        Text(DietaryType.getEmoji(type), style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(DietaryType.getDisplayName(type)),
                      ],
                    ),
                    subtitle: Text(
                      DietaryType.getDescription(type),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Spice Tolerance Section
            _SectionCard(
              title: 'Spice Tolerance',
              icon: Icons.local_fire_department,
              child: Column(
                children: SpiceTolerance.all.map((tolerance) {
                  return RadioListTile<String>(
                    value: tolerance,
                    groupValue: _selectedSpiceTolerance,
                    onChanged: (value) {
                      setState(() {
                        _selectedSpiceTolerance = value!;
                      });
                    },
                    title: Row(
                      children: [
                        Text(SpiceTolerance.getEmoji(tolerance)),
                        const SizedBox(width: 8),
                        Text(SpiceTolerance.getDisplayName(tolerance)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Allergies Section
            _SectionCard(
              title: 'Allergies (Critical)',
              icon: Icons.warning,
              iconColor: Colors.red,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CommonAllergens.all.map((allergen) {
                  final isSelected = _selectedAllergies.contains(allergen);
                  return FilterChip(
                    label: Text(CommonAllergens.getDisplayName(allergen)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAllergies.add(allergen);
                        } else {
                          _selectedAllergies.remove(allergen);
                        }
                      });
                    },
                    selectedColor: Colors.red[100],
                    checkmarkColor: Colors.red,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Dislikes Section
            _SectionCard(
              title: 'Dislikes',
              icon: Icons.thumb_down,
              iconColor: Colors.orange,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CommonDislikes.all.map((dislike) {
                  final isSelected = _selectedDislikes.contains(dislike);
                  return FilterChip(
                    label: Text(dislike),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDislikes.add(dislike);
                        } else {
                          _selectedDislikes.remove(dislike);
                        }
                      });
                    },
                    selectedColor: Colors.orange[100],
                    checkmarkColor: Colors.orange,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Special Preferences
            _SectionCard(
              title: 'Special Preferences',
              icon: Icons.settings,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Avoid Onion'),
                    value: _avoidOnion,
                    onChanged: (value) {
                      setState(() {
                        _avoidOnion = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Avoid Garlic'),
                    value: _avoidGarlic,
                    onChanged: (value) {
                      setState(() {
                        _avoidGarlic = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cuisine Preferences
            _SectionCard(
              title: 'Favorite Cuisines',
              icon: Icons.public,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CuisineType.all.map((cuisine) {
                  final isSelected = _selectedCuisines.contains(cuisine);
                  return FilterChip(
                    label: Text(cuisine),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCuisines.add(cuisine);
                        } else {
                          _selectedCuisines.remove(cuisine);
                        }
                      });
                    },
                    selectedColor: Colors.blue[100],
                    checkmarkColor: Colors.blue,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Favorite Dishes Section
            _SectionCard(
              title: 'Favorite Dishes',
              icon: Icons.favorite,
              iconColor: Colors.pink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dishController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a favorite dish',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _addFavoriteDish(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addFavoriteDish,
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (_favoriteDishes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _favoriteDishes.map((dish) {
                        return Chip(
                          label: Text(dish),
                          onDeleted: () => _removeFavoriteDish(dish),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          backgroundColor: Colors.pink[50],
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Additional Notes Section
            _SectionCard(
              title: 'Additional Notes',
              icon: Icons.notes,
              child: TextField(
                controller: _additionalNotesController,
                decoration: const InputDecoration(
                  hintText: 'Any other preferences or restrictions...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _savePreferences,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Preferences',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor ?? Colors.green, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}