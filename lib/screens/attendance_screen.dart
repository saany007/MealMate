import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../models/attendance_model.dart';
import '../widgets/custom_button.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final String _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _markAttendance(
    String systemId,
    String mealType,
    String status,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);

    final success = await attendanceService.markAttendance(
      systemId: systemId,
      date: _todayDate,
      mealType: mealType,
      userId: authService.userModel!.userId,
      userName: authService.userModel!.name,
      status: status,
    );

    if (success && mounted) {
      Fluttertoast.showToast(
        msg: 'Attendance marked for ${mealType.toLowerCase()}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _quickCheckInAll(String systemId, String status) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);

    final success = await attendanceService.quickCheckInAllMeals(
      systemId: systemId,
      userId: authService.userModel!.userId,
      userName: authService.userModel!.name,
      status: status,
    );

    if (success && mounted) {
      Fluttertoast.showToast(
        msg: 'Checked in for all meals!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) {
      return const Scaffold(
        body: Center(child: Text('No meal system found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Meal Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/attendance-history');
            },
          ),
        ],
      ),
      body: StreamBuilder<AttendanceModel?>(
        stream: Provider.of<AttendanceService>(context)
            .streamAttendanceForDate(systemId: systemId, date: _todayDate),
        builder: (context, snapshot) {
          final attendance = snapshot.data;
          final userId = authService.userModel!.userId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mark your meal attendance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        label: 'All Yes',
                        icon: Icons.check_circle,
                        color: Colors.green,
                        onPressed: () => _quickCheckInAll(systemId, AttendanceStatus.yes),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        label: 'All No',
                        icon: Icons.cancel,
                        color: Colors.red,
                        onPressed: () => _quickCheckInAll(systemId, AttendanceStatus.no),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Breakfast
                _MealCard(
                  mealType: 'breakfast',
                  icon: Icons.wb_twilight,
                  title: 'Breakfast',
                  currentStatus: attendance?.getUserStatus(userId, 'breakfast'),
                  attendeeCount: attendance?.countAttendees('breakfast') ?? 0,
                  onStatusSelected: (status) {
                    _markAttendance(systemId, 'breakfast', status);
                  },
                ),
                const SizedBox(height: 16),

                // Lunch
                _MealCard(
                  mealType: 'lunch',
                  icon: Icons.wb_sunny,
                  title: 'Lunch',
                  currentStatus: attendance?.getUserStatus(userId, 'lunch'),
                  attendeeCount: attendance?.countAttendees('lunch') ?? 0,
                  onStatusSelected: (status) {
                    _markAttendance(systemId, 'lunch', status);
                  },
                ),
                const SizedBox(height: 16),

                // Dinner
                _MealCard(
                  mealType: 'dinner',
                  icon: Icons.nights_stay,
                  title: 'Dinner',
                  currentStatus: attendance?.getUserStatus(userId, 'dinner'),
                  attendeeCount: attendance?.countAttendees('dinner') ?? 0,
                  onStatusSelected: (status) {
                    _markAttendance(systemId, 'dinner', status);
                  },
                ),
                const SizedBox(height: 24),

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
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your attendance helps the cook prepare the right amount of food and is used for expense calculations.',
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
        },
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final String mealType;
  final IconData icon;
  final String title;
  final String? currentStatus;
  final int attendeeCount;
  final Function(String) onStatusSelected;

  const _MealCard({
    required this.mealType,
    required this.icon,
    required this.title,
    required this.currentStatus,
    required this.attendeeCount,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$attendeeCount ${attendeeCount == 1 ? 'person' : 'people'} eating',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (currentStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(currentStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AttendanceStatus.getEmoji(currentStatus!)),
                        const SizedBox(width: 4),
                        Text(
                          AttendanceStatus.getDisplayName(currentStatus!),
                          style: TextStyle(
                            color: _getStatusColor(currentStatus),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),

            // Status Buttons
            const Text(
              'Will you be eating?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: 'Yes',
                    emoji: '✅',
                    isSelected: currentStatus == AttendanceStatus.yes,
                    color: Colors.green,
                    onPressed: () => onStatusSelected(AttendanceStatus.yes),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: 'No',
                    emoji: '❌',
                    isSelected: currentStatus == AttendanceStatus.no,
                    color: Colors.red,
                    onPressed: () => onStatusSelected(AttendanceStatus.no),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: 'Maybe',
                    emoji: '❓',
                    isSelected: currentStatus == AttendanceStatus.maybe,
                    color: Colors.orange,
                    onPressed: () => onStatusSelected(AttendanceStatus.maybe),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case AttendanceStatus.yes:
        return Colors.green;
      case AttendanceStatus.no:
        return Colors.red;
      case AttendanceStatus.maybe:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final Color color;
  final VoidCallback onPressed;

  const _StatusButton({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[100],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}