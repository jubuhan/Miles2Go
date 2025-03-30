import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../models/location_model.dart';
import './bottom_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassengerRideTrackingScreen extends StatefulWidget {
  final String rideId;
  final String locationDocId;
  final String pickupLocation;
  
  const PassengerRideTrackingScreen({
    Key? key,
    required this.rideId,
    required this.locationDocId,
    required this.pickupLocation,
  }) : super(key: key);

  @override
  State<PassengerRideTrackingScreen> createState() => _PassengerRideTrackingScreenState();
}

class _PassengerRideTrackingScreenState extends State<PassengerRideTrackingScreen> {
  int _selectedIndex = 1; // Set to 1 for Find Rides tab
  bool _isLoading = true;
  
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _pickedUpByDriver = false;
  bool _pickupConfirmed = false;
  String _requestId = '';
  bool _hasShownPickupDialog = false;
  
  // Ride completion variables
  bool _rideCompleted = false;
  bool _dropoffConfirmed = false;
  
  // Stream subscription for driver's location updates
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  
  // Ride and location data
  Map<String, dynamic>? _rideData;
  Map<String, dynamic>? _driverLocation;
  
  // ETA calculation
  String _estimatedArrival = 'Calculating...';
  Timer? _etaTimer;
  
  @override
  void initState() {
    super.initState();
    _fetchRideDetails();
    _startLocationUpdates();
    _listenForPickupStatus();
    _listenForRideCompletion(); // Added for ride completion 
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    _mapController?.dispose();
    _etaTimer?.cancel();
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

    setState(() {
      _rideData = data;
      _isLoading = false;
    });
    
    // Fetch driver contact information
    final driverId = data['userId'] ?? data['driverId'];
    if (driverId != null) {
      final driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();
          
      if (driverDoc.exists) {
        final driverData = driverDoc.data() as Map<String, dynamic>;
        final phoneNumber = driverData['phoneNumber'];
        
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          setState(() {
            _rideData = {
              ..._rideData!,
              'driverContact': phoneNumber,
            };
          });
          print('Driver contact updated: $phoneNumber');
        }
      }
    }
  } catch (e) {
    print('Error fetching ride details: $e');
    setState(() {
      _isLoading = false;
    });
    _showError('Failed to load ride details');
  }
}
  void _startLocationUpdates() {
    // Listen to real-time updates on the driver's location
    _locationSubscription = FirebaseFirestore.instance
        .collection('liveLocations')
        .doc(widget.locationDocId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _driverLocation = snapshot.data() as Map<String, dynamic>;
        });
        
        // Update the map with the new location
        _updateMapWithDriverLocation();
        
        // Update ETA
        _updateEstimatedArrival();
      }
    }, onError: (error) {
      print('Error listening to location updates: $error');
    });
    
    // Set up a timer to update the ETA periodically
    _etaTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_driverLocation != null) {
        _updateEstimatedArrival();
      }
    });
  }
  
  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _etaTimer?.cancel();
    _etaTimer = null;
  }
  
  void _updateMapWithDriverLocation() async {
    if (_driverLocation == null || !mounted) return;
    
    final driverLat = _driverLocation!['latitude'];
    final driverLng = _driverLocation!['longitude'];
    
    if (driverLat == null || driverLng == null) return;
    
    // Add or update driver marker
    _addMarker(
      'driver', 
      driverLat, 
      driverLng, 
      'Driver Location', 
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
    );
    
    // Add or update pickup marker
    LatLng? pickupLatLng;
    
    // Try to get pickup location coordinates
    if (widget.pickupLocation.isNotEmpty) {
      pickupLatLng = await _locationService.getLatLngFromAddress(
        widget.pickupLocation,
        (error) => print('Error geocoding pickup: $error')
      );
    }
    
    if (pickupLatLng != null) {
      _addMarker(
        'pickup', 
        pickupLatLng.latitude, 
        pickupLatLng.longitude, 
        'Your Pickup', 
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
      );
      
      // Draw route from driver to pickup
      _drawRoute(
        LatLng(driverLat, driverLng),
        pickupLatLng
      );
    }
    
    // Animate camera to show both driver and pickup
    if (_mapController != null && pickupLatLng != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(driverLat, pickupLatLng.latitude),
          math.min(driverLng, pickupLatLng.longitude),
        ),
        northeast: LatLng(
          math.max(driverLat, pickupLatLng.latitude),
          math.max(driverLng, pickupLatLng.longitude),
        ),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, LocationService.defaultMapPadding),
      );
    } else if (_mapController != null) {
      // If we couldn't get pickup coordinates, just focus on driver
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(driverLat, driverLng),
          15.0,
        ),
      );
    }
  }
  
  Future<void> _drawRoute(LatLng from, LatLng to) async {
    try {
      final fromLocation = LocationModel(
        name: 'Driver',
        latitude: from.latitude,
        longitude: from.longitude,
      );
      
      final toLocation = LocationModel(
        name: 'Pickup',
        latitude: to.latitude,
        longitude: to.longitude,
      );
      
      final routes = await _locationService.getRoutes(
        fromLocation, 
        toLocation,
        (error) => print('Error getting route: $error')
      );
      
      if (routes.isNotEmpty) {
        final route = routes.first;
        final polylinePoints = _locationService.decodePolyline(route['points']);
        
        final polyline = Polyline(
          polylineId: const PolylineId('driver_to_pickup'),
          color: Colors.blue,
          points: polylinePoints,
          width: 5,
        );
        
        setState(() {
          _polylines = {polyline};
        });
      }
    } catch (e) {
      print('Error drawing route: $e');
    }
  }
  
  void _updateEstimatedArrival() async {
    if (_driverLocation == null) return;
    
    final driverLat = _driverLocation!['latitude'];
    final driverLng = _driverLocation!['longitude'];
    
    if (driverLat == null || driverLng == null) return;
    
    // Get pickup location coordinates
    LatLng? pickupLatLng;
    if (widget.pickupLocation.isNotEmpty) {
      pickupLatLng = await _locationService.getLatLngFromAddress(
        widget.pickupLocation,
        (error) => print('Error geocoding pickup: $error')
      );
    }
    
    if (pickupLatLng != null) {
      final fromLocation = LocationModel(
        name: 'Driver',
        latitude: driverLat,
        longitude: driverLng,
      );
      
      final toLocation = LocationModel(
        name: 'Pickup',
        latitude: pickupLatLng.latitude,
        longitude: pickupLatLng.longitude,
      );
      
      final routes = await _locationService.getRoutes(
        fromLocation, 
        toLocation,
        (error) => print('Error getting route for ETA: $error')
      );
      
      if (routes.isNotEmpty) {
        final route = routes.first;
        final duration = route['duration'];
        
        setState(() {
          _estimatedArrival = duration;
        });
      }
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

  
  // Enhanced method to contact the driver
  Future<void> _contactDriver() async {
    if (_rideData == null) {
      _showError('Ride information not available');
      return;
    }
    
    // Get driver contact info
    final String driverName = _rideData!['driverName'] ?? 'Driver';
    final String? driverContact = _rideData!['driverContact'];
    
    if (driverContact == null || driverContact.isEmpty) {
      _showError('Driver contact information is not available');
      return;
    }
    
    // Show contact options
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact $driverName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_rideData!.containsKey('vehicleDetails'))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _getVehicleDescription(_rideData!),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.call, color: Colors.green),
              title: const Text('Call'),
              subtitle: Text(driverContact),
              onTap: () async {
                Navigator.pop(context);
                final Uri launchUri = Uri(
                  scheme: 'tel',
                  path: driverContact,
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
              subtitle: Text(driverContact),
              onTap: () async {
                Navigator.pop(context);
                final Uri launchUri = Uri(
                  scheme: 'sms',
                  path: driverContact,
                );
                try {
                  await launchUrl(launchUri);
                } catch (e) {
                  _showError('Could not launch messaging app: $e');
                }
              },
            ),
            // Add WhatsApp option if it's a mobile number
            if (driverContact.length >= 10)
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('WhatsApp'),
                subtitle: Text(driverContact),
                onTap: () async {
                  Navigator.pop(context);
                  // Format the phone number for WhatsApp (remove spaces, dashes, etc.)
                  final formattedNumber = driverContact.replaceAll(RegExp(r'[^\d+]'), '');
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
  
  // Enhanced method to listen for pickup status
  void _listenForPickupStatus() {
    // Get the current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    print('Setting up pickup status listener for user: ${user.uid} and ride: ${widget.rideId}');
    
    // First, find the request ID
    FirebaseFirestore.instance
      .collection('rideRequests')
      .where('rideId', isEqualTo: widget.rideId)
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'accepted')
      .limit(1)
      .get()
      .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final requestId = snapshot.docs.first.id;
          
          print('Found request ID: $requestId, setting up real-time listener');
          
          // Now set up a real-time listener specifically for this document
          FirebaseFirestore.instance
            .collection('rideRequests')
            .doc(requestId)
            .snapshots()
            .listen((docSnapshot) {
              if (docSnapshot.exists) {
                final data = docSnapshot.data() as Map<String, dynamic>;
                
                print('Pickup status update: isPickedUp=${data['isPickedUp']}, isPickupConfirmed=${data['isPickupConfirmed']}');
                
                setState(() {
                  _requestId = requestId;
                  _pickedUpByDriver = data['isPickedUp'] ?? false;
                  _pickupConfirmed = data['isPickupConfirmed'] ?? false;
                });
                
                // Show the confirmation dialog if needed
                if (_pickedUpByDriver && !_pickupConfirmed && !_hasShownPickupDialog) {
                  setState(() {
                    _hasShownPickupDialog = true;
                  });
                  _showPickupConfirmationDialog();
                }
              }
            }, onError: (e) {
              print('Error listening to pickup status: $e');
            });
        } else {
          print('No ride request found for this user and ride');
        }
      })
      .catchError((e) {
        print('Error finding ride request: $e');
      });
  }
  
  // Enhanced method to show pickup confirmation dialog
  void _showPickupConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Pickup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The driver has marked you as picked up. Please confirm that you have been picked up.',
            ),
            const SizedBox(height: 16),
            if (_rideData != null && _rideData!.containsKey('driverName'))
              Text(
                'Driver: ${_rideData!['driverName']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (_rideData != null && _rideData!.containsKey('vehicleDetails')) 
              Text(
                'Vehicle: ${_getVehicleDescription(_rideData!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // If user dismisses without confirming, we'll show again later
              _hasShownPickupDialog = false;
              _showContactDriverDialog();
            },
            child: const Text('NOT YET'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmPickup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('CONFIRM PICKUP'),
          ),
        ],
      ),
    );
  }
  
  // Add this method to handle when passenger says they haven't been picked up
  void _showContactDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not Picked Up?'),
        content: const Text(
          'If the driver has marked you as picked up but you haven\'t been, you should contact them to clarify your pickup location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DISMISS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _contactDriver();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('CONTACT DRIVER'),
          ),
        ],
      ),
    );
  }
  
  // Enhanced confirmPickup method with more feedback
  Future<void> _confirmPickup() async {
    if (_requestId.isEmpty) {
      _showError('Cannot confirm pickup: Request ID not found');
      return;
    }
    
    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Update the ride request
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(_requestId)
          .update({
        'isPickupConfirmed': true,
        'pickupConfirmedAt': FieldValue.serverTimestamp(),
      });
      
      // Also update in the published ride's acceptedPassengers array
      final rideDoc = await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(widget.rideId)
          .get();
      
      if (rideDoc.exists) {
        final rideData = rideDoc.data() as Map<String, dynamic>;
        List<dynamic> acceptedPassengersList = rideData['acceptedPassengers'] ?? [];
        
        // Find the passenger in the list and update pickup status
        bool found = false;
        for (int i = 0; i < acceptedPassengersList.length; i++) {
          if (acceptedPassengersList[i]['requestId'] == _requestId) {
            acceptedPassengersList[i]['isPickupConfirmed'] = true;
            found = true;
            break;
          }
        }
        
        // Update the document with the modified list
        if (found) {
          await FirebaseFirestore.instance
              .collection('publishedRides')
              .doc(widget.rideId)
              .update({
            'acceptedPassengers': acceptedPassengersList,
          });
        }
      }
      
      // Update state
      setState(() {
        _pickupConfirmed = true;
        _isLoading = false;
      });
      
      _showSuccess('Pickup confirmed! Enjoy your ride.');
    } catch (e) {
      print('Error confirming pickup: $e');
      _showError('Failed to confirm pickup: ${e.toString()}');
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // RIDE COMPLETION METHODS
  
  // Method to listen for ride completion
  void _listenForRideCompletion() {
    // First, find the request ID if we don't have it yet
    if (_requestId.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      FirebaseFirestore.instance
        .collection('rideRequests')
        .where('rideId', isEqualTo: widget.rideId)
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            setState(() {
              _requestId = snapshot.docs.first.id;
            });
            
            // Now that we have the request ID, set up the real-time listener
            _setupRideCompletionListener();
          }
        })
        .catchError((e) {
          print('Error finding ride request: $e');
        });
    } else {
      // If we already have the request ID, just set up the listener
      _setupRideCompletionListener();
    }
  }

  void _setupRideCompletionListener() {
    // Listen to both the ride document and the ride request document
    
    // 1. Listen to published ride for completion status
    FirebaseFirestore.instance
      .collection('publishedRides')
      .doc(widget.rideId)
      .snapshots()
      .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];
          
          if (status == 'completed') {
            // Ride has been marked as completed by driver
            setState(() {
              _rideCompleted = true;
            });
            
            // If not already confirmed, show completion confirmation dialog
            if (!_dropoffConfirmed) {
              _showRideCompletionDialog();
            }
          }
        }
      }, onError: (e) {
        print('Error listening to ride updates: $e');
      });
    
    // 2. Listen to ride request for this specific passenger's dropoff status
    if (_requestId.isNotEmpty) {
      FirebaseFirestore.instance
        .collection('rideRequests')
        .doc(_requestId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            
            setState(() {
              _rideCompleted = data['status'] == 'completed';
              _dropoffConfirmed = data['isDropoffConfirmed'] ?? false;
            });
          }
        }, onError: (e) {
          print('Error listening to ride request updates: $e');
        });
    }
  }

  void _showRideCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ride Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The driver has marked this ride as completed. Please confirm you\'ve reached your destination.',
            ),
            const SizedBox(height: 12),
            if (_rideData != null && _rideData!.containsKey('driverName'))
              Text(
                'Driver: ${_rideData!['driverName']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showNotReachedDestinationDialog();
            },
            child: const Text('NOT AT DESTINATION'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmRideCompletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('CONFIRM COMPLETION'),
          ),
        ],
      ),
    );
  }

  void _showNotReachedDestinationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not at Destination?'),
        content: const Text(
          'If you haven\'t reached your destination yet, please contact the driver to resolve the issue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DISMISS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _contactDriver();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('CONTACT DRIVER'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRideCompletion() async {
    if (_requestId.isEmpty) {
      _showError('Cannot confirm completion: Request ID not found');
      return;
    }
    
    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Update the ride request
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(_requestId)
          .update({
        'isDropoffConfirmed': true,
        'dropoffConfirmedAt': FieldValue.serverTimestamp(),
      });
      
      // Also update in the published ride's acceptedPassengers array
      final rideDoc = await FirebaseFirestore.instance
          .collection('publishedRides')
          .doc(widget.rideId)
          .get();
      
      if (rideDoc.exists) {
        final rideData = rideDoc.data() as Map<String, dynamic>;
        List<dynamic> acceptedPassengersList = rideData['acceptedPassengers'] ?? [];
        
        // Find the passenger in the list and update dropoff status
        bool found = false;
        for (int i = 0; i < acceptedPassengersList.length; i++) {
          if (acceptedPassengersList[i]['requestId'] == _requestId) {
            acceptedPassengersList[i]['isDropoffConfirmed'] = true;
            found = true;
            break;
          }
        }
        
        // Update the document with the modified list
        if (found) {
          await FirebaseFirestore.instance
              .collection('publishedRides')
              .doc(widget.rideId)
              .update({
            'acceptedPassengers': acceptedPassengersList,
          });
        }
      }
      
      // Update state
      setState(() {
        _dropoffConfirmed = true;
        _isLoading = false;
      });
      
      _showSuccess('Ride completion confirmed! Thank you for using our service.');
      
      // Navigate back to home screen or ride history after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      
    } catch (e) {
      print('Error confirming ride completion: $e');
      _showError('Failed to confirm ride completion: ${e.toString()}');
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to build the ride completion status UI
  Widget _buildRideCompletionStatus() {
    if (!_rideCompleted) {
      return const SizedBox.shrink(); // Don't show anything if ride is not completed
    }
    
    if (_dropoffConfirmed) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ride Completed',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'You have confirmed arrival at your destination',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Has Completed the Ride',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Please confirm you\'ve reached your destination',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showNotReachedDestinationDialog(),
                  child: const Text('NOT AT DESTINATION'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _confirmRideCompletion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CONFIRM COMPLETION'),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
  
  // Enhanced pickup status indicator
  Widget _buildPickupStatusIndicator() {
    if (_pickedUpByDriver && _pickupConfirmed) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup Confirmed',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'You have confirmed that you were picked up',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } 
    else if (_pickedUpByDriver) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Has Marked You as Picked Up',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Please confirm if you have been picked up',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showContactDriverDialog(),
                  child: const Text('NOT PICKED UP YET'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _confirmPickup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CONFIRM PICKUP'),
                ),
              ],
            ),
          ],
        ),
      );
    } 
    else {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting for Pickup',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Driver will mark you as picked up when they arrive',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
          'Track Your Ride',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _updateMapWithDriverLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map taking up the full screen
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _updateMapWithDriverLocation(); // Update map once controller is available
            },
            initialCameraPosition: CameraPosition(
              target: const LatLng(0, 0), // Will be updated when driver location is available
              zoom: LocationService.defaultZoom,
            ),
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),
          
          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
            
          // Bottom panel with ETA and contact driver button
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
                  // Driver info and ETA
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.directions_car, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _rideData?['driverName'] ?? 'Your Driver',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'ETA: $_estimatedArrival',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Vehicle info
                  if (_rideData != null && _rideData!.containsKey('vehicleDetails')) ...[
                    Row(
                      children: [
                        const Icon(Icons.car_rental, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getVehicleDescription(_rideData!),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Pickup status indicator
                  _buildPickupStatusIndicator(),
                  
                  // Add ride completion status indicator
                  _buildRideCompletionStatus(),
                  
                  const SizedBox(height: 16),
                  
                  // Contact driver button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _contactDriver,
                      icon: const Icon(Icons.phone),
                      label: const Text('CONTACT DRIVER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
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