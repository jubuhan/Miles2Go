import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/location_model.dart';
import './bottom_navigation.dart';

class PublishRideScreen extends StatefulWidget {
  const PublishRideScreen({super.key});

  @override
  State<PublishRideScreen> createState() => _PublishRideScreenState();
}

class _PublishRideScreenState extends State<PublishRideScreen> {
  // Map and Location Controllers
  GoogleMapController? _mapController;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  // Location Services
  late final GooglePlace _googlePlace;
  Position? _currentPosition;
  
  // Location State
  LocationModel? _fromLocation;
  LocationModel? _toLocation;
  String? _selectedDate;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {}; // For storing route polylines
  List<AutocompletePrediction> _predictions = [];
  bool _isLoading = false;
  bool _isLoadingRoute = false; // For route loading indicator
  
  // Navigation state
  int _selectedIndex = 2; // Set to 2 for Rides tab

  // Constants
  static const _defaultZoom = 15.0;
  static const _defaultMapPadding = 100.0;
  static const _apiKey = 'AIzaSyA-qhXwh2ygO9JRbQ_22gc9WRf_Xp9Unow'; // Move to secure config

  // Route options
  List<Map<String, dynamic>> _availableRoutes = [];
  int _selectedRouteIndex = 0;
  List<Color> _routeColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
  ];
  
  // Manual Google polyline decoder function
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace(_apiKey);
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Please enable location services');
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions permanently denied');
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          // We don't add a marker for current location
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to initialize location: $e');
      }
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
    // Don't search if query is empty
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    // Search for places
    try {
      final result = await _googlePlace.autocomplete.get(query);
      if (mounted) {
        setState(() {
          if (result != null && result.predictions != null) {
            _predictions = result.predictions!;
          } else {
            _predictions = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      if (mounted) {
        setState(() => _predictions = []);
      }
    }
  }

  Future<void> _handleLocationSelect(
    AutocompletePrediction prediction,
    bool isOrigin,
  ) async {
    try {
      final details = await _googlePlace.details.get(prediction.placeId!);
      if (details?.result == null || 
          details!.result!.geometry?.location?.lat == null || 
          details.result!.geometry?.location?.lng == null) {
        _showError('Could not get location details');
        return;
      }

      final lat = details.result!.geometry!.location!.lat!;
      final lng = details.result!.geometry!.location!.lng!;
      
      final location = LocationModel(
        name: prediction.description!,
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
        // Get routes when both locations are set
        await _getRoutes();
        _fitMapToBounds();
      } else {
        _animateToLocation(lat, lng);
      }

      // Clear the search results
      setState(() => _predictions = []);
    } catch (e) {
      debugPrint('Error selecting location: $e');
      _showError('Error selecting location');
    }
  }

  void _animateToLocation(double lat, double lng) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(lat, lng),
        _defaultZoom,
      ),
    );
  }

  void _fitMapToBounds() {
    if (_fromLocation == null || _toLocation == null) return;

    final southwest = LatLng(
      math.min(_fromLocation!.latitude, _toLocation!.latitude),
      math.min(_fromLocation!.longitude, _toLocation!.longitude),
    );
    
    final northeast = LatLng(
      math.max(_fromLocation!.latitude, _toLocation!.latitude),
      math.max(_fromLocation!.longitude, _toLocation!.longitude),
    );
    
    final bounds = LatLngBounds(
      southwest: southwest,
      northeast: northeast,
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, _defaultMapPadding),
    );
  }

  // Function to get routes between origin and destination
  Future<void> _getRoutes() async {
    if (_fromLocation == null || _toLocation == null) {
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _polylines.clear();
      _availableRoutes = [];
    });

    try {
      // Make the HTTP request to the Directions API
      final origin = '${_fromLocation!.latitude},${_fromLocation!.longitude}';
      final destination = '${_toLocation!.latitude},${_toLocation!.longitude}';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        'alternatives=true&'
        'key=$_apiKey'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        _showError('Could not get directions: ${data['status']}');
        setState(() => _isLoadingRoute = false);
        return;
      }

      // Parse routes
      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        _showError('No routes found');
        setState(() => _isLoadingRoute = false);
        return;
      }

      // Store route information
      final newRoutes = <Map<String, dynamic>>[];
      final newPolylines = <Polyline>{};

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final legs = route['legs'] as List;
        final leg = legs[0];
        
        // Extract route info
        final distance = leg['distance']['text'];
        final duration = leg['duration']['text'];
        // Get the encoded polyline points
        final String encodedPolyline = route['overview_polyline']['points'];
        
        // Decode the polyline points manually
        final List<LatLng> polylineCoordinates = _decodePolyline(encodedPolyline);

        // Choose color for this route
        final color = _routeColors[i % _routeColors.length];
            
        // Create a polyline for this route
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
        
        // Add route info to our list
        newRoutes.add({
          'index': i,
          'distance': distance,
          'duration': duration,
          'summary': route['summary'],
          'color': color,
        });
      }

      setState(() {
        _availableRoutes = newRoutes;
        _polylines = newPolylines;
        _isLoadingRoute = false;
      });
    } catch (e) {
      debugPrint('Error getting routes: $e');
      _showError('Error getting routes');
      setState(() => _isLoadingRoute = false);
    }
  }

  // Update the polyline style when a different route is selected
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
    if (_currentPosition == null) {
      _showError('Current location not available');
      return;
    }

    try {
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;
      
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

  void _publishRide() {
    if (_fromLocation == null || _toLocation == null || _selectedDate == null || _amountController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    // Here you would implement the ride publishing logic
    _showSuccess('Your ride has been published successfully!');
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
    // For demonstration, we're just updating the selected index
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish Ride'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A3A4A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFF1A3A4A),
      body: SafeArea(
        child: Stack(
          children: [
            _buildMap(),
            _buildPublishPanel(),
            if (_predictions.isNotEmpty) _buildPredictionsList(),
            if (_isLoadingRoute) _buildLoadingIndicator(),
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
    if (_currentPosition == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: _defaultZoom,
      ),
      markers: _markers,
      polylines: _polylines, // Add polylines to the map
      myLocationEnabled: true, // Keep the blue dot for current location
      myLocationButtonEnabled: true, // Keep the button to center on current location
      mapToolbarEnabled: false,
      padding: const EdgeInsets.only(bottom: 300),
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
          child: const Row(
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
                'Loading routes...',
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
                _buildDragHandle(),
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

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildPublishContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PUBLISH A RIDE',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildFromField(),
          const SizedBox(height: 16),
          _buildToField(),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildAmountField(),
          const SizedBox(height: 24),
          _buildPublishButton(),
        ],
      ),
    );
  }

  Widget _buildFromField() {
    return TextField(
      controller: _fromController,
      style: const TextStyle(color: Colors.black),
      onChanged: (value) => _searchPlaces(value),
      onTap: () => setState(() => _predictions = []),
      decoration: InputDecoration(
        labelText: 'FROM WHERE:',
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
        ),
        hintText: 'Your departure location',
        hintStyle: TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.location_on, color: Colors.black54),
        suffixIcon: IconButton(
          icon: const Icon(Icons.my_location, color: Colors.black54),
          onPressed: () => _useCurrentLocation(true),
        ),
      ),
    );
  }

  Widget _buildToField() {
    return TextField(
      controller: _toController,
      style: const TextStyle(color: Colors.black),
      onChanged: (value) => _searchPlaces(value),
      onTap: () => setState(() => _predictions = []),
      decoration: InputDecoration(
        labelText: 'WHERE TO:',
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
        ),
        hintText: 'Your destination',
        hintStyle: TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.location_on, color: Colors.black54),
        suffixIcon: IconButton(
          icon: const Icon(Icons.place, color: Colors.black54),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DATE OF DEPARTURE:',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.black54),
                const SizedBox(width: 12),
                Text(
                  _selectedDate ?? 'Select Date',
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.black : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _publishRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: const Text(
          'PUBLISH RIDE',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPredictionsList() {
    final focusedField = FocusScope.of(context).focusedChild;
    final isFromFocused = _fromController.selection.isValid;
    final isToFocused = _toController.selection.isValid;
    
    // Only show predictions when a field is focused
    if (!isFromFocused && !isToFocused) return const SizedBox.shrink();
    
    // Determine if we're searching for origin or destination
    final isOrigin = isFromFocused;
    
    return Positioned(
      top: 230, // Adjust this value based on your UI
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: _predictions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final prediction = _predictions[index];
            return ListTile(
              leading: const Icon(Icons.location_on, color: Colors.black54),
              title: Text(
                prediction.structuredFormatting?.mainText ?? prediction.description ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A3A4A),
                ),
              ),
              subtitle: Text(
                prediction.structuredFormatting?.secondaryText ?? '',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                _handleLocationSelect(prediction, isOrigin);
              },
            );
          },
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