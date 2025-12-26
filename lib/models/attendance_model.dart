import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String date; // Format: YYYY-MM-DD
  final Map<String, MealAttendance> breakfast;
  final Map<String, MealAttendance> lunch;
  final Map<String, MealAttendance> dinner;

  AttendanceModel({
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'breakfast': breakfast.map((key, value) => MapEntry(key, value.toMap())),
      'lunch': lunch.map((key, value) => MapEntry(key, value.toMap())),
      'dinner': dinner.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  // Create from Map
  factory AttendanceModel.fromMap(String date, Map<String, dynamic> map) {
    Map<String, MealAttendance> parseAttendance(dynamic data) {
      if (data == null) return {};
      return (data as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, MealAttendance.fromMap(value)),
      );
    }

    return AttendanceModel(
      date: date,
      breakfast: parseAttendance(map['breakfast']),
      lunch: parseAttendance(map['lunch']),
      dinner: parseAttendance(map['dinner']),
    );
  }

  // Create from DocumentSnapshot
  factory AttendanceModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel.fromMap(doc.id, data);
  }

  // Get attendance for specific meal
  Map<String, MealAttendance> getAttendanceForMeal(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return breakfast;
      case 'lunch':
        return lunch;
      case 'dinner':
        return dinner;
      default:
        return {};
    }
  }

  // Get user's status for specific meal
  String? getUserStatus(String userId, String mealType) {
    final mealAttendance = getAttendanceForMeal(mealType);
    return mealAttendance[userId]?.status;
  }

  // Count attendees for a meal
  int countAttendees(String mealType) {
    return getAttendanceForMeal(mealType)
        .values
        .where((a) => a.status == AttendanceStatus.yes)
        .length;
  }

  // Count total attendees for the day
  int get totalDayAttendees {
    return countAttendees('breakfast') +
        countAttendees('lunch') +
        countAttendees('dinner');
  }

  @override
  String toString() {
    return 'AttendanceModel(date: $date, breakfast: ${breakfast.length}, lunch: ${lunch.length}, dinner: ${dinner.length})';
  }
}

class MealAttendance {
  final String userId;
  final String userName;
  final String status; // "yes", "no", "maybe"
  final DateTime checkedAt;

  MealAttendance({
    required this.userId,
    required this.userName,
    required this.status,
    required this.checkedAt,
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'status': status,
      'checkedAt': Timestamp.fromDate(checkedAt),
    };
  }

  // Create from Map
  factory MealAttendance.fromMap(Map<String, dynamic> map) {
    return MealAttendance(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      status: map['status'] ?? AttendanceStatus.yes,
      checkedAt: (map['checkedAt'] as Timestamp).toDate(),
    );
  }

  // Copy with updated fields
  MealAttendance copyWith({
    String? userId,
    String? userName,
    String? status,
    DateTime? checkedAt,
  }) {
    return MealAttendance(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }

  @override
  String toString() {
    return 'MealAttendance(user: $userName, status: $status)';
  }
}

// Attendance status constants
class AttendanceStatus {
  static const String yes = 'yes';
  static const String no = 'no';
  static const String maybe = 'maybe';

  static List<String> get all => [yes, no, maybe];

  static String getDisplayName(String status) {
    switch (status) {
      case yes:
        return 'Eating';
      case no:
        return 'Skipping';
      case maybe:
        return 'Maybe';
      default:
        return 'Unknown';
    }
  }

  static String getEmoji(String status) {
    switch (status) {
      case yes:
        return '✅';
      case no:
        return '❌';
      case maybe:
        return '❓';
      default:
        return '⚪';
    }
  }
}

// Monthly attendance summary for a user
class UserAttendanceSummary {
  final String userId;
  final String userName;
  final int totalMealsEaten;
  final int totalMealsSkipped;
  final int totalMealsMaybe;
  final double attendanceRate;

  UserAttendanceSummary({
    required this.userId,
    required this.userName,
    required this.totalMealsEaten,
    required this.totalMealsSkipped,
    required this.totalMealsMaybe,
    required this.attendanceRate,
  });

  int get totalCheckins => totalMealsEaten + totalMealsSkipped + totalMealsMaybe;

  @override
  String toString() {
    return 'UserAttendanceSummary(user: $userName, eaten: $totalMealsEaten, rate: ${attendanceRate.toStringAsFixed(1)}%)';
  }
}