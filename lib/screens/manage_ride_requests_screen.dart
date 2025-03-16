import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './bottom_navigation.dart';

class ManageRideRequestsScreen extends StatefulWidget {
  final String? rideId; // Optional - if provided, only show requests for this ride

  const ManageRideRequestsScreen({
    Key? key,
    this.rideId,
  }) : super(key: key);

  @override
  State<ManageRideRequestsScreen> createState() => _ManageRideRequestsScreenState();
}

class _ManageRideRequestsScreenState extends State<ManageRideRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  int _selectedIndex = 2; // Set to 2 for Rides tab
  String _userId = '';
  
  // Stream for real-time updates
  Stream<QuerySnapshot>? _requestsStream;

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _setupRequestsStream();
    } else {
      setState(() {
        _isLoading = false;
      });
      _showError('You must be logged in to view requests');
    }
  }

  void _setupRequestsStream() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<String> userRideIds = [];
      
      // If we have a specific rideId, use it directly
      if (widget.rideId != null) {
        userRideIds.add(widget.rideId!);
      } else {
        // Otherwise get all ride IDs published by this user
        final QuerySnapshot ridesSnapshot = await FirebaseFirestore.instance
            .collection('publishedRides')
            .where('userId', isEqualTo: _userId)
            .get();
            
        userRideIds = ridesSnapshot.docs.map((doc) => doc.id).toList();
      }

      if (userRideIds.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Simple query without composite index for real-time updates
      if (userRideIds.length <= 10) {
        // Firestore has a limit of 10 items in "whereIn" queries
        _requestsStream = FirebaseFirestore.instance
            .collection('rideRequests')
            .where('rideId', whereIn: userRideIds)
            .snapshots();
      } else {
        // If more than 10 rides, we'll just use the first 10
        // In a real app, you might want to implement pagination
        _requestsStream = FirebaseFirestore.instance
            .collection('rideRequests')
            .where('rideId', whereIn: userRideIds.sublist(0, 10))
            .snapshots();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error setting up requests stream: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load ride requests');
    }
  }

  Future<void> _handleRequestAction(String requestId, String action) async {
    // Find the request in our list
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        _showError('Request not found');
        return;
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final rideId = requestData['rideId'];
      final requestedSeats = requestData['requestedSeats'] ?? 1;
      
      // Update the request status
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(requestId)
          .update({
        'status': action,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (action == 'rejected') {
        // If rejected, restore the available seats
        await FirebaseFirestore.instance
            .collection('publishedRides')
            .doc(rideId)
            .update({
          'availableSeats': FieldValue.increment(requestedSeats),
          'bookedSeats': FieldValue.increment(-requestedSeats),
        });
      }

      _showSuccess(action == 'accepted' 
          ? 'Ride request accepted!' 
          : 'Ride request rejected');
      
    } catch (e) {
      print('Error updating request: $e');
      _showError('Failed to process request');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle navigation if needed
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
        title: Text(
          widget.rideId != null ? 'Ride Requests' : 'Manage Ride Requests',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _setupRequestsStream,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildRequestsList(),
      ),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No pending ride requests',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see requests here when someone wants to join your ride',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requestsStream == null) {
      return _buildEmptyState();
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }
        
        // Filter for pending requests
        final pendingDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).toList();
        
        if (pendingDocs.isEmpty) {
          return _buildEmptyState();
        }
        
        // Sort by requested date/time
        pendingDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aTime = aData['requestedAt'] as Timestamp?;
          final bTime = bData['requestedAt'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime); // Descending order - newest first
        });
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingDocs.length,
          itemBuilder: (context, index) {
            final doc = pendingDocs[index];
            final requestData = doc.data() as Map<String, dynamic>;
            
            return FutureBuilder(
              future: _getRideData(requestData['rideId']),
              builder: (context, rideSnapshot) {
                Map<String, dynamic>? rideData;
                if (rideSnapshot.hasData) {
                  rideData = rideSnapshot.data as Map<String, dynamic>?;
                }
                
                return _buildRequestCard({
                  'requestId': doc.id,
                  'requestData': requestData,
                  'rideData': rideData,
                });
              },
            );
          },
        );
      },
    );
  }
  
  Future<Map<String, dynamic>?> _getRideData(String rideId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(rideId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Error fetching ride data: $e');
    }
    return null;
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestData = request['requestData'] as Map<String, dynamic>;
    final rideData = request['rideData'] as Map<String, dynamic>?;
    final requestId = request['requestId'];
    
    // Extract request details
    final userName = requestData['userName'] ?? 'Unknown User';
    final String from = requestData['from'] ?? '';
    final String to = requestData['to'] ?? '';
    
    // Get passenger's specific pickup and dropoff locations
    final String passengerPickup = requestData['passengerPickup'] ?? from;
    final String passengerDropoff = requestData['passengerDropoff'] ?? to;
    
    final date = requestData['date'] ?? '';
    final time = requestData['time'] ?? '';
    final requestedSeats = requestData['requestedSeats'] ?? 1;
    final price = requestData['price'] != null ? '₹${requestData['price']}' : '';
    final requestedAt = requestData['requestedAt'] != null
        ? (requestData['requestedAt'] as Timestamp).toDate()
        : DateTime.now();
    
    // Format the request time
    final formattedTime = '${requestedAt.hour}:${requestedAt.minute.toString().padLeft(2, '0')}';
    final formattedDate = '${requestedAt.day}/${requestedAt.month}/${requestedAt.year}';
    
    // Get ride vehicle details
    String vehicle = 'Unknown vehicle';
    if (rideData != null && rideData.containsKey('vehicleDetails')) {
      final vehicleDetails = rideData['vehicleDetails'] as Map<String, dynamic>?;
      if (vehicleDetails != null) {
        final vehicleName = vehicleDetails['vehicleName'] ?? '';
        final vehicleModel = vehicleDetails['model'] ?? '';
        vehicle = vehicleName.isNotEmpty ? '$vehicleName ($vehicleModel)' : vehicleModel;
      }
    }
    
    // Get passenger contact if available
    final contact = requestData['contact'] ?? 'Not provided';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade400,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Requested at $formattedTime on $formattedDate',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$requestedSeats',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Route details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Passenger pickup/dropoff
                  Text(
                    'Passenger Locations:',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.circle_outlined, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          passengerPickup,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          passengerDropoff,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Show ride endpoints if different
                  if (passengerPickup != from || passengerDropoff != to) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Your Ride Route:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              const Icon(Icons.circle_outlined, color: Colors.black38, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  from,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              const Icon(Icons.location_on, color: Colors.black38, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  to,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(child: _buildDetailRow('Date', date)),
                      if (time.isNotEmpty)
                        Expanded(child: _buildDetailRow('Time', time)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildDetailRow('Vehicle', vehicle)),
                      if (price.isNotEmpty)
                        Expanded(child: _buildDetailRow('Price', price)),
                    ],
                  ),
                  
                  // Contact info
                  if (contact != 'Not provided') ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildDetailRow('Contact', contact),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequestAction(requestId, 'rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('REJECT'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequestAction(requestId, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('ACCEPT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}