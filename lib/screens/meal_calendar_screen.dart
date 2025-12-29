import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart'; // Kept for other reads if needed
import '../models/attendance_model.dart'; 

class MealCalendarScreen extends StatefulWidget {
  const MealCalendarScreen({super.key});

  @override
  State<MealCalendarScreen> createState() => _MealCalendarScreenState();
}

class _MealCalendarScreenState extends State<MealCalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  // Generate next 14 days for the horizontal scroller
  List<DateTime> get _calendarDays {
    final now = DateTime.now();
    return List.generate(14, (index) => now.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) {
      return const Scaffold(body: Center(child: Text("No System Found")));
    }

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Meal Calendar'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Modern Date Selector
          _buildDateSelector(),

          // 2. Real-time Meal Content
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              // STREAM 1: Read Meal Details (Cook, Menu) from mealCalendar
              stream: FirebaseFirestore.instance
                  .collection('mealCalendar')
                  .doc(systemId)
                  .collection('days')
                  .doc(selectedDateStr)
                  .snapshots(),
              builder: (context, mealSnapshot) {
                
                return StreamBuilder<DocumentSnapshot>(
                  // STREAM 2: Read Attendance (Who is eating) directly to calculate count
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .doc(systemId)
                      .collection('days')
                      .doc(selectedDateStr)
                      .snapshots(),
                  builder: (context, attendanceSnapshot) {
                    if (mealSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Parse Meal Data (Cooks & Menus)
                    final mealData = mealSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                    
                    // Parse Attendance Data (To count attendees)
                    final attendanceData = attendanceSnapshot.data?.data() as Map<String, dynamic>? ?? {};

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildMealCard(
                          context,
                          'Breakfast',
                          'breakfast',
                          mealData['breakfast'],
                          attendanceData['breakfast'],
                          Icons.wb_twilight_rounded,
                          Colors.orange,
                          systemId,
                        ),
                        _buildMealCard(
                          context,
                          'Lunch',
                          'lunch',
                          mealData['lunch'],
                          attendanceData['lunch'],
                          Icons.wb_sunny_rounded,
                          Colors.amber[700]!,
                          systemId,
                        ),
                        _buildMealCard(
                          context,
                          'Dinner',
                          'dinner',
                          mealData['dinner'],
                          attendanceData['dinner'],
                          Icons.nights_stay_rounded,
                          Colors.indigo,
                          systemId,
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildDateSelector() {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 10, bottom: 5),
            child: Text(
              DateFormat('MMMM yyyy').format(_selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _calendarDays.length,
              itemBuilder: (context, index) {
                final date = _calendarDays[index];
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final isToday = DateUtils.isSameDay(date, DateTime.now());

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: isToday && !isSelected
                          ? Border.all(color: Colors.white70, width: 1.5)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildMealCard(
    BuildContext context,
    String title,
    String mealType,
    Map<String, dynamic>? mealInfo,
    Map<String, dynamic>? attendanceInfo,
    IconData icon,
    Color accentColor,
    String systemId,
  ) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.userModel?.userId;

    // 1. Extract Cook Info
    final String? cookName = mealInfo?['cookName'];
    final String? cookId = mealInfo?['cookId'];
    // This reads the 'menu' field. We will ensure we write to THIS exact field.
    final String menu = mealInfo?['menu'] ?? 'Not decided yet';
    final bool isAssigned = cookId != null;
    final bool isMe = cookId == userId;

    // 2. Calculate Real Attendee Count
    int attendeeCount = 0;
    if (attendanceInfo != null) {
      attendanceInfo.forEach((key, value) {
        if (value is Map && value['status'] == AttendanceStatus.yes) {
          attendeeCount++;
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAssigned 
                  ? (isMe ? Colors.yellow[50] : Colors.green[50])
                  : Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (isAssigned)
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                    label: Text(
                      isMe ? 'You are cooking' : 'Chef: $cookName',
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: isMe ? Colors.orange : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  )
                else
                  Chip(
                    label: const Text('No Cook Assigned'),
                    labelStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                    backgroundColor: Colors.red[50],
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(Icons.restaurant_menu, 'Menu', menu),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.groups, 'Attendees', '$attendeeCount people eating'),
                
                if (!isAssigned || isMe) ...[ // Allow editing if it's me!
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showVolunteerDialog(systemId, mealType, currentMenu: isMe ? menu : null),
                      icon: Icon(isMe ? Icons.edit : Icons.volunteer_activism, size: 18),
                      label: Text(isMe ? 'Update Menu' : 'Volunteer to Cook'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // UPDATED: DIRECT FIREBASE WRITE TO FIX UPDATE ISSUE
  Future<void> _showVolunteerDialog(String systemId, String mealType, {String? currentMenu}) async {
    final menuController = TextEditingController(text: currentMenu == 'Not decided yet' ? '' : currentMenu);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel!;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentMenu == null ? 'Volunteer for $mealType' : 'Update Menu'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What are you planning to cook?",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: menuController,
              decoration: InputDecoration(
                hintText: "e.g., Chicken Curry & Rice",
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final menuText = menuController.text.isEmpty ? 'TBD' : menuController.text;

              // DIRECT WRITE: Ensures the menu updates instantly
              await FirebaseFirestore.instance
                  .collection('mealCalendar')
                  .doc(systemId)
                  .collection('days')
                  .doc(dateStr)
                  .set({
                    mealType: {
                      'cookId': user.userId,
                      'cookName': user.name,
                      'menu': menuText, // This updates the field UI is reading
                    }
                  }, SetOptions(merge: true));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}