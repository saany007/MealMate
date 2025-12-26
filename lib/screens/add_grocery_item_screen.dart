import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/grocery_service.dart';
import '../models/grocery_item_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class AddGroceryItemScreen extends StatefulWidget {
  const AddGroceryItemScreen({super.key});

  @override
  State<AddGroceryItemScreen> createState() => _AddGroceryItemScreenState();
}

class _AddGroceryItemScreenState extends State<AddGroceryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();

  String _selectedUnit = GroceryUnit.kg;
  String _selectedCategory = GroceryCategory.vegetables;
  bool _isUrgent = false;
  bool _isOptional = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _handleAddItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final systemId = args['systemId']!;
    final listId = args['listId']!;

    final authService = Provider.of<AuthService>(context, listen: false);
    final groceryService = Provider.of<GroceryService>(context, listen: false);

    final success = await groceryService.addItem(
      systemId: systemId,
      listId: listId,
      name: _nameController.text.trim(),
      quantity: double.parse(_quantityController.text),
      unit: _selectedUnit,
      estimatedCost: double.parse(_costController.text),
      category: _selectedCategory,
      addedBy: authService.userModel!.userId,
      isUrgent: _isUrgent,
      isOptional: _isOptional,
    );

    if (!mounted) return;

    if (success) {
      Fluttertoast.showToast(
        msg: 'Item added successfully!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.of(context).pop();
    } else {
      Fluttertoast.showToast(
        msg: groceryService.errorMessage ?? 'Failed to add item',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Grocery Item'),
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
                  hint: 'e.g., Rice, Chicken, Onions',
                  controller: _nameController,
                  prefixIcon: Icons.shopping_basket,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => FieldValidators.required(value, 'Item name'),
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
                                items: GroceryUnit.all.map((unit) {
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

                // Estimated Cost
                NumberField(
                  label: 'Estimated Cost (BDT) *',
                  hint: '500',
                  controller: _costController,
                  allowDecimal: true,
                  prefixIcon: Icons.attach_money,
                  validator: (value) =>
                      FieldValidators.positiveNumber(value, 'Cost'),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GroceryCategory.all.map((category) {
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = category);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  GroceryCategory.getEmoji(category),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  GroceryCategory.getDisplayName(category),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Options
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Options',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Mark as Urgent'),
                        subtitle: const Text(
                          'Highlighted in red for priority purchase',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _isUrgent,
                        onChanged: (value) {
                          setState(() => _isUrgent = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text('Mark as Optional'),
                        subtitle: const Text(
                          'Can be skipped if budget is tight',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _isOptional,
                        onChanged: (value) {
                          setState(() => _isOptional = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Add Button
                CustomButton(
                  text: 'Add Item',
                  onPressed: _handleAddItem,
                  width: double.infinity,
                  icon: Icons.add_shopping_cart,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}