import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RideHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save ride to user's history for both passenger and driver
  Future<void> saveRideToHistory({
    required String rideId,
    required String requestId,
    bool isDriver = false,
  }) async {
    try {
      // Get current user ID
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the ride details
      final rideDoc = await _firestore.collection('publishedRides').doc(rideId).get();
      if (!rideDoc.exists) return;
      
      final rideData = rideDoc.data() as Map<String, dynamic>;
      
      // Get request details if this is a passenger
      Map<String, dynamic>? requestData;
      if (!isDriver && requestId.isNotEmpty) {
        final requestDoc = await _firestore.collection('rideRequests').doc(requestId).get();
        if (requestDoc.exists) {
          requestData = requestDoc.data() as Map<String, dynamic>;
        }
      }
      
      // Safely get values from maps
      final from = rideData['from'] is Map ? Map<String, dynamic>.from(rideData['from']) : {'name': 'Unknown location'};
      final to = rideData['to'] is Map ? Map<String, dynamic>.from(rideData['to']) : {'name': 'Unknown destination'};
      
      // Safe number handling
      num pricePerSeat = 0;
      if (rideData['pricePerSeat'] is num) {
        pricePerSeat = rideData['pricePerSeat'];
      } else if (rideData['pricePerSeat'] is String) {
        pricePerSeat = double.tryParse(rideData['pricePerSeat']) ?? 0;
      }
      
      // Build history entry
      Map<String, dynamic> historyEntry = {
        'rideId': rideId,
        'timestamp': FieldValue.serverTimestamp(),
        'from': from,
        'to': to,
        'date': rideData['date'],
        'time': rideData['time'],
        'vehicleDetails': rideData['vehicleDetails'] ?? {},
      };
      
      // Safely handle price
      if (isDriver) {
        historyEntry['price'] = pricePerSeat;
      } else {
        num price = pricePerSeat;
        if (requestData != null && requestData['price'] is num) {
          price = requestData['price'];
        } else if (requestData != null && requestData['price'] is String) {
          price = double.tryParse(requestData['price']) ?? pricePerSeat;
        }
        historyEntry['price'] = price;
      }
      
      historyEntry['paymentStatus'] = 'unpaid';
      
      // Add passenger-specific data
      if (!isDriver) {
        final driverId = rideData['userId'] is String ? rideData['userId'] : 
                        (rideData['driverId'] is String ? rideData['driverId'] : '');
        
        final pickupLocation = requestData != null && requestData['pickupLocation'] is Map ? 
                              requestData['pickupLocation'] : 
                              (requestData != null && requestData['passengerPickup'] is String ? 
                              {'name': requestData['passengerPickup']} : {'name': 'Unknown pickup'});
                              
        final dropoffLocation = requestData != null && requestData['dropoffLocation'] is Map ? 
                               requestData['dropoffLocation'] : 
                               (requestData != null && requestData['passengerDropoff'] is String ? 
                               {'name': requestData['passengerDropoff']} : {'name': 'Unknown dropoff'});
        
        historyEntry.addAll({
          'requestId': requestId,
          'driverName': rideData['driverName'],
          'driverId': driverId,
          'pickupLocation': pickupLocation,
          'dropoffLocation': dropoffLocation,
        });
      } 
      // Add driver-specific data
      else {
        // Get list of passengers for driver history
        List<Map<String, dynamic>> passengers = [];
        if (rideData.containsKey('acceptedPassengers') && rideData['acceptedPassengers'] is List) {
          for (var passenger in rideData['acceptedPassengers']) {
            if (passenger is Map<String, dynamic>) {
              passengers.add({
                'name': passenger['passengerName'],
                'id': passenger['userId'] ?? '',
                'requestId': passenger['requestId'] ?? '',
                'paymentStatus': 'unpaid',
              });
            }
          }
        }
        
        int bookedSeats = 0;
        if (rideData['bookedSeats'] is int) {
          bookedSeats = rideData['bookedSeats'];
        } else if (rideData['bookedSeats'] is String) {
          bookedSeats = int.tryParse(rideData['bookedSeats']) ?? passengers.length;
        } else {
          bookedSeats = passengers.length;
        }
        
        int totalSeats = 1;
        if (rideData['totalSeats'] is int) {
          totalSeats = rideData['totalSeats'];
        } else if (rideData['totalSeats'] is String) {
          totalSeats = int.tryParse(rideData['totalSeats']) ?? 1;
        }
        
        num totalEarnings = pricePerSeat * bookedSeats;
        
        historyEntry.addAll({
          'passengers': passengers,
          'totalSeats': totalSeats,
          'bookedSeats': bookedSeats,
          'totalEarnings': totalEarnings,
          'paidEarnings': 0,
        });
      }
      
      // Save to user's history collection
      await _firestore.collection('users').doc(user.uid).collection('rideHistory').doc(rideId).set(historyEntry);
      
      // Also update the main ride document to mark completion
      if (isDriver) {
        await _firestore.collection('publishedRides').doc(rideId).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'archived': true,
        });
      }
      
      print('Ride successfully saved to history');
    } catch (e) {
      print('Error saving ride to history: $e');
      throw Exception('Failed to save ride to history: $e');
    }
  }
  
  // Method to update payment status (can be called after payment is processed)
  Future<void> updatePaymentStatus({
    required String rideId,
    required String requestId,
    required bool isDriver,
    required String passengerId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update in passenger's history
      if (!isDriver) {
        await _firestore.collection('users').doc(user.uid).collection('rideHistory').doc(rideId).update({
          'paymentStatus': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
        });
      }
      // Update in driver's history for specific passenger
      else {
        // First get the current history doc
        final historyDoc = await _firestore.collection('users').doc(user.uid).collection('rideHistory').doc(rideId).get();
        if (!historyDoc.exists) return;
        
        final historyData = historyDoc.data() as Map<String, dynamic>;
        List<dynamic> passengers = historyData['passengers'] ?? [];
        
        // Find and update the passenger's payment status
        bool passengerFound = false;
        for (int i = 0; i < passengers.length; i++) {
          if ((passengers[i]['id'] ?? '') == passengerId || (passengers[i]['requestId'] ?? '') == requestId) {
            passengers[i]['paymentStatus'] = 'paid';
            passengerFound = true;
          }
        }
        
        // Only update if we found and modified the passenger
        if (passengerFound) {
          // Calculate how much has been paid
          int paidCount = 0;
          for (var passenger in passengers) {
            if ((passenger['paymentStatus'] ?? '') == 'paid') {
              paidCount++;
            }
          }
          
          // Get price safely
          num price = 0;
          if (historyData['price'] is num) {
            price = historyData['price'];
          } else if (historyData['price'] is String) {
            price = double.tryParse(historyData['price']) ?? 0;
          }
          
          // Update the document
          await _firestore.collection('users').doc(user.uid).collection('rideHistory').doc(rideId).update({
            'passengers': passengers,
            'paidEarnings': price * paidCount,
          });
        }
      }
      
      // Also update the ride request
      if (requestId.isNotEmpty) {
        await _firestore.collection('rideRequests').doc(requestId).update({
          'paymentStatus': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('Payment status updated successfully');
    } catch (e) {
      print('Error updating payment status: $e');
      throw Exception('Failed to update payment status: $e');
    }
  }
}