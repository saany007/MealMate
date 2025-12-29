import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../models/inventory_item_model.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Grains',
    'Vegetables',
    'Fruits',
    'Meat',
    'Fish',
    'Dairy',
    'Spices',
    'Beverages',
    'Snacks',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
  }

  Color _getStockStatusColor(InventoryItemModel item) {
    if (item.isOutOfStock) {
      return Colors.red;
    } else if (item.isLowStock) {
      return Colors.orange;
    } else if (item.isExpired) {
      return Colors.red;
    } else if (item.isExpiringSoon) {
      return Colors.orange;
    }
    return Colors.green;
  }

  String _getStockStatusText(InventoryItemModel item) {
    if (item.isOutOfStock) {
      return 'Out of Stock';
    } else if (item.isLowStock) {
      return 'Low Stock';
    } else if (item.isExpired) {
      return 'Expired';
    } else if (item.isExpiringSoon) {
      return 'Expires Soon';
    }
    return 'In Stock';
  }

  Future<void> _deleteItem(String systemId, String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final inventoryService = Provider.of<InventoryService>(context, listen: false);
      final success = await inventoryService.deleteItem(
        systemId: systemId,
        itemId: itemId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    }
  }

  Future<void> _updateQuantity(String systemId, InventoryItemModel item, bool increment) async {
    final inventoryService = Provider.of<InventoryService>(context, listen: false);
    await inventoryService.updateQuantity(
      systemId: systemId,
      itemId: item.itemId,
      amount: 1,
      increment: increment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: const Center(child: Text('No meal system found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: _categories.map((category) {
                          return ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory')
            .doc(systemId)
            .collection('items')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No items in inventory',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first item to get started',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Parse items from snapshot
          List<InventoryItemModel> items = snapshot.data!.docs
              .map((doc) => InventoryItemModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          // Calculate stats manually since we are not using the service getter
          int totalItems = items.length;
          int lowStockItems = items.where((i) => i.isLowStock || i.isOutOfStock).length;
          int expiringItems = items.where((i) => i.isExpiringSoon || i.isExpired).length;

          // Filter by category
          if (_selectedCategory != 'All') {
            items = items.where((item) => 
              InventoryCategory.getDisplayName(item.category) == _selectedCategory
            ).toList();
          }

          // Sort items: expired/low stock first
          items.sort((a, b) {
            final aStatus = _getStockStatusColor(a);
            final bStatus = _getStockStatusColor(b);
            if (aStatus == Colors.red && bStatus != Colors.red) return -1;
            if (aStatus != Colors.red && bStatus == Colors.red) return 1;
            if (aStatus == Colors.orange && bStatus == Colors.green) return -1;
            if (aStatus == Colors.green && bStatus == Colors.orange) return 1;
            return a.name.compareTo(b.name);
          });

          return Column(
            children: [
              // Statistics Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.inventory_2,
                      label: 'Total',
                      value: '$totalItems',
                      color: Colors.blue,
                    ),
                    _StatItem(
                      icon: Icons.warning,
                      label: 'Low Stock',
                      value: '$lowStockItems',
                      color: Colors.orange,
                    ),
                    _StatItem(
                      icon: Icons.event_busy,
                      label: 'Expiring',
                      value: '$expiringItems',
                      color: Colors.red,
                    ),
                  ],
                ),
              ),

              // Items List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final statusColor = _getStockStatusColor(item);
                    final statusText = _getStockStatusText(item);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/edit-inventory-item',
                            arguments: {'item': item},
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.quantity} ${item.unit}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: statusColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (item.expiryDate != null)
                                          Text(
                                            'Exp: ${DateFormat('MMM d').format(item.expiryDate!)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: Colors.red,
                                        onPressed: () => _updateQuantity(systemId, item, false),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        color: Colors.green,
                                        onPressed: () => _updateQuantity(systemId, item, true),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red[300],
                                    onPressed: () => _deleteItem(systemId, item.itemId),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-inventory-item');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}