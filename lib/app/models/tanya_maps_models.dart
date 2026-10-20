class TanyaMapsEvent {
  final String id;
  final String title;
  final String locationName;
  final double latitude;
  final double longitude;
  final String date;
  final String htm;
  final String posterUrl;
  final double? distanceKm;
  final String? category;
  final String? socialMedia;

  const TanyaMapsEvent({
    required this.id,
    required this.title,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.htm,
    required this.posterUrl,
    this.distanceKm,
    this.category,
    this.socialMedia,
  });

  factory TanyaMapsEvent.fromFirestore(String id, Map<String, dynamic> data, {double? distance}) {
    double lat = 0.0;
    double lng = 0.0;

    if (data['lat'] is num) {
      lat = (data['lat'] as num).toDouble();
    } else if (data['lat'] is String) {
      lat = double.tryParse(data['lat'] as String) ?? 0.0;
    }

    if (data['lng'] is num) {
      lng = (data['lng'] as num).toDouble();
    } else if (data['lng'] is String) {
      lng = double.tryParse(data['lng'] as String) ?? 0.0;
    }

    // Ekstraksi poster URL dari berbagai kemungkinan struktur Firestore
    String extractedPoster = '';
    if (data['posters'] is List && (data['posters'] as List).isNotEmpty) {
      final list = data['posters'] as List;
      for (final p in list) {
        if (p is Map && p['is_main'] == true && p['url'] != null) {
          extractedPoster = p['url'].toString();
          break;
        }
      }
      if (extractedPoster.isEmpty) {
        for (final p in list) {
          if (p is Map && p['url'] != null) {
            extractedPoster = p['url'].toString();
            break;
          }
        }
      }
    }
    if (extractedPoster.isEmpty) {
      extractedPoster = data['poster_url']?.toString() ??
          data['image_url']?.toString() ??
          data['poster']?.toString() ??
          '';
    }

    // Ekstraksi nama event (prioritaskan event_name sesuai jfestchart)
    final rawTitle = (data['event_name'] ??
            data['nama_event'] ??
            data['title'] ??
            data['name'] ??
            'Event')
        .toString()
        .replaceAll(r'\n', ' ')
        .trim();

    // Ekstraksi lokasi (prioritaskan location sesuai jfestchart)
    final rawLocation = (data['location'] ??
            data['lokasi'] ??
            data['address'] ??
            'Lokasi belum tersedia')
        .toString()
        .trim();

    return TanyaMapsEvent(
      id: id,
      title: rawTitle.isNotEmpty ? rawTitle : 'Event',
      locationName: rawLocation,
      latitude: lat,
      longitude: lng,
      date: data['date']?.toString() ?? data['tanggal']?.toString() ?? '',
      htm: data['htm']?.toString() ?? data['price']?.toString() ?? 'Gratis',
      posterUrl: extractedPoster,
      distanceKm: distance,
      category: data['category']?.toString() ?? 'JEventku',
      socialMedia: data['social_media']?.toString() ?? data['instagram']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'location': locationName,
      'lat': latitude,
      'lng': longitude,
      'date': date,
      'htm': htm,
      'poster': posterUrl,
      'distanceKm': distanceKm,
    };
  }
}

class TanyaMapsMessage {
  final String id;
  final bool isUser;
  final String text;
  final List<TanyaMapsEvent> recommendedEvents;
  final DateTime timestamp;

  const TanyaMapsMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.recommendedEvents = const [],
    required this.timestamp,
  });
}
