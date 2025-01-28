import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart' as google_place;
import '../models/location_model.dart';
import './available_rides_screen.dart';

class RideSearchScreen extends StatefulWidget {
  const RideSearchScreen({Key? key}) : super(key: key);

  @override
  State<RideSearchScreen> createState() => _RideSearchScreenState();
}

class _RideSearchScreenState extends State<RideSearchScreen> {
  // Location state
  LocationModel? fromLocation;
  LocationModel? toLocation;
  String? selectedDate;
  Position? currentUserPosition;
  
  // Controllers
  final TextEditingController _fromSearchController = TextEditingController();
  final TextEditingController _toSearchController = TextEditingController();
  GoogleMapController? mapController;
  
  // Google Places
  late google_place.GooglePlace googlePlace;
  List<google_place.AutocompletePrediction> predictions = [];
  
  // Map markers
  Set<Marker> markers = {};
  
  @override
  void initState() {
    super.initState();
    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // Move to environment config
    googlePlace = google_place.GooglePlace(apiKey);
    _initializeLocation();
  }
  
  Future<void> _initializeLocation() async {
    await _checkLocationPermission();
    await _getCurrentLocation();
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Show error message or handle denied permission
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Show error message or handle permanent denial
      return;
    }
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        currentUserPosition = position;
        _updateMarker(
          markerId: 'currentLocation',
          position: LatLng(position.latitude, position.longitude),
          title: 'Current Location',
        );
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Handle error appropriately
    }
  }

  void _updateMarker({
    required String markerId,
    required LatLng position,
    required String title,
  }) {
    markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        infoWindow: InfoWindow(title: title),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _searchPlaces(String query, bool isFrom) async {
    if (query.isEmpty) return;

    try {
      var result = await googlePlace.autocomplete.get(query);
      if (result != null && result.predictions != null) {
        setState(() {
          predictions = result.predictions!;
        });
        
        _showPredictionsList(isFrom);
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      // Handle error appropriately
    }
  }

  void _showPredictionsList(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPredictionsList(isFrom),
    );
  }

  Widget _buildPredictionsList(bool isFrom) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A3A4A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Location',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    predictions[index].description ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => _handleLocationSelected(predictions[index], isFrom),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLocationSelected(google_place.AutocompletePrediction prediction, bool isFrom) async {
    try {
      var details = await googlePlace.details.get(prediction.placeId!);
      if (details != null && details.result != null) {
        final lat = details.result!.geometry?.location?.lat;
        final lng = details.result!.geometry?.location?.lng;
        
        if (lat != null && lng != null) {
          final location = LocationModel(
            name: prediction.description!,
            latitude: lat,
            longitude: lng,
          );
          
          setState(() {
            if (isFrom) {
              fromLocation = location;
              _fromSearchController.text = location.name;
              _updateMarker(
                markerId: 'fromLocation',
                position: LatLng(lat, lng),
                title: 'Pick-up Location',
              );
            } else {
              toLocation = location;
              _toSearchController.text = location.name;
              _updateMarker(
                markerId: 'toLocation',
                position: LatLng(lat, lng),
                title: 'Drop-off Location',
              );
            }
          });
          
          _animateToLocation(lat, lng);
        }
      }
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error handling location selection: $e');
      // Handle error appropriately
    }
  }

  void _animateToLocation(double lat, double lng) {
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(lat, lng),
        15,
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
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
        selectedDate = "${date.day}/${date.month}/${date.year}";
      });
    }
  }

  void _searchRides() {
    if (fromLocation == null || toLocation == null || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvailableRidesScreen(
          from: fromLocation!.name,
          to: toLocation!.name,
          date: selectedDate!,
          passengers: '1',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A4A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: _buildMap(),
            ),
            Expanded(
              flex: 1,
              child: _buildSearchPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (currentUserPosition == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: LatLng(
          currentUserPosition!.latitude,
          currentUserPosition!.longitude,
        ),
        zoom: 15,
      ),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildSearchPanel() {
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
          _buildSearchField(
            controller: _fromSearchController,
            hint: 'From...',
            isFrom: true,
          ),
          const SizedBox(height: 16),
          _buildSearchField(
            controller: _toSearchController,
            hint: 'To...',
            isFrom: false,
          ),
          const SizedBox(height: 16),
          _buildDateAndSearchRow(),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required bool isFrom,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: const Icon(Icons.search, color: Colors.white),
      ),
      onChanged: (value) => _searchPlaces(value, isFrom),
    );
  }

  Widget _buildDateAndSearchRow() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
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
                    selectedDate ?? 'Select Date',
                    style: TextStyle(
                      color: selectedDate != null ? Colors.white : Colors.white54,
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
    _fromSearchController.dispose();
    _toSearchController.dispose();
    mapController?.dispose();
    super.dispose();
  }
}