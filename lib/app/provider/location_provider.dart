import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/geolocation_gate.dart';

class LocationProvider extends ChangeNotifier {
  bool _isFetching = false;
  Position? _userPosition;
  String? _userAddress;
  String? _error;

  // ===== Getters =====
  bool get isFetching => _isFetching;
  Position? get userPosition => _userPosition;
  String? get userAddress => _userAddress;
  String? get error => _error;

  // ===== Actions =====
  Future<void> fetchUserLocationWeb() async { // Nama fungsi tetap, tapi isinya dinamis
    _isFetching = true;
    _error = null;
    notifyListeners();

    try {
      // Sekarang memanggil fungsi hasil conditional import
      final pos = await getUserLocationPlatform();

      _userPosition = Position(
        latitude: pos.lat,
        longitude: pos.lng,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      _userAddress = "Lat: ${pos.lat}, Lng: ${pos.lng}";
    } catch (e) {
      _error = "Gagal mendapatkan lokasi: $e";
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  void clearLocation() {
    _userPosition = null;
    _userAddress = null;
    _error = null;
    notifyListeners();
  }
}
