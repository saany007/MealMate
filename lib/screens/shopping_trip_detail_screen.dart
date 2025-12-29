import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Services & Models
import '../services/shopping_trip_service.dart';
import '../services/auth_service.dart';
import '../models/shopping_trip_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class ShoppingTripDetailScreen extends StatefulWidget {
  final ShoppingTripModel trip;

  const ShoppingTripDetailScreen({super.key, required this.trip});

  @override
  State<ShoppingTripDetailScreen> createState() => _ShoppingTripDetailScreenState();
}

class _ShoppingTripDetailScreenState extends State<ShoppingTripDetailScreen> {
  final _amountController = TextEditingController();
  final _itemsController = TextEditingController();
  final _notesController = TextEditingController();
  
  late ShoppingTripModel _trip;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _amountController.text = _trip.totalSpent > 0 ? _trip.totalSpent.toStringAsFixed(0) : '';
    _itemsController.text = _trip.itemsPurchased.join('\n');
    _notesController.text = _trip.notes ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _itemsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- NEW: START SHOPPING ---
  Future<void> _startShopping() async {
    setState(() => _isUpdating = true);
    try {
      final tripService = Provider.of<ShoppingTripService>(context, listen: false);
      final success = await tripService.updateTrip(
        systemId: _trip.systemId,
        tripId: _trip.tripId,
        updates: {'status': 'in_progress'},
      );
      
      if (success && mounted) {
        setState(() {
          _trip = _trip.copyWith(status: 'in_progress');
          _isUpdating = false;
        });
        _showSnackBar("Trip Started! Moved to Active tab.");
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // --- UPDATE TRIP DETAILS ---
  Future<void> _updateTripDetails() async {
    setState(() => _isUpdating = true);
    
    try {
      final tripService = Provider.of<ShoppingTripService>(context, listen: false);
      final double amount = double.tryParse(_amountController.text) ?? 0.0;
      
      final List<String> itemsList = _itemsController.text
          .split('\n')
          .where((item) => item.trim().isNotEmpty)
          .map((item) => item.trim())
          .toList();

      final bool shouldComplete = amount > 0 && _trip.status != 'completed';

      bool success;
      if (shouldComplete) {
        success = await tripService.completeTrip(
          systemId: _trip.systemId,
          tripId: _trip.tripId,
          totalSpent: amount,
          itemsPurchased: itemsList,
        );
      } else {
        Map<String, dynamic> updates = {
          'totalSpent': amount,
          'itemsPurchased': itemsList,
          'notes': _notesController.text.trim(),
        };
        
        success = await tripService.updateTrip(
          systemId: _trip.systemId,
          tripId: _trip.tripId,
          updates: updates,
        );
      }

      if (success && mounted) {
        _showSnackBar(shouldComplete ? "Trip Completed!" : "Trip Updated");
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markReimbursed() async {
    setState(() => _isUpdating = true);
    try {
      final tripService = Provider.of<ShoppingTripService>(context, listen: false);
      final success = await tripService.updateTrip(
        systemId: _trip.systemId,
        tripId: _trip.tripId,
        updates: {'reimbursementStatus': 'paid'},
      );
      
      if (success && mounted) {
        setState(() {
          _trip = _trip.copyWith(reimbursementStatus: 'paid');
          _isUpdating = false;
        });
        _showSnackBar("Marked as Reimbursed");
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.userModel?.userId;
    final isAssignee = currentUserId == _trip.assignedTo;
    final canEdit = isAssignee; 
    final isCompleted = _trip.status == 'completed';
    final isPending = _trip.status == 'pending';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Trip Details"),
        elevation: 0,
        actions: [
          if (canEdit && !isCompleted && !isPending) // Only show Save check if Active
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _updateTripDetails,
              tooltip: "Save & Complete",
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.teal[50],
                    child: Text(
                      _trip.assignedToName.isNotEmpty ? _trip.assignedToName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 32, color: Colors.teal[800]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _trip.assignedToName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_trip.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(_trip.status)),
                    ),
                    child: Text(
                      _getStatusText(_trip.status).toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(_trip.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // --- DETAILS FORM ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Trip Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  _buildDetailRow(
                    Icons.calendar_today,
                    "Assigned Date",
                    DateFormat('MMMM d, yyyy').format(_trip.assignedDate),
                  ),
                  
                  const SizedBox(height: 16),

                  // Total Spent
                  if (canEdit && !isCompleted)
                    CustomTextField(
                      label: "Total Amount Spent (BDT)",
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.attach_money,
                      hint: "0.00",
                    )
                  else
                    _buildDetailRow(
                      Icons.attach_money,
                      "Total Spent",
                      "${_trip.totalSpent.toStringAsFixed(0)} BDT",
                      valueColor: Colors.teal[800],
                      isBold: true,
                    ),

                  const SizedBox(height: 16),

                  // Items Input Section
                  if (canEdit && !isCompleted)
                    TextField(
                      controller: _itemsController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: "Items Purchased (One per line)",
                        hintText: "Milk\nEggs\nBread",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.list),
                      ),
                    )
                  else
                    _buildDetailRow(
                      Icons.shopping_bag,
                      "Items Purchased",
                      _trip.itemsPurchased.isEmpty 
                          ? "No items listed" 
                          : "${_trip.itemsPurchased.length} items (${_trip.itemsPurchased.take(2).join(', ')}${_trip.itemsPurchased.length > 2 ? '...' : ''})",
                    ),

                  const SizedBox(height: 16),

                  // Notes
                  if (canEdit && !isCompleted)
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Notes",
                        hintText: "Add details about the shopping...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    )
                  else if (_trip.notes != null && _trip.notes!.isNotEmpty)
                     _buildDetailRow(Icons.note, "Notes", _trip.notes!),

                  const SizedBox(height: 30),

                  // Actions
                  if (_trip.status == 'completed' && _trip.reimbursementStatus != 'paid')
                    CustomButton(
                      text: "Mark as Reimbursed",
                      icon: Icons.check_circle,
                      onPressed: _isUpdating ? null : _markReimbursed,
                      backgroundColor: Colors.green,
                      isLoading: _isUpdating,
                    ),

                  // NEW: "Start Shopping" Button for Pending Trips
                  if (canEdit && isPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CustomButton(
                        text: "Start Shopping",
                        icon: Icons.shopping_cart_checkout,
                        onPressed: _isUpdating ? null : _startShopping,
                        isLoading: _isUpdating,
                        backgroundColor: Colors.blueAccent, // Distinct color
                      ),
                    ),

                  // Existing "Complete Trip" Button (Only show if Active)
                  if (canEdit && !isCompleted && !isPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CustomButton(
                        text: "Complete Trip",
                        onPressed: _isUpdating ? null : _updateTripDetails,
                        isLoading: _isUpdating,
                        backgroundColor: Colors.teal,
                      ),
                    ),
                    
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[700], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? Colors.black87,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return "Pending";
      case 'in_progress': return "In Progress";
      case 'completed': return "Completed";
      default: return "Unknown";
    }
  }
}