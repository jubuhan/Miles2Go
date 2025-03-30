import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../models/location_model.dart';
import '../widgets/accepted_passengers_widget.dart';
import './bottom_navigation.dart';

class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  final String locationDocId;

  const ActiveRideScreen({
    Key? key,
    required this.rideId,
    required this.locationDocId,
  }) : super(key: key);

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  int _selectedIndex = 2; // Set to 2 for Rides tab
  bool _isLoading = true;
  Map<String, dynamic>? _rideData;
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Tracking related properties
  Timer? _locationUpdateTimer;
  final Duration _updateInterval = const Duration(seconds: 10);

  // UI related
  bool _isNavigatingToPickup = true;
  List<LocationModel> _pickupLocations = [];
  int _currentPickupIndex = 0;
  List<Map<String, dynamic>> _passengers = [];

  @override
  void initState() {
    super.initState();
    _fetchRideDetails();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    _mapController?.dispose();
    super.dispose();
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

      final data = rideDoc.data() as Map<String, dynamic>;

      // Get passenger information from the acceptedPassengers array
      List<Map<String, dynamic>> passengers = [];
      if (data.containsKey('acceptedPassengers') &&
          data['acceptedPassengers'] is List) {
        final acceptedPassengers = data['acceptedPassengers'] as List;
        for (var passenger in acceptedPassengers) {
          if (passenger is Map<String, dynamic>) {
            passengers.add(passenger);
          }
        }
      }

      // If no passengers in the array, get them from rideRequests collection
      if (passengers.isEmpty) {
        final QuerySnapshot acceptedPassengers = await FirebaseFirestore
            .instance
            .collection('rideRequests')
            .where('rideId', isEqualTo: widget.rideId)
            .where('status', isEqualTo: 'accepted')
            .get();

        for (var doc in acceptedPassengers.docs) {
          final passengerData = doc.data() as Map<String, dynamic>;
          passengers.add({
            'requestId': doc.id,
            'userId': passengerData['userId'],
            'passengerName': passengerData['userName'] ??
                passengerData['passengerName'] ??
                'Passenger',
            'passengerContact': passengerData['contact'] ??
                passengerData['passengerContact'] ??
                '',
            'isPickedUp': passengerData['isPickedUp'] ?? false,
            'isPickupConfirmed': passengerData['isPickupConfirmed'] ?? false,
          });
        }
      }

      // Build list of pickup locations
      List<LocationModel> pickupLocations = [];
      for (var passengerData in passengers) {
        // Skip passengers who are already picked up and confirmed
        if (passengerData['isPickedUp'] == true &&
            passengerData['isPickupConfirmed'] == true) {
          continue;
        }

        // Get pickup location from ride requests
        final requestDoc = await FirebaseFirestore.instance
            .collection('rideRequests')
            .doc(passengerData['requestId'])
            .get();

        if (requestDoc.exists) {
          final requestData = requestDoc.data() as Map<String, dynamic>;

          // Try to get structured location data
          if (requestData.containsKey('pickupLocation')) {
            final pickupLocation = _extractLocation(
                requestData['pickupLocation'],
                passengerData['passengerName'] ?? 'Passenger');
            pickupLocations.add(pickupLocation);
          }
          // Try to get from string location
          else if (requestData.containsKey('passengerPickup') &&
              requestData['passengerPickup'] != null) {
            final pickupString = requestData['passengerPickup'];
            final pickupLocation = await _locationService.getLatLngFromAddress(
                pickupString,
                (error) => print('Error geocoding pickup: $error'));

            if (pickupLocation != null) {
              pickupLocations.add(LocationModel(
                name: passengerData['passengerName'] ?? 'Passenger',
                latitude: pickupLocation.latitude,
                longitude: pickupLocation.longitude,
              ));
            }
          }
        }
      }

      setState(() {
        _rideData = data;
        _passengers = passengers;
        _pickupLocations = pickupLocations;
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
      // Clear existing markers and polylines
      setState(() {
        _markers = {};
        _polylines = {};
      });

      // Get driver's current location
      _locationService.getCurrentPosition().then((position) {
        if (position != null) {
          // Add driver marker
          _addMarker(
              'driver',
              position.latitude,
              position.longitude,
              'Your Location',
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue));

          // If in pickup mode, show pickup locations
          if (_isNavigatingToPickup && _pickupLocations.isNotEmpty) {
            for (int i = 0; i < _pickupLocations.length; i++) {
              final pickupLoc = _pickupLocations[i];
              _addMarker(
                  'pickup_$i',
                  pickupLoc.latitude,
                  pickupLoc.longitude,
                  'Pickup: ${pickupLoc.name}',
                  BitmapDescriptor.defaultMarkerWithHue(i == _currentPickupIndex
                      ? BitmapDescriptor.hueGreen
                      : BitmapDescriptor.hueYellow));
            }

            // Draw route to current pickup location
            if (_currentPickupIndex < _pickupLocations.length) {
              _drawRouteToPickup(
                  position, _pickupLocations[_currentPickupIndex]);
            }
          } else {
            // Show destination
            final toLocation =
                _extractLocation(_rideData!['to'], 'Destination');
            _addMarker(
                'destination',
                toLocation.latitude,
                toLocation.longitude,
                'Destination: ${toLocation.name}',
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));

            // Draw route to destination
            _drawRouteToDestination(position, toLocation);
          }
        }
      });
    } catch (e) {
      print('Error setting up map: $e');
    }
  }

  Future<void> _drawRouteToPickup(
      Position driverPosition, LocationModel pickup) async {
    try {
      final from = LocationModel(
        name: 'Driver',
        latitude: driverPosition.latitude,
        longitude: driverPosition.longitude,
      );

      final routes = await _locationService.getRoutes(
          from, pickup, (error) => _showError(error));

      if (routes.isNotEmpty) {
        final route = routes.first;
        final polylinePoints = _locationService.decodePolyline(route['points']);

        final polyline = Polyline(
          polylineId: const PolylineId('pickup_route'),
          color: Colors.green,
          points: polylinePoints,
          width: 5,
        );

        setState(() {
          _polylines = {polyline};
        });

        // Calculate bounds and animate camera
        final bounds = _locationService.getBounds(from, pickup);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
              bounds, LocationService.defaultMapPadding),
        );
      }
    } catch (e) {
      print('Error drawing route to pickup: $e');
    }
  }

  Future<void> _drawRouteToDestination(
      Position driverPosition, LocationModel destination) async {
    try {
      final from = LocationModel(
        name: 'Driver',
        latitude: driverPosition.latitude,
        longitude: driverPosition.longitude,
      );

      final routes = await _locationService.getRoutes(
          from, destination, (error) => _showError(error));

      if (routes.isNotEmpty) {
        final route = routes.first;
        final polylinePoints = _locationService.decodePolyline(route['points']);

        final polyline = Polyline(
          polylineId: const PolylineId('destination_route'),
          color: Colors.blue,
          points: polylinePoints,
          width: 5,
        );

        setState(() {
          _polylines = {polyline};
        });

        // Calculate bounds and animate camera
        final bounds = _locationService.getBounds(from, destination);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
              bounds, LocationService.defaultMapPadding),
        );
      }
    } catch (e) {
      print('Error drawing route to destination: $e');
    }
  }

  void _addMarker(
      String id, double lat, double lng, String title, BitmapDescriptor? icon) {
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
        longitude:
            (data['longitude'] is num) ? data['longitude'].toDouble() : 0.0,
      );
    }
    return LocationModel(
      name: defaultName,
      latitude: 0.0,
      longitude: 0.0,
    );
  }

  void _startLocationUpdates() {
    // Cancel any existing timer
    _stopLocationUpdates();

    // Create a new timer for location updates
    _locationUpdateTimer = Timer.periodic(_updateInterval, (timer) {
      _updateDriverLocation();
    });

    // Also update immediately
    _updateDriverLocation();
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _updateDriverLocation() async {
    try {
      // Get current position
      final position = await _locationService.getCurrentPosition();

      if (position != null) {
        // Update live location document
        await FirebaseFirestore.instance
            .collection('liveLocations')
            .doc(widget.locationDocId)
            .update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'heading': position.heading,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update driver marker on the map
        _addMarker(
            'driver',
            position.latitude,
            position.longitude,
            'Your Location',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue));

        // If needed, redraw route based on current navigation mode
        if (_isNavigatingToPickup &&
            _currentPickupIndex < _pickupLocations.length) {
          _drawRouteToPickup(position, _pickupLocations[_currentPickupIndex]);
        } else if (!_isNavigatingToPickup && _rideData != null) {
          final toLocation = _extractLocation(_rideData!['to'], 'Destination');
          _drawRouteToDestination(position, toLocation);
        }
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Individual passenger pickup method
  void _pickupPassenger(String requestId, String passengerName) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick up $passengerName?'),
        content: Text('Are you sure you want to mark $passengerName as picked up?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // 1. Update the ride request document
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(requestId)
          .update({
        'isPickedUp': true,
        'pickedUpAt': FieldValue.serverTimestamp(),
      });

      // 2. Update the published ride's acceptedPassengers array
      final rideDoc = await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(widget.rideId)
          .get();

      if (rideDoc.exists) {
        final rideData = rideDoc.data() as Map<String, dynamic>;
        List<dynamic> acceptedPassengersList = rideData['acceptedPassengers'] ?? [];

        // Find and update the specific passenger in the array
        bool passengerFound = false;
        for (int i = 0; i < acceptedPassengersList.length; i++) {
          if (acceptedPassengersList[i]['requestId'] == requestId) {
            acceptedPassengersList[i]['isPickedUp'] = true;
            passengerFound = true;
            break;
          }
        }

        // Only update if we found and modified the passenger
        if (passengerFound) {
          await FirebaseFirestore.instance
              .collection('publishedRides')
              .doc(widget.rideId)
              .update({
            'acceptedPassengers': acceptedPassengersList,
          });
        }
      }

      // 3. Update local state to reflect changes
      setState(() {
        for (int i = 0; i < _passengers.length; i++) {
          if (_passengers[i]['requestId'] == requestId) {
            _passengers[i]['isPickedUp'] = true;
            break;
          }
        }
        _isLoading = false;
      });

      // Show success message
      _showSuccess('Marked $passengerName as picked up. Waiting for confirmation.');
      
      // Update map if needed
      _setupMap();
      
    } catch (e) {
      print('Error marking pickup complete: $e');
      _showError('Failed to update pickup status');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _markPickupComplete() async {
    // If there are no pickup locations, just proceed
    if (_pickupLocations.isEmpty) {
      setState(() {
        _isNavigatingToPickup = false;
      });
      _setupMap();
      return;
    }

    // Make sure we have a current pickup location
    if (_currentPickupIndex >= _pickupLocations.length) {
      setState(() {
        _isNavigatingToPickup = false;
      });
      _setupMap();
      return;
    }

    // Get the current pickup location
    final currentPickupLocation = _pickupLocations[_currentPickupIndex];
    
    try {
      // Find the passenger that matches this pickup location
      String? currentPassengerId;
      Map<String, dynamic>? currentPassenger;
      
      for (var passenger in _passengers) {
        // Match by name - this assumes names are unique enough to identify passengers
        if (passenger['passengerName'] == currentPickupLocation.name) {
          currentPassengerId = passenger['requestId'];
          currentPassenger = passenger;
          break;
        }
      }

      if (currentPassengerId != null) {
        // Show loading indicator
        setState(() {
          _isLoading = true;
        });

        // 1. Update the ride request document
        await FirebaseFirestore.instance
            .collection('rideRequests')
            .doc(currentPassengerId)
            .update({
          'isPickedUp': true,
          'pickedUpAt': FieldValue.serverTimestamp(),
        });

        // 2. Update the published ride's acceptedPassengers array
        final rideDoc = await FirebaseFirestore.instance
            .collection('publishedRides')
            .doc(widget.rideId)
            .get();

        if (rideDoc.exists) {
          final rideData = rideDoc.data() as Map<String, dynamic>;
          List<dynamic> acceptedPassengersList = rideData['acceptedPassengers'] ?? [];

          // Find and update the specific passenger in the array
          bool passengerFound = false;
          for (int i = 0; i < acceptedPassengersList.length; i++) {
            if (acceptedPassengersList[i]['requestId'] == currentPassengerId) {
              acceptedPassengersList[i]['isPickedUp'] = true;
              passengerFound = true;
              break;
            }
          }

          // Only update if we found and modified the passenger
          if (passengerFound) {
            await FirebaseFirestore.instance
                .collection('publishedRides')
                .doc(widget.rideId)
                .update({
              'acceptedPassengers': acceptedPassengersList,
            });
          }
        }

        // 3. Update local state to reflect changes
        setState(() {
          for (int i = 0; i < _passengers.length; i++) {
            if (_passengers[i]['requestId'] == currentPassengerId) {
              _passengers[i]['isPickedUp'] = true;
              break;
            }
          }
          _isLoading = false;
        });

        // Show success message with passenger name
        _showSuccess('Marked ${currentPassenger?['passengerName'] ?? 'passenger'} as picked up. Waiting for confirmation.');
      } else {
        // No matching passenger found
        _showError('Could not find passenger for this pickup location');
        setState(() {
          _isLoading = false;
        });
      }

      // Move to next pickup or switch to destination mode
      if (_currentPickupIndex >= _pickupLocations.length - 1) {
        setState(() {
          _isNavigatingToPickup = false;
        });
      } else {
        setState(() {
          _currentPickupIndex++;
        });
      }
      
      // Update the map to show the next destination
      _setupMap();
      
    } catch (e) {
      print('Error marking pickup complete: $e');
      _showError('Failed to update pickup status');
      
      setState(() {
        _isLoading = false;
      });
      
      // Still proceed to next pickup or destination
      if (_currentPickupIndex >= _pickupLocations.length - 1) {
        setState(() {
          _isNavigatingToPickup = false;
        });
      } else {
        setState(() {
          _currentPickupIndex++;
        });
      }
      _setupMap();
    }
  }

  // Method to contact a passenger
  Future<void> _contactPassenger(String contact, String name) async {
    if (contact.isEmpty || contact == 'No contact info') {
      _showError('No contact information available for $name');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact $name',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.call, color: Colors.green),
              title: const Text('Call'),
              subtitle: Text(contact),
              onTap: () async {
                Navigator.pop(context);
                final Uri launchUri = Uri(
                  scheme: 'tel',
                  path: contact,
                );
                try {
                  await launchUrl(launchUri);
                } catch (e) {
                  _showError('Could not launch phone call: $e');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.blue),
              title: const Text('Message'),
              subtitle: Text(contact),
              onTap: () async {
                Navigator.pop(context);
                final Uri launchUri = Uri(
                  scheme: 'sms',
                  path: contact,
                );
                try {
                  await launchUrl(launchUri);
                } catch (e) {
                  _showError('Could not launch messaging app: $e');
                }
              },
            ),
            // Add WhatsApp option if it's a mobile number
            if (contact.length >= 10)
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('WhatsApp'),
                subtitle: Text(contact),
                onTap: () async {
                  Navigator.pop(context);
                  // Format the phone number for WhatsApp (remove spaces, dashes, etc.)
                  final formattedNumber = contact.replaceAll(RegExp(r'[^\d+]'), '');
                  final whatsappUrl = 'https://wa.me/$formattedNumber';
                  try {
                    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                      await launchUrl(Uri.parse(whatsappUrl));
                    } else {
                      _showError('WhatsApp is not installed');
                    }
                  } catch (e) {
                    _showError('Could not open WhatsApp: $e');
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
  void _handleSOSPressed() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Emergency SOS'),
      content: const Text(
        'Do you want to contact your emergency number?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _contactEmergencyNumber();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('CONTACT EMERGENCY'),
        ),
      ],
    ),
  );
}

Future<void> _contactEmergencyNumber() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User not authenticated');
      return;
    }
    
    // Get user document with emergency contact
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
        
    if (!userDoc.exists) {
      _showError('User profile not found');
      return;
    }
    
    final userData = userDoc.data() as Map<String, dynamic>;
    final emergencyContact = userData['emergencyContact'];
    
    if (emergencyContact == null || emergencyContact.isEmpty) {
      // Show dialog to set emergency contact
      _showSetEmergencyContactDialog();
      return;
    }
    
    // Call emergency contact
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: emergencyContact,
    );
    
    try {
      await launchUrl(launchUri);
    } catch (e) {
      _showError('Could not launch call: $e');
    }
  } catch (e) {
    print('Error contacting emergency number: $e');
    _showError('Failed to contact emergency number');
  }
}

