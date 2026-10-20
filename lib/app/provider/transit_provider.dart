import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/transit_maps.dart';


class TransitProvider extends ChangeNotifier {
  bool _isFetching = false;
  List<Map<String, dynamic>> _routes = [];
  String? _totalDuration;
  String? _totalDistance;
  int _totalDurationSeconds = 0;
  int _totalDistanceMeters = 0;
  String? _overallEncodedPolyline;
  LatLng? _startLocation;
  LatLng? _endLocation;
  LatLngBounds? _bounds;
  String? _error;

  bool get isFetching => _isFetching;
  List<Map<String, dynamic>> get routes => _routes;
  String? get totalDuration => _totalDuration;
  String? get totalDistance => _totalDistance;
  int get totalDurationSeconds => _totalDurationSeconds;
  int get totalDistanceMeters => _totalDistanceMeters;
  String? get overallEncodedPolyline => _overallEncodedPolyline;
  LatLng? get startLocation => _startLocation;
  LatLng? get endLocation => _endLocation;
  LatLngBounds? get bounds => _bounds;
  String? get error => _error;

  Future<void> fetchTransitRoutes({
    required Position userPosition,
    required String destinationLocation,
    required List<String> allowedTravelModes,
    required String? routingPreference,
  }) async {
    _isFetching = true;
    _error = null;
    notifyListeners();

    try {
      final destLatLng =
          await GeocodingService.getLatLngFromLocationName(destinationLocation);

      if (destLatLng == null) {
        throw Exception("Lokasi tujuan tidak ditemukan");
      }

      final routeInfo = await TransitService.getTransitRouteInfo(
        userPosition.latitude,
        userPosition.longitude,
        destLatLng.latitude,
        destLatLng.longitude,
        allowedTravelModes: allowedTravelModes,
        routingPreference: routingPreference,
        destinationName: destinationLocation,
      );

      _routes = List<Map<String, dynamic>>.from(routeInfo.segments);
      _totalDuration = routeInfo.totalDuration;
      _totalDistance = routeInfo.totalDistance;
      _totalDurationSeconds = routeInfo.totalDurationSeconds;
      _totalDistanceMeters = routeInfo.totalDistanceMeters;
      _overallEncodedPolyline = routeInfo.overallEncodedPolyline;
      _startLocation = routeInfo.startLocation;
      _endLocation = routeInfo.endLocation;
      _bounds = routeInfo.bounds;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Transit error: $e");
      }
      _routes = [];
      _totalDuration = null;
      _totalDistance = null;
      _totalDurationSeconds = 0;
      _totalDistanceMeters = 0;
      _overallEncodedPolyline = null;
      _startLocation = null;
      _endLocation = null;
      _bounds = null;
      _error = e.toString();
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  void clearRoutes() {
    _routes = [];
    _totalDuration = null;
    _totalDistance = null;
    _totalDurationSeconds = 0;
    _totalDistanceMeters = 0;
    _overallEncodedPolyline = null;
    _startLocation = null;
    _endLocation = null;
    _bounds = null;
    _error = null;
    notifyListeners();
  }
}
