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

  // --- Step 1: Verify Code & Preview System ---
  Future<void> _handleVerifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
      _previewSystem = null;
    });

    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);
    
    final code = _codeController.text.trim().toUpperCase();
    
    // 1. Validate format locally
    if (!mealSystemService.isValidSystemCode(code)) {
      setState(() => _isVerifying = false);
      Fluttertoast.showToast(
        msg: 'Invalid code format. Code should be 6-8 characters.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // 2. Fetch System Details
    try {
      final system = await _databaseService.getMealSystemByCode(code);
      
      if (!mounted) return;
      
      setState(() {
        _previewSystem = system;
        _isVerifying = false;
      });

      if (system == null) {
        Fluttertoast.showToast(
          msg: 'System not found. Please check the code.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      Fluttertoast.showToast(msg: 'Error verifying code: $e');
    }
  }

  // --- Step 2: Join the System ---
  Future<void> _handleJoinSystem() async {
    if (_previewSystem == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);

    if (authService.userModel == null) {
      Fluttertoast.showToast(msg: 'User not found. Please login again.');
      return;
    }

    // Check if already a member
    if (_previewSystem!.isMember(authService.userModel!.userId)) {
      Fluttertoast.showToast(
        msg: 'You are already a member of this system.',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      
      // Update local state and navigate
      await authService.updateCurrentMealSystem(_previewSystem!.systemId);
      await authService.reloadUser();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
      return;
    }

    // Perform Join
    final result = await mealSystemService.joinMealSystem(
      systemCode: _previewSystem!.systemCode,
      userId: authService.userModel!.userId,
      userName: authService.userModel!.name,
    );

    if (!mounted) return;

    if (result != null) {
      // --- CRITICAL FIX ---
      // 1. Update local auth provider state
      await authService.updateCurrentMealSystem(_previewSystem!.systemId);
      
      // 2. Force fetch fresh user data from Firestore
      await authService.reloadUser();

      Fluttertoast.showToast(
        msg: 'Successfully joined ${_previewSystem!.systemName}!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // 3. Navigate to Dashboard (Fresh Stack)
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    } else {
      Fluttertoast.showToast(
        msg: mealSystemService.errorMessage ?? 'Failed to join system',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB), // Premium light background
      appBar: AppBar(
        title: const Text(
          'Join Meal System',
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
                const SizedBox(height: 10),
                
                // --- Top Icon ---
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF22C55E).withOpacity(0.15),
                          const Color(0xFF16A34A).withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.link,
                      size: 40,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // --- Titles ---
                const Text(
                  'Enter System Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get the 6-character code from the system owner to join their kitchen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                
                // --- Input Field ---
                CustomTextField(
                  label: 'System Code',
                  hint: 'e.g., A1B2C3',
                  controller: _codeController,
                  prefixIcon: Icons.vpn_key_outlined,
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
                
                // --- Verify Button ---
                // Only show this if we haven't found a system yet to avoid clutter
                if (_previewSystem == null)
                  CustomButton(
                    text: 'Find System',
                    onPressed: _handleVerifyCode,
                    isLoading: _isVerifying,
                    width: double.infinity,
                    height: 50,
                    icon: Icons.search,
                    backgroundColor: const Color(0xFF22C55E),
                  ),
                
                // --- System Preview Card ---
                if (_previewSystem != null) ...[
                  const SizedBox(height: 30),
                  FadeTransition(
                    opacity: const AlwaysStoppedAnimation(1), // Simple fade effect placeholder
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            const Color(0xFF22C55E).withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.withOpacity(0.15),
                                      Colors.green.withOpacity(0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'System Found',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Details
                          _InfoRow(
                            label: 'Name',
                            value: _previewSystem!.systemName,
                            icon: Icons.home_work,
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Members',
                            value: '${_previewSystem!.memberCount} active members',
                            icon: Icons.people_alt,
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Est. Cost',
                            value: '${_previewSystem!.monthlyRate.toStringAsFixed(0)} BDT / month',
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
                  ),
                  const SizedBox(height: 24),
                  
                  // Confirm Join Button
                  Consumer<MealSystemService>(
                    builder: (context, mealSystemService, child) {
                      return CustomButton(
                        text: 'Confirm & Join',
                        onPressed: _handleJoinSystem,
                        isLoading: mealSystemService.isLoading,
                        width: double.infinity,
                        height: 56,
                        backgroundColor: const Color(0xFF22C55E), // Green for success action
                        icon: Icons.login,
                      );
                    },
                  ),
                  
                  // Cancel / Search Again
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _previewSystem = null;
                        _codeController.clear();
                      });
                    },
                    child: const Text("Search different code"),
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // --- Help Tip ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF59E0B).withOpacity(0.12),
                        const Color(0xFFF59E0B).withOpacity(0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFB45309),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Don\'t have a code? Contact the system owner and ask them to share their meal system code with you.',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFFB45309),
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

// --- Helper Widget for Preview Card ---
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF22C55E).withOpacity(0.15),
                const Color(0xFF16A34A).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF22C55E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
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