import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/cooking_rotation_service.dart';
import '../models/cooking_rotation_model.dart';
import '../widgets/custom_button.dart';

class RotationSettingsScreen extends StatefulWidget {
  const RotationSettingsScreen({super.key});

  @override
  State<RotationSettingsScreen> createState() => _RotationSettingsScreenState();
}

class _RotationSettingsScreenState extends State<RotationSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Settings
  String _selectedFrequency = RotationFrequency.daily;
  List<String> _selectedMeals = ['lunch', 'dinner'];
  bool _autoAssign = true;
  int _daysAhead = 7;
  bool _respectPreferences = true;

  // Member preferences
  List<String> _myPreferredDays = [];
  bool _isActive = true;
  DateTime? _inactiveUntil;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rotationService = Provider.of<CookingRotationService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || userId == null) return;

    final rotation = await rotationService.getRotation(systemId);

    if (rotation != null && mounted) {
      setState(() {
        _selectedFrequency = rotation.settings.frequency;
        _selectedMeals = List.from(rotation.settings.mealsToRotate);
        _autoAssign = rotation.settings.autoAssign;
        _daysAhead = rotation.settings.daysAhead;
        _respectPreferences = rotation.settings.respectPreferences;

        final memberInfo = rotation.members[userId];
        if (memberInfo != null) {
          _myPreferredDays = List.from(memberInfo.preferredDays);
          _isActive = memberInfo.isActive;
          _inactiveUntil = memberInfo.inactiveUntil;
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _saveSystemSettings() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rotationService = Provider.of<CookingRotationService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) return;

    final settings = RotationSettings(
      frequency: _selectedFrequency,
      mealsToRotate: _selectedMeals,
      autoAssign: _autoAssign,
      daysAhead: _daysAhead,
      respectPreferences: _respectPreferences,
    );

    final success = await rotationService.updateSettings(
      systemId: systemId,
      settings: settings,
    );

    if (success && mounted) {
      Fluttertoast.showToast(
        msg: 'Settings saved and schedule regenerated!',
        backgroundColor: Colors.green,
      );
    }
  }

  Future<void> _saveMyPreferences() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rotationService = Provider.of<CookingRotationService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || userId == null) return;

    final success = await rotationService.updateMemberPreferences(
      systemId: systemId,
      userId: userId,
      preferredDays: _myPreferredDays,
      isActive: _isActive,
      inactiveUntil: _inactiveUntil,
    );

    if (success && mounted) {
      Fluttertoast.showToast(
        msg: 'Your preferences saved!',
        backgroundColor: Colors.green,
      );
    }
  }

  Future<void> _selectInactiveUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inactiveUntil ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _inactiveUntil = picked;
        _isActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rotation Settings'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'System Settings'),
            Tab(text: 'My Preferences'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSystemSettingsTab(),
          _buildMyPreferencesTab(),
        ],
      ),
    );
  }

  Widget _buildSystemSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rotation Frequency
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rotation Frequency',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...RotationFrequency.all.map((frequency) {
                    return RadioListTile<String>(
                      title: Text(RotationFrequency.getDisplayName(frequency)),
                      value: frequency,
                      groupValue: _selectedFrequency,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedFrequency = value);
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Meals to Rotate
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meals to Rotate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Breakfast'),
                    value: _selectedMeals.contains('breakfast'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedMeals.add('breakfast');
                        } else {
                          _selectedMeals.remove('breakfast');
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Lunch'),
                    value: _selectedMeals.contains('lunch'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedMeals.add('lunch');
                        } else {
                          _selectedMeals.remove('lunch');
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Dinner'),
                    value: _selectedMeals.contains('dinner'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedMeals.add('dinner');
                        } else {
                          _selectedMeals.remove('dinner');
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Other Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Auto-assign cooks'),
                    subtitle: const Text('Automatically schedule cooks in advance'),
                    value: _autoAssign,
                    onChanged: (value) {
                      setState(() => _autoAssign = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Respect member preferences'),
                    subtitle: const Text('Consider preferred cooking days'),
                    value: _respectPreferences,
                    onChanged: (value) {
                      setState(() => _respectPreferences = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Days to schedule ahead'),
                    subtitle: Text('Currently: $_daysAhead days'),
                    trailing: DropdownButton<int>(
                      value: _daysAhead,
                      items: [7, 14, 21, 30].map((days) {
                        return DropdownMenuItem(
                          value: days,
                          child: Text('$days days'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _daysAhead = value);
                        }
                      },
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          CustomButton(
            text: 'Save System Settings',
            onPressed: _saveSystemSettings,
            width: double.infinity,
            icon: Icons.save,
          ),

          const SizedBox(height: 16),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Changing settings will regenerate the cooking schedule. '
                    'Existing assignments may be updated to match new settings.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preferred Days
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferred Cooking Days',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select days when you prefer to cook',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DaysOfWeek.all.map((day) {
                      final isSelected = _myPreferredDays.contains(day);
                      return ChoiceChip(
                        label: Text(day),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _myPreferredDays.add(day);
                            } else {
                              _myPreferredDays.remove(day);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Active Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Availability',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('I am available to cook'),
                    subtitle: Text(
                      _isActive ? 'You will be included in rotation' : 'You are temporarily inactive',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                        if (value) {
                          _inactiveUntil = null;
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!_isActive) ...[
                    const Divider(),
                    ListTile(
                      title: const Text('Inactive until'),
                      subtitle: Text(
                        _inactiveUntil != null
                            ? '${_inactiveUntil!.day}/${_inactiveUntil!.month}/${_inactiveUntil!.year}'
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _selectInactiveUntilDate,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          CustomButton(
            text: 'Save My Preferences',
            onPressed: _saveMyPreferences,
            width: double.infinity,
            icon: Icons.person,
          ),

          const SizedBox(height: 16),

          // Info Cards
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Preferred days help the system schedule you on days that work best for you. '
                    'Leave empty if you have no preference.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_outlined, color: Colors.orange[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mark yourself inactive if you\'re traveling or unavailable. '
                    'You won\'t be assigned cooking duties during this period.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}