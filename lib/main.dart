import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/system_choice_screen.dart';
import 'screens/create_system_screen.dart';
import 'screens/join_system_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/meal_calendar_screen.dart';
import 'screens/grocery_list_screen.dart';
import 'screens/add_grocery_item_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/attendance_history_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/expense_summary_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/add_inventory_item_screen.dart';
import 'screens/cooking_rotation_screen.dart';
import 'screens/rotation_settings_screen.dart';
import 'screens/recipe_browser_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/shopping_trip_screen.dart';
import 'screens/meal_preference_screen.dart';
import 'screens/settlement_report_screen.dart';

// Services
import 'services/auth_service.dart';
import 'services/meal_system_service.dart';
import 'services/grocery_service.dart';
import 'services/attendance_service.dart';
import 'services/expense_service.dart';
import 'services/inventory_service.dart';
import 'services/cooking_rotation_service.dart';
import 'services/recipe_service.dart';
import 'services/shopping_trip_service.dart';
import 'services/meal_preference_service.dart';
import 'services/settlement_service.dart';
import 'services/notification_service.dart'; // Added NotificationService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  // Schedule the default daily reminder immediately
  await notificationService.scheduleDailyMealReminder();
  
  runApp(MealMateApp(notificationService: notificationService));
}

class MealMateApp extends StatelessWidget {
  final NotificationService notificationService;

  const MealMateApp({
    super.key, 
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Inject NotificationService
        Provider<NotificationService>.value(value: notificationService),
        
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MealSystemService()),
        ChangeNotifierProvider(create: (_) => GroceryService()),
        ChangeNotifierProvider(create: (_) => AttendanceService()),
        ChangeNotifierProvider(create: (_) => ExpenseService()),
        ChangeNotifierProvider(create: (_) => InventoryService()),
        ChangeNotifierProvider(create: (_) => CookingRotationService()),
        ChangeNotifierProvider(create: (_) => RecipeService()),
        ChangeNotifierProvider(create: (_) => ShoppingTripService()),
        ChangeNotifierProvider(create: (_) => MealPreferenceService()),
        ChangeNotifierProvider(create: (_) => SettlementService()),
      ],
      child: MaterialApp(
        title: 'MealMate',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF22C55E),
            primary: const Color(0xFF22C55E),
            secondary: const Color(0xFF16A34A),
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF22C55E),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF22C55E),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/system-choice': (context) => const SystemChoiceScreen(),
          '/create-system': (context) => const CreateSystemScreen(),
          '/join-system': (context) => const JoinSystemScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/calendar': (context) => const MealCalendarScreen(),
          '/grocery-list': (context) => const GroceryListScreen(),
          '/add-grocery-item': (context) => const AddGroceryItemScreen(),
          '/attendance': (context) => const AttendanceScreen(),
          '/attendance-history': (context) => const AttendanceHistoryScreen(),
          '/expenses': (context) => const ExpenseScreen(),
          '/add-expense': (context) => const AddExpenseScreen(),
          '/expense-summary': (context) => const ExpenseSummaryScreen(),
          '/inventory': (context) => const InventoryScreen(),
          '/add-inventory-item': (context) => const AddInventoryItemScreen(),
          '/edit-inventory-item': (context) => const AddInventoryItemScreen(),
          '/cooking-rotation': (context) => const CookingRotationScreen(),
          '/rotation-settings': (context) => const RotationSettingsScreen(),
          '/recipe-browser': (context) => const RecipeBrowserScreen(),
          '/recipe-detail': (context) => const RecipeDetailScreen(),
          '/shopping-trips': (context) => const ShoppingTripScreen(),
          '/meal-preferences': (context) => const MealPreferenceScreen(),
          '/settlement-reports': (context) => const SettlementReportScreen(),
        },
      ),
    );
  }
}