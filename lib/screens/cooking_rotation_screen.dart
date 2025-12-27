import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/cooking_rotation_service.dart';
import '../services/meal_system_service.dart';
import '../models/cooking_rotation_model.dart';
import '../widgets/custom_button.dart';

class CookingRotationScreen extends StatefulWidget {
  const CookingRotationScreen({super.key});

  @override
  State<CookingRotationScreen> createState() => _CookingRotationScreenState();
}

class _CookingRotationScreenState extends State<CookingRotationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRotation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRotation() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rotationService = Provider.of<CookingRotationService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) return;

    final rotation = await rotationService.getRotation(systemId);

    if (rotation == null && mounted) {
      // Show initialization dialog
      _showInitializationDialog();
    } else {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _showInitializationDialog() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rotationService = Provider.of<CookingRotationService>(context, listen: false);
    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) return;

    final shouldInitialize = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Setup Cooking Rotation'),
        content: const Text(
          'Cooking rotation is not set up yet. Would you like to initialize it with default settings?\n\n'
          'This will automatically schedule cooking duties fairly among all members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Initialize'),
          ),
        ],
      ),
    );

    if (shouldInitialize == true && mounted) {
      final mealSystem = await mealSystemService.loadMealSystem(systemId);
      if (mealSystem != null) {
        final success = await rotationService.initializeRotation(
          systemId: systemId,
          mealSystem: mealSystem,
        );

        if (success && mounted) {
          setState(() => _isInitialized = true);
          Fluttertoast.showToast(
            msg: 'Cooking rotation initialized!',
            backgroundColor: Colors.green,
          );
        }
      }
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showManualAssignDialog(String date, String mealType) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rotationService = Provider.of<CookingRotationService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null || rotationService.currentRotation == null) return;

    final members = rotationService.currentRotation!.members.values.toList();

    final selectedMember = await showDialog<MemberRotationInfo>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign cook for $mealType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.parse(date)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...members.map((member) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    member.userName[0].toUpperCase(),
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
                title: Text(member.userName),
                subtitle: Text('Cooked ${member.totalCooksCompleted} times'),
                onTap: () => Navigator.pop(context, member),
              );
            }).toList(),
          ],
        ),
      ),
    );

    if (selectedMember != null) {
      final success = await rotationService.manuallyAssignCook(
        systemId: systemId,
        date: date,
        mealType: mealType,
        assignedTo: selectedMember.userId,
        assignedToName: selectedMember.userName,
      );

      if (success && mounted) {
        Fluttertoast.showToast(
          msg: 'Assigned ${selectedMember.userName} to cook',
          backgroundColor: Colors.green,
        );
      }
    }
  }

  Future<void> _markCompleted(ScheduledCook schedule) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rotationService = Provider.of<CookingRotationService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || schedule.assignedTo != userId) return;

    // Show menu input dialog
    final menuController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What did you cook?'),
            const SizedBox(height: 16),
            TextField(
              controller: menuController,
              decoration: const InputDecoration(
                hintText: 'e.g., Chicken Curry & Rice',
                labelText: 'Menu',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await rotationService.markCookingCompleted(
        systemId: systemId,
        scheduleId: schedule.scheduleId,
        menu: menuController.text.trim().isEmpty ? null : menuController.text.trim(),
      );

      if (success && mounted) {
        Fluttertoast.showToast(
          msg: 'Marked as completed!',
          backgroundColor: Colors.green,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
        title: const Text('Cooking Rotation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/rotation-settings');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Schedule'),
            Tab(text: 'My Turn'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      body: StreamBuilder<CookingRotationModel?>(
        stream: Provider.of<CookingRotationService>(context).streamRotation(systemId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rotation = snapshot.data;
          if (rotation == null) {
            return const Center(child: Text('Failed to load rotation'));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildScheduleTab(rotation),
              _buildMyTurnTab(rotation, authService.userModel!.userId),
              _buildStatisticsTab(rotation),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final rotationService = Provider.of<CookingRotationService>(context, listen: false);
          await rotationService.generateSchedule(systemId);
          Fluttertoast.showToast(
            msg: 'Schedule regenerated!',
            backgroundColor: Colors.green,
          );
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Regenerate'),
      ),
    );
  }

  Widget _buildScheduleTab(CookingRotationModel rotation) {
    final groupedSchedule = <String, List<ScheduledCook>>{};
    
    for (var schedule in rotation.upcomingSchedule) {
      if (!schedule.completed) {
        groupedSchedule.putIfAbsent(schedule.date, () => []).add(schedule);
      }
    }

    final sortedDates = groupedSchedule.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No upcoming schedule', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final schedules = groupedSchedule[date]!;
        final dateObj = DateTime.parse(date);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
              // Date Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMM d').format(dateObj),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Meals
              ...schedules.map((schedule) {
                return _ScheduleCard(
                  schedule: schedule,
                  onAssign: () => _showManualAssignDialog(date, schedule.mealType),
                  onComplete: () => _markCompleted(schedule),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyTurnTab(CookingRotationModel rotation, String userId) {
    final mySchedules = rotation.upcomingSchedule
        .where((s) => s.assignedTo == userId && !s.completed)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (mySchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No cooking scheduled for you', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mySchedules.length,
      itemBuilder: (context, index) {
        final schedule = mySchedules[index];
        final dateObj = DateTime.parse(schedule.date);
        final isToday = schedule.isToday;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isToday
                ? Border.all(color: Colors.orange, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isToday ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        schedule.mealType == 'breakfast'
                            ? Icons.wb_twilight
                            : schedule.mealType == 'lunch'
                                ? Icons.wb_sunny
                                : Icons.nights_stay,
                        color: isToday ? Colors.orange : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.mealType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMM d').format(dateObj),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Mark as Completed',
                  onPressed: () => _markCompleted(schedule),
                  width: double.infinity,
                  height: 45,
                  icon: Icons.check_circle,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab(CookingRotationModel rotation) {
    final statistics = rotation.members.values
        .map((m) => CookingStatistics.fromMemberInfo(m))
        .toList()
      ..sort((a, b) => b.totalCooksCompleted.compareTo(a.totalCooksCompleted));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: statistics.length,
      itemBuilder: (context, index) {
        final stat = statistics[index];
        final rank = index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: rank <= 3
                ? Border.all(
                    color: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey
                            : Colors.brown,
                    width: 2,
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? (rank == 1
                            ? Colors.amber
                            : rank == 2
                                ? Colors.grey
                                : Colors.brown)
                        : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                      style: TextStyle(
                        fontSize: rank <= 3 ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: rank > 3 ? Colors.black87 : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Member Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed: ${stat.totalCooksCompleted} | Assigned: ${stat.totalCooksAssigned}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Fairness Score
                Column(
                  children: [
                    Text(
                      '${(stat.fairnessScore * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      'Fairness',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final ScheduledCook schedule;
  final VoidCallback onAssign;
  final VoidCallback onComplete;

  const _ScheduleCard({
    required this.schedule,
    required this.onAssign,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isMyTurn = schedule.assignedTo == authService.userModel?.userId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(
            schedule.mealType == 'breakfast'
                ? Icons.wb_twilight
                : schedule.mealType == 'lunch'
                    ? Icons.wb_sunny
                    : Icons.nights_stay,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.mealType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schedule.assignedToName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isMyTurn ? Theme.of(context).primaryColor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (isMyTurn && schedule.isToday)
            TextButton(
              onPressed: onComplete,
              child: const Text('Complete'),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onAssign,
            ),
        ],
      ),
    );
  }
}