void _showSetEmergencyContactDialog() {
  final TextEditingController controller = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Set Emergency Contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'You haven\'t set an emergency contact yet. Please enter a phone number to use for emergencies.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Emergency Contact Number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              Navigator.pop(context);
              _saveEmergencyContact(controller.text);
            } else {
              _showError('Please enter a valid phone number');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: const Text('SAVE'),
        ),
      ],
    ),
  );
}

Future<void> _saveEmergencyContact(String number) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'emergencyContact': number,
    });
    
    _showSuccess('Emergency contact saved');
    
    // Try to call the emergency contact
    _contactEmergencyNumber();
  } catch (e) {
    print('Error saving emergency contact: $e');
    _showError('Failed to save emergency contact');
  }
}

  void _completeRide() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Ride'),
        content: const Text(
          'Are you sure you want to mark this ride as completed? This will notify all passengers.',
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
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // 1. Update ride status to 'completed'
      await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(widget.rideId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 2. Get accepted passengers to update their status
      final QuerySnapshot acceptedPassengers = await FirebaseFirestore.instance
          .collection('rideRequests')
          .where('rideId', isEqualTo: widget.rideId)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Update all accepted ride requests to completed
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in acceptedPassengers.docs) {
        batch.update(doc.reference, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // 3. Delete the live location document
      await FirebaseFirestore.instance
          .collection('liveLocations')
          .doc(widget.locationDocId)
          .delete();

      // Stop location updates
      _stopLocationUpdates();

      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });

      _showSuccess('Ride completed successfully');

      // Return to ride details screen
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error completing ride: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to complete ride');
    }
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
  

  // Helper methods for passenger list UI
  Color _getStatusColor(bool isPickedUp, bool isConfirmed) {
    if (isPickedUp && isConfirmed) return Colors.green;
    if (isPickedUp) return Colors.orange;
    return Colors.grey;
  }

  IconData _getStatusIcon(bool isPickedUp, bool isConfirmed) {
    if (isPickedUp && isConfirmed) return Icons.check;
    if (isPickedUp) return Icons.timer;
    return Icons.person;
  }

  Widget _buildStatusBadge(bool isPickedUp, bool isConfirmed) {
    if (isPickedUp && isConfirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Confirmed',
          style: TextStyle(
            color: Colors.green.shade800,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (isPickedUp) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Waiting',
          style: TextStyle(
            color: Colors.orange.shade800,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Pending',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  // New improved passenger list
  Widget _buildPassengerList() {
    if (_passengers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'No passengers to pick up',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Passengers',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_passengers.length, (index) {
            final passenger = _passengers[index];
            final bool isPickedUp = passenger['isPickedUp'] ?? false;
            final bool isConfirmed = passenger['isPickupConfirmed'] ?? false;
            final String name = passenger['passengerName'] ?? 'Passenger';
            final String contact = passenger['passengerContact'] ?? 'No contact info';
            final String requestId = passenger['requestId'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(isPickedUp, isConfirmed),
                    ),
                    child: Center(
                      child: Icon(
                        _getStatusIcon(isPickedUp, isConfirmed),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                contact,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(isPickedUp, isConfirmed),
                  if (!isPickedUp)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () => _pickupPassenger(requestId, name),
                      tooltip: 'Mark as picked up',
                    ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.blue),
                    onPressed: () => _contactPassenger(contact, name),
                    tooltip: 'Contact passenger',
                  ),
                ],
              ),
            );
          }),
        ],
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
          onPressed: () {
            // Show confirmation dialog
            showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit Navigation'),
                content: const Text(
                  'Are you sure you want to exit navigation? The ride will continue and you can return later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('NO'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      Navigator.pop(context);
                    },
                    child: const Text('YES'),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          _isNavigatingToPickup
              ? 'Navigating to Pickup'
              : 'Navigating to Destination',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _setupMap();
              _updateDriverLocation();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map taking up the full screen
          GoogleMap(
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
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: true,
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
            // SOS Button - Add in the same position as the passenger screen
Positioned(
  top: 100,
  right: 16,
  child: FloatingActionButton(
    onPressed: _handleSOSPressed,
    backgroundColor: Colors.red,
    child: const Icon(Icons.sos, color: Colors.white),
    tooltip: 'Emergency SOS',
  ),
),

          // Bottom panel for navigation info and actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Navigation info
                  if (_isNavigatingToPickup && _pickupLocations.isNotEmpty) ...[
                    Text(
                      'Pickup ${_currentPickupIndex + 1} of ${_pickupLocations.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPassengerList(),
                    const SizedBox(height: 16),
                    // Pickup action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _markPickupComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _currentPickupIndex >= _pickupLocations.length - 1
                              ? 'ALL PASSENGERS PICKED UP'
                              : 'NEXT PASSENGER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Destination info and passenger list
                    const Text(
                      'Navigating to Destination',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rideData?['to']?['name'] ?? 'Destination',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildPassengerList(),
                    const SizedBox(height: 16),
                    // Complete ride button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _completeRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'COMPLETE RIDE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isLoading
          ? null // Hide bottom nav during loading
          : Miles2GoBottomNav(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
    );
  }
}