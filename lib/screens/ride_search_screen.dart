import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import '../models/location_model.dart';
import './available_rides_screen.dart';
import './bottom_navigation.dart';
import '../services/location_service.dart';
import '../widgets/location_widgets.dart';

class RideSearchScreen extends StatefulWidget {
  const RideSearchScreen({Key? key}) : super(key: key);

  @override
  State<RideSearchScreen> createState() => _RideSearchScreenState();
}

class _RideSearchScreenState extends State<RideSearchScreen> {
  // Map and Location Controllers
  GoogleMapController? _mapController;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  
  // Services
  late final LocationService _locationService;
  
  // Location State
  LocationModel? _fromLocation;
  LocationModel? _toLocation;
  String? _selectedDate;
  int _passengerCount = 1;
  Set<Marker> _markers = {};
  List<AutocompletePrediction> _predictions = [];
  bool _isLoading = false;
  
  // Navigation state
  int _currentNavIndex = 1; // Set to 1 for Search tab
  
  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    
    final position = await _locationService.initializeLocation(_showError);
    
    if (position != null && mounted) {
      setState(() {
        _isLoading = false;
        _addMarker(
          id: 'current_location',
          position: LatLng(position.latitude, position.longitude),
          title: 'Current Location'
        );
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

  // Changed to accept latitude and longitude directly instead of Position
  void _animateToPosition(double latitude, double longitude) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: LocationService.defaultZoom,
        ),
      ),
    );
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
        _fitMapToBounds();
      }
    } catch (e) {
      debugPrint('Error using current location: $e');
      _showError('Error using current location');
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
    if (_passengerCount < 8) { // Common max limit for standard vehicles
      setState(() {
        _passengerCount++;
      });
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
              onPrimary: Colors.blue,
              surface: Colors.blue,
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

  void _searchRides() {
    if (_fromLocation == null || _toLocation == null || _selectedDate == null) {
      _showError('Please fill in all fields');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvailableRidesScreen(
          from: _fromLocation!.name,
          to: _toLocation!.name,
          date: _selectedDate!,
          passengers: _passengerCount.toString(),
        ),
      ),
    );
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

  void _handleNavigation(int index) {
    if (index == _currentNavIndex) return;
    
    setState(() {
      _currentNavIndex = index;
    });
    
    // Navigate to the corresponding screen based on index
    // Implementation left for future development
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('Request Ride'),
        //centerTitle: true,
        backgroundColor:  Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor:  Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            _buildMap(),
            _buildSearchPanel(),
            if (_predictions.isNotEmpty) 
              LocationWidgets.buildPredictionsList(
                predictions: _predictions,
                onSelect: _handleLocationSelect,
                isOrigin: _fromController.selection.isValid,
                top: 230,
              ),
          ],
        ),
      ),
      bottomNavigationBar: Miles2GoBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _handleNavigation,
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
        // Immediately update camera to current position when controller is ready
        if (_locationService.currentPosition != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(
                _locationService.currentPosition!.latitude,
                _locationService.currentPosition!.longitude
              ),
              LocationService.defaultZoom,
            ),
          );
        }
      },
      initialCameraPosition: CameraPosition(
        target: _locationService.currentPosition != null
            ? LatLng(_locationService.currentPosition!.latitude, _locationService.currentPosition!.longitude)
            : const LatLng(0, 0), // Will be updated once we have the location
        zoom: LocationService.defaultZoom,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false, // Hide the default button
      mapToolbarEnabled: false,
      padding: const EdgeInsets.only(bottom: 300),
      zoomControlsEnabled: false, // Hide default zoom controls
      compassEnabled: true,
      buildingsEnabled: false, // Disable 3D buildings for better performance
      trafficEnabled: false, // Disable traffic display for better performance
    );
  }

  Widget _buildSearchPanel() {
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
                _buildSearchContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'SEARCH A RIDE',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildFromField(),
          const SizedBox(height: 16),
          _buildToField(),
          const SizedBox(height: 16),
          _buildPassengersSelector(),
          const SizedBox(height: 16),
          _buildDateAndSearchRow(),
        ],
      ),
    );
  }

  Widget _buildFromField() {
    return Container(
    decoration: BoxDecoration(
      color: Colors.grey[100], // Background color
      borderRadius: BorderRadius.circular(8), // Optional rounded corners
    ),
    child:  LocationWidgets.buildLocationField(
      controller: _fromController,
      hint: 'your location',
      onChanged: (value) => _searchPlaces(value),
      onTap: () => setState(() => _predictions = []),
      onCurrentLocation: () => _useCurrentLocation(true),
      borderColor: Colors.transparent,
    ),
    );
  }

  Widget _buildToField() {
    return Container(
    decoration: BoxDecoration(
      color: Colors.grey[100], // Background color
      borderRadius: BorderRadius.circular(8), // Optional rounded corners
    ),
    child:  LocationWidgets.buildLocationField(
      controller: _toController,
      hint: 'destination location',
      onChanged: (value) => _searchPlaces(value),
      onTap: () => setState(() => _predictions = []),
      onCurrentLocation: () => _useCurrentLocation(false),
      borderColor: Colors.transparent,
      suffixIcon: const Icon(Icons.place, color: Colors.black54),
    ),
    );
  }

Widget _buildPassengersSelector() {
    return Container(
    decoration: BoxDecoration(
      color: Colors.grey[100], // Background color
      borderRadius: BorderRadius.circular(8), // Optional rounded corners
    ),
    child:  LocationWidgets.buildPassengersSelector(
      passengerCount: _passengerCount,
      onDecrement: _decrementPassengers,
      onIncrement: _incrementPassengers,
      borderColor: Colors.transparent,
    ),
    );
  }

  Widget _buildDateAndSearchRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDate ?? 'Select Date',
                    style: TextStyle(
                      color: _selectedDate != null ? Colors.black54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _searchRides,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Search',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}