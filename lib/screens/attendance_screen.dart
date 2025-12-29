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

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  // Use today's date for default view
  final DateTime _selectedDate = DateTime.now();
  late String _formattedDate;

  @override
  void initState() {
    super.initState();
    _formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  // Mark attendance using the service
  Future<void> _markAttendance(
    String systemId,
    String mealType,
    String status,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);
    final user = authService.userModel;

    if (user == null) return;

    // Call the transaction-based method
    final success = await attendanceService.markAttendance(
      systemId: systemId,
      date: _formattedDate,
      mealType: mealType,
      userId: user.userId,
      userName: user.name,
      status: status,
    );

    if (success && mounted) {
      // Optional: Show a subtle toast or snackbar
      // We rely on the StreamBuilder to update the UI instantly
    } else if (mounted) {
      Fluttertoast.showToast(
        msg: attendanceService.errorMessage ?? 'Failed to update',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final attendanceService = Provider.of<AttendanceService>(context);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    // Safety check
    if (systemId == null || userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: const Center(child: Text('You are not part of a meal system.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Attendance'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'View History',
            onPressed: () {
              Navigator.pushNamed(context, '/attendance-history');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. DATE HEADER
          _buildDateHeader(),

          // 2. MAIN CONTENT (Wrapped in StreamBuilder for Real-Time Updates)
          Expanded(
            child: StreamBuilder<Map<String, String?>>(
              // Listen to the specific document for this user/date
              stream: attendanceService.streamUserAttendance(
                systemId: systemId,
                userId: userId,
                date: _formattedDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading data: ${snapshot.error}'),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Current statuses from DB
                final statuses = snapshot.data ?? 
                    {'breakfast': null, 'lunch': null, 'dinner': null};

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 3. DAILY SUMMARY CARD
                    _buildDailySummaryCard(statuses),
                    const SizedBox(height: 24),

                    // 4. MEAL CARDS
                    _buildSectionTitle('Mark Your Meals'),
                    const SizedBox(height: 12),
                    
                    _buildMealCard(
                      systemId: systemId,
                      title: 'Breakfast',
                      timeRange: '07:00 AM - 10:00 AM',
                      mealType: 'breakfast',
                      currentStatus: statuses['breakfast'],
                      icon: Icons.wb_twilight_rounded,
                      color: Colors.orange,
                    ),
                    
                    _buildMealCard(
                      systemId: systemId,
                      title: 'Lunch',
                      timeRange: '12:30 PM - 03:00 PM',
                      mealType: 'lunch',
                      currentStatus: statuses['lunch'],
                      icon: Icons.wb_sunny_rounded,
                      color: Colors.amber[700]!,
                    ),
                    
                    _buildMealCard(
                      systemId: systemId,
                      title: 'Dinner',
                      timeRange: '08:00 PM - 10:30 PM',
                      mealType: 'dinner',
                      currentStatus: statuses['dinner'],
                      icon: Icons.nights_stay_rounded,
                      color: Colors.indigo,
                    ),

                    const SizedBox(height: 32),
                    const Center(
                      child: Text(
                        'Marking correct attendance helps reduce food waste!',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummaryCard(Map<String, String?> statuses) {
    int eatingCount = 0;
    statuses.forEach((key, value) {
      if (value == AttendanceStatus.yes) eatingCount++;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Overview',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'You are eating $eatingCount meal${eatingCount != 1 ? 's' : ''} today',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMealCard({
    required String systemId,
    required String title,
    required String timeRange,
    required String mealType,
    required String? currentStatus,
    required IconData icon,
    required Color color,
  }) {
    final bool isAnswered = currentStatus != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isAnswered
            ? Border.all(color: _getStatusColor(currentStatus!).withOpacity(0.3), width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            timeRange,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isAnswered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(currentStatus!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(currentStatus),
                          size: 14,
                          color: _getStatusColor(currentStatus),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AttendanceStatus.getDisplayName(currentStatus),
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
          ),
          
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Colors.grey[100]),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _StatusSelectionButton(
                    label: 'Eating',
                    emoji: '✅',
                    isActive: currentStatus == AttendanceStatus.yes,
                    activeColor: Colors.green,
                    onTap: () => _markAttendance(systemId, mealType, AttendanceStatus.yes),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusSelectionButton(
                    label: 'Skip',
                    emoji: '❌',
                    isActive: currentStatus == AttendanceStatus.no,
                    activeColor: Colors.red,
                    onTap: () => _markAttendance(systemId, mealType, AttendanceStatus.no),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusSelectionButton(
                    label: 'Maybe',
                    emoji: '❓',
                    isActive: currentStatus == AttendanceStatus.maybe,
                    activeColor: Colors.orange,
                    onTap: () => _markAttendance(systemId, mealType, AttendanceStatus.maybe),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AttendanceStatus.yes:
        return Colors.green[700]!;
      case AttendanceStatus.no:
        return Colors.red[700]!;
      case AttendanceStatus.maybe:
        return Colors.orange[800]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case AttendanceStatus.yes:
        return Icons.check_circle_outline;
      case AttendanceStatus.no:
        return Icons.cancel_outlined;
      case AttendanceStatus.maybe:
        return Icons.help_outline;
      default:
        return Icons.circle_outlined;
    }
  }
}

// ==================== CUSTOM HELPER WIDGETS ====================

class _StatusSelectionButton extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _StatusSelectionButton({
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? activeColor : Colors.grey[200]!,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: TextStyle(
                  fontSize: 20,
                  shadows: isActive
                      ? [
                          const Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}