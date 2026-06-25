import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TransitService {
  static String _getVehicleType(String agencyName, String vehicleType) {
    print("agencyName: $agencyName, vehicleType: $vehicleType");
    if (agencyName.startsWith("Angkot")) return "Angkot";
    if (agencyName.startsWith("PT Transportasi Jakarta")) return "Bus";
    if (agencyName.startsWith("Kereta")) return "Kereta";
    if (vehicleType == "TRAM") return "LRT";
    if (vehicleType == "SUBWAY" && agencyName.contains("MRT Jakarta")) return "MRT Jakarta";
    return agencyName;
  }

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
            // Menangani langkah transit
            if (step.containsKey("transitDetails")) {
              var transit = step["transitDetails"];
              String agencyName = transit["transitLine"]["agencies"][0]["name"];

              transitSteps.add({
                "type": "TRANSIT",
                "departure": transit["stopDetails"]["departureStop"]["name"],
                "departureTime": transit["localizedValues"]["departureTime"]
                    ["time"]["text"],
                "arrival": transit["stopDetails"]["arrivalStop"]["name"],
                "arrivalTime": transit["localizedValues"]["arrivalTime"]["time"]
                    ["text"],
                "codeLine": transit["transitLine"]["nameShort"],
                "colorLine": transit["transitLine"]["color"],
                "line": transit["transitLine"]["name"],
                "headsign": transit["headsign"],
                "agency": agencyName,
                "vehicle": _getVehicleType(agencyName, transit["transitLine"]["vehicle"]["type"]),
                "stopCount": transit["stopCount"],
                "duration": step["localizedValues"]?["staticDuration"]?["text"],
                "durationSeconds": int.tryParse(
                        step["staticDuration"]?.toString().replaceAll('s', '') ??
                            '0') ??
                    0,
                "transitDetails": transit,
                "navigationInstruction":
                    step.containsKey("navigationInstruction")
                        ? step["navigationInstruction"]["instructions"]
                        : null
              });
            }
          }
        }
      }

      print("transitSteps: ${json.encode(transitSteps)}");

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
      // print("response: $response");
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
