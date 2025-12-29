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
  
  // Controllers
  final _systemNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _monthlyRateController = TextEditingController();
  final _rulesController = TextEditingController();

  // State
  bool _isCreating = false;

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

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final authService = Provider.of<AuthService>(context, listen: false);
    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);

    if (authService.userModel == null) {
      Fluttertoast.showToast(msg: 'User not found. Please login again.');
      return;
    }

    // Set local loading state to prevent double taps
    setState(() => _isCreating = true);

    try {
      // Call service to create system
      final result = await mealSystemService.createMealSystem(
        ownerId: authService.userModel!.userId,
        ownerName: authService.userModel!.name,
        systemName: _systemNameController.text.trim(),
        location: _locationController.text.trim(),
        monthlyRate: double.tryParse(_monthlyRateController.text) ?? 0.0,
        rules: _rulesController.text.trim(),
      );

      if (result != null && mounted) {
        // --- CRITICAL FIX ---
        // Reload user to fetch the new 'currentMealSystemId' from Firestore.
        // This ensures the Dashboard knows which system to load.
        await authService.reloadUser();
        
        Fluttertoast.showToast(msg: 'System created successfully!');
        
        // Use pushNamedAndRemoveUntil to clear the stack and force a fresh Dashboard load
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error creating system: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access loading state from service or local
    final mealSystemService = Provider.of<MealSystemService>(context);
    final isLoading = _isCreating || mealSystemService.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9), // Premium light background
      appBar: AppBar(
        title: const Text(
          'Create New Mess',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF22C55E), // Green AppBar
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Section ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      const Color(0xFF22C55E).withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF22C55E),
                            Color(0xFF16A34A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Setup Your Kitchen',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create a shared space to manage meals, expenses, and shopping with your roommates.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Owner Privileges Info Card ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF22C55E).withOpacity(0.08),
                      const Color(0xFF16A34A).withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Owner Privileges',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'As the system creator, you will have admin rights to:\n'
                            '• Manage members (approve/remove)\n'
                            '• Edit system settings & rules\n'
                            '• Finalize monthly settlements',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF14532D),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- Form Section 1: Basic Info ---
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),
              
              CustomTextField(
                label: 'Mess/System Name',
                hint: 'e.g., Sunnydale Apartment 4B',
                controller: _systemNameController,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'System name is required';
                  if (val.length < 3) return 'Name must be at least 3 characters';
                  return null;
                },
                prefixIcon: Icons.home_work_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              
              CustomTextField(
                label: 'Location / Address',
                hint: 'e.g., Road 5, Dhanmondi',
                controller: _locationController,
                validator: (val) => val?.isEmpty ?? true ? 'Location is required' : null,
                prefixIcon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // --- Form Section 2: Financials ---
              _buildSectionHeader('Financial Settings'),
              const SizedBox(height: 16),
              
              CustomTextField(
                label: 'Estimated Monthly Rate (Per Person)',
                hint: 'e.g., 3000',
                controller: _monthlyRateController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money,
                validator: (val) {
                  if (val == null || val.isEmpty) return null; // Optional
                  if (double.tryParse(val) == null) return 'Please enter a valid number';
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This is just an estimate to help members plan their budget.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Form Section 3: Rules ---
              _buildSectionHeader('House Rules'),
              const SizedBox(height: 16),
              
              CustomTextField(
                label: 'System Rules & Notes',
                hint: 'e.g., Meal count cutoff is 10 AM. Shopping rotation is weekly.',
                controller: _rulesController,
                maxLines: 4,
                prefixIcon: Icons.gavel_outlined,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 40),

              // --- Action Button ---
              CustomButton(
                text: 'Create System',
                onPressed: isLoading ? null : _handleCreateSystem,
                isLoading: isLoading,
                width: double.infinity,
                height: 56,
                icon: Icons.add_circle_outline,
                backgroundColor: const Color(0xFF22C55E), // Brand Green
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for consistent section headers
  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF22C55E).withOpacity(0.1),
            const Color(0xFF22C55E).withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF22C55E).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF22C55E),
                  Color(0xFF16A34A),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}