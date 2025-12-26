import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/daily_meal_model.dart';
import '../widgets/custom_button.dart';

class MealCalendarScreen extends StatefulWidget {
  const MealCalendarScreen({super.key});

  @override
  State<MealCalendarScreen> createState() => _MealCalendarScreenState();
}

class _MealCalendarScreenState extends State<MealCalendarScreen> {
  final DatabaseService _db = DatabaseService();
  DateTime _selectedDate = DateTime.now();
  
  // Get next 7 days
  List<DateTime> get _weekDays {
    final now = DateTime.now();
    return List.generate(7, (index) => now.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) return const Scaffold(body: Center(child: Text("No System Found")));

    // Prepare date keys for DB
    List<String> dateKeys = _weekDays.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Meal Calendar')),
      body: Column(
        children: [
          // 1. Horizontal Date Selector
          Container(
            height: 100,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _weekDays.length,
              itemBuilder: (context, index) {
                final date = _weekDays[index];
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[300]!),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8)] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Meal List
          Expanded(
            child: StreamBuilder<List<DailyMealModel>>(
              stream: _db.streamWeeklyMeals(systemId, dateKeys),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Find data for selected date
                final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                final dayData = snapshot.data?.firstWhere(
                  (m) => m.date == selectedDateStr,
                  orElse: () => DailyMealModel(
                    date: selectedDateStr, 
                    breakfast: MealSlot(), 
                    lunch: MealSlot(), 
                    dinner: MealSlot()
                  ),
                );

                if (dayData == null) return const Center(child: Text("Error loading data"));

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildMealCard('Breakfast', dayData.breakfast, 'breakfast', systemId),
                    _buildMealCard('Lunch', dayData.lunch, 'lunch', systemId),
                    _buildMealCard('Dinner', dayData.dinner, 'dinner', systemId),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String title, MealSlot slot, String mealType, String systemId) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.userModel?.userId;
    
    bool isAssigned = slot.cookId != null;
    bool isMe = slot.cookId == userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      title == 'Breakfast' ? Icons.wb_twilight : title == 'Lunch' ? Icons.wb_sunny : Icons.nights_stay,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAssigned ? (isMe ? Colors.yellow[100] : Colors.green[50]) : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAssigned ? (isMe ? 'You' : slot.cookName!) : 'No Cook',
                    style: TextStyle(
                      color: isAssigned ? (isMe ? Colors.orange[800] : Colors.green[800]) : Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Details
            _buildDetailRow(Icons.restaurant_menu, 'Menu', slot.menu ?? 'Not decided'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.group, 'Attendees', '${slot.attendees} people'),
            
            const SizedBox(height: 16),
            
            // Action Button
            if (!isAssigned)
              CustomButton(
                text: 'Volunteer to Cook',
                onPressed: () => _showVolunteerDialog(systemId, mealType),
                height: 40,
                isOutlined: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Future<void> _showVolunteerDialog(String systemId, String mealType) async {
    final menuController = TextEditingController();
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel!;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Volunteer for $mealType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("What are you planning to cook?"),
            const SizedBox(height: 10),
            TextField(
              controller: menuController,
              decoration: const InputDecoration(
                hintText: "e.g., Chicken Curry & Rice",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _db.volunteerToCook(
                systemId: systemId,
                date: dateStr,
                mealType: mealType,
                cookId: user.userId,
                cookName: user.name,
                menu: menuController.text.isEmpty ? 'TBD' : menuController.text,
              );
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}