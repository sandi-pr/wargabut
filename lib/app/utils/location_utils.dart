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

/// Daftar wilayah standar Jabodetabek
const List<String> jabodetabekAreas = [
  'Jakarta',
  'Jakarta Pusat',
  'Jakarta Utara',
  'Jakarta Barat',
  'Jakarta Timur',
  'Jakarta Selatan',
  'Bogor',
  'Depok',
  'Tangerang',
  'Tangerang Selatan',
  'Bekasi',
];

/// Mengecek apakah suatu nama area atau teks lokasi termasuk wilayah Jabodetabek
bool isJabodetabekArea(String? area) {
  if (area == null) return false;
  final lower = area.trim().toLowerCase();
  if (lower.isEmpty) return false;
  return lower.contains('jakarta') ||
      lower.contains('kepulauan seribu') ||
      lower.contains('bogor') ||
      lower.contains('depok') ||
      lower.contains('tangerang') ||
      lower.contains('tangsel') ||
      lower.contains('bekasi') ||
      lower.contains('jabodetabek');
}