import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart'; // Added for Clipboard

// Services
import '../services/auth_service.dart';
import '../services/meal_system_service.dart';
import '../services/expense_service.dart';
import '../services/attendance_service.dart';
import '../services/shopping_trip_service.dart';

// Models
import '../models/meal_system_model.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';

// Widgets
import '../widgets/custom_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  // State Variables
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  // Dashboard Data
  double _myBalance = 0.0;
  int _mealsEaten = 0;
  List<ExpenseModel> _recentExpenses = [];
  String _nextMealStatus = "Not Set";
  
  // Animation Controller for smooth loading
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup Animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Load Data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // CORE LOGIC: Load & Calculate Stats
  // ==========================================================================
  Future<void> _loadDashboardData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealSystemService = Provider.of<MealSystemService>(context, listen: false);
    final expenseService = Provider.of<ExpenseService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);

    final user = authService.userModel;
    final systemId = user?.currentMealSystemId;

    if (user == null || systemId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Load System Details
      await mealSystemService.loadMealSystem(systemId);
      
      // Force refresh stats to ensure Balance & Meals are accurate
      await mealSystemService.refreshSystemStats(systemId);

      // 2. Load Recent Expenses (Fetch locally sorted)
      final expenses = await expenseService.getExpenses(
        systemId: systemId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      // Sort by date (newest first) and take top 5
      expenses.sort((a, b) => b.date.compareTo(a.date));
      final recentExpenses = expenses.take(5).toList();

      // 3. Get Next Meal Status (Using helper)
      final nextMeal = await _calculateNextMealStatus(
        attendanceService,
        systemId,
        user.userId,
      );

      // 4. Update Local State from the Fresh Provider Data
      if (mounted) {
        final currentSystem = mealSystemService.currentMealSystem;
        final memberData = currentSystem?.members[user.userId];

        setState(() {
          _myBalance = memberData?.totalOwed ?? 0.0; 
          _mealsEaten = memberData?.totalMealsEaten ?? 0;
          
          _recentExpenses = recentExpenses;
          _nextMealStatus = nextMeal;
          _isLoading = false;
        });
        
        // Start Fade In Animation
        _fadeController.forward();
      }
    } catch (e) {
      print("Dashboard Load Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper to calculate next meal status
  Future<String> _calculateNextMealStatus(
    AttendanceService service, 
    String systemId, 
    String userId
  ) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get attendance for today
      final attendanceList = await service.getAttendanceRange(
        systemId: systemId, 
        startDate: today, 
        endDate: today
      );
      
      if (attendanceList.isEmpty) return "Not Set";
      
      final todayAttendance = attendanceList.first;
      final hour = now.hour;
      
      // Logic: Show status based on time of day
      if (hour < 11) { // Before 11 AM -> Breakfast
        final status = todayAttendance.breakfast[userId]?.status ?? 'maybe';
        return _formatStatus("Breakfast", status);
      } else if (hour < 16) { // Before 4 PM -> Lunch
        final status = todayAttendance.lunch[userId]?.status ?? 'maybe';
        return _formatStatus("Lunch", status);
      } else { // After 4 PM -> Dinner
        final status = todayAttendance.dinner[userId]?.status ?? 'maybe';
        return _formatStatus("Dinner", status);
      }
    } catch (e) {
      return "Not Set";
    }
  }

  String _formatStatus(String meal, String status) {
    if (status == 'yes') return "$meal: Eating";
    if (status == 'no') return "$meal: Skipping";
    return "$meal: Not Set";
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadDashboardData();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.userModel;
    final hasSystem = user?.currentMealSystemId != null;

    // Handle No System Case
    if (!hasSystem && !_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_off_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "You haven't joined a Meal System yet",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: "Create or Join System",
                onPressed: () => Navigator.pushReplacementNamed(context, '/system-choice'),
                width: 200,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(user),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeHeader(user),
                      const SizedBox(height: 24),
                      _buildQuickStatsCard(),
                      const SizedBox(height: 24),
                      const Text(
                        "Features",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeaturesGrid(),
                      const SizedBox(height: 24),
                      _buildRecentActivitySection(),
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  // ==========================================================================
  // WIDGET BUILDERS
  // ==========================================================================

  PreferredSizeWidget _buildAppBar(UserModel? user) {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF16A34A), 
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            "MealMate",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ],
      ),
      actions: [
        // REMOVED: Notification bell button as requested
        
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/meal-preferences'),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    user?.name.substring(0, 1).toUpperCase() ?? "U",
                    style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildWelcomeHeader(UserModel? user) {
    final mealSystemService = Provider.of<MealSystemService>(context);
    final systemName = mealSystemService.currentMealSystem?.systemName ?? "Your System";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hello, ${user?.name.split(' ').first ?? 'User'}! 👋",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          systemName,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsCard() {
    // Determine Color and Label based on Balance
    final isOwing = _myBalance > 0;
    final isOwed = _myBalance < 0;
    
    final balanceLabel = isOwing 
        ? "You Owe" 
        : (isOwed ? "Owed to You" : "Settled");

    final absBalance = _myBalance.abs();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Balance Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        balanceLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "৳ ${absBalance.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              
              Container(
                width: 1,
                height: 50,
                color: Colors.white12,
              ),

              // 2. Meals Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Meals Eaten",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.restaurant, color: Colors.white70, size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$_mealsEaten",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // 3. Next Meal Status Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule, color: Colors.orangeAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Upcoming Meal",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _nextMealStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: Size.zero, 
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  "Update",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _FeatureCard(
          title: "Calendar",
          icon: Icons.calendar_month_outlined,
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, '/calendar'),
        ),
        _FeatureCard(
          title: "Grocery",
          icon: Icons.shopping_basket_outlined,
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, '/grocery-list'),
        ),
        _FeatureCard(
          title: "Expenses",
          icon: Icons.attach_money_outlined,
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, '/expenses'),
        ),
        _FeatureCard(
          title: "Inventory",
          icon: Icons.inventory_2_outlined,
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, '/inventory'),
        ),
        _FeatureCard(
          title: "Cooking",
          icon: Icons.soup_kitchen_outlined,
          color: Colors.redAccent,
          onTap: () => Navigator.pushNamed(context, '/cooking-rotation'),
        ),
        _FeatureCard(
          title: "Recipes",
          icon: Icons.menu_book_outlined,
          color: Colors.teal,
          onTap: () => Navigator.pushNamed(context, '/recipe-browser'),
        ),
        _FeatureCard(
          title: "Shopping",
          icon: Icons.shopping_cart_checkout,
          color: Colors.indigo,
          onTap: () => Navigator.pushNamed(context, '/shopping-trips'),
        ),
        _FeatureCard(
          title: "Reports",
          icon: Icons.summarize_outlined,
          color: Colors.brown,
          onTap: () => Navigator.pushNamed(context, '/settlement-reports'),
        ),
        _FeatureCard(
          title: "Settings",
          icon: Icons.settings_outlined,
          color: Colors.grey,
          onTap: () {
            // Settings navigation or system info
            final systemService = Provider.of<MealSystemService>(context, listen: false);
            final system = systemService.currentMealSystem;
            final code = system?.systemCode ?? "";
            final currentUser = Provider.of<AuthService>(context, listen: false).userModel;
            // ignore: unused_local_variable
            final isOwner = system != null && currentUser != null && system.ownerId == currentUser.userId;
            
            showDialog(context: context, builder: (c) => AlertDialog(
              title: const Text("System Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text("Meal Preferences"),
                    leading: const Icon(Icons.tune, color: Colors.blue),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/meal-preferences');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text("System Code"),
                    subtitle: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: const Icon(Icons.copy),
                    onTap: () async {
                      // FIX: Copy code to clipboard
                      await Clipboard.setData(ClipboardData(text: code));
                      Fluttertoast.showToast(msg: "Code copied!");
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text("System Members"),
                    leading: const Icon(Icons.people, color: Colors.purple),
                    onTap: () {
                      Navigator.pop(context);
                      _showMembersDialog(context, systemService, currentUser?.userId);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text("Log Out"), 
                    leading: const Icon(Icons.logout, color: Colors.red), 
                    onTap: () async {
                       Navigator.pop(context);
                       // Call Sign Out
                       await Provider.of<AuthService>(context, listen: false).signOut();
                       // Navigator to login
                       if (context.mounted) {
                         Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                       }
                    },
                  ),
                ],
              ),
            ));
          },
        ),
      ],
    );
  }

  // Helper for Members Dialog
  void _showMembersDialog(BuildContext context, MealSystemService service, String? currentUserId) {
    if (service.currentMealSystem == null) return;
    
    final members = service.currentMealSystem!.members;
    final isOwner = service.currentMealSystem!.ownerId == currentUserId;

    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text("System Members"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final memberId = members.keys.elementAt(index);
              final memberInfo = members[memberId]!;
              final isMe = memberId == currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(memberInfo.name[0].toUpperCase()),
                ),
                title: Text(memberInfo.name + (isMe ? " (You)" : "")),
                subtitle: Text(memberInfo.role.toUpperCase()),
                trailing: (isOwner && !isMe) // Only owner can remove others
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          // Confirm deletion
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text("Remove Member"),
                              content: Text("Are you sure you want to remove ${memberInfo.name}?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          
                          if (confirm == true) {
                            await service.removeMember(memberId);
                            if (context.mounted) Navigator.pop(context); 
                            Fluttertoast.showToast(msg: "Member removed");
                          }
                        },
                      )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Activity",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/expenses'),
              child: const Text("View All"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentExpenses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  "No recent expenses",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentExpenses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final expense = _recentExpenses[index];
              return _buildExpenseItem(expense);
            },
          ),
      ],
    );
  }

  Widget _buildExpenseItem(ExpenseModel expense) {
    // Format date nicely
    final dateStr = DateFormat('MMM d').format(expense.date);
    
    // Category Icon
    IconData icon;
    Color color;
    switch (expense.category.toLowerCase()) {
      case 'groceries': icon = Icons.shopping_basket; color = Colors.green; break;
      case 'utilities': icon = Icons.lightbulb; color = Colors.orange; break;
      case 'gas': icon = Icons.local_fire_department; color = Colors.red; break;
      case 'other': default: icon = Icons.receipt; color = Colors.blue; break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.paidByName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expense.category[0].toUpperCase() + expense.category.substring(1),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "৳ ${expense.amount.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: "add_expense",
          onPressed: () => Navigator.pushNamed(context, '/add-expense'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.purple,
          child: const Icon(Icons.attach_money),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: "mark_attendance",
          onPressed: () => Navigator.pushNamed(context, '/attendance'),
          backgroundColor: Colors.teal, 
          child: const Icon(Icons.check, color: Colors.white), 
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}