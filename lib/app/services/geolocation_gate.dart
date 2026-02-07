// geolocation_gate.dart
export 'geolocation_platform_stub.dart'
  if (dart.library.js) 'package:wargabut/app/services/web_only/web_geolocation_service.dart'
  if (dart.library.io) 'mobile_geolocation_service.dart';