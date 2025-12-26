import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../models/expense_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = ExpenseCategory.groceries;
  String _selectedSplitMethod = SplitMethod.mealBased;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleAddExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final expenseService = Provider.of<ExpenseService>(context, listen: false);
    final systemId = authService.userModel?.currentMealSystemId;

    if (systemId == null) {
      Fluttertoast.showToast(
        msg: 'No meal system found',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final success = await expenseService.addExpense(
      systemId: systemId,
      amount: double.parse(_amountController.text),
      paidBy: authService.userModel!.userId,
      paidByName: authService.userModel!.name,
      category: _selectedCategory,
      date: _selectedDate,
      splitMethod: _selectedSplitMethod,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Fluttertoast.showToast(
        msg: 'Expense added successfully!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.of(context).pop();
    } else {
      Fluttertoast.showToast(
        msg: expenseService.errorMessage ?? 'Failed to add expense',
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
        title: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount
                NumberField(
                  label: 'Amount (BDT) *',
                  hint: '1500',
                  controller: _amountController,
                  allowDecimal: true,
                  prefixIcon: Icons.attach_money,
                  validator: (value) =>
                      FieldValidators.positiveNumber(value, 'Amount'),
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
                      children: ExpenseCategory.all.map((category) {
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
                                  ExpenseCategory.getEmoji(category),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  ExpenseCategory.getDisplayName(category),
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

                // Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDate,
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
                              DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                TextAreaField(
                  label: 'Description (Optional)',
                  hint: 'e.g., Weekly grocery shopping',
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 20),

                // Split Method
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Split Method *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Meal-Based Split'),
                            subtitle: const Text(
                              'Split based on meals eaten by each member',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: SplitMethod.mealBased,
                            groupValue: _selectedSplitMethod,
                            onChanged: (value) {
                              setState(() => _selectedSplitMethod = value!);
                            },
                          ),
                          Divider(height: 1, color: Colors.grey[300]),
                          RadioListTile<String>(
                            title: const Text('Equal Split'),
                            subtitle: const Text(
                              'Split equally among all members',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: SplitMethod.equal,
                            groupValue: _selectedSplitMethod,
                            onChanged: (value) {
                              setState(() => _selectedSplitMethod = value!);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Meal-based split calculates each member\'s share based on their attendance. This is the recommended method for fair expense distribution.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Add Button
                Consumer<ExpenseService>(
                  builder: (context, expenseService, child) {
                    return CustomButton(
                      text: 'Add Expense',
                      onPressed: _handleAddExpense,
                      isLoading: expenseService.isLoading,
                      width: double.infinity,
                      icon: Icons.add,
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