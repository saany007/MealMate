import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_trip_model.dart';
import '../models/meal_system_model.dart';

class ShoppingTripService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  List<ShoppingTripModel> _trips = [];
  Map<String, ShoppingRotationTracker> _rotationTrackers = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<ShoppingTripModel> get trips => _trips;
  Map<String, ShoppingRotationTracker> get rotationTrackers => _rotationTrackers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get pending trips
  List<ShoppingTripModel> get pendingTrips =>
      _trips.where((t) => t.isPending).toList();

  // Get in-progress trips
  List<ShoppingTripModel> get inProgressTrips =>
      _trips.where((t) => t.isInProgress).toList();

  // Get completed trips
  List<ShoppingTripModel> get completedTrips =>
      _trips.where((t) => t.isCompleted).toList();

  // Get trips needing reimbursement
  List<ShoppingTripModel> get tripsNeedingReimbursement =>
      _trips.where((t) => t.needsReimbursement).toList();

  // ==================== LOAD SHOPPING TRIPS ====================

  Future<void> loadShoppingTrips(String systemId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final QuerySnapshot snapshot = await _firestore
          .collection('shoppingTrips')
          .doc(systemId)
          .collection('trips')
          .orderBy('assignedDate', descending: true)
          .limit(50)
          .get();

      _trips = snapshot.docs
          .map((doc) => ShoppingTripModel.fromDocument(doc))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load shopping trips: ${e.toString()}';
      notifyListeners();
    }
  }

  // ==================== LOAD ROTATION TRACKERS ====================

  Future<void> loadRotationTrackers(String systemId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('shoppingRotation')
          .doc(systemId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _rotationTrackers = data.map(
          (key, value) => MapEntry(
            key,
            ShoppingRotationTracker.fromMap(value as Map<String, dynamic>),
          ),
        );
      } else {
        _rotationTrackers = {};
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load rotation trackers: ${e.toString()}';
      notifyListeners();
    }
  }

  // ==================== CREATE SHOPPING TRIP ====================

  Future<ShoppingTripModel?> createShoppingTrip({
    required String systemId,
    required String assignedTo,
    required String assignedToName,
    String? groceryListId,
    String? notes,
  }) async {
    try {
      final tripId = _uuid.v4();
      final now = DateTime.now();

      final trip = ShoppingTripModel(
        tripId: tripId,
        systemId: systemId,
        assignedTo: assignedTo,
        assignedToName: assignedToName,
        assignedDate: now,
        status: ShoppingTripStatus.pending,
        groceryListId: groceryListId,
        notes: notes,
        createdAt: now,
      );

      await _firestore
          .collection('shoppingTrips')
          .doc(systemId)
          .collection('trips')
          .doc(tripId)
          .set(trip.toMap());

      _trips.insert(0, trip);
      notifyListeners();

      return trip;
    } catch (e) {
      _errorMessage = 'Failed to create shopping trip: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // ==================== UPDATE SHOPPING TRIP ====================

  Future<bool> updateShoppingTrip({
    required String systemId,
    required String tripId,
    String? status,
    double? totalSpent,
    String? receiptURL,
    List<String>? itemsPurchased,
    String? reimbursementStatus,
    String? notes,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (status != null) {
        updates['status'] = status;
        if (status == ShoppingTripStatus.completed) {
          updates['completedDate'] = Timestamp.now();
        }
      }
      if (totalSpent != null) updates['totalSpent'] = totalSpent;
      if (receiptURL != null) updates['receiptURL'] = receiptURL;
      if (itemsPurchased != null) updates['itemsPurchased'] = itemsPurchased;
      if (reimbursementStatus != null) {
        updates['reimbursementStatus'] = reimbursementStatus;
      }
      if (notes != null) updates['notes'] = notes;

      await _firestore
          .collection('shoppingTrips')
          .doc(systemId)
          .collection('trips')
          .doc(tripId)
          .update(updates);

      // Update local list
      final index = _trips.indexWhere((t) => t.tripId == tripId);
      if (index != -1) {
        final oldTrip = _trips[index];
        _trips[index] = oldTrip.copyWith(
          status: status,
          totalSpent: totalSpent,
          receiptURL: receiptURL,
          itemsPurchased: itemsPurchased,
          reimbursementStatus: reimbursementStatus,
          notes: notes,
          completedDate: status == ShoppingTripStatus.completed 
              ? DateTime.now() 
              : oldTrip.completedDate,
        );

        // If trip is completed, update rotation tracker
        if (status == ShoppingTripStatus.completed) {
          await _updateRotationTracker(
            systemId: systemId,
            userId: oldTrip.assignedTo,
            userName: oldTrip.assignedToName,
            spent: totalSpent ?? oldTrip.totalSpent,
          );
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update shopping trip: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== DELETE SHOPPING TRIP ====================

  Future<bool> deleteShoppingTrip(String systemId, String tripId) async {
    try {
      await _firestore
          .collection('shoppingTrips')
          .doc(systemId)
          .collection('trips')
          .doc(tripId)
          .delete();

      _trips.removeWhere((t) => t.tripId == tripId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete shopping trip: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== AUTO-ASSIGN NEXT SHOPPER ====================

  Future<String?> autoAssignNextShopper({
    required String systemId,
    required MealSystemModel mealSystem,
  }) async {
    try {
      // Load rotation trackers if not loaded
      if (_rotationTrackers.isEmpty) {
        await loadRotationTrackers(systemId);
      }

      // Initialize trackers for members who don't have one
      for (var entry in mealSystem.members.entries) {
        if (!_rotationTrackers.containsKey(entry.key)) {
          _rotationTrackers[entry.key] = ShoppingRotationTracker(
            userId: entry.key,
            userName: entry.value.name,
          );
        }
      }

      // Find member with lowest trip count (fairness algorithm)
      String? nextShopperId;
      int minTrips = 999999;

      for (var entry in _rotationTrackers.entries) {
        // Check if user is still a member
        if (mealSystem.members.containsKey(entry.key)) {
          if (entry.value.totalTripsCompleted < minTrips) {
            minTrips = entry.value.totalTripsCompleted;
            nextShopperId = entry.key;
          }
        }
      }

      return nextShopperId;
    } catch (e) {
      _errorMessage = 'Failed to assign next shopper: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // ==================== UPDATE ROTATION TRACKER ====================

  Future<void> _updateRotationTracker({
    required String systemId,
    required String userId,
    required String userName,
    required double spent,
  }) async {
    try {
      final tracker = _rotationTrackers[userId] ?? ShoppingRotationTracker(
        userId: userId,
        userName: userName,
      );

      final updatedTracker = ShoppingRotationTracker(
        userId: userId,
        userName: userName,
        totalTripsCompleted: tracker.totalTripsCompleted + 1,
        lastShoppingDate: DateTime.now(),
        totalSpent: tracker.totalSpent + spent,
        preferredDays: tracker.preferredDays,
      );

      await _firestore
          .collection('shoppingRotation')
          .doc(systemId)
          .set({
        userId: updatedTracker.toMap(),
      }, SetOptions(merge: true));

      _rotationTrackers[userId] = updatedTracker;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update rotation tracker: ${e.toString()}';
    }
  }

  // ==================== UPDATE PREFERRED DAYS ====================

  Future<bool> updatePreferredDays({
    required String systemId,
    required String userId,
    required String userName,
    required List<String> preferredDays,
  }) async {
    try {
      final tracker = _rotationTrackers[userId] ?? ShoppingRotationTracker(
        userId: userId,
        userName: userName,
      );

      final updatedTracker = ShoppingRotationTracker(
        userId: userId,
        userName: userName,
        totalTripsCompleted: tracker.totalTripsCompleted,
        lastShoppingDate: tracker.lastShoppingDate,
        totalSpent: tracker.totalSpent,
        preferredDays: preferredDays,
      );

      await _firestore
          .collection('shoppingRotation')
          .doc(systemId)
          .set({
        userId: updatedTracker.toMap(),
      }, SetOptions(merge: true));

      _rotationTrackers[userId] = updatedTracker;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update preferred days: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== STREAM SHOPPING TRIPS ====================

  Stream<List<ShoppingTripModel>> streamShoppingTrips(String systemId) {
    return _firestore
        .collection('shoppingTrips')
        .doc(systemId)
        .collection('trips')
        .orderBy('assignedDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShoppingTripModel.fromDocument(doc))
          .toList();
    });
  }

  // ==================== GET SHOPPING SUMMARY ====================

  ShoppingTripSummary getShoppingTripSummary() {
    final totalTrips = _trips.length;
    final completedTrips = _trips.where((t) => t.isCompleted).length;
    final pendingTrips = _trips.where((t) => t.isPending).length;
    final totalSpent = _trips.fold<double>(
      0.0,
      (sum, trip) => sum + trip.totalSpent,
    );
    final averageSpent = completedTrips > 0 ? totalSpent / completedTrips : 0.0;

    final Map<String, int> tripsByMember = {};
    for (var trip in _trips) {
      tripsByMember[trip.assignedToName] = 
          (tripsByMember[trip.assignedToName] ?? 0) + 1;
    }

    return ShoppingTripSummary(
      totalTrips: totalTrips,
      completedTrips: completedTrips,
      pendingTrips: pendingTrips,
      totalSpent: totalSpent,
      averageSpentPerTrip: averageSpent,
      tripsByMember: tripsByMember,
    );
  }

  // ==================== CLEAR DATA ====================

  void clearData() {
    _trips = [];
    _rotationTrackers = {};
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}