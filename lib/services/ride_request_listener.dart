// import 'dart:async';
// import 'dart:developer';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:miles2go/services/ipfs_pinata_service.dart';

// class RideRequestListener {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final IPFSPinataService _ipfsService = IPFSPinataService();
  
//   StreamSubscription? _requestSubscription;
  
//   // Start listening for all ride requests with status changes
//   void startListening() {
//     final user = _auth.currentUser;
//     if (user == null) {
//       log('No user logged in, cannot start listening for ride requests');
//       return;
//     }
    
//     log('Starting to listen for ride request status changes');
    
//     // Listen to ride requests collection for status changes
//     _requestSubscription = _firestore
//         .collection('rideRequests')
//         .snapshots()
//         .listen((snapshot) {
//           _processRideRequestChanges(snapshot);
//         });
//   }
  
//   // Process any changes to ride requests
//   void _processRideRequestChanges(QuerySnapshot snapshot) {
//     for (var change in snapshot.docChanges) {
//       final requestDoc = change.doc;
//       final requestData = requestDoc.data() as Map<String, dynamic>?;
      
//       if (requestData == null) continue;
      
//       // Check if status was changed to 'accepted'
//       if (requestData.containsKey('status') && requestData['status'] == 'accepted') {
//         // Check if already has CID
//         if (requestData.containsKey('ipfsCid') && requestData['ipfsCid'] != null) {
//           log('Request ${requestDoc.id} already has IPFS CID, skipping upload');
//           continue;
//         }
        
//         _uploadRequestToIPFS(requestDoc.id, requestData);
//       }
//     }
//   }
  
//   // Upload request data to IPFS
//   Future<void> _uploadRequestToIPFS(String requestId, Map<String, dynamic> requestData) async {
//     try {
//       log('Detected accepted ride request: $requestId, uploading to IPFS');
      
//       final user = _auth.currentUser;
//       if (user == null) return;
      
//       // Get ride details
//       final rideId = requestData['rideId'] as String? ?? '';
//       if (rideId.isEmpty) {
//         log('No ride ID found for request $requestId');
//         return;
//       }
      
//       final rideDoc = await _firestore.collection('publishedRides').doc(rideId).get();
//       if (!rideDoc.exists) {
//         log('Ride $rideId not found for request $requestId');
//         return;
//       }
      
//       final rideData = rideDoc.data() as Map<String, dynamic>;
      
//       // Combine data for IPFS upload
//       final combinedData = {
//         'requestId': requestId,
//         'rideId': rideId,
//         'requestData': requestData,
//         'rideData': rideData,
//         'timestamp': FieldValue.serverTimestamp(),
//         'userId': user.uid
//       };
      
//       // Upload to IPFS
//       final ipfsResult = await _ipfsService.uploadRideToIPFS(combinedData);
      
//       if (ipfsResult['success']) {
//         // Store CID reference
//         await _ipfsService.storeIPFSReference(
//           user.uid,
//           rideId,
//           requestId,
//           ipfsResult['cid']
//         );
        
//         log('Successfully uploaded request $requestId to IPFS with CID: ${ipfsResult['cid']}');
//       } else {
//         log('Failed to upload request $requestId to IPFS: ${ipfsResult['message']}');
//       }
//     } catch (e) {
//       log('Error processing ride request $requestId: $e');
//     }
//   }
  
//   // Stop listening
//   void stopListening() {
//     _requestSubscription?.cancel();
//     _requestSubscription = null;
//     log('Stopped listening for ride request status changes');
//   }
// }