import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();
  
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserModel(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  // Load user model from Firestore
  Future<void> _loadUserModel(String userId) async {
    try {
      _userModel = await _databaseService.getUserById(userId);
      notifyListeners();
    } catch (e) {
      print('Error loading user model: $e');
    }
  }

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

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required List<String> dietaryPreferences,
    String? photoURL,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Create user model
      UserModel newUser = UserModel(
        userId: userCredential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        photoURL: photoURL,
        dietaryPreferences: dietaryPreferences,
        dateJoined: DateTime.now(),
        currentMealSystemId: null,
      );

      // Save user to Firestore
      await _databaseService.createUser(newUser);

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      _userModel = newUser;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      switch (e.code) {
        case 'weak-password':
          _setError('The password is too weak. Please use at least 6 characters.');
          break;
        case 'email-already-in-use':
          _setError('An account already exists for this email.');
          break;
        case 'invalid-email':
          _setError('The email address is not valid.');
          break;
        default:
          _setError('Registration failed: ${e.message}');
      }
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred: $e');
      return false;
    }
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Load user model
      await _loadUserModel(userCredential.user!.uid);

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      switch (e.code) {
        case 'user-not-found':
          _setError('No user found with this email.');
          break;
        case 'wrong-password':
          _setError('Incorrect password.');
          break;
        case 'invalid-email':
          _setError('The email address is not valid.');
          break;
        case 'user-disabled':
          _setError('This account has been disabled.');
          break;
        case 'too-many-requests':
          _setError('Too many login attempts. Please try again later.');
          break;
        default:
          _setError('Login failed: ${e.message}');
      }
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred: $e');
      return false;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _setError(null);

      await _auth.sendPasswordResetEmail(email: email);

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      switch (e.code) {
        case 'user-not-found':
          _setError('No user found with this email.');
          break;
        case 'invalid-email':
          _setError('The email address is not valid.');
          break;
        default:
          _setError('Failed to send reset email: ${e.message}');
      }
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _userModel = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to sign out: $e');
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? photoURL,
    List<String>? dietaryPreferences,
  }) async {
    try {
      if (_userModel == null) return false;

      _setLoading(true);

      // Update display name in Firebase Auth if changed
      if (name != null && name != _userModel!.name) {
        await _user?.updateDisplayName(name);
      }

      // Create updated user model
      UserModel updatedUser = _userModel!.copyWith(
        name: name,
        phone: phone,
        photoURL: photoURL,
        dietaryPreferences: dietaryPreferences,
      );

      // Update in Firestore
      await _databaseService.updateUser(updatedUser);

      _userModel = updatedUser;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to update profile: $e');
      return false;
    }
  }

  // Update current meal system
  Future<bool> updateCurrentMealSystem(String? systemId) async {
    try {
      if (_userModel == null) return false;

      UserModel updatedUser = _userModel!.copyWith(
        currentMealSystemId: systemId,
      );

      await _databaseService.updateUser(updatedUser);

      _userModel = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update meal system: $e');
      return false;
    }
  }

  // Check if email is verified
  bool get isEmailVerified => _user?.emailVerified ?? false;

  // Resend verification email
  Future<bool> resendVerificationEmail() async {
    try {
      await _user?.sendEmailVerification();
      return true;
    } catch (e) {
      _setError('Failed to send verification email: $e');
      return false;
    }
  }

  // Reload user to check email verification status
  Future<void> reloadUser() async {
    try {
      await _user?.reload();
      _user = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      if (_user == null) return false;

      // Delete user document from Firestore
      await _databaseService.deleteUser(_user!.uid);

      // Delete user from Firebase Auth
      await _user?.delete();

      _userModel = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete account: $e');
      return false;
    }
  }
}