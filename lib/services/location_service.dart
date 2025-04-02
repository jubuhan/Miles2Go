import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:geocoding/geocoding.dart';
import '../models/location_model.dart';

class LocationService {
  // Constants
  static const String apiKey = 'AIzaSyA-qhXwh2ygO9JRbQ_22gc9WRf_Xp9Unow';
  static const double defaultZoom = 15.0;
  static const double defaultMapPadding = 100.0;
  
  final GooglePlace _googlePlace;
  Position? currentPosition;
  
  LocationService() : _googlePlace = GooglePlace(apiKey);
  
  // Initialize location services with optimized accuracy
  Future<Position?> initializeLocation(Function(String) onError) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError('Please enable location services');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError('Location permissions permanently denied');
        return null;
      }

      // First get a quick position with lower accuracy for initial map loading
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        currentPosition = lastKnownPosition;
      }
      
      // Then get a more accurate position in the background
      Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5)
      ).then((position) {
        currentPosition = position;
      }).catchError((e) {
        print('Background location update error: $e');
      });
      
      return currentPosition ?? await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low
      );
    } catch (e) {
      onError('Failed to initialize location: $e');
      return null;
    }
  }
  
  // Search for places using Google Places API
  Future<List<AutocompletePrediction>> searchPlaces(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final result = await _googlePlace.autocomplete.get(query);
      if (result != null && result.predictions != null) {
        return result.predictions!;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      return [];
    }
  }
  
  // Get location details from Place ID
  Future<LocationModel?> getLocationFromPrediction(
    AutocompletePrediction prediction,
    Function(String) onError,
  ) async {
    try {
      final details = await _googlePlace.details.get(prediction.placeId!);
      if (details?.result == null || 
          details!.result!.geometry?.location?.lat == null || 
          details.result!.geometry?.location?.lng == null) {
        onError('Could not get location details');
        return null;
      }

      final lat = details.result!.geometry!.location!.lat!;
      final lng = details.result!.geometry!.location!.lng!;
      
      return LocationModel(
        name: prediction.description!,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      debugPrint('Error selecting location: $e');
      onError('Error selecting location');
      return null;
    }
  }
  
  // Calculate LatLngBounds to fit multiple locations
  LatLngBounds getBounds(LocationModel from, LocationModel to) {
    final southwest = LatLng(
      math.min(from.latitude, to.latitude),
      math.min(from.longitude, to.longitude),
    );
    
    final northeast = LatLng(
      math.max(from.latitude, to.latitude),
      math.max(from.longitude, to.longitude),
    );
    
    return LatLngBounds(
      southwest: southwest,
      northeast: northeast,
    );
  }
  
  // Calculate bounds for multiple points
  LatLngBounds getBoundsForMultipleLocations(List<LocationModel> locations) {
    if (locations.isEmpty) {
      // Default bounds if no locations
      return LatLngBounds(
        southwest: LatLng(0, 0),
        northeast: LatLng(0, 0),
      );
    }
    
    // Start with the first location
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;
    
    // Find min and max values
    for (var location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  
  // Get routes between two locations
  Future<List<Map<String, dynamic>>> getRoutes(
    LocationModel from, 
    LocationModel to,
    Function(String) onError
  ) async {
    try {
      final origin = '${from.latitude},${from.longitude}';
      final destination = '${to.latitude},${to.longitude}';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        'alternatives=true&'
        'key=$apiKey'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        onError('Could not get directions: ${data['status']}');
        return [];
      }

      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        onError('No routes found');
        return [];
      }

      final routesList = <Map<String, dynamic>>[];

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final legs = route['legs'] as List;
        final leg = legs[0];
        
        routesList.add({
          'index': i,
          'distance': leg['distance']['text'],
          'duration': leg['duration']['text'],
          'summary': route['summary'],
          'points': route['overview_polyline']['points'],
        });
      }

      return routesList;
    } catch (e) {
      debugPrint('Error getting routes: $e');
      onError('Error getting routes');
      return [];
    }
  }
  
  // Get routes with waypoints between two locations
  Future<Map<String, dynamic>?> getRouteWithWaypoints(
    LocationModel from,
    LocationModel to,
    List<LocationModel> waypoints,
    Function(String) onError,
  ) async {
    try {
      final origin = '${from.latitude},${from.longitude}';
      final destination = '${to.latitude},${to.longitude}';
      
      // Format waypoints string
      // Don't use via: prefix to ensure the waypoints are actually included in the route
      // Use optimize:true to let Google reorder waypoints for the most efficient route
      final waypointsParam = 'optimize:true|' + waypoints.map((wp) => 
        '${wp.latitude},${wp.longitude}'
      ).join('|');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        'waypoints=$waypointsParam&'
        'key=$apiKey'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        if (data['status'] == 'ZERO_RESULTS') {
          onError('One or more stops are not reachable by road. Try moving them closer to a road.');
        } else {
          onError('Could not get directions with waypoints: ${data['status']}');
        }
        return null;
      }

      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        onError('No routes found with waypoints');
        return null;
      }

      // Get the first (and likely only) route with waypoints
      final route = routes[0];
      final legs = route['legs'] as List;
      
      // Get the waypoint order if provided
      List<int>? waypointOrder;
      if (route.containsKey('waypoint_order')) {
        waypointOrder = List<int>.from(route['waypoint_order']);
      }
      
      // Calculate total distance and duration
      double distanceMeters = 0;
      double durationSeconds = 0;
      
      for (var leg in legs) {
        distanceMeters += leg['distance']['value'];
        durationSeconds += leg['duration']['value'];
      }
      
      // Format the totals
      final totalDistance = legs.length == 1 ? 
        legs[0]['distance']['text'] : 
        _formatDistance(distanceMeters);
        
      final totalDuration = legs.length == 1 ? 
        legs[0]['duration']['text'] : 
        _formatDuration(durationSeconds);
      
      return {
        'index': 0,
        'distance': totalDistance,
        'duration': totalDuration,
        'summary': route['summary'] ?? 'Route with stops',
        'points': route['overview_polyline']['points'],
        'waypointOrder': waypointOrder,
      };
    } catch (e) {
      debugPrint('Error getting routes with waypoints: $e');
      onError('Error getting routes with waypoints');
      return null;
    }
  }
  
  // Helper method to format distance
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
  
  // Helper method to format duration
  String _formatDuration(double seconds) {
    final Duration duration = Duration(seconds: seconds.round());
    if (duration.inHours > 0) {
      return '${duration.inHours} hr ${duration.inMinutes.remainder(60)} min';
    } else {
      return '${duration.inMinutes} min';
    }
  }
  
  // Get address from lat-lng coordinates using Google Places API
  Future<String?> getAddressFromLatLng(LatLng position) async {
    try {
      // Use the Google Places API to get a nearby address
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=${position.latitude},${position.longitude}&'
        'key=$apiKey'
      );
      
      final response = await http.get(url);
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
        // Get the first result which should be the most accurate
        final address = data['results'][0]['formatted_address'];
        return address ?? 'Custom Stop';
      }
      
      return 'Custom Stop';
    } catch (e) {
      debugPrint('Error getting address: $e');
      return 'Custom Stop';
    }
  }
  
  // Get current position with optimized accuracy - Improved version
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        // Try to enable location services (on Android)
        try {
          await Geolocator.openLocationSettings();
          // Check again after user potentially enables it
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            return null;
          }
        } catch (e) {
          print('Error opening location settings: $e');
          return null;
        }
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied');
        return null;
      }

      // First try - with provided accuracy and timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
          timeLimit: timeout,
        );
        
        currentPosition = position;
        return position;
      } catch (e) {
        print('First location attempt failed: $e');
        // Don't return - continue to try fallbacks
      }
      
      // Second try - with medium accuracy and extended timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
        
        currentPosition = position;
        return position;
      } catch (e) {
        print('Second location attempt failed: $e');
        // Don't return - continue to try fallbacks
      }
      
      // Third try - with low accuracy
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 20),
        );
        
        currentPosition = position;
        return position;
      } catch (e) {
        print('Third location attempt failed: $e');
        // Now try last known position
      }
      
      // Last fallback - get last known position
      print('Falling back to last known position');
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        currentPosition = lastPosition;
        return lastPosition;
      }
      
      // If we have a stored position from earlier in the app session, use that
      if (currentPosition != null) {
        return currentPosition;
      }
      
      print('All location attempts failed');
      return null;
    } catch (e) {
      print('Error in getCurrentPosition: $e');
      return currentPosition; // Return last stored position if available
    }
  }

  // Get latitude and longitude from a string address
  Future<LatLng?> getLatLngFromAddress(String address, Function(String) onError) async {
    try {
      if (address.isEmpty) {
        onError('Address is empty');
        return null;
      }

      // Use the Google Places API to geocode address
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'address=${Uri.encodeComponent(address)}&'
        'key=$apiKey'
      );
      
      final response = await http.get(url);
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        
        return LatLng(lat, lng);
      } else {
        onError('Could not geocode address: ${data['status']}');
        return null;
      }
    } catch (e) {
      onError('Error geocoding address: $e');
      return null;
    }
  }
  
  // Decode Google polyline to list of LatLng
  List<LatLng> decodePolyline(String encoded) {
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
}