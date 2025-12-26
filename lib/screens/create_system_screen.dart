import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/meal_system_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class CreateSystemScreen extends StatefulWidget {
  const CreateSystemScreen({super.key});

  @override
  State<CreateSystemScreen> createState() => _CreateSystemScreenState();
}

class _CreateSystemScreenState extends State<CreateSystemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _systemNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _monthlyRateController = TextEditingController();
  final _rulesController = TextEditingController();

  @override
  void dispose() {
    _systemNameController.dispose();
    _locationController.dispose();
    _monthlyRateController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateSystem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);

    if (authService.userModel == null) {
      Fluttertoast.showToast(
        msg: 'User not found. Please login again.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final mealSystem = await mealSystemService.createMealSystem(
      systemName: _systemNameController.text.trim(),
      ownerId: authService.userModel!.userId,
      ownerName: authService.userModel!.name,
      monthlyRate: double.parse(_monthlyRateController.text.trim()),
      location: _locationController.text.trim().isEmpty 
          ? null 
          : _locationController.text.trim(),
      rules: _rulesController.text.trim().isEmpty 
          ? null 
          : _rulesController.text.trim(),
    );

    if (!mounted) return;

    if (mealSystem != null) {
      // Update user's current meal system
      await authService.updateCurrentMealSystem(mealSystem.systemId);

      // Show success dialog with system code
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'System Created!',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your meal system has been created successfully.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your System Code:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      mealSystem.systemCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this code with others to invite them',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            CustomButton(
              text: 'Continue to Dashboard',
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/dashboard');
              },
            ),
          ],
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: mealSystemService.errorMessage ?? 'Failed to create meal system',
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Meal System'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
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
                          'Set up your shared cooking space. You\'ll receive a unique code to share with others.',
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
                
                // System Name Field
                CustomTextField(
                  label: 'System Name *',
                  hint: 'e.g., Bachelor Pad 401',
                  controller: _systemNameController,
                  prefixIcon: Icons.home_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => FieldValidators.required(value, 'System name'),
                ),
                const SizedBox(height: 20),
                
                // Location Field (Optional)
                CustomTextField(
                  label: 'Location (Optional)',
                  hint: 'e.g., Dhaka, Bangladesh',
                  controller: _locationController,
                  prefixIcon: Icons.location_on_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                
                // Monthly Rate Field
                NumberField(
                  label: 'Monthly Rate per Meal (BDT) *',
                  hint: 'e.g., 80',
                  controller: _monthlyRateController,
                  allowDecimal: true,
                  prefixIcon: Icons.attach_money,
                  validator: (value) => FieldValidators.positiveNumber(value, 'Monthly rate'),
                ),
                const SizedBox(height: 20),
                
                // House Rules Field (Optional)
                TextAreaField(
                  label: 'House Rules (Optional)',
                  hint: 'Enter any rules or guidelines for the meal system...',
                  controller: _rulesController,
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 30),
                
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'You will be the system owner',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'As the owner, you can:\n• Edit system settings\n• Remove members\n• View all reports\n• Change meal rates',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Create Button
                Consumer<MealSystemService>(
                  builder: (context, mealSystemService, child) {
                    return CustomButton(
                      text: 'Create System',
                      onPressed: _handleCreateSystem,
                      isLoading: mealSystemService.isLoading,
                      width: double.infinity,
                      icon: Icons.add_circle_outline,
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