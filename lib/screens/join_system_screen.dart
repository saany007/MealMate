import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/meal_system_service.dart';
import '../services/database_service.dart';
import '../models/meal_system_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class JoinSystemScreen extends StatefulWidget {
  const JoinSystemScreen({super.key});

  @override
  State<JoinSystemScreen> createState() => _JoinSystemScreenState();
}

class _JoinSystemScreenState extends State<JoinSystemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _databaseService = DatabaseService();
  MealSystemModel? _previewSystem;
  bool _isVerifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _previewSystem = null;
    });

    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);
    
    final code = _codeController.text.trim().toUpperCase();
    
    // Validate code format
    if (!mealSystemService.isValidSystemCode(code)) {
      setState(() {
        _isVerifying = false;
      });
      Fluttertoast.showToast(
        msg: 'Invalid code format. Code should be 6-8 characters.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Try to find the system using database service
    try {
      final system = await _databaseService.getMealSystemByCode(code);
      
      if (!mounted) return;
      
      setState(() {
        _previewSystem = system;
        _isVerifying = false;
      });

      if (system == null) {
        Fluttertoast.showToast(
          msg: 'System not found. Please check the code and try again.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isVerifying = false;
      });
      
      Fluttertoast.showToast(
        msg: 'Error verifying code: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _handleJoinSystem() async {
    if (_previewSystem == null) return;

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

    // Check if already a member
    if (_previewSystem!.isMember(authService.userModel!.userId)) {
      Fluttertoast.showToast(
        msg: 'You are already a member of this system.',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      
      // Update current meal system and navigate to dashboard
      await authService.updateCurrentMealSystem(_previewSystem!.systemId);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
      return;
    }

    final result = await mealSystemService.joinMealSystem(
      systemCode: _previewSystem!.systemCode,
      userId: authService.userModel!.userId,
      userName: authService.userModel!.name,
    );

    if (!mounted) return;

    if (result != null) {
      // Update user's current meal system
      await authService.updateCurrentMealSystem(result.systemId);

      Fluttertoast.showToast(
        msg: 'Successfully joined ${result.systemName}!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      Fluttertoast.showToast(
        msg: mealSystemService.errorMessage ?? 'Failed to join meal system',
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
        title: const Text('Join Meal System'),
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
                const SizedBox(height: 20),
                
                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.link,
                      size: 40,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Title
                const Text(
                  'Enter System Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get the code from the system owner',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Code Input Field
                CustomTextField(
                  label: 'System Code',
                  hint: 'Enter 6-8 character code',
                  controller: _codeController,
                  prefixIcon: Icons.vpn_key,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'System code is required';
                    }
                    if (value.length < 6 || value.length > 8) {
                      return 'Code must be 6-8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Verify Button
                CustomButton(
                  text: 'Verify Code',
                  onPressed: _handleVerifyCode,
                  isLoading: _isVerifying,
                  width: double.infinity,
                  icon: Icons.search,
                ),
                
                // System Preview
                if (_previewSystem != null) ...[
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'System Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        _InfoRow(
                          label: 'Name',
                          value: _previewSystem!.systemName,
                          icon: Icons.home,
                        ),
                        const SizedBox(height: 12),
                        
                        _InfoRow(
                          label: 'Members',
                          value: '${_previewSystem!.memberCount} people',
                          icon: Icons.people,
                        ),
                        const SizedBox(height: 12),
                        
                        _InfoRow(
                          label: 'Rate/Meal',
                          value: '${_previewSystem!.monthlyRate.toStringAsFixed(0)} BDT',
                          icon: Icons.attach_money,
                        ),
                        
                        if (_previewSystem!.location != null) ...[
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Location',
                            value: _previewSystem!.location!,
                            icon: Icons.location_on,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Join Button
                  Consumer<MealSystemService>(
                    builder: (context, mealSystemService, child) {
                      return CustomButton(
                        text: 'Confirm & Join',
                        onPressed: _handleJoinSystem,
                        isLoading: mealSystemService.isLoading,
                        width: double.infinity,
                      );
                    },
                  ),
                ],
                
                const SizedBox(height: 30),
                
                // Help Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: Colors.amber[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Don\'t have a code? Contact the system owner and ask them to share their meal system code with you.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}