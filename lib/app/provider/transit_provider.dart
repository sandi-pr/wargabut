import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/transit_maps.dart';


class TransitProvider extends ChangeNotifier {
  bool _isFetching = false;
  List<Map<String, dynamic>> _routes = [];
  String? _error;

  bool get isFetching => _isFetching;
  List<Map<String, dynamic>> get routes => _routes;
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

      final transitDetails = await TransitService.getTransitDetails(
        userPosition.latitude,
        userPosition.longitude,
        destLatLng.latitude,
        destLatLng.longitude,
        allowedTravelModes: allowedTravelModes,
        routingPreference: routingPreference,
      );

      _routes = List<Map<String, dynamic>>.from(transitDetails);
    } catch (e) {
      if (kDebugMode) {
        print("❌ Transit error: $e");
      }
      _routes = [];
      _error = e.toString();
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  void clearRoutes() {
    _routes = [];
    _error = null;
    notifyListeners();
  }
}
