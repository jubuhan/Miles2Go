import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
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