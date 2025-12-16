import 'dart:js' as js;
import 'dart:async';

class WebGeolocationService {
  static Future<({double lat, double lng})> getUserLocation() {
    final completer = Completer<({double lat, double lng})>();

    js.context['onGeolocationSuccess'] = (double lat, double lng) {
      if (!completer.isCompleted) {
        completer.complete((lat: lat, lng: lng));
      }
    };

    js.context['onGeolocationError'] = (String errorMsg) {
      if (!completer.isCompleted) {
        completer.completeError(errorMsg);
      }
    };

    js.context.callMethod(
      'getUserLocation',
      ['onGeolocationSuccess', 'onGeolocationError'],
    );

    return completer.future;
  }
}
