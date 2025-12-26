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
    _isLoading = value;
    notifyListeners();
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

  // Mark attendance for a meal
  Future<bool> markAttendance({
    required String systemId,
    required String date,
    required String mealType,
    required String userId,
    required String userName,
    required String status,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final attendance = MealAttendance(
        userId: userId,
        userName: userName,
        status: status,
        checkedAt: DateTime.now(),
      );

      await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('daily')
          .doc(date)
          .set({
        '$mealType.$userId': attendance.toMap(),
      }, SetOptions(merge: true));

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to mark attendance: $e');
      return false;
    }
  }

  // Get attendance for a specific date
  Future<AttendanceModel?> getAttendanceForDate({
    required String systemId,
    required String date,
  }) async {
    try {
      final doc = await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('daily')
          .doc(date)
          .get();

      if (doc.exists) {
        return AttendanceModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      _setError('Failed to get attendance: $e');
      return null;
    }
  }

  // Stream attendance for a specific date
  Stream<AttendanceModel?> streamAttendanceForDate({
    required String systemId,
    required String date,
  }) {
    return _firestore
        .collection('attendance')
        .doc(systemId)
        .collection('daily')
        .doc(date)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return AttendanceModel.fromDocument(doc);
      }
      return null;
    });
  }

  // Get attendance for a date range
  Future<List<AttendanceModel>> getAttendanceRange({
    required String systemId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      final querySnapshot = await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('daily')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
          .get();

      return querySnapshot.docs
          .map((doc) => AttendanceModel.fromDocument(doc))
          .toList();
    } catch (e) {
      _setError('Failed to get attendance range: $e');
      return [];
    }
  }

  // Get user's attendance summary for a month
  Future<UserAttendanceSummary?> getUserMonthlySummary({
    required String systemId,
    required String userId,
    required DateTime month,
  }) async {
    try {
      // Get first and last day of month
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      final attendanceList = await getAttendanceRange(
        systemId: systemId,
        startDate: firstDay,
        endDate: lastDay,
      );

      int totalEaten = 0;
      int totalSkipped = 0;
      int totalMaybe = 0;

      for (var attendance in attendanceList) {
        // Check breakfast
        final breakfastStatus = attendance.breakfast[userId]?.status;
        if (breakfastStatus == AttendanceStatus.yes) totalEaten++;
        if (breakfastStatus == AttendanceStatus.no) totalSkipped++;
        if (breakfastStatus == AttendanceStatus.maybe) totalMaybe++;

        // Check lunch
        final lunchStatus = attendance.lunch[userId]?.status;
        if (lunchStatus == AttendanceStatus.yes) totalEaten++;
        if (lunchStatus == AttendanceStatus.no) totalSkipped++;
        if (lunchStatus == AttendanceStatus.maybe) totalMaybe++;

        // Check dinner
        final dinnerStatus = attendance.dinner[userId]?.status;
        if (dinnerStatus == AttendanceStatus.yes) totalEaten++;
        if (dinnerStatus == AttendanceStatus.no) totalSkipped++;
        if (dinnerStatus == AttendanceStatus.maybe) totalMaybe++;
      }

      final totalCheckins = totalEaten + totalSkipped + totalMaybe;
      final attendanceRate = totalCheckins > 0 
          ? (totalEaten / totalCheckins) * 100 
          : 0.0;

      // Get user name (you might need to fetch this from user service)
      return UserAttendanceSummary(
        userId: userId,
        userName: 'User', // You should fetch this from the user model
        totalMealsEaten: totalEaten,
        totalMealsSkipped: totalSkipped,
        totalMealsMaybe: totalMaybe,
        attendanceRate: attendanceRate,
      );
    } catch (e) {
      _setError('Failed to get user summary: $e');
      return null;
    }
  }

  // Get today's attendance status for a user
  Future<Map<String, String?>> getTodayUserStatus({
    required String systemId,
    required String userId,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendance = await getAttendanceForDate(
        systemId: systemId,
        date: today,
      );

      if (attendance == null) {
        return {
          'breakfast': null,
          'lunch': null,
          'dinner': null,
        };
      }

      return {
        'breakfast': attendance.breakfast[userId]?.status,
        'lunch': attendance.lunch[userId]?.status,
        'dinner': attendance.dinner[userId]?.status,
      };
    } catch (e) {
      _setError('Failed to get today\'s status: $e');
      return {
        'breakfast': null,
        'lunch': null,
        'dinner': null,
      };
    }
  }

  // Quick check-in for all meals (set default as "yes")
  Future<bool> quickCheckInAllMeals({
    required String systemId,
    required String userId,
    required String userName,
    String status = AttendanceStatus.yes,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final attendance = MealAttendance(
        userId: userId,
        userName: userName,
        status: status,
        checkedAt: DateTime.now(),
      );

      await _firestore
          .collection('attendance')
          .doc(systemId)
          .collection('daily')
          .doc(today)
          .set({
        'breakfast.$userId': attendance.toMap(),
        'lunch.$userId': attendance.toMap(),
        'dinner.$userId': attendance.toMap(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      _setError('Failed to quick check-in: $e');
      return false;
    }
  }

  // Get all members' attendance for today
  Future<Map<String, Map<String, String>>> getTodayAllMembersStatus({
    required String systemId,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendance = await getAttendanceForDate(
        systemId: systemId,
        date: today,
      );

      if (attendance == null) return {};

      final Map<String, Map<String, String>> allStatus = {};

      // Collect all unique user IDs
      final allUserIds = <String>{};
      allUserIds.addAll(attendance.breakfast.keys);
      allUserIds.addAll(attendance.lunch.keys);
      allUserIds.addAll(attendance.dinner.keys);

      for (var userId in allUserIds) {
        allStatus[userId] = {
          'breakfast': attendance.breakfast[userId]?.status ?? AttendanceStatus.yes,
          'lunch': attendance.lunch[userId]?.status ?? AttendanceStatus.yes,
          'dinner': attendance.dinner[userId]?.status ?? AttendanceStatus.yes,
        };
      }

      return allStatus;
    } catch (e) {
      _setError('Failed to get all members status: $e');
      return {};
    }
  }

  // Count today's attendees for a specific meal
  Future<int> getTodayMealAttendeeCount({
    required String systemId,
    required String mealType,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendance = await getAttendanceForDate(
        systemId: systemId,
        date: today,
      );

      if (attendance == null) return 0;
      return attendance.countAttendees(mealType);
    } catch (e) {
      return 0;
    }
  }

  // Check if user has checked in today
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

  // Get attendance statistics for the system
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
        totalMealsServed += 3; // breakfast, lunch, dinner
        totalAttendees += attendance.totalDayAttendees;
      }

      final avgAttendeesPerMeal = totalMealsServed > 0 
          ? totalAttendees / totalMealsServed 
          : 0.0;

      return {
        'totalDays': attendanceList.length,
        'totalMealsServed': totalMealsServed,
        'totalAttendees': totalAttendees,
        'avgAttendeesPerMeal': avgAttendeesPerMeal,
      };
    } catch (e) {
      _setError('Failed to get system stats: $e');
      return {};
    }
  }
}