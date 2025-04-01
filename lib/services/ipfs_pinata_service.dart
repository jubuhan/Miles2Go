import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:miles2go/services/blockchain_service.dart';

class IPFSPinataService {
  // Pinata API credentials - Replace these with your actual Pinata API keys
  final String _pinataApiKey = 'b93e22ea51ab8f5cbf78';
  final String _pinataSecretApiKey = 'bbc59913c234b3f35cea1e3adc600a2bf0f310be7043f28e22a5c1805f55db57';
  
  // Pinata API endpoint
  final String _pinJSONToIPFSUrl = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';
  
  // Firestore and Auth instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Blockchain service
  final BlockchainService _blockchainService = BlockchainService();
  bool _blockchainInitialized = false;
  
  // Initialize the service
  Future<void> initialize() async {
  if (!_blockchainInitialized) {
    print("Initializing Blockchain Service...");
    await _blockchainService.initialize();
    _blockchainInitialized = true;
    print("Blockchain Service Initialized");
  }
}

  
  // Listen for ride request status changes
  void listenForAcceptedRideRequests() async {
    print("Starting to listen for ride request status changes");
    
    // Initialize blockchain service
    await initialize();
    
    _firestore.collection('rideRequests').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final doc = change.doc;
        final data = doc.data();
        
        if (data != null && data['status'] == 'accepted') {
          final requestId = doc.id;
          
          // Check if already uploaded
          if (data['ipfsCid'] == null) {
            print("Found accepted ride request: $requestId");
            uploadRideRequestToIPFS(requestId, data);
          } else {
            print("Request $requestId already has IPFS CID: ${data['ipfsCid']}");
          }
        }
      }
    }, onError: (error) {
      print("Error listening to ride requests: $error");
    });
  }
  
  // Upload a ride request to IPFS with only essential data
  Future<void> uploadRideRequestToIPFS(String requestId, Map<String, dynamic> requestData) async {
    try {
      print("Starting upload for request $requestId");
      
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in, cannot upload");
        return;
      }
      
      // Get the ride details
      final rideId = requestData['rideId'] as String? ?? '';
      if (rideId.isEmpty) {
        print("No ride ID found for request $requestId");
        return;
      }
      
      print("Fetching ride data for ride $rideId");
      final rideDoc = await _firestore.collection('publishedRides').doc(rideId).get();
      if (!rideDoc.exists) {
        print("Ride $rideId not found");
        return;
      }
      
      final rideData = rideDoc.data() as Map<String, dynamic>;
      
      // Extract only essential ride details
      final cleanRideData = _extractEssentialRideData(rideData);
      
      // Extract only essential request details
      final cleanRequestData = _extractEssentialRequestData(requestData);
      final blockchainCID = await _blockchainService.getRideCIDFromBlockchain(rideId);
if (blockchainCID != null) {
    print("Blockchain CID for ride $rideId: $blockchainCID");
} else {
    print("Error: No CID found on blockchain for ride $rideId");
}

      
      // Combine data for IPFS but keep it minimal
      final ipfsData = {
        'requestId': requestId,
        'rideId': rideId,
        'request': cleanRequestData,
        'ride': cleanRideData,
        'timestamp': DateTime.now().toIso8601String()
      };
      
      print("Uploading clean data to IPFS");
      
      // Upload to IPFS
      final result = await _uploadToIPFS(ipfsData);
      
      if (result['success']) {
        final cid = result['cid'];
        print("Successfully uploaded to IPFS with CID: $cid");
        
        // Store CID in Firebase
        await _storeIPFSReference(user.uid, rideId, requestId, cid);
        
        print("CID reference stored successfully");
        
        // Store CID on blockchain
        print("Storing CID on blockchain...");
        final txHash = await _blockchainService.storeRideCIDOnBlockchain(rideId, cid);
        
        if (txHash != null) {
          print("Successfully stored CID on blockchain with transaction: $txHash");
          
          // Update the request with blockchain transaction info
          await _firestore.collection('rideRequests').doc(requestId).update({
            'blockchainTxHash': txHash,
            'blockchainTimestamp': FieldValue.serverTimestamp()
          });
          
          print("Ride request updated with blockchain transaction info");
        } else {
          print("Failed to store CID on blockchain");
        }
      } else {
        print("Failed to upload to IPFS: ${result['message']}");
      }
    } catch (e) {
      print("Error in uploadRideRequestToIPFS: $e");
    }
  }
  
  // Extract only essential ride data for IPFS
  Map<String, dynamic> _extractEssentialRideData(Map<String, dynamic> rideData) {
    final cleanData = <String, dynamic>{};
    
    // Include only important ride fields
    final fieldsToInclude = [
      'from', 'to', 'date', 'time', 'pricePerSeat', 
      'totalSeats', 'bookedSeats', 'driverName', 'vehicleDetails', 
      'routeDistance', 'routeDuration'
    ];
    
    for (var field in fieldsToInclude) {
      if (rideData.containsKey(field)) {
        var value = rideData[field];
        
        // Convert complex types to simple ones
        if (value is Timestamp) {
          cleanData[field] = value.toDate().toIso8601String();
        } else if (value is Map) {
          // For complex maps like from/to/vehicleDetails,
          // extract only needed info
          if (field == 'from' || field == 'to') {
            cleanData[field] = {
              'name': value['name'] ?? 'Unknown',
              'latitude': value['latitude'] ?? 0.0,
              'longitude': value['longitude'] ?? 0.0,
            };
          } else if (field == 'vehicleDetails') {
            cleanData[field] = {
              'vehicleName': value['vehicleName'] ?? 'Unknown',
              'plate': value['plate'] ?? 'Unknown',
              'model': value['model'] ?? 'Unknown',
              'seats': value['seats'] ?? 0,
              'vehicleType': value['vehicleType'] ?? 'car',
            };
          } else {
            cleanData[field] = value;
          }
        } else {
          cleanData[field] = value;
        }
      }
    }
    
    return cleanData;
  }
  
  // Extract only essential request data for IPFS
  Map<String, dynamic> _extractEssentialRequestData(Map<String, dynamic> requestData) {
    final cleanData = <String, dynamic>{};
    
    // Include only important request fields
    final fieldsToInclude = [
      'date', 'passengerName', 'passengerEmail', 'passengerContact',
      'price', 'pickupLocation', 'dropoffLocation', 'status',
      'acceptedAt', 'routeDistance', 'routeDuration', 'seats'
    ];
    
    for (var field in fieldsToInclude) {
      if (requestData.containsKey(field)) {
        var value = requestData[field];
        
        // Convert complex types to simple ones
        if (value is Timestamp) {
          cleanData[field] = value.toDate().toIso8601String();
        } else if (value is Map && (field == 'pickupLocation' || field == 'dropoffLocation')) {
          cleanData[field] = {
            'name': value['name'] ?? 'Unknown',
            'latitude': value['latitude'] ?? 0.0,
            'longitude': value['longitude'] ?? 0.0,
          };
        } else {
          cleanData[field] = value;
        }
      }
    }
    
    return cleanData;
  }
  
  // Upload data to IPFS Pinata
  Future<Map<String, dynamic>> _uploadToIPFS(Map<String, dynamic> data) async {
    try {
      // Prepare data for pinning
      final body = {
        'pinataOptions': {
          'cidVersion': 1
        },
        'pinataMetadata': {
          'name': 'Ride_${data['rideId']}_${DateTime.now().toIso8601String()}'
        },
        'pinataContent': data
      };
      
      // Make sure the JSON is properly formatted
      final jsonString = jsonEncode(body);
      print("JSON body length: ${jsonString.length}");
      
      // Make API request to Pinata
      final response = await http.post(
        Uri.parse(_pinJSONToIPFSUrl),
        headers: {
          'Content-Type': 'application/json',
          'pinata_api_key': _pinataApiKey,
          'pinata_secret_api_key': _pinataSecretApiKey
        },
        body: jsonString
      );
      
      print("Pinata API response status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final cid = responseData['IpfsHash'];
        
        return {
          'success': true,
          'cid': cid,
          'ipfsUrl': 'https://gateway.pinata.cloud/ipfs/$cid'
        };
      } else {
        return {
          'success': false,
          'message': 'Pinata API error: ${response.statusCode} - ${response.body}'
        };
      }
    } catch (e) {
      print("Error in _uploadToIPFS: $e");
      return {
        'success': false,
        'message': 'Error uploading to IPFS: $e'
      };
    }
  }
  
  // Store CID reference in Firebase
  Future<void> _storeIPFSReference(String userId, String rideId, String requestId, String cid) async {
    try {
      // Update ride request with the CID
      await _firestore.collection('rideRequests').doc(requestId).update({
        'ipfsCid': cid,
        'ipfsUploadedAt': FieldValue.serverTimestamp()
      });
      
      // Also store in a dedicated collection for reference
      await _firestore.collection('ipfsReferences').add({
        'userId': userId,
        'rideId': rideId,
        'requestId': requestId,
        'cid': cid,
        'timestamp': FieldValue.serverTimestamp()
      });
    } catch (e) {
      print("Error storing CID reference: $e");
      throw Exception('Failed to store IPFS reference: $e');
    }
  }
  
  // Verify a CID on the blockchain
  Future<bool> verifyCIDOnBlockchain(String rideId) async {
    try {
      await initialize();
      
      // Get the CID from Firebase
      final querySnapshot = await _firestore
          .collection('ipfsReferences')
          .where('rideId', isEqualTo: rideId)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isEmpty) {
        print("No IPFS reference found for ride $rideId");
        return false;
      }
      
      final storedCID = querySnapshot.docs.first.data()['cid'];
      
      // Get the CID from blockchain
      final blockchainCID = await _blockchainService.getRideCIDFromBlockchain(rideId);
      
      if (blockchainCID == null) {
        print("No CID found on blockchain for ride $rideId");
        return false;
      }
      
      // Compare the CIDs
      final match = storedCID == blockchainCID;
      print("CID verification for ride $rideId: ${match ? 'MATCH' : 'MISMATCH'}");
      return match;
    } catch (e) {
      print("Error verifying CID on blockchain: $e");
      return false;
    }
  }
}