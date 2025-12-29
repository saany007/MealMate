import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Services
import '../services/shopping_trip_service.dart';
import '../services/auth_service.dart';
import '../services/meal_system_service.dart';

// Models
import '../models/shopping_trip_model.dart';

// Screens & Widgets
import 'shopping_trip_detail_screen.dart';

class ShoppingTripScreen extends StatefulWidget {
  const ShoppingTripScreen({super.key});

  @override
  State<ShoppingTripScreen> createState() => _ShoppingTripScreenState();
}

class _ShoppingTripScreenState extends State<ShoppingTripScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State for Creating Trip
  final TextEditingController _notesController = TextEditingController();
  String? _selectedAssignedUserId;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Master load function
  Future<void> _loadData() async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);
    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);

    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId != null) {
      await mealSystemService.loadMealSystem(systemId);
      await tripService.loadShoppingTrips(systemId);
    }
  }

  /// Handles creating a new shopping trip
  Future<void> _createTrip() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);
    final systemService = Provider.of<MealSystemService>(context, listen: false);

    final systemId = authService.userModel?.currentMealSystemId;
    if (systemId == null || _selectedAssignedUserId == null) {
      Fluttertoast.showToast(msg: "Please select a member");
      return;
    }

    setState(() => _isCreating = true);

    try {
      final member = systemService.currentMealSystem!.members[_selectedAssignedUserId];
      final memberName = member?.name ?? 'Unknown';

      final success = await tripService.createShoppingTrip(
        systemId: systemId,
        assignedTo: _selectedAssignedUserId!,
        assignedToName: memberName,
        notes: _notesController.text.trim(),
      );

      if (success) {
        if (mounted) {
          Navigator.pop(context); // Close modal
          Fluttertoast.showToast(msg: "Shopping trip assigned to $memberName");
          _notesController.clear();
          setState(() => _selectedAssignedUserId = null);
          _tabController.animateTo(0); // Switch to Pending tab
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error creating trip: $e");
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Shopping Trips"),
        elevation: 0,
        backgroundColor: const Color(0xFF16A34A),
        // FIX: Changed text colors to white for visibility
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, 
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Active"),
            Tab(text: "History"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer<ShoppingTripService>(
        builder: (context, tripService, child) {
          if (tripService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // --- SECTION 1: SHOPPING ROTATION & SUGGESTION ---
              _buildRotationHeader(context),

              // --- SECTION 2: TRIP LISTS ---
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTripList(tripService.pendingTrips, "No pending trips. Plan one now!"),
                    _buildTripList(tripService.inProgressTrips, "No active trips."),
                    _buildTripList(tripService.completedTrips, "No past trips found."),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignTripModal(context),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text("Assign Trip", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ==================== WIDGETS: HEADER ====================

  Widget _buildRotationHeader(BuildContext context) {
    return Consumer2<ShoppingTripService, MealSystemService>(
      builder: (context, tripService, systemService, _) {
        final allMembers = systemService.currentMealSystem?.members;
        
        if (allMembers == null || allMembers.isEmpty) return const SizedBox.shrink();

        List<ShoppingRotationTracker> allTrackers = [];

        allMembers.forEach((userId, memberInfo) {
          if (tripService.rotationTrackers.containsKey(userId)) {
            allTrackers.add(tripService.rotationTrackers[userId]!);
          } else {
            allTrackers.add(ShoppingRotationTracker(
              userId: userId,
              userName: memberInfo.name,
              totalTripsCompleted: 0,
              totalSpent: 0.0,
            ));
          }
        });

        allTrackers.sort((ShoppingRotationTracker a, ShoppingRotationTracker b) {
          int cmp = a.totalTripsCompleted.compareTo(b.totalTripsCompleted);
          if (cmp != 0) return cmp;
          return a.totalSpent.compareTo(b.totalSpent);
        });

        if (allTrackers.isEmpty) return const SizedBox.shrink();

        final nextShopper = allTrackers.first;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.teal.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.teal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Suggested Shopper",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal[700],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "It's likely ${nextShopper.userName}'s turn",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "They have done ${nextShopper.totalTripsCompleted} trips so far.",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== WIDGETS: LISTS ====================

  Widget _buildTripList(List<ShoppingTripModel> trips, String emptyMessage) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        return _ShoppingTripCard(trip: trips[index]);
      },
    );
  }

  // ==================== WIDGETS: MODALS ====================

  void _showAssignTripModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Assign Shopping Trip",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                const Text("Assign To", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Consumer<MealSystemService>(
                  builder: (context, systemService, _) {
                    final members = systemService.currentMealSystem?.members.values.toList() ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedAssignedUserId,
                      hint: const Text("Select Member"),
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: members.map((member) {
                        final entry = systemService.currentMealSystem!.members.entries.firstWhere(
                          (e) => e.value == member,
                        );
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.teal[100],
                                child: Text(
                                  member.name[0].toUpperCase(),
                                  style: TextStyle(fontSize: 10, color: Colors.teal[800]),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(member.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() => _selectedAssignedUserId = value);
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                const Text("Notes / Instructions", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "e.g., Buy from Agora, check for fresh fish...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text("Create Trip", style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShoppingTripCard extends StatelessWidget {
  final ShoppingTripModel trip;

  const _ShoppingTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (trip.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = "Pending";
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.shopping_cart;
        statusText = "Active";
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusText = "Done";
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = "Unknown";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShoppingTripDetailScreen(trip: trip),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: statusColor.withOpacity(0.1),
                        child: Text(
                          trip.assignedToName.isNotEmpty ? trip.assignedToName[0].toUpperCase() : "?",
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.assignedToName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            DateFormat('MMM d, y').format(trip.assignedDate),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                      Icons.list_alt,
                      "Items",
                      "${trip.itemsPurchased.length} items",
                    ),
                  ),
                  if (trip.totalSpent > 0)
                    Expanded(
                      child: _buildInfoColumn(
                        Icons.attach_money,
                        "Total Cost",
                        "${trip.totalSpent.toStringAsFixed(0)} BDT",
                        valueColor: Colors.black,
                      ),
                    ),
                  if (trip.status == 'completed')
                    Expanded(
                      child: _buildReimbursementBadge(trip),
                    ),
                ],
              ),

              if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.notes!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87
          ),
        ),
      ],
    );
  }

  Widget _buildReimbursementBadge(ShoppingTripModel trip) {
    bool isPaid = trip.reimbursementStatus == 'paid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Reimbursement",
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPaid ? "PAID" : "PENDING",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.green : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }
}