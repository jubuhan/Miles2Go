import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'waiting_confirmation_screen.dart';
import './bottom_navigation.dart';

class AvailableRidesScreen extends StatefulWidget {
  final String from;
  final String to;
  final String date;
  final String passengers;

  const AvailableRidesScreen({
    Key? key,
    required this.from,
    required this.to,
    required this.date,
    required this.passengers,
  }) : super(key: key);

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  int _selectedIndex = 1;
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableRides = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailableRides();
  }

  Future<void> _fetchAvailableRides() async {
    setState(() {
      _isLoading = true;
      _availableRides = [];
    });

    try {
      // Get all rides for the date
      final QuerySnapshot ridesSnapshot = await FirebaseFirestore.instance
          .collection('publishedRides')
          .where('date', isEqualTo: widget.date)
          .get();
      
      print('Found ${ridesSnapshot.docs.length} rides for date ${widget.date}');
      
      // Filter by route
      List<Map<String, dynamic>> matchingRides = [];
      
      for (var doc in ridesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check route match
        final bool routeMatches = simpleRouteMatch(data);
        
        if (routeMatches) {
          matchingRides.add({
            'id': doc.id,
            ...data,
          });
        }
      }
      
      setState(() {
        _availableRides = matchingRides;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Simple route matching function
  bool simpleRouteMatch(Map<String, dynamic> ride) {
    // 1. Extract all locations in the ride (origin, waypoints, destination)
    List<String> allLocations = [];
    
    // Add origin
    if (ride['from'] != null && ride['from']['name'] != null) {
      allLocations.add(ride['from']['name'].toString().toLowerCase());
    }
    
    // Add waypoints if any
    if (ride['intermediatePoints'] != null) {
      List<dynamic> waypoints = ride['intermediatePoints'];
      for (var point in waypoints) {
        if (point['name'] != null) {
          allLocations.add(point['name'].toString().toLowerCase());
        }
      }
    }
    
    // Add destination
    if (ride['to'] != null && ride['to']['name'] != null) {
      allLocations.add(ride['to']['name'].toString().toLowerCase());
    }
    
    // 2. Normalize search terms
    final String searchFrom = widget.from.toLowerCase();
    final String searchTo = widget.to.toLowerCase();
    
    // 3. Look for from/to matches in the route locations
    int fromIndex = -1;
    int toIndex = -1;
    
    for (int i = 0; i < allLocations.length; i++) {
      String location = allLocations[i];
      
      // Simple contains matching
      if (fromIndex == -1 && 
          (location.contains(searchFrom) || searchFrom.contains(location))) {
        fromIndex = i;
      }
      
      if (toIndex == -1 && 
          (location.contains(searchTo) || searchTo.contains(location))) {
        toIndex = i;
      }
    }
    
    // 4. Check if from and to are found in correct order
    return fromIndex != -1 && toIndex != -1 && fromIndex < toIndex;
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
        title: const Text(
          'Available Rides',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Journey Details Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
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
                    _buildJourneyDetail('From', widget.from),
                    const SizedBox(height: 8),
                    _buildJourneyDetail('To', widget.to),
                    const SizedBox(height: 8),
                    _buildJourneyDetail('Date', widget.date),
                    const SizedBox(height: 8),
                    _buildJourneyDetail('Passengers', widget.passengers),
                  ],
                ),
              ),
            ),
            
            // Available Rides Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AVAILABLE RIDES (${_isLoading ? "..." : _availableRides.length})',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchAvailableRides,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Rides List
            Expanded(
              child: _isLoading 
                ? _buildLoadingIndicator()
                : _availableRides.isEmpty
                  ? _buildNoRidesFound()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _availableRides.length,
                      itemBuilder: (context, index) {
                        final ride = _availableRides[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildRideCard(context, ride),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: 16),
          Text(
            'Finding available rides...',
            style: TextStyle(color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRidesFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_transfer, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No rides found for this route and date',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchAvailableRides,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // Build ride card
  Widget _buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    // Extract data safely
    String getSafe(dynamic data, List<String> path) {
      try {
        dynamic current = data;
        for (String key in path) {
          if (current is Map && current.containsKey(key)) {
            current = current[key];
          } else {
            return '';
          }
        }
        return current?.toString() ?? '';
      } catch (e) {
        return '';
      }
    }
    
    final String rideId = ride['id'] ?? '';
    final String name = getSafe(ride, ['userName']) != '' 
        ? getSafe(ride, ['userName']) 
        : 'Unknown Driver';
    final String fromLocation = getSafe(ride, ['from', 'name']);
    final String toLocation = getSafe(ride, ['to', 'name']);
    final String date = getSafe(ride, ['date']);
    final String time = getSafe(ride, ['time']) != '' 
        ? getSafe(ride, ['time']) 
        : 'Not specified';
    final String carModel = getSafe(ride, ['vehicleDetails', 'model']) != '' 
        ? getSafe(ride, ['vehicleDetails', 'model']) 
        : 'Unknown';
    final String vehicleName = getSafe(ride, ['vehicleDetails', 'vehicleName']);
    final String price = '₹${ride['amount'] ?? 0}';
    
    // Check if ride has intermediate stops
    bool hasIntermediateStops = false;
    if (ride.containsKey('intermediatePoints') && 
        ride['intermediatePoints'] is List && 
        (ride['intermediatePoints'] as List).isNotEmpty) {
      hasIntermediateStops = true;
    }
    
    return Container(
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
          // Driver and price
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
                      name,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      vehicleName.isNotEmpty ? '$vehicleName ($carModel)' : carModel,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Route info
          Container(
            padding: const EdgeInsets.all(8),
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
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fromLocation,
                        style: TextStyle(color: Colors.blue.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                // Show intermediate stops if any
                if (hasIntermediateStops) ...[
                  for (var point in ride['intermediatePoints'])
                    if (point is Map && point['name'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.more_vert, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                point['name'].toString(),
                                style: TextStyle(color: Colors.blue.shade800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
                
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        toLocation,
                        style: TextStyle(color: Colors.blue.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // If has intermediate stops, show a badge
          if (hasIntermediateStops)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.more_vert, color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Has stops',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Time and date
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.black54, size: 16),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today, color: Colors.black54, size: 16),
              const SizedBox(width: 4),
              Text(
                date,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Request Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _requestRide(ride),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'REQUEST RIDE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Streamlined request ride method without redundant selection
  void _requestRide(Map<String, dynamic> ride) {
    final String rideId = ride['id'] ?? '';
    final String driverName = ride['userName'] ?? 'Unknown Driver';
    final String fromLocation = getSafe(ride, ['from', 'name']);
    final String toLocation = getSafe(ride, ['to', 'name']);
    final String date = getSafe(ride, ['date']);
    final String time = getSafe(ride, ['time']) != '' 
        ? getSafe(ride, ['time']) 
        : 'Not specified';
    final String carModel = getSafe(ride, ['vehicleDetails', 'model']) != '' 
        ? getSafe(ride, ['vehicleDetails', 'model']) 
        : 'Unknown';
    final String vehicleName = getSafe(ride, ['vehicleDetails', 'vehicleName']);
    final String price = '₹${ride['amount'] ?? 0}';

    // Check if ride has intermediate stops
    bool hasIntermediateStops = false;
    if (ride.containsKey('intermediatePoints') && 
        ride['intermediatePoints'] is List && 
        (ride['intermediatePoints'] as List).isNotEmpty) {
      hasIntermediateStops = true;
    }

    // For rides with intermediate points, show an info snackbar
    if (hasIntermediateStops) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'This ride has stops along the way. Your search locations will be used for pickup and dropoff.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              // Dismiss the snackbar
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }

    // Always use the search criteria as the passenger's pickup and dropoff
    // This is more intuitive since they already searched for these locations
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WaitingConfirmationScreen(
          rideId: rideId,
          driverName: driverName,
          from: fromLocation,
          to: toLocation,
          date: date,
          time: time,
          vehicle: vehicleName.isNotEmpty ? '$vehicleName ($carModel)' : carModel,
          price: price,
          passengers: widget.passengers,
          passengerPickup: widget.from,  // Use search criteria
          passengerDropoff: widget.to,   // Use search criteria
        ),
      ),
    );
  }
  
  // Safe getter for nested map values
  String getSafe(dynamic data, List<String> path) {
    try {
      dynamic current = data;
      for (String key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          return '';
        }
      }
      return current?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }
}