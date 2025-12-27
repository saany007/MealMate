import 'package:cloud_firestore/cloud_firestore.dart';

class CookingRotationModel {
  final String systemId;
  final Map<String, MemberRotationInfo> members;
  final List<ScheduledCook> upcomingSchedule;
  final RotationSettings settings;
  final DateTime lastUpdated;

  CookingRotationModel({
    required this.systemId,
    required this.members,
    required this.upcomingSchedule,
    required this.settings,
    required this.lastUpdated,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'systemId': systemId,
      'members': members.map((key, value) => MapEntry(key, value.toMap())),
      'upcomingSchedule': upcomingSchedule.map((s) => s.toMap()).toList(),
      'settings': settings.toMap(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  // Create from Map
  factory CookingRotationModel.fromMap(Map<String, dynamic> map) {
    Map<String, MemberRotationInfo> membersMap = {};
    if (map['members'] != null) {
      (map['members'] as Map<String, dynamic>).forEach((key, value) {
        membersMap[key] = MemberRotationInfo.fromMap(value);
      });
    }

    List<ScheduledCook> scheduleList = [];
    if (map['upcomingSchedule'] != null) {
      scheduleList = (map['upcomingSchedule'] as List)
          .map((s) => ScheduledCook.fromMap(s))
          .toList();
    }

    return CookingRotationModel(
      systemId: map['systemId'] ?? '',
      members: membersMap,
      upcomingSchedule: scheduleList,
      settings: RotationSettings.fromMap(map['settings'] ?? {}),
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Create from DocumentSnapshot
  factory CookingRotationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CookingRotationModel.fromMap(data);
  }

  // Copy with updated fields
  CookingRotationModel copyWith({
    String? systemId,
    Map<String, MemberRotationInfo>? members,
    List<ScheduledCook>? upcomingSchedule,
    RotationSettings? settings,
    DateTime? lastUpdated,
  }) {
    return CookingRotationModel(
      systemId: systemId ?? this.systemId,
      members: members ?? this.members,
      upcomingSchedule: upcomingSchedule ?? this.upcomingSchedule,
      settings: settings ?? this.settings,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Get member by ID
  MemberRotationInfo? getMember(String userId) => members[userId];

  // Get next cook in schedule
  ScheduledCook? get nextScheduledCook {
    if (upcomingSchedule.isEmpty) return null;
    return upcomingSchedule.first;
  }

  // Get member with lowest fairness score (should cook next)
  String? getMemberWithLowestScore() {
    if (members.isEmpty) return null;

    var sortedMembers = members.entries.toList()
      ..sort((a, b) => a.value.fairnessScore.compareTo(b.value.fairnessScore));

    return sortedMembers.first.key;
  }

  @override
  String toString() {
    return 'CookingRotationModel(system: $systemId, members: ${members.length}, scheduled: ${upcomingSchedule.length})';
  }
}

// Member rotation information
class MemberRotationInfo {
  final String userId;
  final String userName;
  final int totalCooksCompleted;
  final int totalCooksAssigned;
  final DateTime? lastCookedDate;
  final List<String> preferredDays; // ["Mon", "Wed", "Fri"]
  final bool isActive; // Can be set to false if member is away
  final DateTime? inactiveSince;
  final DateTime? inactiveUntil;

  MemberRotationInfo({
    required this.userId,
    required this.userName,
    this.totalCooksCompleted = 0,
    this.totalCooksAssigned = 0,
    this.lastCookedDate,
    this.preferredDays = const [],
    this.isActive = true,
    this.inactiveSince,
    this.inactiveUntil,
  });

  // Calculate fairness score (lower = should cook sooner)
  double get fairnessScore {
    if (totalCooksAssigned == 0) return 0.0;
    return totalCooksCompleted / totalCooksAssigned;
  }

  // Get days since last cooked
  int? get daysSinceLastCooked {
    if (lastCookedDate == null) return null;
    return DateTime.now().difference(lastCookedDate!).inDays;
  }

  // Check if member is available on a specific day
  bool isAvailableOnDay(String dayOfWeek) {
    if (!isActive) return false;
    if (preferredDays.isEmpty) return true; // No preference = available any day
    return preferredDays.contains(dayOfWeek);
  }

  // Check if currently inactive
  bool get isCurrentlyInactive {
    if (!isActive) {
      if (inactiveUntil == null) return true;
      return DateTime.now().isBefore(inactiveUntil!);
    }
    return false;
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'totalCooksCompleted': totalCooksCompleted,
      'totalCooksAssigned': totalCooksAssigned,
      'lastCookedDate': lastCookedDate != null
          ? Timestamp.fromDate(lastCookedDate!)
          : null,
      'preferredDays': preferredDays,
      'isActive': isActive,
      'inactiveSince': inactiveSince != null
          ? Timestamp.fromDate(inactiveSince!)
          : null,
      'inactiveUntil': inactiveUntil != null
          ? Timestamp.fromDate(inactiveUntil!)
          : null,
    };
  }

  // Create from Map
  factory MemberRotationInfo.fromMap(Map<String, dynamic> map) {
    return MemberRotationInfo(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      totalCooksCompleted: map['totalCooksCompleted'] ?? 0,
      totalCooksAssigned: map['totalCooksAssigned'] ?? 0,
      lastCookedDate: map['lastCookedDate'] != null
          ? (map['lastCookedDate'] as Timestamp).toDate()
          : null,
      preferredDays: map['preferredDays'] != null
          ? List<String>.from(map['preferredDays'])
          : [],
      isActive: map['isActive'] ?? true,
      inactiveSince: map['inactiveSince'] != null
          ? (map['inactiveSince'] as Timestamp).toDate()
          : null,
      inactiveUntil: map['inactiveUntil'] != null
          ? (map['inactiveUntil'] as Timestamp).toDate()
          : null,
    );
  }

  // Copy with updated fields
  MemberRotationInfo copyWith({
    String? userId,
    String? userName,
    int? totalCooksCompleted,
    int? totalCooksAssigned,
    DateTime? lastCookedDate,
    List<String>? preferredDays,
    bool? isActive,
    DateTime? inactiveSince,
    DateTime? inactiveUntil,
  }) {
    return MemberRotationInfo(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      totalCooksCompleted: totalCooksCompleted ?? this.totalCooksCompleted,
      totalCooksAssigned: totalCooksAssigned ?? this.totalCooksAssigned,
      lastCookedDate: lastCookedDate ?? this.lastCookedDate,
      preferredDays: preferredDays ?? this.preferredDays,
      isActive: isActive ?? this.isActive,
      inactiveSince: inactiveSince ?? this.inactiveSince,
      inactiveUntil: inactiveUntil ?? this.inactiveUntil,
    );
  }

  @override
  String toString() {
    return 'MemberRotationInfo(user: $userName, completed: $totalCooksCompleted, assigned: $totalCooksAssigned, score: ${fairnessScore.toStringAsFixed(2)})';
  }
}

// Scheduled cook assignment
class ScheduledCook {
  final String scheduleId;
  final String date; // Format: YYYY-MM-DD
  final String mealType; // breakfast, lunch, dinner
  final String assignedTo;
  final String assignedToName;
  final DateTime assignedDate;
  final bool notificationSent;
  final bool completed;
  final DateTime? completedDate;
  final String? menu;

  ScheduledCook({
    required this.scheduleId,
    required this.date,
    required this.mealType,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedDate,
    this.notificationSent = false,
    this.completed = false,
    this.completedDate,
    this.menu,
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'date': date,
      'mealType': mealType,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'notificationSent': notificationSent,
      'completed': completed,
      'completedDate': completedDate != null
          ? Timestamp.fromDate(completedDate!)
          : null,
      'menu': menu,
    };
  }

  // Create from Map
  factory ScheduledCook.fromMap(Map<String, dynamic> map) {
    return ScheduledCook(
      scheduleId: map['scheduleId'] ?? '',
      date: map['date'] ?? '',
      mealType: map['mealType'] ?? '',
      assignedTo: map['assignedTo'] ?? '',
      assignedToName: map['assignedToName'] ?? '',
      assignedDate: (map['assignedDate'] as Timestamp).toDate(),
      notificationSent: map['notificationSent'] ?? false,
      completed: map['completed'] ?? false,
      completedDate: map['completedDate'] != null
          ? (map['completedDate'] as Timestamp).toDate()
          : null,
      menu: map['menu'],
    );
  }

  // Copy with updated fields
  ScheduledCook copyWith({
    String? scheduleId,
    String? date,
    String? mealType,
    String? assignedTo,
    String? assignedToName,
    DateTime? assignedDate,
    bool? notificationSent,
    bool? completed,
    DateTime? completedDate,
    String? menu,
  }) {
    return ScheduledCook(
      scheduleId: scheduleId ?? this.scheduleId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedDate: assignedDate ?? this.assignedDate,
      notificationSent: notificationSent ?? this.notificationSent,
      completed: completed ?? this.completed,
      completedDate: completedDate ?? this.completedDate,
      menu: menu ?? this.menu,
    );
  }

  // Check if this cook is in the past
  bool get isPast {
    final cookDate = DateTime.parse(date);
    return cookDate.isBefore(DateTime.now());
  }

  // Check if this cook is today
  bool get isToday {
    final cookDate = DateTime.parse(date);
    final now = DateTime.now();
    return cookDate.year == now.year &&
        cookDate.month == now.month &&
        cookDate.day == now.day;
  }

  // Check if notification should be sent (1 day before)
  bool get shouldSendNotification {
    if (notificationSent) return false;
    final cookDate = DateTime.parse(date);
    final now = DateTime.now();
    final difference = cookDate.difference(now).inHours;
    return difference <= 24 && difference > 0;
  }

  @override
  String toString() {
    return 'ScheduledCook(date: $date, meal: $mealType, cook: $assignedToName)';
  }
}

// Rotation settings
class RotationSettings {
  final String frequency; // "daily", "alternateDays", "weekly"
  final List<String> mealsToRotate; // ["breakfast", "lunch", "dinner"]
  final bool autoAssign; // Auto-assign cooks or require manual assignment
  final int daysAhead; // How many days ahead to schedule
  final bool respectPreferences; // Consider member preferred days

  RotationSettings({
    this.frequency = 'daily',
    this.mealsToRotate = const ['lunch', 'dinner'],
    this.autoAssign = true,
    this.daysAhead = 7,
    this.respectPreferences = true,
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency,
      'mealsToRotate': mealsToRotate,
      'autoAssign': autoAssign,
      'daysAhead': daysAhead,
      'respectPreferences': respectPreferences,
    };
  }

  // Create from Map
  factory RotationSettings.fromMap(Map<String, dynamic> map) {
    return RotationSettings(
      frequency: map['frequency'] ?? 'daily',
      mealsToRotate: map['mealsToRotate'] != null
          ? List<String>.from(map['mealsToRotate'])
          : ['lunch', 'dinner'],
      autoAssign: map['autoAssign'] ?? true,
      daysAhead: map['daysAhead'] ?? 7,
      respectPreferences: map['respectPreferences'] ?? true,
    );
  }

  // Copy with updated fields
  RotationSettings copyWith({
    String? frequency,
    List<String>? mealsToRotate,
    bool? autoAssign,
    int? daysAhead,
    bool? respectPreferences,
  }) {
    return RotationSettings(
      frequency: frequency ?? this.frequency,
      mealsToRotate: mealsToRotate ?? this.mealsToRotate,
      autoAssign: autoAssign ?? this.autoAssign,
      daysAhead: daysAhead ?? this.daysAhead,
      respectPreferences: respectPreferences ?? this.respectPreferences,
    );
  }

  @override
  String toString() {
    return 'RotationSettings(frequency: $frequency, meals: $mealsToRotate)';
  }
}

// Rotation frequency options
class RotationFrequency {
  static const String daily = 'daily';
  static const String alternateDays = 'alternateDays';
  static const String weekly = 'weekly';

  static List<String> get all => [daily, alternateDays, weekly];

  static String getDisplayName(String frequency) {
    switch (frequency) {
      case daily:
        return 'Every Day';
      case alternateDays:
        return 'Alternate Days';
      case weekly:
        return 'Weekly';
      default:
        return 'Unknown';
    }
  }
}

// Days of week constants
class DaysOfWeek {
  static const String monday = 'Mon';
  static const String tuesday = 'Tue';
  static const String wednesday = 'Wed';
  static const String thursday = 'Thu';
  static const String friday = 'Fri';
  static const String saturday = 'Sat';
  static const String sunday = 'Sun';

  static List<String> get all => [
        monday,
        tuesday,
        wednesday,
        thursday,
        friday,
        saturday,
        sunday,
      ];

  static String getFullName(String shortName) {
    switch (shortName) {
      case monday:
        return 'Monday';
      case tuesday:
        return 'Tuesday';
      case wednesday:
        return 'Wednesday';
      case thursday:
        return 'Thursday';
      case friday:
        return 'Friday';
      case saturday:
        return 'Saturday';
      case sunday:
        return 'Sunday';
      default:
        return shortName;
    }
  }

  static String getDayOfWeek(DateTime date) {
    switch (date.weekday) {
      case 1:
        return monday;
      case 2:
        return tuesday;
      case 3:
        return wednesday;
      case 4:
        return thursday;
      case 5:
        return friday;
      case 6:
        return saturday;
      case 7:
        return sunday;
      default:
        return '';
    }
  }
}

// Cooking statistics for a member
class CookingStatistics {
  final String userId;
  final String userName;
  final int totalCooksCompleted;
  final int totalCooksAssigned;
  final double completionRate;
  final double fairnessScore;
  final DateTime? lastCookedDate;
  final int? daysSinceLastCooked;
  final List<String> preferredDays;

  CookingStatistics({
    required this.userId,
    required this.userName,
    required this.totalCooksCompleted,
    required this.totalCooksAssigned,
    required this.completionRate,
    required this.fairnessScore,
    this.lastCookedDate,
    this.daysSinceLastCooked,
    required this.preferredDays,
  });

  factory CookingStatistics.fromMemberInfo(MemberRotationInfo memberInfo) {
    final completionRate = memberInfo.totalCooksAssigned > 0
        ? (memberInfo.totalCooksCompleted / memberInfo.totalCooksAssigned) * 100
        : 0.0;

    return CookingStatistics(
      userId: memberInfo.userId,
      userName: memberInfo.userName,
      totalCooksCompleted: memberInfo.totalCooksCompleted,
      totalCooksAssigned: memberInfo.totalCooksAssigned,
      completionRate: completionRate,
      fairnessScore: memberInfo.fairnessScore,
      lastCookedDate: memberInfo.lastCookedDate,
      daysSinceLastCooked: memberInfo.daysSinceLastCooked,
      preferredDays: memberInfo.preferredDays,
    );
  }

  @override
  String toString() {
    return 'CookingStatistics(user: $userName, completed: $totalCooksCompleted/$totalCooksAssigned, rate: ${completionRate.toStringAsFixed(1)}%)';
  }
}