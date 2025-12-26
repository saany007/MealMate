import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String? photoURL;
  final List<String> dietaryPreferences;
  final DateTime dateJoined;
  final String? currentMealSystemId;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    this.photoURL,
    required this.dietaryPreferences,
    required this.dateJoined,
    this.currentMealSystemId,
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'photoURL': photoURL,
      'dietaryPreferences': dietaryPreferences,
      'dateJoined': Timestamp.fromDate(dateJoined),
      'currentMealSystemId': currentMealSystemId,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoURL: map['photoURL'],
      dietaryPreferences: List<String>.from(map['dietaryPreferences'] ?? []),
      dateJoined: (map['dateJoined'] as Timestamp).toDate(),
      currentMealSystemId: map['currentMealSystemId'],
    );
  }

  // Create UserModel from Firestore DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data);
  }

  // Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? photoURL,
    List<String>? dietaryPreferences,
    DateTime? dateJoined,
    String? currentMealSystemId,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoURL: photoURL ?? this.photoURL,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      dateJoined: dateJoined ?? this.dateJoined,
      currentMealSystemId: currentMealSystemId ?? this.currentMealSystemId,
    );
  }

  @override
  String toString() {
    return 'UserModel(userId: $userId, name: $name, email: $email, phone: $phone)';
  }
}