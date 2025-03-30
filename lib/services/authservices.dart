import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:miles2go/services/database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Updated to include phone number parameter
  Future<dynamic> signUp(BuildContext context, String email, String userName, String password, String phoneNumber) async {
    final FirebaseAuth firebaseAuth = await FirebaseAuth.instance;
    try {
      log("in signup email and password :$email  ,$password");
      log(password);
      User user = (await firebaseAuth.createUserWithEmailAndPassword(
              email: email, password: password))
          .user!;

      if (user != null) {
        // Pass phone number to DatabaseServices
        final update = await DatabaseServices().updateUserData(
          context,
          user.uid,
          userName, 
          email,
          phoneNumber, // Add phone number here
        );
        log("Update : $update");
        if(update != null)
          return true;
      }
    } on FirebaseAuthException catch (e) {
      print(e);
      // return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e.message}'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blueAccent,
        ),
      );
      return e.message;
    }
  }

  // Login function
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error in login: $e");
      return null;
    }
  }

  // Logout function
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
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
      await _firestore.collection('users').doc(userId).update({
        'phoneNumber': phoneNumber,
      });
      return true;
    } catch (e) {
      log("Error updating phone number: $e");
      return false;
    }
  }
}