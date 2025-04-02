import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../screens/passenger_ride_tracking_screen.dart';
import 'package:miles2go/screens/published_ride_details_screen.dart';
import 'package:miles2go/screens/manage_ride_requests_screen.dart';
import 'package:miles2go/screens/waiting_confirmation_screen.dart';
import './bottom_navigation.dart';

class MyRidesPage extends StatefulWidget {
  final int initialTabIndex;
  
  const MyRidesPage({
    Key? key,
    this.initialTabIndex = 0, // Default to the Published tab
  }) : super(key: key);

  @override
  State<MyRidesPage> createState() => _MyRidesPageState();
}

class _MyRidesPageState extends State<MyRidesPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 2; // Set to 2 for My Rides tab
  late TabController _tabController;
  bool _isLoading = true;
  String _userId = '';
  
  // Streams for real-time updates
  Stream<QuerySnapshot>? _publishedRidesStream;
  Stream<QuerySnapshot>? _requestedRidesStream;
  
  // Add these variables for ride started notifications
  StreamSubscription<QuerySnapshot>? _rideRequestsSubscription;
  Map<String, bool> _hasShownRideStartedAlert = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _getUserId();
  }
  
  Future<void> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
        _isLoading = false;
      });
      
      // Set up simple streams to avoid index issues
      _setupStreams();
      
      // Listen for ride updates
      _listenForRideUpdates();
    } else {
      setState(() {
        _isLoading = false;
      });
      _showError('You must be logged in to view your rides');
    }
  }
  
  void _listenForRideUpdates() {
    // Cancel existing subscription if any
    _rideRequestsSubscription?.cancel();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _rideRequestsSubscription = FirebaseFirestore.instance
      .collection('rideRequests')
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots()
      .listen((snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final requestId = doc.id;
          
          // Check if the ride has started and we haven't shown an alert for it yet
          if (data['rideStarted'] == true && 
              (!_hasShownRideStartedAlert.containsKey(requestId) || 
               _hasShownRideStartedAlert[requestId] != true)) {
            
            // Mark that we've shown an alert for this ride
            _hasShownRideStartedAlert[requestId] = true;
            
            // Show an alert to the user
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Your ride has started!'),
                  content: const Text('The driver is on the way to pick you up. Would you like to track their location?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('LATER'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to tracking screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PassengerRideTrackingScreen(
                              rideId: data['rideId'],
                              locationDocId: data['locationDocId'] ?? '',
                              pickupLocation: data['passengerPickup'] ?? data['from'] ?? '',
                            ),
                          ),
                        );
                      },
                      child: const Text('TRACK NOW'),
                    ),
                  ],
                ),
              );
            }
          }
        }
      });
  }
  
  void _setupStreams() {
    if (_userId.isEmpty) return;
    
    // Simple query that doesn't require a composite index
    _publishedRidesStream = FirebaseFirestore.instance
        .collection('publishedRides')
        .where('userId', isEqualTo: _userId)
        .snapshots();
    
    // Simple query that doesn't require a composite index
    _requestedRidesStream = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('userId', isEqualTo: _userId)
        .snapshots();
  }
  
  Future<Map<String, dynamic>?> _getRideData(String rideId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(rideId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching ride data: $e');
    }
    return null;
  }
  
  Future<int> _getPendingRequestsCount(String rideId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rideRequests')
          .where('rideId', isEqualTo: rideId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting pending requests: $e');
      return 0;
    }
  }
  
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    setState(() {
      _selectedIndex = index;
    });
    
    // Navigation handled by the bottom nav component
  }
  
  void _viewPublishedRideDetails(String rideId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublishedRideDetailsScreen(rideId: rideId),
      ),
    );
  }
  
  void _viewRideRequests(String rideId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageRideRequestsScreen(rideId: rideId),
      ),
    );
  }
  
  void _viewRequestDetails(Map<String, dynamic> request) {
    // Get passenger's custom pickup and dropoff locations
    final String from = request['from'] ?? 'Unknown';
    final String to = request['to'] ?? 'Unknown';
    final String passengerPickup = request['passengerPickup'] ?? from;
    final String passengerDropoff = request['passengerDropoff'] ?? to;
    
    // Check if ride is started and has location tracking info
    if (request['rideStarted'] == true && request['locationDocId'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PassengerRideTrackingScreen(
            rideId: request['rideId'] ?? '',
            locationDocId: request['locationDocId'] ?? '',
            pickupLocation: passengerPickup,
          ),
        ),
      );
      return;
    }
    
    // If the ride data exists, we can show the waiting confirmation screen
    if (request.containsKey('rideData') && request['rideData'] != null) {
      final rideData = request['rideData'] as Map<String, dynamic>;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingConfirmationScreen(
            rideId: request['rideId'] ?? '',
            driverName: request['driverName'] ?? 'Unknown Driver',
            from: from,
            to: to,
            date: request['date'] ?? '',
            time: request['time'] ?? '',
            vehicle: _getVehicleDescription(rideData),
            price: '₹${request['price'] ?? "0"}',
            passengers: '${request['requestedSeats'] ?? "1"}',
            passengerPickup: passengerPickup,
            passengerDropoff: passengerDropoff,
          ),
        ),
      );
    } else {
      // Just show a simple dialog with request details
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Status', request['status'] ?? 'Unknown'),
              const SizedBox(height: 8),
              _buildDetailRow('Driver', request['driverName'] ?? 'Unknown'),
              const SizedBox(height: 16),
              
              // Show passenger-specific pickup/dropoff
              Text(
                'Your Trip:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              _buildDetailRow('Pickup', passengerPickup),
              const SizedBox(height: 8),
              _buildDetailRow('Dropoff', passengerDropoff),
              const SizedBox(height: 16),
              
              // Show ride from/to if different
              if (passengerPickup != from || passengerDropoff != to) ...[
                Text(
                  'Ride Route:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                if (passengerPickup != from)
                  _buildDetailRow('Ride From', from),
                if (passengerPickup != from)
                  const SizedBox(height: 8),
                if (passengerDropoff != to)
                  _buildDetailRow('Ride To', to),
                if (passengerDropoff != to)
                  const SizedBox(height: 16),
              ],
              
              _buildDetailRow('Date', request['date'] ?? 'Unknown'),
              const SizedBox(height: 8),
              _buildDetailRow('Time', request['time'] ?? 'Unknown'),
              const SizedBox(height: 8),
              _buildDetailRow('Price', '₹${request['price'] ?? "0"}'),
              const SizedBox(height: 8),
              _buildDetailRow('Requested Seats', '${request['requestedSeats'] ?? "1"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
  
  String _getVehicleDescription(Map<String, dynamic> rideData) {
    if (rideData.containsKey('vehicleDetails')) {
      final vehicleDetails = rideData['vehicleDetails'] as Map<String, dynamic>?;
      if (vehicleDetails != null) {
        final vehicleName = vehicleDetails['vehicleName'] ?? '';
        final model = vehicleDetails['model'] ?? '';
        
        return vehicleName.isNotEmpty 
            ? '$vehicleName ($model)' 
            : model;
      }
    }
    return 'Unknown vehicle';
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('My Rides'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'PUBLISHED'),
            Tab(text: 'REQUESTED'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Force refresh
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Published Rides Tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPublishedRidesStreamView(),
          
          // Requested Rides Tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildRequestedRidesStreamView(),
        ],
      ),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPublishedRidesStreamView() {
    if (_publishedRidesStream == null) {
      return _buildEmptyState('You have not published any rides yet.');
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _publishedRidesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('You have not published any rides yet.');
        }
        
        // Sort the documents manually (instead of in the query)
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            // Sort by createdAt if available
            if (aData.containsKey('createdAt') && bData.containsKey('createdAt')) {
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              
              if (aTime != null && bTime != null) {
                return bTime.compareTo(aTime); // Descending order
              }
            }
            
            // Fallback to date field
            if (aData.containsKey('date') && bData.containsKey('date')) {
              return (bData['date'] ?? '').toString().compareTo((aData['date'] ?? '').toString());
            }
            
            return 0;
          });
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return FutureBuilder<int>(
              future: _getPendingRequestsCount(doc.id),
              builder: (context, requestSnapshot) {
                final pendingCount = requestSnapshot.data ?? 0;
                
                return _buildPublishedRideCard({
                  'id': doc.id,
                  ...data,
                  'pendingRequests': pendingCount
                });
              }
            );
          },
        );
      },
    );
  }
  
  Widget _buildRequestedRidesStreamView() {
    if (_requestedRidesStream == null) {
      return _buildEmptyState('You have not requested any rides yet.');
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _requestedRidesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('You have not requested any rides yet.');
        }
        
        // Sort manually
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            // Sort by requestedAt if available
            if (aData.containsKey('requestedAt') && bData.containsKey('requestedAt')) {
              final aTime = aData['requestedAt'] as Timestamp?;
              final bTime = bData['requestedAt'] as Timestamp?;
              
              if (aTime != null && bTime != null) {
                return bTime.compareTo(aTime); // Descending order
              }
            }
            
            // Fallback to date field
            if (aData.containsKey('date') && bData.containsKey('date')) {
              return (bData['date'] ?? '').toString().compareTo((aData['date'] ?? '').toString());
            }
            
            return 0;
          });
        
        final futureList = docs.map((doc) async {
          final requestData = doc.data() as Map<String, dynamic>;
          // Fetch the associated ride data if available
          Map<String, dynamic>? rideData;
          if (requestData.containsKey('rideId') && requestData['rideId'] != null) {
            rideData = await _getRideData(requestData['rideId']);
          }
          
          return {
            'id': doc.id,
            ...requestData,
            'rideData': rideData,
          };
        }).toList();
        
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(futureList),
          builder: (context, futureSnapshot) {
            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (!futureSnapshot.hasData || futureSnapshot.data!.isEmpty) {
              return _buildEmptyState('You have not requested any rides yet.');
            }
            
            final requests = futureSnapshot.data!;
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                return _buildRequestedRideCard(requests[index]);
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildPublishedRideCard(Map<String, dynamic> ride) {
    // Your existing implementation
    final String from = ride['from']?['name'] ?? 'Unknown';
    final String to = ride['to']?['name'] ?? 'Unknown';
    final String date = ride['date'] ?? 'Unknown';
    final String time = ride['time'] ?? 'Unknown';
    final String status = ride['status'] ?? 'active';
    final bool isActive = status == 'active';
    
    // Count pending requests for this ride
    final pendingRequests = ride['pendingRequests'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewPublishedRideDetails(ride['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : status.toUpperCase(),
                      style: TextStyle(
                        color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '$date, $time',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Route
              Row(
                children: [
                  const Icon(Icons.circle_outlined, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      from,
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
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      to,
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
              
              const SizedBox(height: 12),
              
              // Price and seats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sepolia eth ${ride['amount'] ?? "0"}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.event_seat, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${ride['availableSeats'] ?? "0"}/${ride['passengerCount'] ?? "0"} seats',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewPublishedRideDetails(ride['id']),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('DETAILS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _viewRideRequests(ride['id']),
                      icon: Badge(
                        label: Text(
                          '$pendingRequests',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        isLabelVisible: pendingRequests > 0,
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.people, size: 16),
                      ),
                      label: const Text('REQUESTS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRequestedRideCard(Map<String, dynamic> request) {
    // Your existing implementation
    final String status = request['status'] ?? 'pending';
    final String from = request['from'] ?? 'Unknown';
    final String to = request['to'] ?? 'Unknown';
    
    // Get the passenger-specific pickup and dropoff if available
    final String passengerPickup = request['passengerPickup'] ?? from;
    final String passengerDropoff = request['passengerDropoff'] ?? to;
    
    final String date = request['date'] ?? 'Unknown';
    final String time = request['time'] ?? 'Unknown';
    final String driverName = request['driverName'] ?? 'Unknown Driver';
    final int requestedSeats = request['requestedSeats'] ?? 1;
    
    // Status color
    Color statusColor;
    if (status == 'pending') {
      statusColor = Colors.orange;
    } else if (status == 'accepted') {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.red;
    }
    
    // Add a "Track" button if ride has started
    final bool rideStarted = request['rideStarted'] == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and driver
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      rideStarted ? 'STARTED' : status.toUpperCase(),
                      style: TextStyle(
                        color: rideStarted ? Colors.green : statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Driver: $driverName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Route - Show passenger-specific pickup/dropoff
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
                    
                    // Show ride endpoints if different from passenger pickup/dropoff
                    if (passengerPickup != from) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 24),
                          Text(
                            '(Ride from: $from)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
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
                    
                    // Show ride endpoints if different from passenger pickup/dropoff
                    if (passengerDropoff != to) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 24),
                          Text(
                            '(Ride to: $to)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Details// Details
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(date),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(time),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.people, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$requestedSeats'),
            ],
          ),
        ],
      ),
      
      const SizedBox(height: 12),
      
      // Action button - Change to Track button if ride has started
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _viewRequestDetails(request),
          style: ElevatedButton.styleFrom(
            backgroundColor: rideStarted ? Colors.green : Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Text(
            rideStarted ? 'TRACK RIDE' : 'VIEW DETAILS',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  ),
),
      ),
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _rideRequestsSubscription?.cancel();
    super.dispose();
  }
}