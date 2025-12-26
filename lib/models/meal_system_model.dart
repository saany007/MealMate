import 'package:cloud_firestore/cloud_firestore.dart';

class MealSystemModel {
  final String systemId;
  final String systemName;
  final String systemCode;
  final String ownerId;
  final DateTime createdDate;
  final double monthlyRate;
  final String? location;
  final String? rules;
  final Map<String, MemberInfo> members;

  MealSystemModel({
    required this.systemId,
    required this.systemName,
    required this.systemCode,
    required this.ownerId,
    required this.createdDate,
    required this.monthlyRate,
    this.location,
    this.rules,
    required this.members,
  });

  // Convert MealSystemModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'systemId': systemId,
      'systemName': systemName,
      'systemCode': systemCode,
      'ownerId': ownerId,
      'createdDate': Timestamp.fromDate(createdDate),
      'monthlyRate': monthlyRate,
      'location': location,
      'rules': rules,
      'members': members.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  // Create MealSystemModel from Firestore document
  factory MealSystemModel.fromMap(Map<String, dynamic> map) {
    Map<String, MemberInfo> membersMap = {};
    if (map['members'] != null) {
      (map['members'] as Map<String, dynamic>).forEach((key, value) {
        membersMap[key] = MemberInfo.fromMap(value);
      });
    }

    return MealSystemModel(
      systemId: map['systemId'] ?? '',
      systemName: map['systemName'] ?? '',
      systemCode: map['systemCode'] ?? '',
      ownerId: map['ownerId'] ?? '',
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      monthlyRate: (map['monthlyRate'] ?? 0).toDouble(),
      location: map['location'],
      rules: map['rules'],
      members: membersMap,
    );
  }

  // Create MealSystemModel from Firestore DocumentSnapshot
  factory MealSystemModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealSystemModel.fromMap(data);
  }

  // Create a copy of MealSystemModel with updated fields
  MealSystemModel copyWith({
    String? systemId,
    String? systemName,
    String? systemCode,
    String? ownerId,
    DateTime? createdDate,
    double? monthlyRate,
    String? location,
    String? rules,
    Map<String, MemberInfo>? members,
  }) {
    return MealSystemModel(
      systemId: systemId ?? this.systemId,
      systemName: systemName ?? this.systemName,
      systemCode: systemCode ?? this.systemCode,
      ownerId: ownerId ?? this.ownerId,
      createdDate: createdDate ?? this.createdDate,
      monthlyRate: monthlyRate ?? this.monthlyRate,
      location: location ?? this.location,
      rules: rules ?? this.rules,
      members: members ?? this.members,
    );
  }

  // Get member count
  int get memberCount => members.length;

  // Check if user is owner
  bool isOwner(String userId) => ownerId == userId;

  // Check if user is member
  bool isMember(String userId) => members.containsKey(userId);

  @override
  String toString() {
    return 'MealSystemModel(systemId: $systemId, systemName: $systemName, code: $systemCode, members: ${members.length})';
  }
}

class MemberInfo {
  final String name;
  final String role; // "owner" or "member"
  final DateTime joinedDate;
  final int totalMealsEaten;
  final double totalOwed;

  MemberInfo({
    required this.name,
    required this.role,
    required this.joinedDate,
    this.totalMealsEaten = 0,
    this.totalOwed = 0.0,
  });

  // Convert MemberInfo to Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'totalMealsEaten': totalMealsEaten,
      'totalOwed': totalOwed,
    };
  }

  // Create MemberInfo from Map
  factory MemberInfo.fromMap(Map<String, dynamic> map) {
    return MemberInfo(
      name: map['name'] ?? '',
      role: map['role'] ?? 'member',
      joinedDate: (map['joinedDate'] as Timestamp).toDate(),
      totalMealsEaten: map['totalMealsEaten'] ?? 0,
      totalOwed: (map['totalOwed'] ?? 0).toDouble(),
    );
  }

  // Create a copy with updated fields
  MemberInfo copyWith({
    String? name,
    String? role,
    DateTime? joinedDate,
    int? totalMealsEaten,
    double? totalOwed,
  }) {
    return MemberInfo(
      name: name ?? this.name,
      role: role ?? this.role,
      joinedDate: joinedDate ?? this.joinedDate,
      totalMealsEaten: totalMealsEaten ?? this.totalMealsEaten,
      totalOwed: totalOwed ?? this.totalOwed,
    );
  }

  @override
  String toString() {
    return 'MemberInfo(name: $name, role: $role, meals: $totalMealsEaten, owed: $totalOwed)';
  }
}