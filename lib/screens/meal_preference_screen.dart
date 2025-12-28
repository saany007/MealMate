import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/meal_preference_service.dart';
import '../services/auth_service.dart';
import '../services/meal_system_service.dart';
import '../models/meal_preference_model.dart';
import 'edit_meal_preference_screen.dart';
import 'group_compatibility_screen.dart';

class MealPreferenceScreen extends StatefulWidget {
  const MealPreferenceScreen({super.key});

  @override
  State<MealPreferenceScreen> createState() => _MealPreferenceScreenState();
}

class _MealPreferenceScreenState extends State<MealPreferenceScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final preferenceService = Provider.of<MealPreferenceService>(context, listen: false);
    
    if (authService.userModel?.currentMealSystemId != null) {
      await preferenceService.loadMealPreferences(
        authService.userModel!.currentMealSystemId!,
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  void _viewGroupCompatibility() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GroupCompatibilityScreen(),
      ),
    );
  }

  void _editMyPreference() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final preferenceService = Provider.of<MealPreferenceService>(context, listen: false);
    
    final myPreference = preferenceService.getPreferenceForUser(
      authService.userModel!.userId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMealPreferenceScreen(
          existingPreference: myPreference,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final preferenceService = Provider.of<MealPreferenceService>(context);
    final systemService = Provider.of<MealSystemService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meal Preferences'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final myUserId = authService.userModel?.userId;
    final myPreference = myUserId != null 
        ? preferenceService.getPreferenceForUser(myUserId) 
        : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Meal Preferences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Group Compatibility',
            onPressed: _viewGroupCompatibility,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // My Preference Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.green,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'My Preferences',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              myPreference == null ? Icons.add : Icons.edit,
                              color: Colors.green,
                            ),
                            onPressed: _editMyPreference,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (myPreference != null)
                        _MyPreferenceView(preference: myPreference)
                      else
                        Column(
                          children: [
                            const Text(
                              'You haven\'t set your meal preferences yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _editMyPreference,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Preferences'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Statistics Section
              Row(
                children: [
                  const Text(
                    'Group Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _viewGroupCompatibility,
                    icon: const Icon(Icons.analytics, size: 18),
                    label: const Text('View Details'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dietary Distribution
              _DietaryDistributionCard(
                distribution: preferenceService.getDietaryDistribution(),
                totalMembers: systemService.currentMealSystem?.memberCount ?? 0,
              ),
              const SizedBox(height: 16),

              // Common Allergies
              if (preferenceService.getCommonAllergies().isNotEmpty) ...[
                _CommonAllergiesCard(
                  allergies: preferenceService.getCommonAllergies(),
                ),
                const SizedBox(height: 16),
              ],

              // Favorite Dishes
              if (preferenceService.getFavoriteDishes().isNotEmpty) ...[
                _FavoriteDishesCard(
                  dishes: preferenceService.getFavoriteDishes(),
                ),
                const SizedBox(height: 16),
              ],

              // All Members' Preferences
              const Text(
                'All Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (preferenceService.preferences.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No preferences set yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...preferenceService.preferences.entries.map((entry) {
                  final userId = entry.key;
                  final preference = entry.value;
                  final isMe = userId == myUserId;

                  return _MemberPreferenceCard(
                    preference: preference,
                    isMe: isMe,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyPreferenceView extends StatelessWidget {
  final MealPreferenceModel preference;

  const _MyPreferenceView({required this.preference});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dietary Type
        Row(
          children: [
            Text(
              DietaryType.getEmoji(preference.dietaryType),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Text(
              DietaryType.getDisplayName(preference.dietaryType),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Spice Tolerance
        Row(
          children: [
            Text(
              SpiceTolerance.getEmoji(preference.spiceTolerance),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Text(
              SpiceTolerance.getDisplayName(preference.spiceTolerance),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Allergies
        if (preference.hasAllergies) ...[
          const Text(
            '⚠️ Allergies',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preference.allergies.map((allergen) {
              return Chip(
                label: Text(allergen),
                backgroundColor: Colors.red[50],
                labelStyle: const TextStyle(fontSize: 12),
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Dislikes
        if (preference.hasDislikes) ...[
          const Text(
            '👎 Dislikes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preference.dislikes.map((dislike) {
              return Chip(
                label: Text(dislike),
                backgroundColor: Colors.orange[50],
                labelStyle: const TextStyle(fontSize: 12),
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _DietaryDistributionCard extends StatelessWidget {
  final Map<String, int> distribution;
  final int totalMembers;

  const _DietaryDistributionCard({
    required this.distribution,
    required this.totalMembers,
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
            const Text(
              'Dietary Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...distribution.entries.where((e) => e.value > 0).map((entry) {
              final percentage = totalMembers > 0 
                  ? (entry.value / totalMembers * 100).toStringAsFixed(0)
                  : '0';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(DietaryType.getEmoji(entry.key)),
                        const SizedBox(width: 8),
                        Text(
                          DietaryType.getDisplayName(entry.key),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          '${entry.value} ($percentage%)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: totalMembers > 0 ? entry.value / totalMembers : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getDietaryColor(entry.key),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getDietaryColor(String type) {
    switch (type) {
      case DietaryType.vegetarian:
        return Colors.green;
      case DietaryType.vegan:
        return Colors.lightGreen;
      case DietaryType.nonVeg:
        return Colors.orange;
      case DietaryType.pescatarian:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _CommonAllergiesCard extends StatelessWidget {
  final Map<String, int> allergies;

  const _CommonAllergiesCard({required this.allergies});

  @override
  Widget build(BuildContext context) {
    final topAllergies = allergies.entries.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text(
                  'Common Allergies',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topAllergies.map((entry) {
                return Chip(
                  label: Text('${entry.key} (${entry.value})'),
                  backgroundColor: Colors.red[50],
                  avatar: const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteDishesCard extends StatelessWidget {
  final Map<String, int> dishes;

  const _FavoriteDishesCard({required this.dishes});

  @override
  Widget build(BuildContext context) {
    final topDishes = dishes.entries.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.favorite, color: Colors.pink, size: 20),
                SizedBox(width: 8),
                Text(
                  'Popular Dishes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...topDishes.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value} 👍',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.pink[700],
                          fontWeight: FontWeight.bold,
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
    );
  }
}

class _MemberPreferenceCard extends StatelessWidget {
  final MealPreferenceModel preference;
  final bool isMe;

  const _MemberPreferenceCard({
    required this.preference,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isMe ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMe
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: Text(
                    preference.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            preference.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(DietaryType.getEmoji(preference.dietaryType)),
                          const SizedBox(width: 4),
                          Text(
                            DietaryType.getDisplayName(preference.dietaryType),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (preference.hasAllergies || preference.hasDislikes) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
            if (preference.hasAllergies) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: preference.allergies.map((allergen) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning, size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          allergen,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}