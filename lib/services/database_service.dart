import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final currentlyLoggedUserId = FirebaseAuth.instance.currentUser?.uid;

class DatabaseServices {
  // final String? userId;

  DatabaseServices();

  // reference for the collections in firestore database
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection("users");

  //updating user data with phone number
  Future updateUserData(BuildContext context, String userId, String userName,
      String email, String phoneNumber) async {
    try {
      await userCollection.doc(userId).set(
        {
          "userId": userId,
          "userName": userName,
          "email": email,
          "phoneNumber": phoneNumber, // Added phone number
          "walletAddress": "",
          "vehicles": [],
        },
        SetOptions(
            merge:
                true), // Ensures existing data is not overwritten if necessary
      );
      return true;
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e}'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blueAccent,
        ),
      );

      return null;
    }
  }

  // Update only phone number
  Future<bool> updatePhoneNumber(String userId, String phoneNumber) async {
    try {
      await userCollection.doc(userId).update({
        "phoneNumber": phoneNumber,
      });
      return true;
    } catch (e) {
      log("Error updating phone number: $e");
      return false;
    }
  }

  // Get user's phone number
  Future<String?> getUserPhoneNumber(String userId) async {
    try {
      DocumentSnapshot doc = await userCollection.doc(userId).get();
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

  Future<bool> addVehicleDetail(BuildContext context, String userId,
      Map<String, dynamic> vehicleData) async {
    try {
      await userCollection.doc(userId).update({
        "vehicles": FieldValue.arrayUnion(
            [vehicleData]), // Adds new vehicle to the list
      });

      return true; // Successfully added vehicle
    } catch (e) {
      print("Error adding vehicle: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );

      return false; // Return false if an error occurs
    }
  }

  Future<List<Map<String, dynamic>>> getUserVehicles() async {
    try {
      // Get the current logged-in user's ID
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("No user is logged in.");
        return [];
      }

      // Fetch user document from Firestore
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection("users").doc(userId).get();

      if (userDoc.exists) {
        // Extract the vehicles list
        List<dynamic>? vehicles = userDoc["vehicles"];

        // Convert to a List<Map<String, dynamic>>
        return vehicles != null ? List<Map<String, dynamic>>.from(vehicles) : [];
      } else {
        print("User document does not exist.");
        return [];
      }
    } catch (e) {
      print("Error fetching vehicles: $e");
      return [];
    }
  }

  // Get user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await userCollection.doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      log("Error getting user data: $e");
      return null;
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return null;
    }
    return getUserData(userId);
  }
}