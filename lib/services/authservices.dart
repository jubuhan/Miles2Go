import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:miles2go/services/database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<dynamic> signUp(BuildContext context, String email,String userName, String password) async {
    final FirebaseAuth firebaseAuth = await FirebaseAuth.instance;
    try {
      log("in signup email and password :$email  ,$password");
      log(password);
      User user = (await firebaseAuth.createUserWithEmailAndPassword(
              email: email, password: password))
          .user!;

      if (user != null) {
      final update =  await DatabaseServices().updateUserData(context,user.uid,userName, email);
      log("Update : $update");
      if(update!=null)
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


  //    Future<User?> signUp(String email, String password, String username) async {
  //   try {
  //     // 1. First create the user account (just Auth, no Firestore yet)
  //     await _auth.createUserWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );
      
  //     // 2. Get current user - should be the one we just created
  //     // This is safer than using the result from createUserWithEmailAndPassword
  //     User? currentUser = _auth.currentUser;
      
  //     // 3. If we have a valid user, update profile and Firestore
  //     if (currentUser != null) {
  //       // Update display name
  //       await currentUser.updateDisplayName(username);
        
  //       // Update Firestore separately
  //       try {
  //         await _firestore.collection("users").doc(currentUser.uid).set({
  //           "uid": currentUser.uid,
  //           "username": username,
  //           "email": email,
  //           "walletAddress": "",
  //           "createdAt": FieldValue.serverTimestamp(),
  //         });
  //       } catch (firestoreError) {
  //         print("Firestore error: $firestoreError");
  //         // Continue anyway - at least the auth account is created
  //       }
        
  //       // Return the current user
  //       return currentUser;
  //     }
  //     return null;
  //   } catch (e) {
  //     print("Error in sign up: $e");
  //     rethrow;
  //   }
  // }


  // Sign up function
  // Future<User?> signUp(String email, String password, String username) async {
  //   try {
  //     UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );

  //     // Save user details in Firestore
  //     await _firestore.collection("users").doc(userCredential.user!.uid).set({
  //       "uid": userCredential.user!.uid,
  //       "username": username,
  //       "email": email,
  //       "walletAddress":"",
  //     });

  //     return userCredential.user;
  //   } catch (e) {
  //     print("Error in sign up: $e");
  //     return null;
  //   }
  // }

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
}
