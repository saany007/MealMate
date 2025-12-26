import 'package:cloud_firestore/cloud_firestore.dart';

class DailyMealModel {
  final String date;
  final MealSlot breakfast;
  final MealSlot lunch;
  final MealSlot dinner;
  final DateTime? lastUpdated; 

  DailyMealModel({
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    this.lastUpdated,
  });

  factory DailyMealModel.fromMap(String date, Map<String, dynamic> map) {
    return DailyMealModel(
      date: date,
      breakfast: MealSlot.fromMap(map['breakfast'] ?? {}),
      lunch: MealSlot.fromMap(map['lunch'] ?? {}),
      dinner: MealSlot.fromMap(map['dinner'] ?? {}),
      // Convert Firestore Timestamp to DateTime
      lastUpdated: map['lastUpdated'] != null 
          ? (map['lastUpdated'] as Timestamp).toDate() 
          : null,
    );
  }
}

class MealSlot {
  final String? cookId;
  final String? cookName;
  final int attendees;
  final String? menu;

  MealSlot({
    this.cookId,
    this.cookName,
    this.attendees = 0,
    this.menu,
  });

  factory MealSlot.fromMap(Map<String, dynamic> map) {
    return MealSlot(
      cookId: map['cookId'],
      cookName: map['cookName'],
      attendees: map['attendees'] ?? 0,
      menu: map['menu'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cookId': cookId,
      'cookName': cookName,
      'attendees': attendees,
      'menu': menu,
    };
  }
}