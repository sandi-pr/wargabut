import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TransitService {
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
  static String _getVehicleType(String agencyName, String vehicleType) {
    if (kDebugMode) {
      print("agencyName: $agencyName, vehicleType: $vehicleType");
    }
    final a = agencyName.toLowerCase();
    final v = vehicleType.toUpperCase();
    if (a.contains("angkot")) return "Angkot";
    if (a.contains("transjakarta") || a.contains("transportasi jakarta")) return "Bus";
    if (a.contains("kereta") || a.contains("krl") || a.contains("commuter")) return "Kereta";
    if (v == "TRAM" || a.contains("lrt")) return "LRT";
    if (v == "SUBWAY" || a.contains("mrt")) return "MRT Jakarta";
    if (v == "BUS") return "Bus";
    return agencyName;
  }

  static bool _isBusTransit(String agencyName, String vehicleType) {
    final a = agencyName.toLowerCase();
    final v = vehicleType.toUpperCase();
    if (a.contains("angkot") ||
        a.contains("transjakarta") ||
        a.contains("transportasi jakarta") ||
        a.contains("damri") ||
        a.contains("agra mas") ||
        a.contains("mayasari") ||
        a.contains("sinar jaya") ||
        a.contains("primajasa")) {
      return true;
    }
    if (v == "BUS" || v == "INTERCITY_BUS" || v == "TROLLEYBUS") {
      return true;
    }
    return false;
  }

  static bool _isRailTransit(String agencyName, String vehicleType) {
    if (_isBusTransit(agencyName, vehicleType)) {
      return false; // Bus atau Angkot tidak boleh dianggap rail
    }
    final a = agencyName.toLowerCase();
    final v = vehicleType.toUpperCase();
    if (a.contains("kereta") ||
        a.contains("krl") ||
        a.contains("commuter") ||
        a.contains("mrt") ||
        a.contains("lrt") ||
        a.contains("whoosh") ||
        a.contains("kai")) {
      return true;
    }
    if (v == "COMMUTER_TRAIN" ||
        v == "HEAVY_RAIL" ||
        v == "HIGH_SPEED_TRAIN" ||
        v == "LONG_DISTANCE_TRAIN" ||
        v == "RAIL" ||
        v == "SUBWAY" ||
        v == "TRAM" ||
        v == "METRO_RAIL") {
      return true;
    }
    return false;
  }

  static String _formatStopTarget(String rawName, {required bool isBus, required bool isRail}) {
    final clean = rawName.trim();
    if (clean.isEmpty) return rawName;
    final lower = clean.toLowerCase();

    if (isBus) {
      if (lower.startsWith("halte") ||
          lower.startsWith("terminal") ||
          lower.startsWith("stasiun") ||
          lower.startsWith("st.") ||
          lower.startsWith("shuttle")) {
        return clean;
      }
      return "Halte $clean";
    }

    if (isRail) {
      if (lower.startsWith("stasiun") ||
          lower.startsWith("st.") ||
          lower.startsWith("halte")) {
        return clean;
      }
      return "Stasiun $clean";
    }

    return clean;
  }

  static Future<List<Map<String, dynamic>>> getTransitDetails(
    double latOrigin,
    double lngOrigin,
    double latDest,
    double lngDest, {
    List<String> allowedTravelModes = const ["RAIL"],
    String? routingPreference,
    String? destinationName,
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
      if (data["routes"] == null || (data["routes"] as List).isEmpty) {
        throw Exception("Tidak ada rute ditemukan");
      }

      if (kDebugMode) {
        print("=========================================");
        print("cek data: ${json.encode(data)}");
        print("=========================================");
      }

      final routeInfo = _parseRouteInfo(data, destinationName: destinationName);
      return routeInfo.segments;
    } catch (e) {
      throw Exception("Error saat mengambil data rute: $e");
    }
  }

  static Future<TransitRouteInfo> getTransitRouteInfo(
    double latOrigin,
    double lngOrigin,
    double latDest,
    double lngDest, {
    List<String> allowedTravelModes = const ["RAIL"],
    String? routingPreference,
    String? destinationName,
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
      if (data["routes"] == null || (data["routes"] as List).isEmpty) {
        throw Exception("Tidak ada rute ditemukan");
      }

      if (kDebugMode) {
        print("=========================================");
        print("cek data: ${json.encode(data)}");
        print("=========================================");
      }

      return _parseRouteInfo(data, destinationName: destinationName);
    } catch (e) {
      throw Exception("Error saat mengambil data rute: $e");
    }
  }

  static TransitRouteInfo _parseRouteInfo(Map<String, dynamic> data, {String? destinationName}) {
    final route = data["routes"][0];
    final List legs = route["legs"] ?? [];
    if (legs.isEmpty) {
      throw Exception("Tidak ada detail perjalanan pada rute.");
    }
    final leg = legs[0];
    final String? overallEncodedPolyline =
        route["polyline"]?["encodedPolyline"] ??
        leg["polyline"]?["encodedPolyline"];

    LatLngBounds? bounds;
    if (route["viewport"] != null) {
      final low = route["viewport"]["low"];
      final high = route["viewport"]["high"];
      if (low != null && high != null) {
        final double lat1 = (low["latitude"] as num).toDouble();
        final double lng1 = (low["longitude"] as num).toDouble();
        final double lat2 = (high["latitude"] as num).toDouble();
        final double lng2 = (high["longitude"] as num).toDouble();
        bounds = LatLngBounds(
          southwest: LatLng(min(lat1, lat2), min(lng1, lng2)),
          northeast: LatLng(max(lat1, lat2), max(lng1, lng2)),
        );
      }
    }

    LatLng? startLocation;
    final startLatLng = leg["startLocation"]?["latLng"];
    if (startLatLng != null) {
      startLocation = LatLng(
        (startLatLng["latitude"] as num).toDouble(),
        (startLatLng["longitude"] as num).toDouble(),
      );
    }

    LatLng? endLocation;
    final endLatLng = leg["endLocation"]?["latLng"];
    if (endLatLng != null) {
      endLocation = LatLng(
        (endLatLng["latitude"] as num).toDouble(),
        (endLatLng["longitude"] as num).toDouble(),
      );
    }

    final String totalDuration = leg["localizedValues"]?["duration"]?["text"] ??
        route["localizedValues"]?["duration"]?["text"] ??
        "-";
    final String totalDistance = leg["localizedValues"]?["distance"]?["text"] ??
        route["localizedValues"]?["distance"]?["text"] ??
        "-";
    final int totalDurationSeconds = int.tryParse(
            leg["duration"]?.toString().replaceAll('s', '') ??
                route["duration"]?.toString().replaceAll('s', '') ??
                '0') ??
        0;
    final int totalDistanceMeters = leg["distanceMeters"] as int? ??
        route["distanceMeters"] as int? ??
        0;

    final List steps = leg["steps"] ?? [];
    final List multiModalSegments =
        leg["stepsOverview"]?["multiModalSegments"] ?? [];

    List<Map<String, dynamic>> rawSegments = [];

    if (multiModalSegments.isNotEmpty) {
      for (var seg in multiModalSegments) {
        final int start = seg["stepStartIndex"] ?? 0;
        final int end = seg["stepEndIndex"] ?? start;
        final String mode = seg["travelMode"] ?? "WALK";
        final String? instr = seg["navigationInstruction"]?["instructions"];
        rawSegments.add({
          "start": start,
          "end": end,
          "mode": mode,
          "instruction": instr,
        });
      }
    } else {
      // Fallback jika stepsOverview tidak ada: kelompokkan langkah berdasarkan travelMode
      int? curStart;
      String? curMode;
      for (int i = 0; i < steps.length; i++) {
        final s = steps[i];
        final String m = s["travelMode"] ??
            (s.containsKey("transitDetails") ? "TRANSIT" : "WALK");
        if (curMode == null) {
          curStart = i;
          curMode = m;
        } else if (m == "TRANSIT" || curMode == "TRANSIT" || m != curMode) {
          rawSegments.add({
            "start": curStart!,
            "end": i - 1,
            "mode": curMode,
            "instruction": null,
          });
          curStart = i;
          curMode = m;
        }
      }
      if (curMode != null && curStart != null) {
        rawSegments.add({
          "start": curStart,
          "end": steps.length - 1,
          "mode": curMode,
          "instruction": null,
        });
      }
    }

    // Sisipkan segmen transfer jika ada 2 moda transit berurutan tanpa langkah jalan kaki di antaranya (misal pindah bus di halte yang sama)
    List<Map<String, dynamic>> normalizedSegments = [];
    for (int i = 0; i < rawSegments.length; i++) {
      normalizedSegments.add(rawSegments[i]);
      if (i < rawSegments.length - 1) {
        final cur = rawSegments[i];
        final next = rawSegments[i + 1];
        if (cur["mode"] == "TRANSIT" && next["mode"] == "TRANSIT") {
          normalizedSegments.add({
            "start": -1,
            "end": -1,
            "mode": "WALK",
            "instruction": null,
            "isDirectTransfer": true,
          });
        }
      }
    }
    rawSegments = normalizedSegments;

    // Temukan index segmen mana saja yang bertipe TRANSIT
    List<int> transitIndices = [];
    for (int i = 0; i < rawSegments.length; i++) {
      if (rawSegments[i]["mode"] == "TRANSIT") {
        transitIndices.add(i);
      }
    }

    List<Map<String, dynamic>> parsedSegments = [];

    for (int i = 0; i < rawSegments.length; i++) {
      final rawSeg = rawSegments[i];
      final int start = rawSeg["start"];
      final int end = rawSeg["end"];
      final String mode = rawSeg["mode"];
      final String? segmentInstruction = rawSeg["instruction"];

      final List subSteps = (start >= 0 && start <= end && end < steps.length)
          ? steps.sublist(start, end + 1)
          : [];

      if (mode == "TRANSIT") {
        // Ambil step yang memiliki data transitDetails
        final transitStep = subSteps.firstWhere(
          (s) => s.containsKey("transitDetails"),
          orElse: () => subSteps.isNotEmpty ? subSteps.first : <String, dynamic>{},
        );

        if (transitStep.containsKey("transitDetails")) {
          final transit = transitStep["transitDetails"];
          final String agencyName =
              transit["transitLine"]?["agencies"]?[0]?["name"] ?? "Transportasi Umum";
          final String vehicleType =
              transit["transitLine"]?["vehicle"]?["type"] ?? "BUS";

          List<LatLng> transitPoints = [];
          final encPoly = transitStep["polyline"]?["encodedPolyline"];
          if (encPoly != null && (encPoly as String).isNotEmpty) {
            transitPoints = decodePolyline(encPoly);
          }

          LatLng? depLoc;
          final depLatLng = transit["stopDetails"]?["departureStop"]?["location"]?["latLng"];
          if (depLatLng != null) {
            depLoc = LatLng((depLatLng["latitude"] as num).toDouble(), (depLatLng["longitude"] as num).toDouble());
          }

          LatLng? arrLoc;
          final arrLatLng = transit["stopDetails"]?["arrivalStop"]?["location"]?["latLng"];
          if (arrLatLng != null) {
            arrLoc = LatLng((arrLatLng["latitude"] as num).toDouble(), (arrLatLng["longitude"] as num).toDouble());
          }

          parsedSegments.add({
            "type": "TRANSIT",
            "departure": transit["stopDetails"]?["departureStop"]?["name"] ?? "-",
            "departureTime": transit["localizedValues"]?["departureTime"]?["time"]?["text"] ?? "-",
            "arrival": transit["stopDetails"]?["arrivalStop"]?["name"] ?? "-",
            "arrivalTime": transit["localizedValues"]?["arrivalTime"]?["time"]?["text"] ?? "-",
            "codeLine": transit["transitLine"]?["nameShort"],
            "colorLine": transit["transitLine"]?["color"],
            "line": transit["transitLine"]?["name"],
            "headsign": transit["headsign"],
            "agency": agencyName,
            "vehicle": _getVehicleType(agencyName, vehicleType),
            "stopCount": transit["stopCount"] ?? 0,
            "duration": transitStep["localizedValues"]?["staticDuration"]?["text"] ??
                transitStep["localizedValues"]?["duration"]?["text"] ??
                "-",
            "durationSeconds": int.tryParse(
                    transitStep["staticDuration"]?.toString().replaceAll('s', '') ??
                        transitStep["duration"]?.toString().replaceAll('s', '') ??
                        '0') ??
                0,
            "distance": transitStep["localizedValues"]?["distance"]?["text"] ?? "-",
            "distanceMeters": transitStep["distanceMeters"] as int? ?? 0,
            "transitDetails": transit,
            "navigationInstruction": segmentInstruction ??
                (transitStep.containsKey("navigationInstruction")
                    ? transitStep["navigationInstruction"]["instructions"]
                    : null),
            "routeTotalDuration": totalDuration,
            "routeTotalDistance": totalDistance,
            "polylinePoints": transitPoints,
            "startLocation": depLoc,
            "endLocation": arrLoc,
          });
        }
      } else {
        // mode == "WALK"
        int segDistanceMeters = 0;
        int segDurationSeconds = 0;
        List<Map<String, dynamic>> walkingTurns = [];
        List<LatLng> walkPoints = [];
        LatLng? walkStart;
        LatLng? walkEnd;

        for (int stepIdx = 0; stepIdx < subSteps.length; stepIdx++) {
          final s = subSteps[stepIdx];
          final enc = s["polyline"]?["encodedPolyline"];
          if (enc != null && enc.toString().isNotEmpty) {
            walkPoints.addAll(decodePolyline(enc.toString()));
          }

          if (stepIdx == 0 && s["startLocation"]?["latLng"] != null) {
            final loc = s["startLocation"]["latLng"];
            walkStart = LatLng((loc["latitude"] as num).toDouble(), (loc["longitude"] as num).toDouble());
          }
          if (stepIdx == subSteps.length - 1 && s["endLocation"]?["latLng"] != null) {
            final loc = s["endLocation"]["latLng"];
            walkEnd = LatLng((loc["latitude"] as num).toDouble(), (loc["longitude"] as num).toDouble());
          }

          final distM = s["distanceMeters"] as int? ?? 0;
          final durSec = int.tryParse(
                  s["staticDuration"]?.toString().replaceAll('s', '') ??
                      s["duration"]?.toString().replaceAll('s', '') ??
                      '0') ??
              0;
          segDistanceMeters += distM;
          segDurationSeconds += durSec;

          final nav = s["navigationInstruction"];
          final instr = nav?["instructions"]?.toString();
          final maneuver = nav?["maneuver"]?.toString();
          final distText = s["localizedValues"]?["distance"]?["text"]?.toString();
          final durText = s["localizedValues"]?["staticDuration"]?["text"]?.toString();

          if (instr != null && instr.trim().isNotEmpty) {
            walkingTurns.add({
              "instruction": instr.trim(),
              "maneuver": maneuver ?? "STRAIGHT",
              "distance": distText ?? (distM > 0 ? "$distM m" : ""),
              "duration": durText ?? "",
            });
          }
        }

        // Tentukan SubType: FIRST_MILE, TRANSFER, LAST_MILE, WALK_ONLY
        String subType = "WALK_ONLY";
        if (transitIndices.isNotEmpty) {
          if (i < transitIndices.first) {
            subType = "FIRST_MILE";
          } else if (i > transitIndices.last) {
            subType = "LAST_MILE";
          } else {
            subType = "TRANSFER";
          }
        }

        String defaultTitle = "Jalan kaki";
        String? waitDuration;
        bool isSameStation = false;
        bool isSameBusStop = false;
        String? prevArrStation;
        String? nextDepStation;
        String? nextTransitLine;
        String? nextTransitLineShort;
        String? nextHeadsign;
        String? prevVehicle;
        String? nextVehicle;
        bool isPrevRail = false;
        bool isNextRail = false;
        bool isPrevBus = false;
        bool isNextBus = false;
        String nextDep = "stasiun/halte";
        LatLng? prevArrLoc;
        LatLng? nextDepLoc;

        final String targetVenue = (destinationName != null && destinationName.trim().isNotEmpty)
            ? destinationName.trim()
            : "lokasi acara";

        if (subType == "FIRST_MILE") {
          nextDep = "halte/stasiun";
          if (transitIndices.isNotEmpty) {
            final nextRaw = rawSegments[transitIndices.first];
            if (nextRaw["start"] >= 0 && nextRaw["start"] < steps.length) {
              final nextSub = steps[nextRaw["start"]];
              if (nextSub != null && nextSub.containsKey("transitDetails")) {
                final td = nextSub["transitDetails"];
                nextDepStation = td?["stopDetails"]?["departureStop"]?["name"];
                final depLatLng = td?["stopDetails"]?["departureStop"]?["location"]?["latLng"];
                if (depLatLng != null) {
                  nextDepLoc = LatLng((depLatLng["latitude"] as num).toDouble(), (depLatLng["longitude"] as num).toDouble());
                }
                final agency = td?["transitLine"]?["agencies"]?[0]?["name"]?.toString() ?? "";
                final vType = td?["transitLine"]?["vehicle"]?["type"]?.toString() ?? "";
                nextVehicle = _getVehicleType(agency, vType);
                isNextRail = _isRailTransit(agency, vType);
                isNextBus = _isBusTransit(agency, vType);
                nextTransitLineShort = td?["transitLine"]?["nameShort"];
                nextTransitLine = nextTransitLineShort ?? td?["transitLine"]?["name"];
                if (nextDepStation != null) {
                  nextDep = nextDepStation;
                }
              }
            }
          }
          final formattedFirstStop = _formatStopTarget(nextDep, isBus: isNextBus, isRail: isNextRail);
          defaultTitle = "Jalan menuju $formattedFirstStop";
        } else if (subType == "TRANSFER") {
          nextDep = "stasiun/halte transit";
          int? nextTransitIndex;
          for (var tIdx in transitIndices) {
            if (tIdx > i) {
              nextTransitIndex = tIdx;
              break;
            }
          }
          int? prevTransitIndex;
          for (var tIdx in transitIndices.reversed) {
            if (tIdx < i) {
              prevTransitIndex = tIdx;
              break;
            }
          }

          if (prevTransitIndex != null) {
            final prevRaw = rawSegments[prevTransitIndex];
            if (prevRaw["start"] >= 0 && prevRaw["start"] < steps.length) {
              final prevSub = steps[prevRaw["start"]];
              if (prevSub != null && prevSub.containsKey("transitDetails")) {
                final td = prevSub["transitDetails"];
                prevArrStation = td?["stopDetails"]?["arrivalStop"]?["name"];
                final arrLatLng = td?["stopDetails"]?["arrivalStop"]?["location"]?["latLng"];
                if (arrLatLng != null) {
                  prevArrLoc = LatLng((arrLatLng["latitude"] as num).toDouble(), (arrLatLng["longitude"] as num).toDouble());
                }
                final agency = td?["transitLine"]?["agencies"]?[0]?["name"]?.toString() ?? "";
                final vType = td?["transitLine"]?["vehicle"]?["type"]?.toString() ?? "";
                prevVehicle = _getVehicleType(agency, vType);
                isPrevRail = _isRailTransit(agency, vType);
                isPrevBus = _isBusTransit(agency, vType);
              }
            }
          }

          if (nextTransitIndex != null) {
            final nextRaw = rawSegments[nextTransitIndex];
            if (nextRaw["start"] >= 0 && nextRaw["start"] < steps.length) {
              final nextSub = steps[nextRaw["start"]];
              if (nextSub != null && nextSub.containsKey("transitDetails")) {
                final td = nextSub["transitDetails"];
                nextDepStation = td?["stopDetails"]?["departureStop"]?["name"];
                final depLatLng = td?["stopDetails"]?["departureStop"]?["location"]?["latLng"];
                if (depLatLng != null) {
                  nextDepLoc = LatLng((depLatLng["latitude"] as num).toDouble(), (depLatLng["longitude"] as num).toDouble());
                }
                nextTransitLineShort = td?["transitLine"]?["nameShort"];
                nextTransitLine = nextTransitLineShort ?? td?["transitLine"]?["name"];
                nextHeadsign = td?["headsign"];
                final agency = td?["transitLine"]?["agencies"]?[0]?["name"]?.toString() ?? "";
                final vType = td?["transitLine"]?["vehicle"]?["type"]?.toString() ?? "";
                nextVehicle = _getVehicleType(agency, vType);
                isNextRail = _isRailTransit(agency, vType);
                isNextBus = _isBusTransit(agency, vType);
                if (nextDepStation != null) {
                  nextDep = nextDepStation;
                }
              }
            }
          }

          String cleanStation(String s) {
            return s
                .toLowerCase()
                .replaceAll('stasiun', '')
                .replaceAll('halte', '')
                .replaceAll('st.', '')
                .replaceAll(RegExp(r'[^a-z0-9]'), '')
                .trim();
          }

          final c1 = cleanStation(prevArrStation ?? "");
          final c2 = cleanStation(nextDepStation ?? "");
          final bool isSameStopName = (c1.isNotEmpty && c2.isNotEmpty && (c1 == c2 || c1.contains(c2) || c2.contains(c1)));

          // Platform transfer (TRANSIT PERON):
          // HANYA jika moda sebelumnya dan berikutnya SAMA-SAMA Kereta/Rail (bukan bus/angkot),
          // berada dalam jarak jalan kaki peron (<= 100m) atau direct transfer,
          // dan stasiun kedatangan sama dengan stasiun keberangkatan berikutnya.
          if (isPrevRail && isNextRail && !isPrevBus && !isNextBus) {
            if (isSameStopName && (segDistanceMeters <= 100 || rawSeg["isDirectTransfer"] == true)) {
              isSameStation = true;
            }
          }

          // Transfer bus di halte yang sama (TRANSIT HALTE / PINDAH BUS):
          // Jika moda sebelumnya dan berikutnya SAMA-SAMA Bus/TJ/Angkot,
          // dan berada di halte yang sama (isSameStopName) atau direct transfer (jarak dekat <= 80m).
          if (isPrevBus && isNextBus && !isPrevRail && !isNextRail) {
            if (isSameStopName && (segDistanceMeters <= 80 || rawSeg["isDirectTransfer"] == true)) {
              isSameBusStop = true;
            }
          }

          final String displayNextLine = nextTransitLineShort ?? nextTransitLine ?? 'berikutnya';
          final String targetStopFormatted = _formatStopTarget(
            nextDepStation ?? nextDep,
            isBus: isNextBus,
            isRail: isNextRail,
          );

          if (isSameStation) {
            defaultTitle = "Transit ke peron $displayNextLine";
          } else if (isSameBusStop) {
            if (nextTransitLineShort != null && nextTransitLineShort.trim().isNotEmpty) {
              defaultTitle = "Pindah bus di $targetStopFormatted ke Koridor $nextTransitLineShort";
            } else {
              defaultTitle = "Pindah bus di $targetStopFormatted ke $displayNextLine";
            }
          } else {
            defaultTitle = "Jalan menuju $targetStopFormatted";
          }

          // Hitung jeda waktu tunggu transit antara kedatangan moda sebelumnya dan keberangkatan moda berikutnya
          if (prevTransitIndex != null && nextTransitIndex != null) {
            try {
              final prevSub = steps[rawSegments[prevTransitIndex]["start"]];
              final nextSub = steps[rawSegments[nextTransitIndex]["start"]];
              final prevArrStr = prevSub["transitDetails"]?["stopDetails"]?["arrivalTime"];
              final nextDepStr = nextSub["transitDetails"]?["stopDetails"]?["departureTime"];
              if (prevArrStr != null && nextDepStr != null) {
                final prevArr = DateTime.parse(prevArrStr);
                final nextDepDt = DateTime.parse(nextDepStr);
                final diff = nextDepDt.difference(prevArr);
                if (!diff.isNegative && diff.inMinutes > 0) {
                  waitDuration = "${diff.inMinutes} menit";
                }
              }
            } catch (_) {}
          }
        } else if (subType == "LAST_MILE") {
          defaultTitle = "Jalan kaki ke $targetVenue";
        }

        final String distText;
        final String durText;
        if (isSameBusStop && (rawSeg["isDirectTransfer"] == true || segDistanceMeters == 0)) {
          distText = "Di dalam halte";
          durText = "< 1 menit";
        } else if (isSameStation && (rawSeg["isDirectTransfer"] == true || segDistanceMeters == 0)) {
          distText = "Di peron stasiun";
          durText = "< 1 menit";
        } else {
          distText = _formatMeters(segDistanceMeters);
          durText = _formatSeconds(segDurationSeconds);
        }

        final String displayNextLine = nextTransitLineShort ?? nextTransitLine ?? 'berikutnya';
        final String targetStopFormatted = _formatStopTarget(
          nextDepStation ?? nextDep,
          isBus: isNextBus,
          isRail: isNextRail,
        );

        final String finalTitle;
        if (subType == "LAST_MILE") {
          finalTitle = "Jalan kaki ke $targetVenue";
        } else if (subType == "TRANSFER" && isSameStation) {
          finalTitle = "Transit ke peron ${nextTransitLineShort ?? nextTransitLine ?? 'berikutnya'}";
        } else if (subType == "TRANSFER" && isSameBusStop) {
          if (nextTransitLineShort != null && nextTransitLineShort.trim().isNotEmpty) {
            finalTitle = "Pindah bus di $targetStopFormatted ke Koridor $nextTransitLineShort";
          } else {
            finalTitle = "Pindah bus di $targetStopFormatted ke ${nextTransitLine ?? 'bus berikutnya'}";
          }
        } else if (subType == "TRANSFER" && !isSameStation && !isSameBusStop) {
          finalTitle = "Jalan menuju $targetStopFormatted";
        } else if (subType == "FIRST_MILE") {
          finalTitle = "Jalan menuju $targetStopFormatted";
        } else if (segmentInstruction != null && segmentInstruction.trim().isNotEmpty) {
          finalTitle = segmentInstruction.trim();
        } else {
          finalTitle = defaultTitle;
        }

        if (isSameStation && (walkingTurns.isEmpty || segDistanceMeters <= 50)) {
          final station = prevArrStation ?? nextDepStation ?? "stasiun";
          final lineInfo = nextTransitLineShort ?? nextTransitLine ?? "kereta berikutnya";
          final headInfo = nextHeadsign != null ? " (arah $nextHeadsign)" : "";
          walkingTurns = [
            {
              "instruction": "Pindah peron di $station menuju peron $lineInfo$headInfo. Gunakan tangga atau jembatan penyeberangan stasiun.",
              "maneuver": "STRAIGHT",
              "distance": distText,
              "duration": durText,
            }
          ];
        } else if (isSameBusStop && (walkingTurns.isEmpty || segDistanceMeters <= 50)) {
          final halte = targetStopFormatted;
          final lineInfo = nextTransitLineShort != null ? "Koridor $nextTransitLineShort" : (nextTransitLine ?? "bus berikutnya");
          final headInfo = nextHeadsign != null ? " (arah $nextHeadsign)" : "";
          walkingTurns = [
            {
              "instruction": "Turun di $halte.",
              "maneuver": "STRAIGHT",
              "distance": distText,
              "duration": durText,
            },
            {
              "instruction": "Tetap berada di dalam area halte (tidak perlu tap out). Silakan menuju pintu peron keberangkatan $lineInfo$headInfo.",
              "maneuver": "STRAIGHT",
              "distance": "",
              "duration": "",
            },
            {
              "instruction": "Tunggu kedatangan bus di pintu peron yang sesuai.",
              "maneuver": "STRAIGHT",
              "distance": "",
              "duration": "",
            }
          ];
        }

        final String navInstruction;
        if (isSameStation) {
          navInstruction = "Transit di ${prevArrStation ?? 'stasiun'} menuju peron ${nextTransitLineShort ?? nextTransitLine ?? ''}${nextHeadsign != null ? ' (arah $nextHeadsign)' : ''}";
        } else if (isSameBusStop) {
          navInstruction = "Pindah bus di $targetStopFormatted menuju ${nextTransitLineShort != null ? 'Koridor $nextTransitLineShort' : (nextTransitLine ?? 'bus berikutnya')}${nextHeadsign != null ? ' (arah $nextHeadsign)' : ''}";
        } else if (subType == "LAST_MILE") {
          navInstruction = "Jalan kaki ke $targetVenue";
        } else {
          navInstruction = "Jalan menuju $targetStopFormatted untuk naik ${nextTransitLineShort ?? nextTransitLine ?? 'transportasi umum'}";
        }

        parsedSegments.add({
          "type": "WALK",
          "subType": subType,
          "isSameStationTransfer": isSameStation,
          "isSameBusStopTransfer": isSameBusStop,
          "isDirectTransfer": rawSeg["isDirectTransfer"] == true,
          "stationName": prevArrStation ?? nextDepStation,
          "targetStopName": targetStopFormatted,
          "prevVehicle": prevVehicle,
          "nextVehicle": nextVehicle,
          "isPrevRail": isPrevRail,
          "isNextRail": isNextRail,
          "isPrevBus": isPrevBus,
          "isNextBus": isNextBus,
          "targetLine": nextTransitLine,
          "targetHeadsign": nextHeadsign,
          "targetVenue": targetVenue,
          "title": finalTitle,
          "navigationInstruction": navInstruction,
          "departure": subType == "FIRST_MILE"
              ? "Lokasi Anda"
              : (isSameStation ? (prevArrStation ?? "Stasiun transit") : (isSameBusStop ? targetStopFormatted : (prevArrStation ?? "Titik transit"))),
          "departureTime": "",
          "arrival": isSameStation
              ? "Peron ${nextTransitLineShort ?? nextTransitLine ?? 'berikutnya'}"
              : (isSameBusStop ? "Pintu bus $displayNextLine" : (subType == "LAST_MILE" ? targetVenue : targetStopFormatted)),
          "arrivalTime": "",
          "stopCount": 0,
          "agency": isSameStation ? "Transit Peron" : (isSameBusStop ? "Transit Halte" : "Jalan Kaki"),
          "vehicle": isSameStation ? "Transit Peron" : (isSameBusStop ? "Transit Halte" : "Jalan Kaki"),
          "line": isSameStation ? (nextTransitLine ?? "Transit Peron") : (isSameBusStop ? (nextTransitLine ?? "Transit Halte") : "Jalan Kaki"),
          "duration": durText,
          "durationSeconds": segDurationSeconds,
          "distance": distText,
          "distanceMeters": segDistanceMeters,
          "transferWaitDuration": waitDuration,
          "walkingSteps": walkingTurns,
          "routeTotalDuration": totalDuration,
          "routeTotalDistance": totalDistance,
          "polylinePoints": walkPoints,
          "startLocation": walkStart ?? (prevArrLoc ?? nextDepLoc),
          "endLocation": walkEnd ?? (nextDepLoc ?? prevArrLoc),
        });
      }
    }

    if (bounds == null) {
      List<LatLng> allPts = [];
      if (overallEncodedPolyline != null && overallEncodedPolyline.isNotEmpty) {
        allPts = decodePolyline(overallEncodedPolyline);
      }
      if (allPts.isEmpty) {
        for (var seg in parsedSegments) {
          final pts = seg["polylinePoints"] as List<LatLng>?;
          if (pts != null) allPts.addAll(pts);
        }
      }
      if (allPts.isNotEmpty) {
        double minLat = allPts.first.latitude;
        double maxLat = allPts.first.latitude;
        double minLng = allPts.first.longitude;
        double maxLng = allPts.first.longitude;
        for (var pt in allPts) {
          if (pt.latitude < minLat) minLat = pt.latitude;
          if (pt.latitude > maxLat) maxLat = pt.latitude;
          if (pt.longitude < minLng) minLng = pt.longitude;
          if (pt.longitude > maxLng) maxLng = pt.longitude;
        }
        bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
      }
    }

    if (kDebugMode) {
      print("TransitRoute parsed: ${parsedSegments.length} segments, total: $totalDuration ($totalDistance)");
    }

    return TransitRouteInfo(
      segments: parsedSegments,
      totalDuration: totalDuration,
      totalDistance: totalDistance,
      totalDurationSeconds: totalDurationSeconds,
      totalDistanceMeters: totalDistanceMeters,
      overallEncodedPolyline: overallEncodedPolyline,
      startLocation: startLocation,
      endLocation: endLocation,
      bounds: bounds,
    );
  }

  static String _formatMeters(int meters) {
    if (meters >= 1000) {
      final km = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return "$km km";
    }
    return "$meters m";
  }

  static String _formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return "1 menit";
    final mins = (totalSeconds / 60).round();
    if (mins < 1) return "< 1 menit";
    if (mins < 60) return "$mins menit";
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    if (remMins == 0) return "$hours jam";
    return "$hours jam $remMins menit";
  }
}

class TransitRouteInfo {
  final List<Map<String, dynamic>> segments;
  final String totalDuration;
  final String totalDistance;
  final int totalDurationSeconds;
  final int totalDistanceMeters;
  final String? overallEncodedPolyline;
  final LatLng? startLocation;
  final LatLng? endLocation;
  final LatLngBounds? bounds;

  TransitRouteInfo({
    required this.segments,
    required this.totalDuration,
    required this.totalDistance,
    required this.totalDurationSeconds,
    required this.totalDistanceMeters,
    this.overallEncodedPolyline,
    this.startLocation,
    this.endLocation,
    this.bounds,
  });
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
