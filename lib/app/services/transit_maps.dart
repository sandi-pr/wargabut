import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TransitService {
  static Future<List<Map<String, dynamic>>> getTransitDetails(
    double latOrigin,
    double lngOrigin,
    double latDest,
    double lngDest, {
    List<String> allowedTravelModes = const ["RAIL"],
    String? routingPreference,
  }) async {
    const String apiKey = "AIzaSyCdAdBDmGPawerj-jc57RtGLm3_pFxQZCo";
    const String url =
        "https://routes.googleapis.com/directions/v2:computeRoutes";

    final Map<String, dynamic> body = {
      "origin": {
        "location": {
          "latLng": {"latitude": latOrigin, "longitude": lngOrigin}
        }
      },
      "destination": {
        "location": {
          "latLng": {"latitude": latDest, "longitude": lngDest}
        }
      },
      "travelMode": "TRANSIT",
      "transitPreferences": {
        "allowedTravelModes": allowedTravelModes,
        if (routingPreference != null) "routingPreference": routingPreference,
      },
      // "computeAlternativeRoutes": true,
      "languageCode": "id-ID"
    };

    try {
      final response = await Dio().post(
        url,
        data: body,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask": "routes.*"
          },
        ),
      );

      final data = response.data;
      if (data["routes"] == null || data["routes"].isEmpty) {
        throw Exception("Tidak ada rute ditemukan");
      }

      List<Map<String, dynamic>> transitSteps = [];

      if (kDebugMode) {
        print("=========================================");
        print("cek data: ${json.encode(data)}");
        print("=========================================");
      }

      // Iterasi melalui semua rute yang tersedia
      for (var route in data["routes"]) {
        for (var leg in route["legs"]) {
          for (var step in leg["steps"]) {
            // if (kDebugMode) {
            //   print("=========================================");
            //   print("cek step: $step");
            //   print("=========================================");
            // }
            // Menangani langkah transit
            if (step.containsKey("transitDetails")) {
              var transit = step["transitDetails"];

              transitSteps.add({
                "type": "TRANSIT",
                "departure": transit["stopDetails"]["departureStop"]["name"],
                "departureTime": transit["localizedValues"]["departureTime"]
                    ["time"]["text"],
                "arrival": transit["stopDetails"]["arrivalStop"]["name"],
                "arrivalTime": transit["localizedValues"]["arrivalTime"]["time"]
                    ["text"],
                "codeLine": transit["transitLine"]["nameShort"],
                "agency": transit["transitLine"]["agencies"][0]["name"],
                "line": transit["transitLine"]["name"],
                "headsign": transit["headsign"],
                "vehicle": transit["transitLine"]["vehicle"]["name"]["text"],
                "stopCount": transit["stopCount"],
                "navigationInstruction":
                    step.containsKey("navigationInstruction")
                        ? step["navigationInstruction"]["instructions"]
                        : null
              });
            }
            // Menangani langkah berjalan (WALK)
            // else if (step["travelMode"] == "WALK") {
            //   Map<String, dynamic> walkStep = {
            //     "type": "WALK",
            //     "distance": step["localizedValues"]["distance"]["text"],
            //     "duration": step["localizedValues"]["staticDuration"]["text"]
            //   };
            //
            //   if (step.containsKey("navigationInstruction") &&
            //       step["navigationInstruction"] is Map &&
            //       step["navigationInstruction"].containsKey("instructions") &&
            //       step["navigationInstruction"]["instructions"] != null) {
            //     walkStep["navigationInstruction"] = step["navigationInstruction"]["instructions"];
            //   }
            //
            //   transitSteps.add(walkStep);
            // }
          }
        }
      }

      return transitSteps;
    } catch (e) {
      throw Exception("Error saat mengambil data rute: $e");
    }
  }
}

class GeocodingService {
  static Future<LatLng?> getLatLngFromLocationName(String locationName) async {
    const String apiKey =
        "AIzaSyCdAdBDmGPawerj-jc57RtGLm3_pFxQZCo"; // Ganti dengan milikmu
    final encodedName = Uri.encodeComponent(locationName);
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=$encodedName&key=$apiKey";

    try {
      final response = await Dio().get(url);
      final data = response.data;

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      } else {
        throw Exception("Lokasi tidak ditemukan: ${data['status']}");
      }
    } catch (e) {
      throw Exception("Error saat geocoding: $e");
    }
  }
}
