import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/shopping_trip_service.dart';
import '../services/auth_service.dart';
import '../services/meal_system_service.dart';
import '../models/shopping_trip_model.dart';
import 'shopping_trip_detail_screen.dart';

class ShoppingTripScreen extends StatefulWidget {
  const ShoppingTripScreen({super.key});

  @override
  State<ShoppingTripScreen> createState() => _ShoppingTripScreenState();
}

class _ShoppingTripScreenState extends State<ShoppingTripScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);
    
    if (authService.userModel?.currentMealSystemId != null) {
      await tripService.loadShoppingTrips(authService.userModel!.currentMealSystemId!);
      await tripService.loadRotationTrackers(authService.userModel!.currentMealSystemId!);
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _createNewTrip() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);
    final systemService = Provider.of<MealSystemService>(context, listen: false);
    
    if (authService.userModel?.currentMealSystemId == null) return;

    final systemId = authService.userModel!.currentMealSystemId!;
    final mealSystem = systemService.currentMealSystem;

    if (mealSystem == null) return;

    // Show assignment options
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AssignShopperSheet(
        systemId: systemId,
        mealSystem: mealSystem,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final tripService = Provider.of<ShoppingTripService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Shopping Trips'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Shopping Trips'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Pending (${tripService.pendingTrips.length})'),
            Tab(text: 'Active (${tripService.inProgressTrips.length})'),
            Tab(text: 'Completed (${tripService.completedTrips.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTripList(tripService.pendingTrips, 'No pending shopping trips'),
          _buildTripList(tripService.inProgressTrips, 'No active shopping trips'),
          _buildTripList(tripService.completedTrips, 'No completed shopping trips'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTrip,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Trip'),
      ),
    );
  }

  Widget _buildTripList(List<ShoppingTripModel> trips, String emptyMessage) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          return _ShoppingTripCard(trip: trips[index]);
        },
      ),
    );
  }
}

class _ShoppingTripCard extends StatelessWidget {
  final ShoppingTripModel trip;

  const _ShoppingTripCard({required this.trip});

  Color _getStatusColor() {
    switch (trip.status) {
      case ShoppingTripStatus.pending:
        return Colors.orange;
      case ShoppingTripStatus.inProgress:
        return Colors.blue;
      case ShoppingTripStatus.completed:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShoppingTripDetailScreen(trip: trip),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      color: _getStatusColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.assignedToName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              ShoppingTripStatus.getEmoji(trip.status),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ShoppingTripStatus.getDisplayName(trip.status),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (trip.isCompleted && trip.totalSpent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${trip.totalSpent.toStringAsFixed(0)} BDT',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Assigned: ${DateFormat('MMM dd, yyyy').format(trip.assignedDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              if (trip.completedDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Completed: ${DateFormat('MMM dd, yyyy').format(trip.completedDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
              if (trip.itemsPurchased.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.shopping_basket, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${trip.itemsPurchased.length} items purchased',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
              if (trip.needsReimbursement) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payment, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Reimbursement Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  trip.notes!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignShopperSheet extends StatefulWidget {
  final String systemId;
  final dynamic mealSystem;

  const _AssignShopperSheet({
    required this.systemId,
    required this.mealSystem,
  });

  @override
  State<_AssignShopperSheet> createState() => _AssignShopperSheetState();
}

class _AssignShopperSheetState extends State<_AssignShopperSheet> {
  String? _selectedUserId;
  String? _selectedUserName;
  final TextEditingController _notesController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _autoAssign() async {
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);
    
    final nextShopperId = await tripService.autoAssignNextShopper(
      systemId: widget.systemId,
      mealSystem: widget.mealSystem,
    );

    if (nextShopperId != null) {
      setState(() {
        _selectedUserId = nextShopperId;
        _selectedUserName = widget.mealSystem.members[nextShopperId]?.name;
      });
    }
  }

  Future<void> _createTrip() async {
    if (_selectedUserId == null) return;

    setState(() {
      _isCreating = true;
    });

    final tripService = Provider.of<ShoppingTripService>(context, listen: false);
    
    final trip = await tripService.createShoppingTrip(
      systemId: widget.systemId,
      assignedTo: _selectedUserId!,
      assignedToName: _selectedUserName!,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    setState(() {
      _isCreating = false;
    });

    if (mounted) {
      if (trip != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shopping trip assigned to $_selectedUserName'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create shopping trip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Assign Shopping Trip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _autoAssign,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Auto-Assign Next Shopper'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Or select manually:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.mealSystem.members.length,
                itemBuilder: (context, index) {
                  final entry = widget.mealSystem.members.entries.elementAt(index);
                  final userId = entry.key;
                  final member = entry.value;
                  
                  return RadioListTile<String>(
                    value: userId,
                    groupValue: _selectedUserId,
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                        _selectedUserName = member.name;
                      });
                    },
                    title: Text(member.name),
                    subtitle: Text(member.role == 'owner' ? 'Owner' : 'Member'),
                    secondary: CircleAvatar(
                      backgroundColor: member.role == 'owner'
                          ? Colors.green
                          : Colors.blue.withOpacity(0.2),
                      child: Text(
                        member.name[0].toUpperCase(),
                        style: TextStyle(
                          color: member.role == 'owner' ? Colors.white : Colors.blue,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any special instructions...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _selectedUserId == null || _isCreating ? null : _createTrip,
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Shopping Trip'),
            ),
          ],
        ),
      ),
    );
  }
}