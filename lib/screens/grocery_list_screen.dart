import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/grocery_service.dart';
import '../models/grocery_list_model.dart';
import '../models/grocery_item_model.dart';
import '../widgets/custom_button.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  String _selectedFilter = 'all'; // all, unchecked, urgent

  @override
  void initState() {
    super.initState();
    _loadGroceryList();
  }

  Future<void> _loadGroceryList() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final groceryService = Provider.of<GroceryService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId != null) {
      final list = await groceryService.getActiveList(systemId);
      
      // If no active list exists, create one
      if (list == null && mounted) {
        await groceryService.createGroceryList(
          systemId: systemId,
          createdBy: authService.userModel!.userId,
        );
      }
    }
  }

  Future<void> _toggleItemChecked(
    String systemId,
    String listId,
    String itemId,
    bool currentValue,
  ) async {
    final groceryService = Provider.of<GroceryService>(context, listen: false);
    await groceryService.toggleItemChecked(
      systemId: systemId,
      listId: listId,
      itemId: itemId,
      isChecked: !currentValue,
    );
  }

  Future<void> _deleteItem(String systemId, String listId, String itemId) async {
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final groceryService = Provider.of<GroceryService>(context, listen: false);
      final success = await groceryService.deleteItem(
        systemId: systemId,
        listId: listId,
        itemId: itemId,
      );

      if (success && mounted) {
        Fluttertoast.showToast(
          msg: 'Item deleted',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _completeList(String systemId, String listId) async {
    final groceryService = Provider.of<GroceryService>(context, listen: false);
    
    final success = await groceryService.completeList(
      systemId: systemId,
      listId: listId,
      totalCost: groceryService.calculateTotalCost(),
    );

    if (success && mounted) {
      Fluttertoast.showToast(
        msg: 'Shopping completed!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      
      // Create a new list
      final authService = Provider.of<AuthService>(context, listen: false);
      await groceryService.createGroceryList(
        systemId: systemId,
        createdBy: authService.userModel!.userId,
      );
    }
  }

  List<GroceryItemModel> _filterItems(List<GroceryItemModel> items) {
    switch (_selectedFilter) {
      case 'unchecked':
        return items.where((item) => !item.isChecked).toList();
      case 'urgent':
        return items.where((item) => item.isUrgent && !item.isChecked).toList();
      default:
        return items;
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
        title: const Text('Grocery List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Fluttertoast.showToast(msg: 'History coming soon!');
            },
          ),
        ],
      ),
      body: StreamBuilder<GroceryListModel?>(
        stream: Provider.of<GroceryService>(context).streamActiveList(systemId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data;

          if (list == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No grocery list found'),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Create List',
                    onPressed: _loadGroceryList,
                  ),
                ],
              ),
            );
          }

          final allItems = list.items.values.toList();
          final filteredItems = _filterItems(allItems);

          return Column(
            children: [
              // Summary Card
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(
                          icon: Icons.shopping_basket,
                          label: 'Total Items',
                          value: '${list.itemCount}',
                          color: Colors.blue,
                        ),
                        _StatItem(
                          icon: Icons.check_circle,
                          label: 'Checked',
                          value: '${list.checkedItemCount}',
                          color: Colors.green,
                        ),
                        _StatItem(
                          icon: Icons.attach_money,
                          label: 'Estimated',
                          value: '${list.calculateTotalCost().toStringAsFixed(0)} BDT',
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    if (list.itemCount > 0) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: list.progressPercentage / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${list.progressPercentage.toStringAsFixed(0)}% Complete',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${allItems.length})',
                      isSelected: _selectedFilter == 'all',
                      onTap: () => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Unchecked (${list.uncheckedItemCount})',
                      isSelected: _selectedFilter == 'unchecked',
                      onTap: () => setState(() => _selectedFilter = 'unchecked'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Urgent (${list.urgentItemCount})',
                      isSelected: _selectedFilter == 'urgent',
                      onTap: () => setState(() => _selectedFilter = 'urgent'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Items List
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in this category',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _GroceryItemCard(
                            item: item,
                            onToggleChecked: () => _toggleItemChecked(
                              systemId,
                              list.listId,
                              item.itemId,
                              item.isChecked,
                            ),
                            onDelete: () => _deleteItem(
                              systemId,
                              list.listId,
                              item.itemId,
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (list.allItemsChecked && list.itemCount > 0)
                      CustomButton(
                        text: 'Complete Shopping',
                        onPressed: () => _completeList(systemId, list.listId),
                        width: double.infinity,
                        icon: Icons.check_circle,
                      )
                    else
                      CustomButton(
                        text: 'Add Item',
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/add-grocery-item',
                            arguments: {
                              'systemId': systemId,
                              'listId': list.listId,
                            },
                          );
                        },
                        width: double.infinity,
                        icon: Icons.add,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _GroceryItemCard extends StatelessWidget {
  final GroceryItemModel item;
  final VoidCallback onToggleChecked;
  final VoidCallback onDelete;

  const _GroceryItemCard({
    required this.item,
    required this.onToggleChecked,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: item.isUrgent
            ? Border.all(color: Colors.red, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleChecked,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox
                Checkbox(
                  value: item.isChecked,
                  onChanged: (_) => onToggleChecked(),
                  shape: const CircleBorder(),
                ),
                const SizedBox(width: 12),
                
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    GroceryCategory.getEmoji(item.category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Item Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (item.isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'URGENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${item.quantity} ${item.unit}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${item.estimatedCost.toStringAsFixed(0)} BDT',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}