import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final currentlyLoggedUserId = FirebaseAuth.instance.currentUser!.uid;

class DatabaseServices {
  // final String? userId;

  DatabaseServices();

  // reference for the collections in firestore database
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection("users");

  //updating user data
  Future updateUserData(BuildContext context, String userId, String userName,
      String email) async {
    try {
      await userCollection.doc(userId).set(
        {
          "userId": userId,
          "userName": userName,
          "email": email,
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

  // //getting user data
  // Future getUserData(String userId) async {
  //   try {
  //     // QuerySnapshot snapshot = await userCollection.where("userId", isEqualTo: userId).get();
  //     // return snapshot;
  //     List userData = [];

  //     await userCollection.where("userId", isEqualTo: userId).get().then((value) {
  //       value.docs.forEach((element) {
  //         userData.add(element.data());
  //       });
  //     });
  //     return userData;
  //   } catch (e) {
  //     print(e);
  //   }
  // }

  // Future getAllUsersList() async {
  //   List allUsersList = [];
  //   List usersList = [];

  //   // print(currentlyLoggedUserId);
  //   try {
  //     log("getting users");
  //     await userCollection.get().then((value) {
  //       value.docs.forEach((element) {
  //         // print(".\n.\nelement ${user}");
  //         allUsersList.add(element.data());
  //       });
  //     });
  //     // log("List ${list.body}");

  //     //for removing currently logged in user from the list for displaying users

  //     for (var user in allUsersList) {
  //       final userId = user["userId"];

  //       if (userId != currentlyLoggedUserId) {
  //         usersList.add(user);
  //       }
  //     }
  //     // log("List of users are ${usersList}");
  //     return usersList;
  //   } catch (e) {
  //     print(e);
  //     return;
  //   }
  // }

  // Future getSpecificUsersList(List<String> specicUsersIdList) async {
  //   List allUsersList = [];
  //   List usersList = [];

  //   // print(currentlyLoggedUserId);
  //   try {
  //     log("getting users");
  //     await userCollection.get().then((value) {
  //       value.docs.forEach((element) {
  //         // print(".\n.\nelement ${user}");
  //         allUsersList.add(element.data());
  //       });
  //     });
  //     // log("List ${list.body}");

  //     //for removing currently logged in user from the list for displaying users

  //     for (var user in allUsersList) {
  //       final userId = user["userId"];

  //       if (specicUsersIdList.contains(userId) ) {
  //         usersList.add(user);
  //       }
  //     }
  //     // log("List of users are ${usersList}");
  //     return usersList;
  //   } catch (e) {
  //     print(e);
  //     return;
  //   }
  // }

  // Future getUserWithName(List usersList, String searchKey) async {
  //   List searchResult = [];

  //   try {
  //     // print("User id :${usersList[0]["userId"]}");
  //     for (var user in usersList) {
  //       // print("name : ${user["userName"]}");
  //       final userName = user["userName"].toString().toLowerCase();

  //       if (userName.contains(searchKey)) {
  //         log("found user $userName");
  //         searchResult.add(user);
  //       }
  //     }

  //     return searchResult;
  //   } catch (e) {
  //     print(e);
  //     return;
  //   }
  // }

  // Future followUser(String followingUserId) async {
  //   try {
  //     await userCollection.doc(currentlyLoggedUserId).update({
  //       "following": FieldValue.arrayUnion([followingUserId])
  //     });
  //   } catch (e) {}
  // }

  // Future getFollowingList(String userId) async {
  //   final userData = await getUserData(userId);
  //   print("following ids are : ${userData[0]["following"]}");
  //   final followingIds = userData[0]["following"];
  //   return followingIds;
  //   // final followingUsersList = await userCollection.where(FieldPath.documentId, whereIn: followingIds).get();
  //   // print("following list     : ${followingUsersList.toString()}");
  // }

  // Future getPostsList() async {
  //   final userData = await getUserData(currentlyLoggedUserId);
  //   print("following post urls : ${userData[0]["posts"]}");
  //   final postsList = userData[0]["posts"];
  // }
}
