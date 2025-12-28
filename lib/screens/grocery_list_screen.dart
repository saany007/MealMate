import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/grocery_service.dart';
import '../models/grocery_list_model.dart';
import '../models/grocery_item_model.dart';
import '../widgets/custom_button.dart';

// Imports for Auto-Generation Feature
import '../services/database_service.dart';
import '../services/recipe_service.dart';
import '../services/inventory_service.dart';

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
    // Load data after the first frame to avoid provider errors during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroceryList();
    });
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
      
      // Create a new list automatically after completion
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

  // ==================== AUTO-GENERATION LOGIC ====================
  Future<void> _handleAutoGenerate() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final groceryService = Provider.of<GroceryService>(context, listen: false);
    
    // Services required for the "Brain" logic
    final recipeService = Provider.of<RecipeService>(context, listen: false);
    final inventoryService = Provider.of<InventoryService>(context, listen: false);
    final databaseService = DatabaseService();

    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || userId == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Generate List?'),
        content: const Text(
          'This will scan your Meal Calendar for the next 7 days, check recipes, '
          'compare with Inventory, and add missing items to this list.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Generate')
          ),
        ],
      ),
    );

    if (confirm == true) {
      await groceryService.autoGenerateGroceryList(
        systemId: systemId,
        userId: userId,
        databaseService: databaseService,
        recipeService: recipeService,
        inventoryService: inventoryService,
        days: 7, 
      );
      
      if (mounted) {
         Fluttertoast.showToast(
           msg: "Grocery list updated from meal plan!",
           backgroundColor: Colors.green,
           textColor: Colors.white,
         );
      }
    }
  }
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final groceryService = Provider.of<GroceryService>(context); // Listens to changes
    
    final systemId = authService.userModel?.currentMealSystemId;
    final list = groceryService.currentList; // We use this variable now

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
          // Auto-Generate Button
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: 'Auto-generate from Meal Plan',
            onPressed: _handleAutoGenerate,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Fluttertoast.showToast(msg: 'History coming soon!');
            },
          ),
        ],
      ),
      // REPLACED StreamBuilder with direct state access to fix warnings
      body: groceryService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : list == null
              ? Center(
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
                )
              : Builder(
                  builder: (context) {
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
                                      
                                      // Auto-Generate Trigger for Empty State
                                      if (_selectedFilter == 'all') ...[
                                        const SizedBox(height: 16),
                                        TextButton.icon(
                                          onPressed: _handleAutoGenerate,
                                          icon: const Icon(Icons.auto_awesome),
                                          label: const Text("Auto-fill from Calendar"),
                                        ),
                                      ],
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
                  }
                ),
    );
  }
}

// ==================== HELPER COMPONENTS ====================

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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
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
    return Dismissible(
      key: Key(item.itemId),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ListTile(
            leading: Checkbox(
              value: item.isChecked,
              onChanged: (_) => onToggleChecked(),
              activeColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                decoration: item.isChecked ? TextDecoration.lineThrough : null,
                color: item.isChecked ? Colors.grey : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.isUrgent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Text(
                      'URGENT',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ),
        ),
      ),
    );
  }
}