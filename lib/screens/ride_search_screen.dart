import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'dart:math' as math;
import '../models/location_model.dart';
import './available_rides_screen.dart';

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
  
  // Location Services
  late final GooglePlace _googlePlace;
  Position? _currentPosition;
  
  // Location State
  LocationModel? _fromLocation;
  LocationModel? _toLocation;
  String? _selectedDate;
  Set<Marker> _markers = {};
  List<AutocompletePrediction> _predictions = [];
  bool _isLoading = false;

  // Constants
  static const _defaultZoom = 15.0;
  static const _defaultMapPadding = 100.0;
  static const _apiKey = 'AIzaSyA-qhXwh2ygO9JRbQ_22gc9WRf_Xp9Unow'; // Move to secure config
  
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
          _addMarker(
            id: 'current_location',
            position: LatLng(position.latitude, position.longitude),
            title: 'Current Location'
          );
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

  void _animateToPosition(Position position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: _defaultZoom,
        ),
      ),
    );
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
            debugPrint('Found ${_predictions.length} predictions');
          } else {
            _predictions = [];
            debugPrint('No predictions found');
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
          passengers: '1',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A4A),
      body: SafeArea(
        child: Stack(
          children: [
            _buildMap(),
            _buildSearchPanel(),
            if (_predictions.isNotEmpty) _buildPredictionsList(),
          ],
        ),
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
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
      padding: const EdgeInsets.only(bottom: 300),
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
            color: Color(0xFF1A3A4A),
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
                _buildSearchContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SEARCH A RIDE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildFromField(),
          const SizedBox(height: 16),
          _buildToField(),
          const SizedBox(height: 16),
          _buildDateAndSearchRow(),
        ],
      ),
    );
  }

  Widget _buildFromField() {
    return TextField(
      controller: _fromController,
      style: const TextStyle(color: Colors.white),
      onChanged: (value) => _searchPlaces(value),
      onTap: () => setState(() => _predictions = []),
      decoration: InputDecoration(
        hintText: 'From...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.white),
        suffixIcon: IconButton(
          icon: const Icon(Icons.my_location, color: Colors.white),
          onPressed: () => _useCurrentLocation(true),
        ),
      ),
    );
  }

  Widget _buildToField() {
    return TextField(
      controller: _toController,
      style: const TextStyle(color: Colors.white),
      onChanged: (value) => _searchPlaces(value),
      onTap: () => setState(() => _predictions = []),
      decoration: InputDecoration(
        hintText: 'To...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.white),
        suffixIcon: IconButton(
          icon: const Icon(Icons.place, color: Colors.white),
          onPressed: () {},
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
              leading: const Icon(Icons.location_on, color: Color(0xFF1A3A4A)),
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

  Widget _buildDateAndSearchRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedDate ?? 'Select Date',
                    style: TextStyle(
                      color: _selectedDate != null ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today, color: Colors.white54),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _searchRides,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Search',
            style: TextStyle(
              color: Color(0xFF1A3A4A),
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