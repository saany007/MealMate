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

  // Collection Reference Helper
  CollectionReference _getTripsCollection(String systemId) {
    return _firestore
        .collection('shoppingTrips')
        .doc(systemId)
        .collection('trips');
  }

  // ==================== GETTERS ====================

  List<ShoppingTripModel> get trips => _trips;
  Map<String, ShoppingRotationTracker> get rotationTrackers => _rotationTrackers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Filtered Lists
  List<ShoppingTripModel> get pendingTrips =>
      _trips.where((t) => t.status == 'pending').toList();

  List<ShoppingTripModel> get inProgressTrips =>
      _trips.where((t) => t.status == 'in_progress').toList();

  List<ShoppingTripModel> get completedTrips =>
      _trips.where((t) => t.status == 'completed').toList();

  List<ShoppingTripModel> get tripsNeedingReimbursement => _trips
      .where((t) =>
          t.status == 'completed' && t.reimbursementStatus == 'pending')
      .toList();

  // ==================== STATE HELPERS ====================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
    if (message != null) {
      debugPrint("ShoppingTripService Error: $message");
    }
  }

  // ==================== CORE METHODS ====================

  Future<void> loadShoppingTrips(String systemId) async {
    try {
      _setLoading(true);
      _setError(null);

      final snapshot = await _getTripsCollection(systemId)
          .orderBy('assignedDate', descending: true)
          .get();

      _trips = snapshot.docs
          .map((doc) => ShoppingTripModel.fromDocument(doc))
          .toList();

      _calculateRotationStats();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load trips: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createShoppingTrip({
    required String systemId,
    required String assignedTo,
    required String assignedToName,
    String? notes,
    String? groceryListId,
  }) async {
    try {
      _setLoading(true);
      final tripId = _uuid.v4();
      final now = DateTime.now();

      final trip = ShoppingTripModel(
        tripId: tripId,
        systemId: systemId,
        assignedTo: assignedTo,
        assignedToName: assignedToName,
        assignedDate: now,
        status: 'pending',
        createdAt: now,
        notes: notes,
        groceryListId: groceryListId,
        totalSpent: 0.0,
        reimbursementStatus: 'not_applicable',
      );

      await _getTripsCollection(systemId).doc(tripId).set(trip.toMap());

      _trips.insert(0, trip);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to create trip: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- UPDATE TRIP ---
  Future<bool> updateTrip({
    required String systemId,
    required String tripId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      _setLoading(true);

      // 1. Update Firestore
      await _getTripsCollection(systemId).doc(tripId).update(updates);

      // 2. Update Local State Manually
      final index = _trips.indexWhere((t) => t.tripId == tripId);
      if (index != -1) {
        final oldTrip = _trips[index];
        Map<String, dynamic> mergedData = oldTrip.toMap();
        
        updates.forEach((key, value) {
          if (value is DateTime) {
            mergedData[key] = Timestamp.fromDate(value);
          } else {
            mergedData[key] = value;
          }
        });

        _trips[index] = ShoppingTripModel.fromMap(mergedData);
        _calculateRotationStats();
        notifyListeners(); 
      } else {
        await loadShoppingTrips(systemId);
      }

      return true;
    } catch (e) {
      _setError('Failed to update trip: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- COMPLETE TRIP ---
  Future<bool> completeTrip({
    required String systemId,
    required String tripId,
    required double totalSpent,
    List<String>? itemsPurchased, 
  }) async {
    final updates = {
      'status': 'completed',
      'completedDate': DateTime.now(),
      'totalSpent': totalSpent,
      'reimbursementStatus': totalSpent > 0 ? 'pending' : 'not_applicable',
    };

    if (itemsPurchased != null) {
      updates['itemsPurchased'] = itemsPurchased;
    }

    return await updateTrip(
      systemId: systemId,
      tripId: tripId,
      updates: updates,
    );
  }

  Future<bool> deleteTrip(String systemId, String tripId) async {
    try {
      _setLoading(true);
      await _getTripsCollection(systemId).doc(tripId).delete();
      _trips.removeWhere((t) => t.tripId == tripId);
      _calculateRotationStats();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- STATS ---
  void _calculateRotationStats() {
    _rotationTrackers.clear();
    if (_trips.isEmpty) return;

    for (var trip in _trips) {
      if (trip.status != 'completed') continue;

      final userId = trip.assignedTo;
      if (!_rotationTrackers.containsKey(userId)) {
        _rotationTrackers[userId] = ShoppingRotationTracker(
          userId: userId,
          userName: trip.assignedToName,
        );
      }

      final current = _rotationTrackers[userId]!;
      _rotationTrackers[userId] = ShoppingRotationTracker(
        userId: userId,
        userName: current.userName,
        totalTripsCompleted: current.totalTripsCompleted + 1,
        totalSpent: current.totalSpent + trip.totalSpent,
      );
    }
  }
}