import 'package:flutter/foundation.dart'; // untuk kIsWeb
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:provider/provider.dart';

import '../../../../provider/location_provider.dart';
import '../../../../provider/transit_provider.dart';

// Callback untuk update filter di parent/mixin
typedef OnOptionChanged = void Function(List<String> modes, String? preference);
// Callback untuk trigger pencarian rute
typedef OnSearchRoute = Future<void> Function();

class SharedTransitSection extends StatelessWidget {
  final String destinationName;
  final List<String> allowedTravelModes;
  final String? routingPreference;
  final OnOptionChanged onOptionChanged;
  final OnSearchRoute onSearchRoute;

  const SharedTransitSection({
    super.key,
    required this.destinationName,
    required this.allowedTravelModes,
    required this.routingPreference,
    required this.onOptionChanged,
    required this.onSearchRoute,
  });

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final transitProvider = context.watch<TransitProvider>();

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & TOMBOL ---
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text("📍 Info Rute Transportasi", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        if (kIsWeb) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Fitur ini masih dalam tahap pengembangan")),
                          );
                        }
                      },
                      child: const Tooltip(
                        message: "Fitur ini masih dalam tahap pengembangan",
                        child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),

              // POPUP MENU FILTER
              PopupMenuButton<String>(
                icon: const Icon(Icons.tune),
                tooltip: "Opsi Rute",
                onSelected: (value) {
                  // Logic update filter
                  final newModes = List<String>.from(allowedTravelModes);
                  String? newPref = routingPreference;

                  if (value == "toggle_bus") {
                    if (newModes.contains("BUS")) {
                      newModes.remove("BUS");
                    } else {
                      newModes.add("BUS");
                    }
                  } else if (value == "less_walking") {
                    newPref = (newPref == "LESS_WALKING") ? null : "LESS_WALKING";
                  } else if (value == "fewer_transfers") {
                    newPref = (newPref == "FEWER_TRANSFERS") ? null : "FEWER_TRANSFERS";
                  }

                  // Kirim perubahan ke parent
                  onOptionChanged(newModes, newPref);

                  // Auto-refresh jika lokasi user sudah ada
                  if (locationProvider.userPosition != null) {
                    onSearchRoute();
                  }
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: "toggle_bus",
                    checked: allowedTravelModes.contains("BUS"),
                    child: const Text("Sertakan Bus"),
                  ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: "less_walking",
                    checked: routingPreference == "LESS_WALKING",
                    child: const Text("Kurangi Jalan Kaki"),
                  ),
                  CheckedPopupMenuItem(
                    value: "fewer_transfers",
                    checked: routingPreference == "FEWER_TRANSFERS",
                    child: const Text("Kurangi Transit"),
                  ),
                ],
              ),

              // TOMBOL CARI / PERBARUI
              ElevatedButton(
                onPressed: locationProvider.isFetching || transitProvider.isFetching
                    ? null
                    : onSearchRoute,
                child: Text(
                  locationProvider.userPosition == null
                      ? "Cari Rute"
                      : (transitProvider.routes.isEmpty ? "Cari Rute" : "Perbarui"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- CONTENT RESULT ---
          if (transitProvider.isFetching)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else if (locationProvider.error != null)
            Center(child: Text(locationProvider.error!, style: const TextStyle(color: Colors.red)))
          else if (transitProvider.routes.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transitProvider.routes.length,
                itemBuilder: (context, index) {
                  final step = transitProvider.routes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: _getAgencyIcon(step["agency"]),
                      title: Text(_formatNavigationInstruction(
                          step["navigationInstruction"], step["agency"], step["codeLine"])),
                      subtitle: Text(
                        "${step["departure"]} (${step["departureTime"]}) → ${step["arrival"]} (${step["arrivalTime"]})\n"
                            "${_buildRouteLabel(step)} | ${step["stopCount"] ?? '0'} pemberhentian",
                      ),
                    ),
                  );
                },
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text("Tekan tombol 'Cari Rute' untuk memulai.", style: TextStyle(color: Colors.grey)),
                ),
              ),
        ],
      ),
    );
  }

  // --- HELPER FUNCTIONS (Private) ---

  String _formatAgencyName(String? agency) {
    if (agency == null || agency.trim().isEmpty) return "";
    final lowerAgency = agency.trim().toLowerCase();

    if (lowerAgency.contains("kereta commuter indonesia")) return "KRL";
    if (lowerAgency.contains("mrt")) return "MRT Jakarta";
    if (lowerAgency.contains("lrt")) return "LRT";
    if (lowerAgency.contains("transjakarta")) return "TransJakarta";
    if (lowerAgency.contains("angkot")) return "Angkot";

    return agency.replaceAll(RegExp(r"^PT\.?\s*", caseSensitive: false), "");
  }

  Icon _getAgencyIcon(String? agency) {
    final name = _formatAgencyName(agency).toLowerCase();
    if (name == "krl") return const Icon(Icons.train, color: Colors.red);
    if (name.contains("mrt")) return const Icon(Icons.subway, color: Colors.blue);
    if (name.contains("lrt")) return const Icon(Icons.tram, color: Colors.green);
    if (name.contains("transjakarta")) return const Icon(Icons.directions_bus, color: Colors.lightBlue);
    if (name.contains("angkot")) return const Icon(Icons.directions_car, color: Colors.orange);
    return const Icon(Icons.directions_transit, color: Colors.grey);
  }

  String _formatNavigationInstruction(String? instruction, String? agency, String? codeLine) {
    if (instruction == null || instruction.trim().isEmpty) return "Ikuti rute";
    String cleanInstr = instruction.replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '');

    final agencyFormatted = _formatAgencyName(agency);
    final isJakLingko = agencyFormatted == "TransJakarta" && (codeLine?.toUpperCase().contains("JAK.") ?? false);

    String replaceMenuju(String replacement) {
      return cleanInstr.replaceAllMapped(
        RegExp(r'\b([Bb]us|[Bb]as)\s+menuju\b', caseSensitive: false),
            (match) => replacement,
      );
    }

    if (isJakLingko) return replaceMenuju("JakLingko menuju");
    if (agencyFormatted == "Angkot") return replaceMenuju("Angkot menuju");
    if (agencyFormatted == "TransJakarta") return replaceMenuju("TransJakarta menuju");
    if (agencyFormatted == "MRT Jakarta") return cleanInstr.replaceAllMapped(RegExp(r'\b[Kk]ereta api\b'), (m) => "MRT");
    if (agencyFormatted == "LRT") return cleanInstr.replaceAllMapped(RegExp(r'\b[Kk]ereta api\b'), (m) => "LRT");

    return cleanInstr;
  }

  String _buildRouteLabel(Map step) {
    final agency = (step["agency"] ?? "").toString().toLowerCase();
    final line = step["line"] ?? "";
    final codeLine = step["codeLine"] ?? "";

    if (agency.contains("transjakarta") && codeLine.toString().isNotEmpty) {
      return "Rute: $codeLine – $line";
    }
    return "Rute: $line";
  }
}