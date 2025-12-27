import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../models/inventory_item_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class AddInventoryItemScreen extends StatefulWidget {
  const AddInventoryItemScreen({super.key});

  @override
  State<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _lowStockController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = InventoryCategory.grains;
  String _selectedUnit = InventoryUnit.kg;
  String? _selectedLocation;
  DateTime _purchaseDate = DateTime.now();
  DateTime? _expiryDate;
  InventoryItemModel? _editingItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItem();
    });
  }

  void _loadItem() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['item'] != null) {
      _editingItem = args['item'] as InventoryItemModel;
      _nameController.text = _editingItem!.name;
      _quantityController.text = _editingItem!.quantity.toString();
      _lowStockController.text = _editingItem!.lowStockThreshold.toString();
      _estimatedCostController.text = _editingItem!.estimatedCost?.toString() ?? '';
      _notesController.text = _editingItem!.notes ?? '';
      
      setState(() {
        _selectedCategory = _editingItem!.category;
        _selectedUnit = _editingItem!.unit;
        _selectedLocation = _editingItem!.location;
        _purchaseDate = _editingItem!.purchaseDate;
        _expiryDate = _editingItem!.expiryDate;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _lowStockController.dispose();
    _estimatedCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isPurchaseDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPurchaseDate
          ? _purchaseDate
          : (_expiryDate ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: isPurchaseDate
          ? DateTime(2020)
          : _purchaseDate,
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final inventoryService = Provider.of<InventoryService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) {
      Fluttertoast.showToast(
        msg: 'No meal system found',
        backgroundColor: Colors.red,
      );
      return;
    }

    bool success;

    if (_editingItem != null) {
      // Update existing item
      success = await inventoryService.updateItem(
        systemId: systemId,
        itemId: _editingItem!.itemId,
        name: _nameController.text.trim(),
        quantity: double.parse(_quantityController.text),
        unit: _selectedUnit,
        category: _selectedCategory,
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        lowStockThreshold: double.parse(_lowStockController.text),
        location: _selectedLocation,
        estimatedCost: _estimatedCostController.text.isEmpty 
            ? null 
            : double.parse(_estimatedCostController.text),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );
    } else {
      // Add new item
      success = await inventoryService.addItem(
        systemId: systemId,
        name: _nameController.text.trim(),
        quantity: double.parse(_quantityController.text),
        unit: _selectedUnit,
        category: _selectedCategory,
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        lowStockThreshold: double.parse(_lowStockController.text),
        location: _selectedLocation,
        estimatedCost: _estimatedCostController.text.isEmpty 
            ? null 
            : double.parse(_estimatedCostController.text),
        addedBy: authService.userModel!.userId,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );
    }

    if (!mounted) return;

    if (success) {
      Fluttertoast.showToast(
        msg: _editingItem != null 
            ? 'Item updated successfully!' 
            : 'Item added successfully!',
        backgroundColor: Colors.green,
      );
      Navigator.pop(context);
    } else {
      Fluttertoast.showToast(
        msg: inventoryService.errorMessage ?? 'Failed to save item',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_editingItem != null ? 'Edit Item' : 'Add Item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Item Name
                CustomTextField(
                  label: 'Item Name *',
                  hint: 'e.g., Basmati Rice',
                  controller: _nameController,
                  prefixIcon: Icons.shopping_basket,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => FieldValidators.required(value, 'Item name'),
                ),
                const SizedBox(height: 20),

                // Category
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          items: InventoryCategory.all.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Row(
                                children: [
                                  Text(InventoryCategory.getEmoji(category)),
                                  const SizedBox(width: 8),
                                  Text(InventoryCategory.getDisplayName(category)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quantity and Unit
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: NumberField(
                        label: 'Quantity *',
                        hint: '5',
                        controller: _quantityController,
                        allowDecimal: true,
                        validator: (value) =>
                            FieldValidators.positiveNumber(value, 'Quantity'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unit *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUnit,
                                isExpanded: true,
                                items: InventoryUnit.all.map((unit) {
                                  return DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedUnit = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Low Stock Threshold
                NumberField(
                  label: 'Low Stock Threshold *',
                  hint: 'Alert when quantity falls below this',
                  controller: _lowStockController,
                  allowDecimal: true,
                  prefixIcon: Icons.warning_amber,
                  validator: (value) =>
                      FieldValidators.positiveNumber(value, 'Threshold'),
                ),
                const SizedBox(height: 20),

                // Estimated Cost (Optional)
                NumberField(
                  label: 'Estimated Cost (BDT) - Optional',
                  hint: '500',
                  controller: _estimatedCostController,
                  allowDecimal: true,
                  prefixIcon: Icons.attach_money,
                ),
                const SizedBox(height: 20),

                // Location (Optional)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Storage Location - Optional',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedLocation,
                          isExpanded: true,
                          hint: const Text('Select location'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Not specified')),
                            ...InventoryLocation.all.map((location) {
                              return DropdownMenuItem(
                                value: location,
                                child: Row(
                                  children: [
                                    Text(InventoryLocation.getEmoji(location)),
                                    const SizedBox(width: 8),
                                    Text(InventoryLocation.getDisplayName(location)),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedLocation = value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Purchase Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Purchase Date *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('dd MMM yyyy').format(_purchaseDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Expiry Date (Optional)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expiry Date - Optional',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _expiryDate != null
                                    ? DateFormat('dd MMM yyyy').format(_expiryDate!)
                                    : 'Not set',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            if (_expiryDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() => _expiryDate = null);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Notes (Optional)
                TextAreaField(
                  label: 'Notes - Optional',
                  hint: 'Additional information about this item',
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 30),

                // Save Button
                Consumer<InventoryService>(
                  builder: (context, inventoryService, child) {
                    return CustomButton(
                      text: _editingItem != null ? 'Update Item' : 'Add Item',
                      onPressed: _handleSave,
                      isLoading: inventoryService.isLoading,
                      width: double.infinity,
                      icon: _editingItem != null ? Icons.save : Icons.add,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}