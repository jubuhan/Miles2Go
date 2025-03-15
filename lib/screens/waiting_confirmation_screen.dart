import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './bottom_navigation.dart';
import './my_rides_page.dart';

class WaitingConfirmationScreen extends StatefulWidget {
  final String rideId;
  final String driverName;
  final String from;
  final String to;
  final String date;
  final String time;
  final String vehicle;
  final String price;
  final String passengers;

  const WaitingConfirmationScreen({
    Key? key,
    required this.rideId,
    required this.driverName,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.vehicle,
    required this.price,
    required this.passengers,
  }) : super(key: key);

  @override
  State<WaitingConfirmationScreen> createState() => _WaitingConfirmationScreenState();
}

class _WaitingConfirmationScreenState extends State<WaitingConfirmationScreen> {
  // Navigation state
  int _selectedIndex = 1; // Set to 1 for Search tab
  bool _isRequesting = false;
  bool _isRequestSent = false;
  String _requestStatus = 'waiting';
  String _requestId = '';

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _sendRideRequest() async {
    if (_isRequestSent) return;

    setState(() {
      _isRequesting = true;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('You must be logged in to request a ride');
        setState(() {
          _isRequesting = false;
        });
        return;
      }

      // Get user's name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      String userName = 'Unknown User';
      if (userDoc.exists && userDoc.data()!.containsKey('userName')) {
        userName = userDoc.data()!['userName'];
      }

      // Create a new ride request
      final requestRef = await FirebaseFirestore.instance.collection('rideRequests').add({
        'rideId': widget.rideId,
        'userId': user.uid,
        'userName': userName,
        'driverName': widget.driverName,
        'from': widget.from,
        'to': widget.to,
        'date': widget.date,
        'time': widget.time,
        'requestedSeats': int.tryParse(widget.passengers) ?? 1,
        'price': widget.price.replaceAll('₹', ''),  // Remove the currency symbol
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Update the ride to reduce available seats
      await FirebaseFirestore.instance.collection('publishedRides').doc(widget.rideId).update({
        'availableSeats': FieldValue.increment(-(int.tryParse(widget.passengers) ?? 1)),
        'bookedSeats': FieldValue.increment(int.tryParse(widget.passengers) ?? 1),
      });

      setState(() {
        _isRequesting = false;
        _isRequestSent = true;
        _requestStatus = 'pending';
        _requestId = requestRef.id;
      });

      // Start listening for updates to the request
      _listenForRequestUpdates();
      
      // Show success message
      _showSuccess('Ride request sent successfully!');
      
      // Wait a moment before navigating to My Rides page
      Future.delayed(const Duration(seconds: 2), () {
        _navigateToRequestList();
      });

    } catch (e) {
      print('Error sending ride request: $e');
      setState(() {
        _isRequesting = false;
      });
      _showError('Failed to send ride request. Please try again.');
    }
  }
  
  void _navigateToRequestList() {
    // Navigate to the My Rides page and select the Requested tab
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MyRidesPage(initialTabIndex: 1), // 1 for the "REQUESTED" tab
      ),
      (route) => false, // Remove all previous routes from the stack
    );
  }

  void _listenForRequestUpdates() {
    if (_requestId.isEmpty) return;

    FirebaseFirestore.instance
        .collection('rideRequests')
        .doc(_requestId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('status')) {
          setState(() {
            _requestStatus = data['status'];
          });

          if (_requestStatus == 'accepted') {
            _showSuccess('Your ride request has been accepted!');
          } else if (_requestStatus == 'rejected') {
            _showError('Your ride request has been rejected.');

            // Restore the available seats in the ride
            FirebaseFirestore.instance.collection('publishedRides').doc(widget.rideId).update({
              'availableSeats': FieldValue.increment(int.tryParse(widget.passengers) ?? 1),
              'bookedSeats': FieldValue.increment(-(int.tryParse(widget.passengers) ?? 1)),
            });
          }
        }
      }
    });
  }

  void _cancelRequest() async {
    if (_requestId.isEmpty) return;

    try {
      // Update the request status
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(_requestId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Restore the available seats in the ride
      await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(widget.rideId)
          .update({
        'availableSeats': FieldValue.increment(int.tryParse(widget.passengers) ?? 1),
        'bookedSeats': FieldValue.increment(-(int.tryParse(widget.passengers) ?? 1)),
      });

      setState(() {
        _requestStatus = 'cancelled';
      });

      // Navigate to the request list
      _navigateToRequestList();
    } catch (e) {
      print('Error cancelling request: $e');
      _showError('Failed to cancel request. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status Indicator
                _buildStatusIndicator(),
                const SizedBox(height: 32),
                
                // Ride Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRideDetailRow('Driver', widget.driverName),
                      const SizedBox(height: 8),
                      _buildRideDetailRow('From', widget.from),
                      const SizedBox(height: 8),
                      _buildRideDetailRow('To', widget.to),
                      const SizedBox(height: 8),
                      _buildRideDetailRow('Date', widget.date),
                      if (widget.time.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildRideDetailRow('Time', widget.time),
                      ],
                      if (widget.vehicle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildRideDetailRow('Vehicle', widget.vehicle),
                      ],
                      if (widget.price.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildRideDetailRow('Price', widget.price),
                      ],
                      const SizedBox(height: 8),
                      _buildRideDetailRow('Passengers', widget.passengers),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                _buildActionButton(),
                if (_isRequestSent && _requestStatus == 'pending')
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextButton(
                      onPressed: _cancelRequest,
                      child: const Text(
                        'Cancel Request',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // View My Requests Button
                if (_isRequestSent)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextButton(
                      onPressed: _navigateToRequestList,
                      child: const Text(
                        'View My Requests',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      // Add the bottom navigation bar
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildStatusIndicator() {
    IconData iconData;
    Color iconColor;
    String statusText;

    if (_isRequesting) {
      iconData = Icons.hourglass_top;
      iconColor = Colors.blue;
      statusText = 'Sending request...';
    } else if (!_isRequestSent) {
      iconData = Icons.directions_car;
      iconColor = Colors.blue;
      statusText = 'Request a Ride';
    } else {
      switch (_requestStatus) {
        case 'pending':
          iconData = Icons.timer;
          iconColor = Colors.orange;
          statusText = 'Waiting for driver confirmation';
          break;
        case 'accepted':
          iconData = Icons.check_circle;
          iconColor = Colors.green;
          statusText = 'Ride confirmed!';
          break;
        case 'rejected':
          iconData = Icons.cancel;
          iconColor = Colors.red;
          statusText = 'Ride request rejected';
          break;
        case 'cancelled':
          iconData = Icons.cancel;
          iconColor = Colors.grey;
          statusText = 'Request cancelled';
          break;
        default:
          iconData = Icons.hourglass_top;
          iconColor = Colors.blue;
          statusText = 'Processing request...';
      }
    }

    return Column(
      children: [
        Icon(
          iconData,
          size: 80,
          color: iconColor,
        ),
        const SizedBox(height: 16),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRideDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isRequesting) {
      return const CircularProgressIndicator(color: Colors.blue);
    }

    if (!_isRequestSent) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _sendRideRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'SEND REQUEST',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Request already sent
    switch (_requestStatus) {
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to ride details or tracking screen
              // This would be implemented in a full app
              _showSuccess('Ride details will be available soon');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'VIEW RIDE DETAILS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      case 'rejected':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Go back to available rides
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'FIND ANOTHER RIDE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}