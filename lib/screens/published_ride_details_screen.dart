import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import './bottom_navigation.dart';
import '../widgets/pending_requests_widget.dart';
import '../widgets/accepted_passengers_widget.dart';
import '../services/location_service.dart';
import '../models/location_model.dart';
import './manage_ride_requests_screen.dart';

class PublishedRideDetailsScreen extends StatefulWidget {
  final String rideId;

  const PublishedRideDetailsScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  @override
  State<PublishedRideDetailsScreen> createState() => _PublishedRideDetailsScreenState();
}

class _PublishedRideDetailsScreenState extends State<PublishedRideDetailsScreen> {
  int _selectedIndex = 2; // Set to 2 for Rides tab
  bool _isLoading = true;
  Map<String, dynamic>? _rideData;
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _fetchRideDetails();
  }

  Future<void> _fetchRideDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(widget.rideId)
          .get();

      if (!rideDoc.exists) {
        _showError('Ride not found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _rideData = rideDoc.data() as Map<String, dynamic>;
        _isLoading = false;
      });

      // Setup map after data is loaded
      _setupMap();
    } catch (e) {
      print('Error fetching ride details: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load ride details');
    }
  }

  void _setupMap() {
    if (_rideData == null) return;

    try {
      // Extract locations
      final fromLocation = _extractLocation(_rideData!['from'], 'Start');
      final toLocation = _extractLocation(_rideData!['to'], 'End');
      
      // Extract waypoints if any
      List<LocationModel> waypoints = [];
      if (_rideData!.containsKey('intermediatePoints') && 
          _rideData!['intermediatePoints'] is List) {
        final points = _rideData!['intermediatePoints'] as List;
        for (int i = 0; i < points.length; i++) {
          waypoints.add(_extractLocation(points[i], 'Stop ${i + 1}'));
        }
      }

      // Add markers
      _addMarker('origin', fromLocation.latitude, fromLocation.longitude, 
          'Pick-up Location', BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));
      
      _addMarker('destination', toLocation.latitude, toLocation.longitude, 
          'Drop-off Location', BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet));
      
      // Add waypoint markers
      for (int i = 0; i < waypoints.length; i++) {
        final waypoint = waypoints[i];
        _addMarker('stop_$i', waypoint.latitude, waypoint.longitude, 
            'Stop ${i + 1}', BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
      }

      // Add polyline if we have encoded points
      if (_rideData!.containsKey('routeEncodedPolyline') && 
          _rideData!['routeEncodedPolyline'] != null) {
        final encodedPolyline = _rideData!['routeEncodedPolyline'];
        final polylinePoints = _locationService.decodePolyline(encodedPolyline);
        
        final polyline = Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          points: polylinePoints,
          width: 5,
        );
        
        setState(() {
          _polylines = {polyline};
        });
      }

      // Calculate bounds
      final List<LocationModel> allLocations = [fromLocation, toLocation, ...waypoints];
      final bounds = _locationService.getBoundsForMultipleLocations(allLocations);
      
      // Animate to bounds when map is created
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, LocationService.defaultMapPadding),
        );
      }
    } catch (e) {
      print('Error setting up map: $e');
    }
  }

  void _addMarker(String id, double lat, double lng, String title, BitmapDescriptor? icon) {
    final marker = Marker(
      markerId: MarkerId(id),
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: title),
      icon: icon ?? BitmapDescriptor.defaultMarker,
    );

    setState(() {
      _markers = {..._markers, marker};
    });
  }

  LocationModel _extractLocation(dynamic data, String defaultName) {
    if (data is Map) {
      return LocationModel(
        name: data['name'] ?? defaultName,
        latitude: (data['latitude'] is num) ? data['latitude'].toDouble() : 0.0,
        longitude: (data['longitude'] is num) ? data['longitude'].toDouble() : 0.0,
      );
    }
    return LocationModel(
      name: defaultName,
      latitude: 0.0,
      longitude: 0.0,
    );
  }

  void _cancelRide() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text(
          'Are you sure you want to cancel this ride? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      // Update the ride status to cancelled
      await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(widget.rideId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      // Also update any pending requests to cancelled
      final QuerySnapshot pendingRequests = await FirebaseFirestore.instance
          .collection('rideRequests')
          .where('rideId', isEqualTo: widget.rideId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in pendingRequests.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      
      _showSuccess('Ride cancelled successfully');
      Navigator.pop(context);
    } catch (e) {
      print('Error cancelling ride: $e');
      _showError('Failed to cancel ride');
    }
  }

  void _showManageRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageRideRequestsScreen(rideId: widget.rideId),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add navigation logic here if needed
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
        title: const Text(
          'Ride Details',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchRideDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rideData == null
              ? const Center(child: Text('Ride not found'))
              : _buildRideDetailsContent(),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildRideDetailsContent() {
    final String status = _rideData!['status'] ?? 'active';
    final bool isActive = status == 'active';
    
    return Column(
      children: [
        // Map showing the route
        Expanded(
          flex: 1,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                _setupMap(); // Setup map once controller is available
              },
              initialCameraPosition: CameraPosition(
                target: const LatLng(0, 0), // Will be updated in _setupMap
                zoom: LocationService.defaultZoom,
              ),
              markers: _markers,
              polylines: _polylines,
              mapType: MapType.normal,
              myLocationEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
        ),
        
        // Ride details section
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : status.toUpperCase(),
                    style: TextStyle(
                      color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Ride details card
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
                      _buildDetailRow('From', _rideData!['from']?['name'] ?? 'Unknown'),
                      const SizedBox(height: 8),
                      _buildDetailRow('To', _rideData!['to']?['name'] ?? 'Unknown'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Date', _rideData!['date'] ?? 'Not specified'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Time', _rideData!['time'] ?? 'Not specified'),
                      const SizedBox(height: 8),
                      
                      // Show intermediate stops if any
                      if (_rideData!.containsKey('intermediatePoints') && 
                          _rideData!['intermediatePoints'] is List &&
                          (_rideData!['intermediatePoints'] as List).isNotEmpty) ...[
                        const Divider(),
                        const Text(
                          'STOPS',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildStopsList(),
                        const Divider(),
                      ],
                      
                      // Vehicle details
                      _buildDetailRow(
                        'Vehicle',
                        _getVehicleDescription(),
                      ),
                      const SizedBox(height: 8),
                      
                      // Route details
                      if (_rideData!.containsKey('routeDistance') && _rideData!.containsKey('routeDuration')) ...[
                        _buildDetailRow(
                          'Distance',
                          _rideData!['routeDistance'] ?? 'Unknown',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Duration',
                          _rideData!['routeDuration'] ?? 'Unknown',
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              'Price',
                              '₹${_rideData!['amount'] ?? "0"}',
                            ),
                          ),
                          Expanded(
                            child: _buildDetailRow(
                              'Seats',
                              '${_rideData!['availableSeats'] ?? "0"}/${_rideData!['passengerCount'] ?? "0"}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // ACCEPTED PASSENGERS LIST
                if (isActive) ...[
                  AcceptedPassengersWidget(rideId: widget.rideId),
                  
                  const SizedBox(height: 16),
                ],
                
                // Pending requests section
                if (isActive) ...[
                  const Text(
                    'RIDE REQUESTS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Widget to show pending requests count and link to manage them
                  PendingRequestsWidget(rideId: widget.rideId),
                  
                  const SizedBox(height: 16),
                ],
                
                // Action buttons
                if (isActive)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cancelRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'CANCEL RIDE',
                        style: TextStyle(
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
      ],
    );
  }
  
  String _getVehicleDescription() {
    if (_rideData!.containsKey('vehicleDetails')) {
      final vehicleDetails = _rideData!['vehicleDetails'] as Map<String, dynamic>?;
      if (vehicleDetails != null) {
        final vehicleName = vehicleDetails['vehicleName'] ?? '';
        final model = vehicleDetails['model'] ?? '';
        final plate = vehicleDetails['plate'] ?? '';
        
        String description = '';
        if (vehicleName.isNotEmpty) description += vehicleName;
        if (model.isNotEmpty) description += description.isNotEmpty ? ' ($model)' : model;
        if (plate.isNotEmpty) description += description.isNotEmpty ? ' - $plate' : plate;
        
        return description.isNotEmpty ? description : 'Unknown vehicle';
      }
    }
    return 'Unknown vehicle';
  }
  
  List<Widget> _buildStopsList() {
    final stops = _rideData!['intermediatePoints'] as List;
    return List.generate(
      stops.length,
      (index) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.green,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stops[index]['name'] ?? 'Stop ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
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
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}