library web_geolocation_service;

import 'dart:js' as js;
import 'dart:async';

Future<({double lat, double lng})> getUserLocationPlatform() {
  final completer = Completer<({double lat, double lng})>();
  js.context['onGeolocationSuccess'] = (double lat, double lng) => completer.complete((lat: lat, lng: lng));
  js.context['onGeolocationError'] = (String error) => completer.completeError(error);
  js.context.callMethod('getUserLocation', ['onGeolocationSuccess', 'onGeolocationError']);
  return completer.future;
}