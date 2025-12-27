import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/cooking_rotation_model.dart';
import '../models/meal_system_model.dart';

class CookingRotationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  CookingRotationModel? _currentRotation;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  CookingRotationModel? get currentRotation => _currentRotation;
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

  // Initialize rotation for a meal system
  Future<bool> initializeRotation({
    required String systemId,
    required MealSystemModel mealSystem,
    RotationSettings? settings,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Create member rotation info from meal system members
      final Map<String, MemberRotationInfo> members = {};
      mealSystem.members.forEach((userId, memberInfo) {
        members[userId] = MemberRotationInfo(
          userId: userId,
          userName: memberInfo.name,
          totalCooksCompleted: 0,
          totalCooksAssigned: 0,
        );
      });

      final rotation = CookingRotationModel(
        systemId: systemId,
        members: members,
        upcomingSchedule: [],
        settings: settings ?? RotationSettings(),
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .set(rotation.toMap());

      // Generate initial schedule
      await generateSchedule(systemId, daysAhead: rotation.settings.daysAhead);

      _currentRotation = rotation;
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to initialize rotation: $e');
      return false;
    }
  }

  // Get rotation for a system
  Future<CookingRotationModel?> getRotation(String systemId) async {
    try {
      _setLoading(true);

      final doc = await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .get();

      if (doc.exists) {
        _currentRotation = CookingRotationModel.fromDocument(doc);
        _setLoading(false);
        return _currentRotation;
      }

      _setLoading(false);
      return null;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to get rotation: $e');
      return null;
    }
  }

  // Stream rotation for real-time updates
  Stream<CookingRotationModel?> streamRotation(String systemId) {
    return _firestore
        .collection('cookingRotation')
        .doc(systemId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        _currentRotation = CookingRotationModel.fromDocument(doc);
        return _currentRotation;
      }
      return null;
    });
  }

  // Generate schedule for upcoming days
  Future<bool> generateSchedule(String systemId, {int daysAhead = 7}) async {
    try {
      final rotation = await getRotation(systemId);
      if (rotation == null) return false;

      final schedule = <ScheduledCook>[];
      final startDate = DateTime.now();

      // Get active members
      final activeMembers = rotation.members.entries
          .where((entry) => entry.value.isActive && !entry.value.isCurrentlyInactive)
          .toList();

      if (activeMembers.isEmpty) {
        _setError('No active members to assign cooking duties');
        return false;
      }

      // Sort members by fairness score (who should cook first)
      activeMembers.sort((a, b) => 
          a.value.fairnessScore.compareTo(b.value.fairnessScore));

      int memberIndex = 0;

      // Generate schedule based on frequency
      for (int day = 0; day < daysAhead; day++) {
        final date = startDate.add(Duration(days: day));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayOfWeek = DaysOfWeek.getDayOfWeek(date);

        bool shouldSchedule = false;

        // Determine if we should schedule cooking for this day
        switch (rotation.settings.frequency) {
          case RotationFrequency.daily:
            shouldSchedule = true;
            break;
          case RotationFrequency.alternateDays:
            shouldSchedule = day % 2 == 0;
            break;
          case RotationFrequency.weekly:
            shouldSchedule = date.weekday == 1; // Monday
            break;
        }

        if (!shouldSchedule) continue;

        // Assign cooks for each meal type in settings
        for (var mealType in rotation.settings.mealsToRotate) {
          // Find next available member
          String? assignedUserId;
          String? assignedUserName;

          if (rotation.settings.respectPreferences) {
            // Try to find member who prefers this day
            for (int i = 0; i < activeMembers.length; i++) {
              final checkIndex = (memberIndex + i) % activeMembers.length;
              final member = activeMembers[checkIndex].value;

              if (member.isAvailableOnDay(dayOfWeek)) {
                assignedUserId = member.userId;
                assignedUserName = member.userName;
                memberIndex = (checkIndex + 1) % activeMembers.length;
                break;
              }
            }
          }

          // If no preferred member found, assign next in rotation
          if (assignedUserId == null) {
            final member = activeMembers[memberIndex].value;
            assignedUserId = member.userId;
            assignedUserName = member.userName;
            memberIndex = (memberIndex + 1) % activeMembers.length;
          }

          // Create scheduled cook
          final scheduledCook = ScheduledCook(
            scheduleId: _uuid.v4(),
            date: dateStr,
            mealType: mealType,
            assignedTo: assignedUserId,
            assignedToName: assignedUserName!,
            assignedDate: DateTime.now(),
          );

          schedule.add(scheduledCook);

          // Update member's assigned count
          final memberInfo = rotation.members[assignedUserId]!;
          rotation.members[assignedUserId] = memberInfo.copyWith(
            totalCooksAssigned: memberInfo.totalCooksAssigned + 1,
          );
        }
      }

      // Update rotation with new schedule
      final updatedRotation = rotation.copyWith(
        upcomingSchedule: schedule,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update(updatedRotation.toMap());

      _currentRotation = updatedRotation;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to generate schedule: $e');
      return false;
    }
  }

  // Manually assign a cook
  Future<bool> manuallyAssignCook({
    required String systemId,
    required String date,
    required String mealType,
    required String assignedTo,
    required String assignedToName,
  }) async {
    try {
      final rotation = await getRotation(systemId);
      if (rotation == null) return false;

      // Check if already assigned
      final existingIndex = rotation.upcomingSchedule.indexWhere(
        (s) => s.date == date && s.mealType == mealType,
      );

      final scheduledCook = ScheduledCook(
        scheduleId: _uuid.v4(),
        date: date,
        mealType: mealType,
        assignedTo: assignedTo,
        assignedToName: assignedToName,
        assignedDate: DateTime.now(),
      );

      List<ScheduledCook> updatedSchedule = List.from(rotation.upcomingSchedule);

      if (existingIndex != -1) {
        // Replace existing assignment
        updatedSchedule[existingIndex] = scheduledCook;
      } else {
        // Add new assignment
        updatedSchedule.add(scheduledCook);
      }

      // Update member's assigned count
      final memberInfo = rotation.members[assignedTo];
      if (memberInfo != null) {
        rotation.members[assignedTo] = memberInfo.copyWith(
          totalCooksAssigned: memberInfo.totalCooksAssigned + 1,
        );
      }

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'upcomingSchedule': updatedSchedule.map((s) => s.toMap()).toList(),
        'members': rotation.members.map((k, v) => MapEntry(k, v.toMap())),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to assign cook: $e');
      return false;
    }
  }

  // Mark cooking as completed
  Future<bool> markCookingCompleted({
    required String systemId,
    required String scheduleId,
    String? menu,
  }) async {
    try {
      final rotation = await getRotation(systemId);
      if (rotation == null) return false;

      final scheduleIndex = rotation.upcomingSchedule.indexWhere(
        (s) => s.scheduleId == scheduleId,
      );

      if (scheduleIndex == -1) {
        _setError('Schedule not found');
        return false;
      }

      final schedule = rotation.upcomingSchedule[scheduleIndex];
      final updatedSchedule = schedule.copyWith(
        completed: true,
        completedDate: DateTime.now(),
        menu: menu,
      );

      List<ScheduledCook> allSchedule = List.from(rotation.upcomingSchedule);
      allSchedule[scheduleIndex] = updatedSchedule;

      // Update member's completed count
      final memberInfo = rotation.members[schedule.assignedTo];
      if (memberInfo != null) {
        rotation.members[schedule.assignedTo] = memberInfo.copyWith(
          totalCooksCompleted: memberInfo.totalCooksCompleted + 1,
          lastCookedDate: DateTime.now(),
        );
      }

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'upcomingSchedule': allSchedule.map((s) => s.toMap()).toList(),
        'members': rotation.members.map((k, v) => MapEntry(k, v.toMap())),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to mark cooking completed: $e');
      return false;
    }
  }

  // Update member preferences
  Future<bool> updateMemberPreferences({
    required String systemId,
    required String userId,
    List<String>? preferredDays,
    bool? isActive,
    DateTime? inactiveUntil,
  }) async {
    try {
      final rotation = await getRotation(systemId);
      if (rotation == null) return false;

      final memberInfo = rotation.members[userId];
      if (memberInfo == null) {
        _setError('Member not found');
        return false;
      }

      final updatedMember = memberInfo.copyWith(
        preferredDays: preferredDays,
        isActive: isActive,
        inactiveSince: isActive == false ? DateTime.now() : null,
        inactiveUntil: inactiveUntil,
      );

      rotation.members[userId] = updatedMember;

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'members.$userId': updatedMember.toMap(),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update preferences: $e');
      return false;
    }
  }

  // Update rotation settings
  Future<bool> updateSettings({
    required String systemId,
    required RotationSettings settings,
  }) async {
    try {
      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'settings': settings.toMap(),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      // Regenerate schedule with new settings
      await generateSchedule(systemId, daysAhead: settings.daysAhead);

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update settings: $e');
      return false;
    }
  }

  // Get cooking statistics for all members
  List<CookingStatistics> getMemberStatistics() {
    if (_currentRotation == null) return [];

    return _currentRotation!.members.values
        .map((member) => CookingStatistics.fromMemberInfo(member))
        .toList()
      ..sort((a, b) => b.totalCooksCompleted.compareTo(a.totalCooksCompleted));
  }

  // Get upcoming schedule for a specific member
  List<ScheduledCook> getMemberUpcomingSchedule(String userId) {
    if (_currentRotation == null) return [];

    return _currentRotation!.upcomingSchedule
        .where((s) => s.assignedTo == userId && !s.completed)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // Remove a scheduled cook
  Future<bool> removeScheduledCook({
    required String systemId,
    required String scheduleId,
  }) async {
    try {
      final rotation = await getRotation(systemId);
      if (rotation == null) return false;

      final updatedSchedule = rotation.upcomingSchedule
          .where((s) => s.scheduleId != scheduleId)
          .toList();

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'upcomingSchedule': updatedSchedule.map((s) => s.toMap()).toList(),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to remove scheduled cook: $e');
      return false;
    }
  }

  // Add a new member to rotation
  Future<bool> addMemberToRotation({
    required String systemId,
    required String userId,
    required String userName,
  }) async {
    try {
      final memberInfo = MemberRotationInfo(
        userId: userId,
        userName: userName,
        totalCooksCompleted: 0,
        totalCooksAssigned: 0,
      );

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'members.$userId': memberInfo.toMap(),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to add member: $e');
      return false;
    }
  }

  // Remove member from rotation
  Future<bool> removeMemberFromRotation({
    required String systemId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'members.$userId': FieldValue.delete(),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to remove member: $e');
      return false;
    }
  }

  // Get next cook assignment for a member
  ScheduledCook? getNextCookForMember(String userId) {
    if (_currentRotation == null) return null;

    final memberSchedule = getMemberUpcomingSchedule(userId);
    return memberSchedule.isNotEmpty ? memberSchedule.first : null;
  }

  // Check if schedule needs regeneration
  bool shouldRegenerateSchedule() {
    if (_currentRotation == null) return false;

    // Check if we have enough days scheduled
    final lastScheduledDate = _currentRotation!.upcomingSchedule
        .map((s) => DateTime.parse(s.date))
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final daysRemaining = lastScheduledDate.difference(DateTime.now()).inDays;

    return daysRemaining < 3; // Regenerate if less than 3 days scheduled
  }

  // Clean up completed schedules (older than 30 days)
  Future<bool> cleanupOldSchedules(String systemId) async {
    try {
      final rotation = await getRotation(systemId);
      if (rotation == null) return false;

      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoffDate);

      final updatedSchedule = rotation.upcomingSchedule
          .where((s) => s.date.compareTo(cutoffStr) >= 0)
          .toList();

      await _firestore
          .collection('cookingRotation')
          .doc(systemId)
          .update({
        'upcomingSchedule': updatedSchedule.map((s) => s.toMap()).toList(),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to cleanup old schedules: $e');
      return false;
    }
  }
}