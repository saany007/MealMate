import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';

class AttendanceService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
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

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== CORE ATTENDANCE LOGIC ====================

  /// Mark attendance for a meal.
  /// Uses a Transaction to update both the user's status AND the global attendee counter atomically.
  Future<bool> markAttendance({
    required String systemId,
    required String date,
    required String mealType,
    required String userId,
    required String userName,
    required String status, // 'yes', 'no', 'maybe'
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // References
      final attendanceDocRef = _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('days')
          .doc(date);
          
      final mealCalendarDocRef = _firestore
          .collection('mealCalendar')
          .doc(systemId)
          .collection('days')
          .doc(date);

      await _firestore.runTransaction((transaction) async {
        // 1. Read current state to calculate delta (change in count)
        final attendanceSnapshot = await transaction.get(attendanceDocRef);
        
        String? oldStatus;
        if (attendanceSnapshot.exists && attendanceSnapshot.data() != null) {
          final data = attendanceSnapshot.data() as Map<String, dynamic>;
          if (data[mealType] != null && data[mealType][userId] != null) {
            oldStatus = data[mealType][userId]['status'];
          }
        }

        // 2. Calculate Counter Delta
        int delta = 0;
        final bool wasYes = (oldStatus == AttendanceStatus.yes);
        final bool isYes = (status == AttendanceStatus.yes);

        if (!wasYes && isYes) delta = 1;      // Changed TO 'yes'
        if (wasYes && !isYes) delta = -1;     // Changed FROM 'yes'

        // 3. Prepare MealAttendance Data
        final mealAttendanceData = {
          'userId': userId,
          'userName': userName,
          'status': status,
          'checkedAt': Timestamp.now(),
        };

        // 4. Update Attendance Document (Records WHO is eating)
        transaction.set(attendanceDocRef, {
          mealType: { userId: mealAttendanceData }
        }, SetOptions(merge: true));

        // 5. Update Meal Calendar Counter (Records TOTAL count)
        // Only update if the count actually changed
        if (delta != 0) {
          transaction.set(mealCalendarDocRef, {
            mealType: { 
              'attendees': FieldValue.increment(delta) 
            }
          }, SetOptions(merge: true));
        }
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to mark attendance: $e');
      return false;
    }
  }

  // ==================== REAL-TIME STREAMS ====================

  /// Stream to listen to the current user's status updates instantly.
  Stream<Map<String, String?>> streamUserAttendance({
    required String systemId,
    required String userId,
    required String date,
  }) {
    return _firestore
        .collection('attendance')
        .doc(systemId)
        .collection('days')
        .doc(date)
        .snapshots()
        .map((doc) {
          // FIX: Explicitly type the map to allow Strings, otherwise Dart infers Map<String, Null>
          final Map<String, String?> result = {
            'breakfast': null, 
            'lunch': null, 
            'dinner': null
          };
          
          if (!doc.exists || doc.data() == null) return result;

          final data = doc.data()!;
          for (var meal in ['breakfast', 'lunch', 'dinner']) {
            if (data[meal] != null && data[meal][userId] != null) {
              result[meal] = data[meal][userId]['status'] as String?;
            }
          }
          return result;
        });
  }

  // ==================== STATISTICS & HELPERS ====================

  /// Check if user has checked in for any meal today
  Future<bool> hasCheckedInToday({
    required String systemId,
    required String userId,
  }) async {
    try {
      final statuses = await getTodayUserStatus(
        systemId: systemId,
        userId: userId,
      );
      return statuses.values.any((status) => status != null);
    } catch (e) {
      return false;
    }
  }

  /// Get single day status for a user (One-time fetch)
  Future<Map<String, String?>> getTodayUserStatus({
    required String systemId,
    required String userId,
  }) async {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    
    try {
      final doc = await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('days')
          .doc(date)
          .get();

      if (!doc.exists || doc.data() == null) {
        return {'breakfast': null, 'lunch': null, 'dinner': null};
      }

      final data = doc.data()!;
      String? getStatus(String meal) {
        if (data[meal] != null && data[meal][userId] != null) {
          return data[meal][userId]['status'];
        }
        return null;
      }

      return {
        'breakfast': getStatus('breakfast'),
        'lunch': getStatus('lunch'),
        'dinner': getStatus('dinner'),
      };
    } catch (e) {
      return {'breakfast': null, 'lunch': null, 'dinner': null};
    }
  }

  /// Get attendance range (Required for Reports/Stats)
  Future<List<AttendanceModel>> getAttendanceRange({
    required String systemId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);

      final snapshot = await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('days')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
          .get();

      return snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error getting attendance range: $e');
      return [];
    }
  }

  /// Get attendance statistics for the whole system
  Future<Map<String, dynamic>> getSystemAttendanceStats({
    required String systemId,
    required DateTime month,
  }) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      final attendanceList = await getAttendanceRange(
        systemId: systemId,
        startDate: firstDay,
        endDate: lastDay,
      );

      int totalMealsServed = 0;
      int totalAttendees = 0;

      for (var attendance in attendanceList) {
        int countYes(Map<String, MealAttendance> map) {
          return map.values.where((m) => m.status == AttendanceStatus.yes).length;
        }

        if (attendance.breakfast.isNotEmpty) {
           totalMealsServed++;
           totalAttendees += countYes(attendance.breakfast);
        }
        if (attendance.lunch.isNotEmpty) {
           totalMealsServed++;
           totalAttendees += countYes(attendance.lunch);
        }
        if (attendance.dinner.isNotEmpty) {
           totalMealsServed++;
           totalAttendees += countYes(attendance.dinner);
        }
      }

      final avgAttendeesPerMeal = totalMealsServed > 0 
          ? totalAttendees / totalMealsServed 
          : 0.0;

      return {
        'totalDays': attendanceList.length,
        'totalMealsServed': totalMealsServed,
        'averageAttendees': avgAttendeesPerMeal,
      };
    } catch (e) {
      return {
        'totalDays': 0,
        'totalMealsServed': 0,
        'averageAttendees': 0.0,
      };
    }
  }

  /// Get User Monthly Summary (History Screen)
  Future<UserAttendanceSummary?> getUserMonthlySummary({
    required String systemId,
    required String userId,
    required DateTime month,
  }) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      final attendanceList = await getAttendanceRange(
        systemId: systemId,
        startDate: firstDay,
        endDate: lastDay,
      );

      int eaten = 0;
      int skipped = 0;
      int maybe = 0;

      for (var day in attendanceList) {
        void checkMeal(Map<String, MealAttendance> mealMap) {
          if (mealMap.containsKey(userId)) {
            final status = mealMap[userId]!.status;
            if (status == AttendanceStatus.yes) eaten++;
            else if (status == AttendanceStatus.no) skipped++;
            else if (status == AttendanceStatus.maybe) maybe++;
          }
        }

        checkMeal(day.breakfast);
        checkMeal(day.lunch);
        checkMeal(day.dinner);
      }

      final total = eaten + skipped + maybe;
      final rate = total > 0 ? (eaten / total) * 100 : 0.0;

      return UserAttendanceSummary(
        userId: userId,
        userName: 'User', 
        totalMealsEaten: eaten,
        totalMealsSkipped: skipped,
        totalMealsMaybe: maybe,
        attendanceRate: rate,
      );
    } catch (e) {
      print('Error getting user summary: $e');
      return null;
    }
  }
}