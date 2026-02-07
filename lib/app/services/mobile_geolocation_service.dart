import 'package:geolocator/geolocator.dart';

Future<({double lat, double lng})> getUserLocationPlatform() async {
  Position pos = await Geolocator.getCurrentPosition();
  return (lat: pos.latitude, lng: pos.longitude);
}