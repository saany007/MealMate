import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/shopping_trip_service.dart';
import '../services/auth_service.dart';
import '../models/shopping_trip_model.dart';

class ShoppingTripDetailScreen extends StatefulWidget {
  final ShoppingTripModel trip;

  const ShoppingTripDetailScreen({super.key, required this.trip});

  @override
  State<ShoppingTripDetailScreen> createState() => _ShoppingTripDetailScreenState();
}

class _ShoppingTripDetailScreenState extends State<ShoppingTripDetailScreen> {
  late ShoppingTripModel _trip;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isUpdating = false;
  String? _receiptURL;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _amountController.text = _trip.totalSpent > 0 ? _trip.totalSpent.toString() : '';
    _notesController.text = _trip.notes ?? '';
    _receiptURL = _trip.receiptURL;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _isUpdating = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);

    final success = await tripService.updateShoppingTrip(
      systemId: authService.userModel!.currentMealSystemId!,
      tripId: _trip.tripId,
      status: newStatus,
    );

    setState(() {
      _isUpdating = false;
    });

    if (mounted) {
      if (success) {
        // Reload data to get updated trip
        await tripService.loadShoppingTrips(authService.userModel!.currentMealSystemId!);
        final updatedTrip = tripService.trips.firstWhere(
          (t) => t.tripId == _trip.tripId,
          orElse: () => _trip,
        );
        setState(() {
          _trip = updatedTrip;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${ShoppingTripStatus.getDisplayName(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadReceipt() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final file = File(image.path);
      final storageRef = FirebaseStorage.instance.ref();
      final receiptRef = storageRef.child(
        'receipts/${authService.userModel!.currentMealSystemId}/${_trip.tripId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await receiptRef.putFile(file);
      final downloadURL = await receiptRef.getDownloadURL();

      final tripService = Provider.of<ShoppingTripService>(context, listen: false);
      final success = await tripService.updateShoppingTrip(
        systemId: authService.userModel!.currentMealSystemId!,
        tripId: _trip.tripId,
        receiptURL: downloadURL,
      );

      if (success && mounted) {
        setState(() {
          _receiptURL = downloadURL;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _completeTrip() async {
    final amount = double.tryParse(_amountController.text.trim());
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Shopping Trip'),
        content: Text(
          'Mark this shopping trip as completed with a total of ${amount.toStringAsFixed(2)} BDT?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (shouldComplete != true) return;

    setState(() {
      _isUpdating = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);

    final success = await tripService.updateShoppingTrip(
      systemId: authService.userModel!.currentMealSystemId!,
      tripId: _trip.tripId,
      status: ShoppingTripStatus.completed,
      totalSpent: amount,
      receiptURL: _receiptURL,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      reimbursementStatus: ReimbursementStatus.pending,
    );

    setState(() {
      _isUpdating = false;
    });

    if (mounted) {
      if (success) {
        // Reload to get updated trip
        await tripService.loadShoppingTrips(authService.userModel!.currentMealSystemId!);
        final updatedTrip = tripService.trips.firstWhere(
          (t) => t.tripId == _trip.tripId,
          orElse: () => _trip,
        );
        setState(() {
          _trip = updatedTrip;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shopping trip completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete shopping trip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markReimbursementPaid() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<ShoppingTripService>(context, listen: false);

    setState(() {
      _isUpdating = true;
    });

    final success = await tripService.updateShoppingTrip(
      systemId: authService.userModel!.currentMealSystemId!,
      tripId: _trip.tripId,
      reimbursementStatus: ReimbursementStatus.paid,
    );

    setState(() {
      _isUpdating = false;
    });

    if (mounted) {
      if (success) {
        await tripService.loadShoppingTrips(authService.userModel!.currentMealSystemId!);
        final updatedTrip = tripService.trips.firstWhere(
          (t) => t.tripId == _trip.tripId,
          orElse: () => _trip,
        );
        setState(() {
          _trip = updatedTrip;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reimbursement marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Color _getStatusColor() {
    switch (_trip.status) {
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
    final authService = Provider.of<AuthService>(context);
    final isAssignedToMe = authService.userModel?.userId == _trip.assignedTo;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Shopping Trip Details'),
        actions: [
          if (_trip.isPending && isAssignedToMe)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Start Shopping',
              onPressed: () => _updateStatus(ShoppingTripStatus.inProgress),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_cart,
                        color: _getStatusColor(),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ShoppingTripStatus.getDisplayName(_trip.status),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assigned to ${_trip.assignedToName}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Trip Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Assigned Date',
                      value: DateFormat('MMM dd, yyyy').format(_trip.assignedDate),
                    ),
                    if (_trip.completedDate != null) ...[
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.check_circle,
                        label: 'Completed Date',
                        value: DateFormat('MMM dd, yyyy').format(_trip.completedDate!),
                      ),
                    ],
                    if (_trip.totalSpent > 0) ...[
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.attach_money,
                        label: 'Total Spent',
                        value: '${_trip.totalSpent.toStringAsFixed(2)} BDT',
                        valueColor: Colors.green,
                      ),
                    ],
                    if (_trip.itemsPurchased.isNotEmpty) ...[
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.shopping_basket,
                        label: 'Items Purchased',
                        value: '${_trip.itemsPurchased.length} items',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reimbursement Status
            if (_trip.isCompleted && _trip.totalSpent > 0) ...[
              Card(
                elevation: 2,
                color: _trip.needsReimbursement ? Colors.orange[50] : Colors.green[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _trip.needsReimbursement ? Icons.payment : Icons.check_circle,
                            color: _trip.needsReimbursement ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Reimbursement Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _trip.needsReimbursement ? Colors.orange[900] : Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _trip.needsReimbursement 
                            ? 'Pending payment of ${_trip.totalSpent.toStringAsFixed(2)} BDT'
                            : 'Reimbursement completed',
                        style: TextStyle(
                          fontSize: 14,
                          color: _trip.needsReimbursement ? Colors.orange[800] : Colors.green[800],
                        ),
                      ),
                      if (_trip.needsReimbursement && !isAssignedToMe) ...[
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isUpdating ? null : _markReimbursementPaid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Mark as Paid'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Receipt Section
            if (_trip.isInProgress || _trip.isCompleted) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_receiptURL != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _receiptURL!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (isAssignedToMe && !_trip.isCompleted)
                        OutlinedButton.icon(
                          onPressed: _isUpdating ? null : _uploadReceipt,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(_receiptURL == null ? 'Upload Receipt' : 'Change Receipt'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Complete Trip Section
            if (isAssignedToMe && _trip.isInProgress) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete Shopping Trip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Total Amount Spent *',
                          hintText: 'Enter amount in BDT',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Add any additional notes...',
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isUpdating ? null : _completeTrip,
                        icon: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle),
                        label: const Text('Complete Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Notes Section
            if (_trip.notes != null && _trip.notes!.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _trip.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}