// lib/src/services/geolocation_interop.dart

@JS()
library geolocation_interop;

import 'dart:async';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

// Anotasi @JS() tanpa nama menargetkan objek 'window' global
@JS()
external Navigator get navigator;

@JS()
@anonymous
class Navigator {
  external Geolocation get geolocation;
}

@JS()
@anonymous
class Geolocation {
  // Memetakan fungsi getCurrentPosition
  external void getCurrentPosition(
      Function successCallback,
      Function errorCallback,
      );
}

// Memetakan objek Position yang dikembalikan oleh browser
@JS()
@anonymous
class Geoposition {
  external GeolocationCoordinates get coords;
}

@JS()
@anonymous
class GeolocationCoordinates {
  external double get latitude;
  external double get longitude;
  external double get accuracy;
}

// Memetakan objek error
@JS()
@anonymous
class GeolocationPositionError {
  external String get message;
}

/// Fungsi high-level untuk memanggil API dan mengubahnya menjadi Future
/// Ini akan menjadi satu-satunya fungsi yang perlu Anda panggil dari UI.
Future<GeolocationCoordinates> getCurrentPosition() {
  final completer = Completer<GeolocationCoordinates>();

  // Panggil fungsi JS dan teruskan callback Dart secara langsung
  navigator.geolocation.getCurrentPosition(
    allowInterop((Geoposition position) {
      // Jika berhasil, selesaikan Future dengan data koordinat
      completer.complete(position.coords);
    }),
    allowInterop((GeolocationPositionError error) {
      // Jika gagal, selesaikan Future dengan error
      completer.completeError(error.message);
    }),
  );

  return completer.future;
}