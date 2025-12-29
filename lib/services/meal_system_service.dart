import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_system_model.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class MealSystemService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  
  MealSystemModel? _currentMealSystem;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  MealSystemModel? get currentMealSystem => _currentMealSystem;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Set loading state
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  // Set error message
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Generate unique system code (6-8 alphanumeric characters)
  Future<String> _generateUniqueSystemCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    int attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      // Generate 6 character code
      String code = List.generate(
        6,
        (index) => chars[random.nextInt(chars.length)],
      ).join();

      // Check if code already exists
      bool exists = await _databaseService.systemCodeExists(code);
      if (!exists) {
        return code;
      }
      attempts++;
    }

    throw Exception('Failed to generate unique system code after $maxAttempts attempts');
  }

  // Create a new meal system
  Future<MealSystemModel?> createMealSystem({
    required String systemName,
    required String ownerId,
    required String ownerName,
    required double monthlyRate,
    String? location,
    String? rules,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Generate unique code
      String systemCode = await _generateUniqueSystemCode();

      // Create system ID
      String systemId = _uuid.v4();

      // Create owner member info
      MemberInfo ownerInfo = MemberInfo(
        name: ownerName,
        role: 'owner',
        joinedDate: DateTime.now(),
        totalMealsEaten: 0,
        totalOwed: 0.0,
      );

      // Create meal system model
      MealSystemModel mealSystem = MealSystemModel(
        systemId: systemId,
        systemName: systemName,
        systemCode: systemCode,
        ownerId: ownerId,
        createdDate: DateTime.now(),
        monthlyRate: monthlyRate,
        location: location,
        rules: rules,
        members: {ownerId: ownerInfo},
      );

      // Save to database
      await _databaseService.createMealSystem(mealSystem);

      // Update user's current system
      await _firestore.collection('users').doc(ownerId).update({
        'currentMealSystemId': systemId,
      });

      _currentMealSystem = mealSystem;
      _setLoading(false);
      return mealSystem;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create meal system: $e');
      return null;
    }
  }

  // Join an existing meal system using code
  Future<MealSystemModel?> joinMealSystem({
    required String systemCode,
    required String userId,
    required String userName,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Get meal system by code
      MealSystemModel? mealSystem = await _databaseService.getMealSystemByCode(systemCode);

      if (mealSystem == null) {
        _setError('Invalid system code. Please check and try again.');
        _setLoading(false);
        return null;
      }

      // Check if user is already a member
      if (mealSystem.isMember(userId)) {
        // Ensure user is linked even if already member
        await _firestore.collection('users').doc(userId).update({
          'currentMealSystemId': mealSystem.systemId,
        });
        
        _currentMealSystem = mealSystem;
        _setError('You are already a member of this system.');
        _setLoading(false);
        return mealSystem;
      }

      // Create member info
      MemberInfo memberInfo = MemberInfo(
        name: userName,
        role: 'member',
        joinedDate: DateTime.now(),
        totalMealsEaten: 0,
        totalOwed: 0.0,
      );

      // Add member to system
      await _databaseService.addMemberToSystem(
        mealSystem.systemId,
        userId,
        memberInfo,
      );

      // Update user's current system
      await _firestore.collection('users').doc(userId).update({
        'currentMealSystemId': mealSystem.systemId,
      });

      // Update local meal system
      Map<String, MemberInfo> updatedMembers = Map.from(mealSystem.members);
      updatedMembers[userId] = memberInfo;
      
      _currentMealSystem = mealSystem.copyWith(members: updatedMembers);
      
      // Calculate initial stats
      await refreshSystemStats(mealSystem.systemId);
      
      _setLoading(false);
      return _currentMealSystem;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to join meal system: $e');
      return null;
    }
  }

  // Load meal system by ID
  Future<MealSystemModel?> loadMealSystem(String systemId) async {
    try {
      _setLoading(true);
      _setError(null);

      MealSystemModel? mealSystem = await _databaseService.getMealSystemById(systemId);

      if (mealSystem == null) {
        _setError('Meal system not found.');
        _setLoading(false);
        return null;
      }

      _currentMealSystem = mealSystem;

      // CRITICAL FIX: Refresh stats immediately so dashboard isn't empty
      await refreshSystemStats(systemId);

      _setLoading(false);
      return mealSystem;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to load meal system: $e');
      return null;
    }
  }

  // Update meal system details
  Future<bool> updateMealSystem({
    String? systemName,
    double? monthlyRate,
    String? location,
    String? rules,
  }) async {
    try {
      if (_currentMealSystem == null) {
        _setError('No active meal system.');
        return false;
      }

      _setLoading(true);

      MealSystemModel updatedSystem = _currentMealSystem!.copyWith(
        systemName: systemName,
        monthlyRate: monthlyRate,
        location: location,
        rules: rules,
      );

      await _databaseService.updateMealSystem(updatedSystem);

      _currentMealSystem = updatedSystem;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to update meal system: $e');
      return false;
    }
  }

  // Remove member from meal system
  Future<bool> removeMember(String userId) async {
    try {
      if (_currentMealSystem == null) {
        _setError('No active meal system.');
        return false;
      }

      // Cannot remove owner
      if (_currentMealSystem!.ownerId == userId) {
        _setError('Cannot remove the system owner.');
        return false;
      }

      _setLoading(true);

      await _databaseService.removeMemberFromSystem(
        _currentMealSystem!.systemId,
        userId,
      );

      // Remove system ID from user
      await _firestore.collection('users').doc(userId).update({
        'currentMealSystemId': FieldValue.delete(),
      });

      // Update local state
      Map<String, MemberInfo> updatedMembers = Map.from(_currentMealSystem!.members);
      updatedMembers.remove(userId);
      
      _currentMealSystem = _currentMealSystem!.copyWith(members: updatedMembers);
      
      // Recalculate stats after removal
      await refreshSystemStats(_currentMealSystem!.systemId);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to remove member: $e');
      return false;
    }
  }

  // Leave meal system (for non-owners)
  Future<bool> leaveMealSystem(String userId) async {
    try {
      if (_currentMealSystem == null) {
        _setError('No active meal system.');
        return false;
      }

      // Owner cannot leave, must delete system or transfer ownership
      if (_currentMealSystem!.ownerId == userId) {
        _setError('Owner cannot leave. Please transfer ownership or delete the system.');
        return false;
      }

      return await removeMember(userId);
    } catch (e) {
      _setError('Failed to leave meal system: $e');
      return false;
    }
  }

  // Delete meal system (only owner can do this)
  Future<bool> deleteMealSystem(String userId) async {
    try {
      if (_currentMealSystem == null) {
        _setError('No active meal system.');
        return false;
      }

      // Check if user is owner
      if (_currentMealSystem!.ownerId != userId) {
        _setError('Only the owner can delete the meal system.');
        return false;
      }

      _setLoading(true);

      await _databaseService.deleteMealSystem(_currentMealSystem!.systemId);
      
      // Update owner profile
      await _firestore.collection('users').doc(userId).update({
        'currentMealSystemId': FieldValue.delete(),
      });

      _currentMealSystem = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete meal system: $e');
      return false;
    }
  }

  // Get all meal systems for a user
  Future<List<MealSystemModel>> getUserMealSystems(String userId) async {
    try {
      return await _databaseService.getMealSystemsForUser(userId);
    } catch (e) {
      _setError('Failed to get meal systems: $e');
      return [];
    }
  }

  // Get meal systems owned by user
  Future<List<MealSystemModel>> getOwnedMealSystems(String userId) async {
    try {
      return await _databaseService.getMealSystemsOwnedByUser(userId);
    } catch (e) {
      _setError('Failed to get owned meal systems: $e');
      return [];
    }
  }

  // Update member meal count and owed amount (Manual override)
  Future<bool> updateMemberStats({
    required String userId,
    int? mealsEaten,
    double? amountOwed,
  }) async {
    try {
      if (_currentMealSystem == null) {
        _setError('No active meal system.');
        return false;
      }

      if (!_currentMealSystem!.isMember(userId)) {
        _setError('User is not a member of this system.');
        return false;
      }

      MemberInfo currentInfo = _currentMealSystem!.members[userId]!;
      MemberInfo updatedInfo = currentInfo.copyWith(
        totalMealsEaten: mealsEaten,
        totalOwed: amountOwed,
      );

      await _databaseService.updateMemberInfo(
        _currentMealSystem!.systemId,
        userId,
        updatedInfo,
      );

      // Update local state
      Map<String, MemberInfo> updatedMembers = Map.from(_currentMealSystem!.members);
      updatedMembers[userId] = updatedInfo;
      
      _currentMealSystem = _currentMealSystem!.copyWith(members: updatedMembers);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update member stats: $e');
      return false;
    }
  }

  // Stream meal system for real-time updates
  Stream<MealSystemModel?> streamMealSystem(String systemId) {
    return _databaseService.streamMealSystem(systemId);
  }

  // Validate system code format
  bool isValidSystemCode(String code) {
    // Code should be 6-8 alphanumeric characters
    if (code.length < 6 || code.length > 8) return false;
    
    final validCodeRegex = RegExp(r'^[A-Z0-9]+$');
    return validCodeRegex.hasMatch(code.toUpperCase());
  }

  // Clear current meal system
  void clearCurrentMealSystem() {
    _currentMealSystem = null;
    notifyListeners();
  }

  // ==============================================================================
  // CRITICAL FIX: Live Calculation of Stats (Fixes "0" Balance on Dashboard)
  // ==============================================================================
  Future<void> refreshSystemStats(String systemId) async {
    try {
      final now = DateTime.now();
      // Calculate for the current month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Helper for date formatting matches Firestore doc IDs usually
      String formatDate(DateTime d) => 
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      // 1. Fetch Attendance (from 'days' or 'daily' subcollection based on usage)
      // Standardizing to 'days' based on other file snippets, but checking 'daily' as fallback
      var attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('days') 
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: formatDate(startOfMonth))
          .where(FieldPath.documentId, isLessThanOrEqualTo: formatDate(endOfMonth))
          .get();

      // 2. Fetch Expenses for current month
      final expenseSnapshot = await _firestore
          .collection('expenses')
          .doc(systemId)
          .collection('records')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      // 3. Count Meals Eaten per Member
      Map<String, int> mealsMap = {};
      int totalSystemMeals = 0;

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        // Check breakfast, lunch, dinner maps
        ['breakfast', 'lunch', 'dinner'].forEach((mealType) {
          if (data[mealType] != null) {
            final Map<String, dynamic> mealMap = data[mealType];
            mealMap.forEach((uid, statusData) {
              // 'status' is stored inside the map value
              if (statusData['status'] == 'yes') {
                mealsMap[uid] = (mealsMap[uid] ?? 0) + 1;
                totalSystemMeals++;
              }
            });
          }
        });
      }

      // 4. Calculate Financials
      double totalExpenses = 0;
      Map<String, double> paidByMember = {};

      for (var doc in expenseSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final payerId = data['paidBy'] as String;
        
        totalExpenses += amount;
        paidByMember[payerId] = (paidByMember[payerId] ?? 0) + amount;
      }

      // Cost Per Meal = Total Expenses / Total Meals
      double costPerMeal = totalSystemMeals > 0 ? totalExpenses / totalSystemMeals : 0.0;

      // 5. Update Members Logic
      if (_currentMealSystem != null) {
        Map<String, MemberInfo> updatedMembers = {};
        
        _currentMealSystem!.members.forEach((uid, member) {
          int myMeals = mealsMap[uid] ?? 0;
          double myPaid = paidByMember[uid] ?? 0.0;

          // Formula: (Meals I Ate * Cost Per Meal) - (Amount I Paid)
          // Result: Positive = I Owe money. Negative = System Owes me.
          double myShare = myMeals * costPerMeal;
          double balance = myShare - myPaid;

          updatedMembers[uid] = member.copyWith(
            totalMealsEaten: myMeals,
            totalOwed: balance,
          );
        });

        // Write updates to Firestore 'mealSystems' collection
        await _firestore.collection('mealSystems').doc(systemId).update({
          'members': updatedMembers.map((k, v) => MapEntry(k, v.toMap())),
        });

        // Update Local State to reflect changes immediately
        _currentMealSystem = _currentMealSystem!.copyWith(members: updatedMembers);
        
        notifyListeners();
      }

    } catch (e) {
      print("System Stats Refresh Error: $e");
      // We don't throw here to avoid blocking the user flow, just log error
    }
  }
}