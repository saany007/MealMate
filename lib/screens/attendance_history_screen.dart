import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../models/attendance_model.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _selectedMonth = DateTime.now();
  UserAttendanceSummary? _summary;
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    _loadMonthlySummary();
  }

  Future<void> _loadMonthlySummary() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || userId == null) return;

    setState(() => _isLoadingSummary = true);

    final summary = await attendanceService.getUserMonthlySummary(
      systemId: systemId,
      userId: userId,
      month: _selectedMonth,
    );

    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadMonthlySummary();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadMonthlySummary();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || userId == null) {
      return const Scaffold(
        body: Center(child: Text('No meal system found')),
      );
    }

    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // Monthly Summary
          if (_isLoadingSummary)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_summary != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryItem(
                        icon: Icons.restaurant,
                        label: 'Meals Eaten',
                        value: '${_summary!.totalMealsEaten}',
                        color: Colors.green,
                      ),
                      _SummaryItem(
                        icon: Icons.cancel,
                        label: 'Skipped',
                        value: '${_summary!.totalMealsSkipped}',
                        color: Colors.red,
                      ),
                      _SummaryItem(
                        icon: Icons.percent,
                        label: 'Attendance',
                        value: '${_summary!.attendanceRate.toStringAsFixed(1)}%',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Daily History
          Expanded(
            child: FutureBuilder<List<AttendanceModel>>(
              future: Provider.of<AttendanceService>(context, listen: false)
                  .getAttendanceRange(
                systemId: systemId,
                startDate: firstDay,
                endDate: lastDay,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records for this month',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final attendanceList = snapshot.data!;
                // Sort by date descending
                attendanceList.sort((a, b) => b.date.compareTo(a.date));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: attendanceList.length,
                  itemBuilder: (context, index) {
                    final attendance = attendanceList[index];
                    return _DayCard(
                      attendance: attendance,
                      userId: userId,
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
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
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
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final AttendanceModel attendance;
  final String userId;

  const _DayCard({
    required this.attendance,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(attendance.date);
    final breakfastStatus = attendance.breakfast[userId]?.status;
    final lunchStatus = attendance.lunch[userId]?.status;
    final dinnerStatus = attendance.dinner[userId]?.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(date),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Meals
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MealStatus(
                    icon: Icons.wb_twilight,
                    label: 'Breakfast',
                    status: breakfastStatus,
                  ),
                  const SizedBox(height: 8),
                  _MealStatus(
                    icon: Icons.wb_sunny,
                    label: 'Lunch',
                    status: lunchStatus,
                  ),
                  const SizedBox(height: 8),
                  _MealStatus(
                    icon: Icons.nights_stay,
                    label: 'Dinner',
                    status: dinnerStatus,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealStatus extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? status;

  const _MealStatus({
    required this.icon,
    required this.label,
    required this.status,
  });

  Color _getStatusColor() {
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        const Spacer(),
        if (status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AttendanceStatus.getEmoji(status!)),
                const SizedBox(width: 4),
                Text(
                  AttendanceStatus.getDisplayName(status!),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'Not marked',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
      ],
    );
  }
}