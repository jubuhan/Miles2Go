import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:miles2go/services/database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Enhanced signup method with handling for existing verified users
  Future<dynamic> signUp(BuildContext context, String email, String userName, String password, String phoneNumber) async {
    try {
      log("In signup with email: $email");
      
      // Check if the user is already signed in (from email verification)
      User? currentUser = _auth.currentUser;
      User? user;
      
      if (currentUser != null && currentUser.email == email) {
        // User is already signed in from verification, update password if needed
        log("User already signed in from verification");
        
        try {
          // Re-authenticate with current credentials
          AuthCredential credential = EmailAuthProvider.credential(
            email: email, 
            password: password
          );
          
          await currentUser.reauthenticateWithCredential(credential);
          log("Re-authentication successful");
        } catch (e) {
          // If reauthentication fails (different password), update the password
          log("Reauthentication failed, updating password: $e");
          await currentUser.updatePassword(password);
          log("Password updated successfully");
        }
        
        // Use the existing user
        user = currentUser;
      } else {
        // Try to sign in first (in case user verified but app restarted)
        try {
          log("Attempting to sign in with existing account");
          UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: email, 
            password: password
          );
          user = userCredential.user;
          log("Signed in with existing account: ${user?.uid}");
        } catch (e) {
          // If sign-in fails, try to create a new user
          log("Sign-in failed, creating new user: $e");
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: email, 
            password: password
          );
          user = userCredential.user;
          log("Created new user account: ${user?.uid}");
        }
      }

      if (user != null) {
        log("Updating user data in Firestore for user: ${user.uid}");
        // Update user data (profile info) in Firestore
        final update = await DatabaseServices().updateUserData(
          context,
          user.uid,
          userName, 
          email,
          phoneNumber,
        );
        log("Firestore update status: $update");
        
        if (update != null) {
          // Verify the update was successful by checking the document
          try {
            DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
            if (doc.exists) {
              log("User document confirmed in Firestore");
              return true;
            } else {
              log("Warning: User document not found after update");
            }
          } catch (e) {
            log("Error verifying user document: $e");
          }
          return true;
        }
      } else {
        log("Error: User is null after authentication");
      }
      
      return false;
    } on FirebaseAuthException catch (e) {
      log("Firebase Auth Exception: ${e.code}, ${e.message}");
      
      // Handle specific error cases
      if (e.code == 'email-already-in-use') {
        // Try to sign in with the provided credentials
        try {
          log("Email already in use, attempting to sign in");
          UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: email, 
            password: password
          );
          User? user = userCredential.user;
          
          if (user != null) {
            log("Sign-in successful, updating user data");
            // Update user data
            final update = await DatabaseServices().updateUserData(
              context,
              user.uid,
              userName, 
              email,
              phoneNumber,
            );
            log("Update after sign-in: $update");
            if (update != null) {
              return true;
            }
          }
          return false;
        } catch (signInError) {
          log("Error signing in with existing account: $signInError");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This email is already registered with a different password. Please use a different email or login with the correct password.'),
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return e.message;
        }
      } else if (e.code == 'weak-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please use a stronger password (at least 6 characters)'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      } else if (e.code == 'invalid-email') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid email address'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Show error message for other cases
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e.message}'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blueAccent,
        ),
      );
      return e.message;
    } catch (e) {
      log("Unexpected error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred. Please try again.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return e.toString();
    }
  }

  // Enhanced login function with better error handling
  Future<User?> login(BuildContext context, String email, String password) async {
    try {
      log("Attempting login with email: $email");
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = userCredential.user;
      if (user != null) {
        log("Login successful for user: ${user.uid}");
        
        // Update last login timestamp in Firestore
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          log("Updated last login timestamp");
        } catch (e) {
          log("Error updating last login timestamp: $e");
        }
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      log("Login error: ${e.code}, ${e.message}");
      
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during login. Please try again.';
      }
      
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null;
    } catch (e) {
      log("Unexpected login error: $e");
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // Enhanced logout function
  Future<bool> logout() async {
    try {
      // Get the current user ID before signing out
      String? userId = _auth.currentUser?.uid;
      
      // Sign out
      await _auth.signOut();
      log("User signed out successfully");
      
      // Update user status in Firestore if we have a userId
      if (userId != null) {
        try {
          await _firestore.collection('users').doc(userId).set({
            'lastLogout': FieldValue.serverTimestamp(),
            'isOnline': false,
          }, SetOptions(merge: true));
          log("Updated user status after logout");
        } catch (e) {
          log("Error updating user status after logout: $e");
        }
      }
      
      return true;
    } catch (e) {
      log("Error during logout: $e");
      return false;
    }
  }

  // Get current user with additional info
  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    
    try {
      // Get user document from Firestore
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      
      // Combine auth user info with Firestore data
      Map<String, dynamic> userInfo = {
        'uid': user.uid,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'displayName': user.displayName,
        'phoneNumber': user.phoneNumber,
      };
      
      // Add Firestore data if document exists
      if (doc.exists) {
        Map<String, dynamic> firestoreData = doc.data() as Map<String, dynamic>;
        userInfo.addAll(firestoreData);
      }
      
      return userInfo;
    } catch (e) {
      log("Error getting current user info: $e");
      return {
        'uid': user.uid,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'displayName': user.displayName,
        'phoneNumber': user.phoneNumber,
      };
    }
  }

  // Get current user basic info
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user profile data from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Update the last access timestamp
        await doc.reference.set({
          'lastProfileAccess': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return data;
      }
      return null;
    } catch (e) {
      log("Error getting user profile: $e");
      return null;
    }
  }

  // Get user phone number
  Future<String?> getUserPhoneNumber(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['phoneNumber'] as String?;
      }
      return null;
    } catch (e) {
      log("Error getting phone number: $e");
      return null;
    }
  }

  // Update user phone number
  Future<bool> updateUserPhoneNumber(String userId, String phoneNumber) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      log("Phone number updated successfully");
      return true;
    } catch (e) {
      log("Error updating phone number: $e");
      return false;
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> profileData) async {
    try {
      // Add an updated timestamp
      profileData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('users').doc(userId).set(
        profileData, 
        SetOptions(merge: true)
      );
      
      log("User profile updated successfully");
      return true;
    } catch (e) {
      log("Error updating user profile: $e");
      return false;
    }
  }
  
  // Check if a user document exists
  Future<bool> doesUserExist(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      log("Error checking if user exists: $e");
      return false;
    }
  }
  
  // Create user document if it doesn't exist
  Future<bool> ensureUserDocument(String userId, String email, [String? displayName]) async {
    try {
      // Check if document exists
      bool exists = await doesUserExist(userId);
      
      if (!exists) {
        // Create basic user document
        await _firestore.collection('users').doc(userId).set({
          'userId': userId,
          'email': email,
          'userName': displayName ?? email.split('@').first,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'wallet': {},
          'vehicles': [],
        });
        log("Created new user document for $userId");
      }
      
      return true;
    } catch (e) {
      log("Error ensuring user document: $e");
      return false;
    }
  }
}