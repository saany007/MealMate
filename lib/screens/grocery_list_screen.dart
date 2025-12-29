import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isActionLoading = false; // To show loading spinner on actions

  // DIRECT FIREBASE WRITE: Guarantees list creation works
  Future<void> _createList(String systemId) async {
    if(mounted) setState(() => _isActionLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.userModel?.userId ?? 'unknown';

      // Create the list document directly
      // Service uses: collection('groceryLists').doc(systemId).collection('lists')
      
      final listId = DateTime.now().millisecondsSinceEpoch.toString(); 
      
      await FirebaseFirestore.instance
          .collection('groceryLists')
          .doc(systemId)
          .collection('lists') 
          .add({
        'listId': listId, 
        'systemId': systemId,
        'createdBy': userId,
        'createdDate': Timestamp.now(),
        // FIX: Removed .name
        'status': GroceryListStatus.active, 
        'items': {}, 
        'itemCount': 0,
        'checkedItemCount': 0,
        'totalEstimatedCost': 0.0,
      });
      
    } catch (e) {
      if(mounted) {
        Fluttertoast.showToast(
          msg: "Failed to create list: $e",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
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
    final groceryService = Provider.of<GroceryService>(context, listen: false);
    await groceryService.deleteItem(
      systemId: systemId,
      listId: listId,
      itemId: itemId,
    );
  }

  Future<void> _completeList(String systemId, String listId, double totalCost) async {
    setState(() => _isActionLoading = true);
    try {
      final groceryService = Provider.of<GroceryService>(context, listen: false);
      final success = await groceryService.completeList(
        systemId: systemId,
        listId: listId,
        totalCost: totalCost,
      );

      if (success && mounted) {
        Fluttertoast.showToast(
          msg: 'Shopping completed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        // Auto-create new list immediately so user doesn't see blank screen
        await _createList(systemId);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error completing list: $e");
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
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

  // ==================== ROBUST AUTO-GENERATE ====================
  Future<void> _handleAutoGenerate() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final groceryService = Provider.of<GroceryService>(context, listen: false);
    final recipeService = Provider.of<RecipeService>(context, listen: false);
    final inventoryService = Provider.of<InventoryService>(context, listen: false);
    final databaseService = DatabaseService();

    final systemId = authService.userModel?.currentMealSystemId;
    final userId = authService.userModel?.userId;

    if (systemId == null || userId == null) return;

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
      setState(() => _isActionLoading = true);
      try {
        // 2. CALL SERVICE (Now returns int)
        int addedCount = await groceryService.autoGenerateGroceryList(
          systemId: systemId,
          userId: userId,
          databaseService: databaseService,
          recipeService: recipeService,
          inventoryService: inventoryService,
          days: 7, 
        );
        
        if (mounted) {
           if (addedCount > 0) {
             Fluttertoast.showToast(
               msg: "Success! Added $addedCount items from meal plan.",
               backgroundColor: Colors.green,
               textColor: Colors.white,
             );
           } else {
             Fluttertoast.showToast(
               msg: "No missing ingredients found for upcoming meals.",
               backgroundColor: Colors.orange,
               textColor: Colors.white,
             );
           }
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Auto-generate failed: $e",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
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
            icon: const Icon(Icons.autorenew),
            tooltip: 'Auto-generate from Meal Plan',
            onPressed: _isActionLoading ? null : _handleAutoGenerate,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groceryLists')
                .doc(systemId)
                .collection('lists')
                .where('status', isEqualTo: GroceryListStatus.active) // FIX: Removed .name
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // AUTO-CREATE LOGIC
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (!_isActionLoading) {
                     _createList(systemId); 
                   }
                 });
                 return const Center(child: CircularProgressIndicator());
              }

              // LIST EXISTS - RENDER UI
              final doc = snapshot.data!.docs.first;
              final data = doc.data() as Map<String, dynamic>;
              final listId = doc.id;
              
              List<GroceryItemModel> allItems = [];
              if (data['items'] != null) {
                final itemsMap = data['items'] as Map<String, dynamic>;
                itemsMap.forEach((key, value) {
                  allItems.add(GroceryItemModel.fromMap(value));
                });
              }

              // Stats Calculation
              int checkedCount = allItems.where((i) => i.isChecked).length;
              int urgentCount = allItems.where((i) => i.isUrgent && !i.isChecked).length;
              int uncheckedCount = allItems.where((i) => !i.isChecked).length;
              double totalCost = allItems.fold(0, (sum, item) => sum + item.estimatedCost);
              double progress = allItems.isEmpty ? 0 : (checkedCount / allItems.length) * 100;
              bool allChecked = allItems.isNotEmpty && checkedCount == allItems.length;

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
                              value: '${allItems.length}',
                              color: Colors.blue,
                            ),
                            _StatItem(
                              icon: Icons.check_circle,
                              label: 'Checked',
                              value: '$checkedCount',
                              color: Colors.green,
                            ),
                            _StatItem(
                              icon: Icons.attach_money,
                              label: 'Estimated',
                              value: '${totalCost.toStringAsFixed(0)} BDT',
                              color: Colors.orange,
                            ),
                          ],
                        ),
                        if (allItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${progress.toStringAsFixed(0)}% Complete',
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
                          label: 'Unchecked ($uncheckedCount)',
                          isSelected: _selectedFilter == 'unchecked',
                          onTap: () => setState(() => _selectedFilter = 'unchecked'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Urgent ($urgentCount)',
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
                                if (_selectedFilter == 'all') ...[
                                  const SizedBox(height: 16),
                                  // Auto Fill Button
                                  TextButton.icon(
                                    onPressed: _handleAutoGenerate,
                                    icon: const Icon(Icons.auto_awesome, color: Colors.green),
                                    label: const Text(
                                      "Auto-fill from Calendar", 
                                      style: TextStyle(color: Colors.green)
                                    ),
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
                                  listId,
                                  item.itemId,
                                  item.isChecked,
                                ),
                                onDelete: () => _deleteItem(
                                  systemId,
                                  listId,
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
                        if (allChecked && allItems.isNotEmpty)
                          CustomButton(
                            text: 'Complete Shopping',
                            onPressed: () => _completeList(systemId, listId, totalCost),
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
                                  'listId': listId,
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
          
          if (_isActionLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
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