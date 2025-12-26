import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/meal_system_model.dart';
import '../models/daily_meal_model.dart'; // <--- ADDED THIS IMPORT TO FIX ERRORS

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  String get usersCollection => 'users';
  String get mealSystemsCollection => 'mealSystems';

  // ==================== USER OPERATIONS ====================

  // Create a new user document
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(user.userId)
          .set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update user document
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(user.userId)
          .update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete user document
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromDocument(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }

  // ==================== MEAL SYSTEM OPERATIONS ====================

  // Create a new meal system
  Future<void> createMealSystem(MealSystemModel mealSystem) async {
    try {
      await _firestore
          .collection(mealSystemsCollection)
          .doc(mealSystem.systemId)
          .set(mealSystem.toMap());
    } catch (e) {
      throw Exception('Failed to create meal system: $e');
    }
  }

  // Get meal system by ID
  Future<MealSystemModel?> getMealSystemById(String systemId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(mealSystemsCollection)
          .doc(systemId)
          .get();

      if (doc.exists) {
        return MealSystemModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get meal system: $e');
    }
  }

  // Get meal system by code
  Future<MealSystemModel?> getMealSystemByCode(String code) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(mealSystemsCollection)
          .where('systemCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return MealSystemModel.fromDocument(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get meal system by code: $e');
    }
  }

  // Update meal system
  Future<void> updateMealSystem(MealSystemModel mealSystem) async {
    try {
      await _firestore
          .collection(mealSystemsCollection)
          .doc(mealSystem.systemId)
          .update(mealSystem.toMap());
    } catch (e) {
      throw Exception('Failed to update meal system: $e');
    }
  }

  // Delete meal system
  Future<void> deleteMealSystem(String systemId) async {
    try {
      await _firestore
          .collection(mealSystemsCollection)
          .doc(systemId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete meal system: $e');
    }
  }

  // Add member to meal system
  Future<void> addMemberToSystem(
    String systemId,
    String userId,
    MemberInfo memberInfo,
  ) async {
    try {
      await _firestore
          .collection(mealSystemsCollection)
          .doc(systemId)
          .update({
        'members.$userId': memberInfo.toMap(),
      });
    } catch (e) {
      throw Exception('Failed to add member to system: $e');
    }
  }

  // Remove member from meal system
  Future<void> removeMemberFromSystem(String systemId, String userId) async {
    try {
      await _firestore
          .collection(mealSystemsCollection)
          .doc(systemId)
          .update({
        'members.$userId': FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Failed to remove member from system: $e');
    }
  }

  // Update member info in meal system
  Future<void> updateMemberInfo(
    String systemId,
    String userId,
    MemberInfo memberInfo,
  ) async {
    try {
      await _firestore
          .collection(mealSystemsCollection)
          .doc(systemId)
          .update({
        'members.$userId': memberInfo.toMap(),
      });
    } catch (e) {
      throw Exception('Failed to update member info: $e');
    }
  }

  // Get all meal systems for a user (where user is a member)
  Future<List<MealSystemModel>> getMealSystemsForUser(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(mealSystemsCollection)
          .where('members.$userId', isNotEqualTo: null)
          .get();

      return querySnapshot.docs
          .map((doc) => MealSystemModel.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get meal systems for user: $e');
    }
  }

  // Get meal systems owned by user
  Future<List<MealSystemModel>> getMealSystemsOwnedByUser(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(mealSystemsCollection)
          .where('ownerId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => MealSystemModel.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get owned meal systems: $e');
    }
  }

  // Check if system code exists
  Future<bool> systemCodeExists(String code) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(mealSystemsCollection)
          .where('systemCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check system code: $e');
    }
  }

  // Stream meal system (for real-time updates)
  Stream<MealSystemModel?> streamMealSystem(String systemId) {
    return _firestore
        .collection(mealSystemsCollection)
        .doc(systemId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return MealSystemModel.fromDocument(doc);
      }
      return null;
    });
  }

  // Stream user (for real-time updates)
  Stream<UserModel?> streamUser(String userId) {
    return _firestore
        .collection(usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromDocument(doc);
      }
      return null;
    });
  }

  // ==================== UTILITY METHODS ====================

  // Batch update (for efficiency)
  Future<void> batchUpdate(List<Map<String, dynamic>> updates) async {
    try {
      WriteBatch batch = _firestore.batch();

      for (var update in updates) {
        DocumentReference docRef = _firestore
            .collection(update['collection'])
            .doc(update['docId']);
        batch.update(docRef, update['data']);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to perform batch update: $e');
    }
  }

  // Transaction update (for atomic operations)
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    try {
      return await _firestore.runTransaction(updateFunction);
    } catch (e) {
      throw Exception('Failed to run transaction: $e');
    }
  }


  // ==================== CALENDAR OPERATIONS ====================

  String get mealCalendarCollection => 'mealCalendar';

  // Stream meals for specific dates
  Stream<List<DailyMealModel>> streamWeeklyMeals(String systemId, List<String> dates) {
    return _firestore
        .collection(mealCalendarCollection)
        .doc(systemId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return [];
      
      final data = doc.data()!;
      List<DailyMealModel> meals = [];
      
      for (String date in dates) {
        if (data.containsKey(date)) {
          meals.add(DailyMealModel.fromMap(date, data[date]));
        } else {
          // Return empty model if date doesn't exist yet
          meals.add(DailyMealModel(
            date: date, 
            breakfast: MealSlot(), 
            lunch: MealSlot(), 
            dinner: MealSlot()
          ));
        }
      }
      return meals;
    });
  }

  // Volunteer to cook
  Future<void> volunteerToCook({
    required String systemId,
    required String date,
    required String mealType,
    required String cookId,
    required String cookName,
    String? menu,
  }) async {
    try {
      await _firestore.collection(mealCalendarCollection).doc(systemId).set({
        date: {
          mealType: {
            'cookId': cookId,
            'cookName': cookName,
            'menu': menu ?? 'TBD',
            'attendees': 0,
          },
          'lastUpdated': FieldValue.serverTimestamp(), 
        }
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to volunteer: $e');
    }
  }
}