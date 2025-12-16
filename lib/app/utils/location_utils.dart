import 'dart:math' as math;

double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    ) {
  const double earthRadiusKm = 6371;

  double dLat = _degToRad(lat2 - lat1);
  double dLon = _degToRad(lon2 - lon1);

  double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_degToRad(lat1)) *
              math.cos(_degToRad(lat2)) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);

  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadiusKm * c;
}

double _degToRad(double deg) {
  return deg * (math.pi / 180);
}