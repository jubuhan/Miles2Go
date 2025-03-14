import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';
import './bottom_navigation.dart';
import '../services/location_service.dart';
import '../widgets/location_widgets.dart';

class PublishRideScreen extends StatefulWidget {
  final Map<String, dynamic> selectedVehicle;
  
  const PublishRideScreen({
    Key? key,
    required this.selectedVehicle,
  }) : super(key: key);

  @override
  State<PublishRideScreen> createState() => _PublishRideScreenState();
}

class _PublishRideScreenState extends State<PublishRideScreen> {
  // Map and Location Controllers
  GoogleMapController? _mapController;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  // Services
  late final LocationService _locationService;
  
  // Location State
  LocationModel? _fromLocation;
  LocationModel? _toLocation;
  String? _selectedDate;
  TimeOfDay? _selectedTime;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<AutocompletePrediction> _predictions = [];
  bool _isLoading = false;
  bool _isLoadingRoute = false;
  
  // Navigation state
  int _selectedIndex = 2; // Set to 2 for Rides tab

  // Route options
  List<Map<String, dynamic>> _availableRoutes = [];
  int _passengerCount = 1;
  int _selectedRouteIndex = 0;
  List<Color> _routeColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
  ];
  
  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _initializeLocation();
    
    // Set initial passenger count based on vehicle seats
    if (widget.selectedVehicle.containsKey('seats')) {
      final vehicleSeats = int.tryParse(widget.selectedVehicle['seats'].toString()) ?? 1;
      setState(() {
        _passengerCount = vehicleSeats > 1 ? vehicleSeats - 1 : 1; // -1 for the driver
      });
    }
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    
    final position = await _locationService.initializeLocation(_showError);
    
    if (position != null && mounted) {
      setState(() {
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _addMarker({
    required String id,
    required LatLng position,
    required String title,
  }) {
    final marker = Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(title: title),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == id);
      _markers.add(marker);
    });
  }

  Future<void> _searchPlaces(String query) async {
    final predictions = await _locationService.searchPlaces(query);
    if (mounted) {
      setState(() => _predictions = predictions);
    }
  }

  Future<void> _handleLocationSelect(
    AutocompletePrediction prediction,
    bool isOrigin,
  ) async {
    final location = await _locationService.getLocationFromPrediction(
      prediction, 
      _showError
    );
    
    if (location == null) return;
    
    setState(() {
      if (isOrigin) {
        _fromLocation = location;
        _fromController.text = location.name;
        _addMarker(
          id: 'origin',
          position: LatLng(location.latitude, location.longitude),
          title: 'Pick-up Location'
        );
      } else {
        _toLocation = location;
        _toController.text = location.name;
        _addMarker(
          id: 'destination',
          position: LatLng(location.latitude, location.longitude),
          title: 'Drop-off Location'
        );
      }
    });

    if (_fromLocation != null && _toLocation != null) {
      await _getRoutes();
      _fitMapToBounds();
    } else {
      _animateToLocation(location.latitude, location.longitude);
    }

    setState(() => _predictions = []);
  }

  void _animateToLocation(double lat, double lng) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(lat, lng),
        LocationService.defaultZoom,
      ),
    );
  }

  void _fitMapToBounds() {
    if (_fromLocation == null || _toLocation == null) return;

    final bounds = _locationService.getBounds(_fromLocation!, _toLocation!);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, LocationService.defaultMapPadding),
    );
  }

  Future<void> _getRoutes() async {
    if (_fromLocation == null || _toLocation == null) {
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _polylines.clear();
      _availableRoutes = [];
    });

    final routes = await _locationService.getRoutes(
      _fromLocation!, 
      _toLocation!, 
      _showError
    );

    if (routes.isEmpty) {
      setState(() => _isLoadingRoute = false);
      return;
    }

    final newPolylines = <Polyline>{};

    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final color = _routeColors[i % _routeColors.length];
      
      // Create a polyline for this route
      final polylineCoordinates = _locationService.decodePolyline(route['points']);
      final polyline = Polyline(
        polylineId: PolylineId('route_$i'),
        color: color,
        points: polylineCoordinates,
        width: i == _selectedRouteIndex ? 5 : 3,
        patterns: i == _selectedRouteIndex 
            ? [] 
            : [PatternItem.dash(20), PatternItem.gap(10)],
      );
      
      newPolylines.add(polyline);
      
      // Add color to our routes info
      route['color'] = color;
    }

    setState(() {
      _availableRoutes = routes;
      _polylines = newPolylines;
      _isLoadingRoute = false;
    });
  }

  List<LocationModel> getIntermediatePoints(Map<String, dynamic> route) {
    // Get polyline points from the selected route
    final polylineCoordinates = _locationService.decodePolyline(route['points']);
    
    // Extract intermediate points at regular intervals
    List<LocationModel> intermediatePoints = [];
    
    // Skip first and last points as they are origin and destination
    if (polylineCoordinates.length > 2) {
      // Take points at regular intervals - adjust the step as needed
      int step = polylineCoordinates.length ~/ 10; // Take about 10 points
      if (step < 1) step = 1;
      
      for (int i = 1; i < polylineCoordinates.length - 1; i += step) {
        intermediatePoints.add(
          LocationModel(
            name: "Waypoint ${intermediatePoints.length + 1}",
            latitude: polylineCoordinates[i].latitude,
            longitude: polylineCoordinates[i].longitude,
          )
        );
      }
    }
    
    return intermediatePoints;
  }

  void _selectRoute(int index) {
    if (index >= _availableRoutes.length) return;
    
    setState(() {
      _selectedRouteIndex = index;
      
      // Update polyline styles based on whether they're selected
      final newPolylines = <Polyline>{};
      for (int i = 0; i < _availableRoutes.length; i++) {
        final polyline = _polylines.firstWhere(
          (p) => p.polylineId.value == 'route_$i',
        );
        
        final newPolyline = polyline.copyWith(
          widthParam: i == index ? 5 : 3,
          patternsParam: i == index 
              ? [] 
              : [PatternItem.dash(20), PatternItem.gap(10)],
        );
        
        newPolylines.add(newPolyline);
      }
      
      _polylines = newPolylines;
    });
  }

  void _useCurrentLocation(bool isOrigin) async {
    if (_locationService.currentPosition == null) {
      _showError('Current location not available');
      return;
    }

    try {
      final position = _locationService.currentPosition!;
      final lat = position.latitude;
      final lng = position.longitude;
      
      final location = LocationModel(
        name: 'Current Location',
        latitude: lat,
        longitude: lng,
      );

      setState(() {
        if (isOrigin) {
          _fromLocation = location;
          _fromController.text = location.name;
          _addMarker(
            id: 'origin',
            position: LatLng(lat, lng),
            title: 'Pick-up Location'
          );
        } else {
          _toLocation = location;
          _toController.text = location.name;
          _addMarker(
            id: 'destination',
            position: LatLng(lat, lng),
            title: 'Drop-off Location'
          );
        }
      });

      if (_fromLocation != null && _toLocation != null) {
        await _getRoutes();
        _fitMapToBounds();
      }
    } catch (e) {
      debugPrint('Error using current location: $e');
      _showError('Error using current location');
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Color(0xFF1A3A4A),
              surface: Color(0xFF1A3A4A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = "${date.day}/${date.month}/${date.year}";
      });
    }
  }
  
  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Color(0xFF1A3A4A),
              surface: Color(0xFF1A3A4A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data()!.containsKey('userName')) {
        return userDoc.data()!['userName'];
      }
      return 'Unknown User';
    } catch (e) {
      print('Error fetching username: $e');
      return 'Unknown User';
    }
  }

  void _publishRide() async {
    if (_fromLocation == null || _toLocation == null || 
        _selectedDate == null || _selectedTime == null || _amountController.text.isEmpty) {
      _showError('Please fill in all fields including time');
      return;
    }

    if (_availableRoutes.isEmpty || _selectedRouteIndex >= _availableRoutes.length) {
      _showError('No valid route selected');
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      // Get current user ID
      final userId = FirebaseAuth.instance.currentUser!.uid;
      
      // Get the selected route
      final selectedRoute = _availableRoutes[_selectedRouteIndex];
      
      // Extract intermediate points
      final intermediatePoints = getIntermediatePoints(selectedRoute);
      
      // Create a new published ride document
      await FirebaseFirestore.instance.collection('publishedRides').add({
        // User information (by reference)
        'userId': userId,
        'userName': await _getUserName(userId),
        
        // Vehicle information (by reference)
        'vehicleId': widget.selectedVehicle['id'] ?? '',
        'vehicleDetails': {
          'model': widget.selectedVehicle['model'] ?? '',
          'plate': widget.selectedVehicle['plate'] ?? '',
          'vehicleName': widget.selectedVehicle['vehicleName'] ?? '',
          'vehicleType': widget.selectedVehicle['vehicleType'] ?? '',
          'seats': widget.selectedVehicle['seats'] ?? '1',
        },
        
        // Route information
        'from': {
          'name': _fromLocation!.name,
          'latitude': _fromLocation!.latitude,
          'longitude': _fromLocation!.longitude,
        },
        'to': {
          'name': _toLocation!.name,
          'latitude': _toLocation!.latitude,
          'longitude': _toLocation!.longitude,
        },
        'intermediatePoints': intermediatePoints.map((point) => {
          'name': point.name,
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
        
        // Ride details
        'date': _selectedDate,
        'time': _selectedTime != null ? '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}' : '',
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'passengerCount': _passengerCount,
        'routeEncodedPolyline': selectedRoute['points'],
        'routeSummary': selectedRoute['summary'],
        'routeDistance': selectedRoute['distance'],
        'routeDuration': selectedRoute['duration'],
        
        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'bookedSeats': 0,
        'availableSeats': _passengerCount,
      });
      
      setState(() => _isLoading = false);
      _showSuccess('Your ride has been published successfully!');
      
      // Navigate back to the previous screen
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to publish ride: ${e.toString()}');
    }
  }

  void _decrementPassengers() {
    if (_passengerCount > 1) {
      setState(() {
        _passengerCount--;
      });
    }
  }

  void _incrementPassengers() {
    // Get maximum seats from vehicle
    final maxSeats = int.tryParse(widget.selectedVehicle['seats'].toString()) ?? 8;
    // Allow one less than total (accounting for driver)
    final passengerLimit = maxSeats > 1 ? maxSeats - 1 : 1;
    
    if (_passengerCount < passengerLimit) {
      setState(() {
        _passengerCount++;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    setState(() {
      _selectedIndex = index;
    });
    
    // Add navigation logic here if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor:  Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            _buildMap(),
            _buildPublishPanel(),
            if (_predictions.isNotEmpty) 
              LocationWidgets.buildPredictionsList(
                predictions: _predictions,
                onSelect: _handleLocationSelect,
                isOrigin: _fromController.selection.isValid,
                top: 230,
              ),
            if (_isLoading || _isLoadingRoute) _buildLoadingIndicator(),
          ],
        ),
      ),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
        // Apply a dark map style (optional)
        _mapController?.setMapStyle('''
          [
            {
              "featureType": "all",
              "elementType": "labels.text.fill",
              "stylers": [{"color": "#7c93a3"},{"lightness": "-10"}]
            },
            {
              "featureType": "administrative.country",
              "elementType": "geometry",
              "stylers": [{"visibility": "on"}]
            },
            {
              "featureType": "administrative.country",
              "elementType": "geometry.stroke",
              "stylers": [{"color": "#a0a4a5"}]
            }
          ]
        ''');
      },
      initialCameraPosition: CameraPosition(
        target: _locationService.currentPosition != null 
            ? LatLng(_locationService.currentPosition!.latitude, _locationService.currentPosition!.longitude)
            : const LatLng(0, 0), // Default position will be updated once location is available
        zoom: LocationService.defaultZoom,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
      mapType: MapType.normal,
      compassEnabled: true,
      padding: const EdgeInsets.only(bottom: 300),
      liteModeEnabled: false, // Set true for very slow devices
      zoomControlsEnabled: false, // Hide default zoom controls for cleaner UI
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
              SizedBox(width: 10),
              Text(
                _isLoading ? 'Publishing ride...' : 'Loading routes...',
                style: TextStyle(color: Color(0xFF1A3A4A)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationWidgets.buildDragHandle(Colors.blue),
                if (_availableRoutes.isNotEmpty) _buildRouteSelector(),
                _buildPublishContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVAILABLE ROUTES',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableRoutes.length,
              itemBuilder: (context, index) {
                final route = _availableRoutes[index];
                final isSelected = index == _selectedRouteIndex;
                
                return GestureDetector(
                  onTap: () => _selectRoute(index),
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? route['color'].withOpacity(0.2) 
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? route['color'] : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: route['color'],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                route['summary'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Distance: ${route['distance']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          'Duration: ${route['duration']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildPublishContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: const Text(
              'PUBLISH A RIDE',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Show the selected vehicle
          _buildSelectedVehicle(),
          const SizedBox(height: 16),
          _buildFromField(),
          const SizedBox(height: 16),
          _buildToField(),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildTimeField(),
          const SizedBox(height: 16),
          _buildAmountField(),
          const SizedBox(height: 16),
          _buildPassengersSelector(),
          const SizedBox(height: 24),
          _buildPublishButton(),
        ],
      ),
    );
  }

  Widget _buildSelectedVehicle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECTED VEHICLE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${widget.selectedVehicle['vehicleName']} (${widget.selectedVehicle['model']})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Plate: ${widget.selectedVehicle['plate']} • Type: ${widget.selectedVehicle['vehicleType']}",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          Text(
            "Seats: ${widget.selectedVehicle['seats']}",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFromField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: LocationWidgets.buildLocationField(
        controller: _fromController,
        hint: 'Your departure location',
        onChanged: (value) => _searchPlaces(value),
        onTap: () => setState(() => _predictions = []),
        onCurrentLocation: () => _useCurrentLocation(true),
        borderColor: Colors.transparent,
        prefixIcon: const Icon(Icons.location_on, color: Colors.black54),
      ),
    );
  }

  Widget _buildToField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: LocationWidgets.buildLocationField(
        controller: _toController,
        hint: 'Your destination',
        onChanged: (value) => _searchPlaces(value),
        onTap: () => setState(() => _predictions = []),
        onCurrentLocation: () => _useCurrentLocation(false),
        borderColor: Colors.transparent,
        prefixIcon: const Icon(Icons.location_on, color: Colors.black54),
        suffixIcon: const Icon(Icons.place, color: Colors.black54),
      ),
    );
  }

  Widget _buildDateField() {
    return LocationWidgets.buildDateField(
      selectedDate: _selectedDate,
      onTap: _selectDate,
      borderColor: Colors.transparent,
    );
  }
  
  Widget _buildTimeField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: _selectTime,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.access_time, color: Colors.black54),
              const SizedBox(width: 12),
              Text(
                _selectedTime != null 
                    ? '${_selectedTime!.format(context)}' 
                    : 'Select time',
                style: TextStyle(
                  color: _selectedTime != null ? Colors.black : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountController,
      style: const TextStyle(color: Colors.black),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'AMOUNT:',
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
        ),
        hintText: 'Enter the amount',
        hintStyle: TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.attach_money, color: Colors.black54),
      ),
    );
  }

  Widget _buildPassengersSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: LocationWidgets.buildPassengersSelector(
        passengerCount: _passengerCount,
        onDecrement: _decrementPassengers,
        onIncrement: _incrementPassengers,
        borderColor: Colors.transparent,
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _publishRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: const Text(
          'PUBLISH RIDE',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _amountController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}