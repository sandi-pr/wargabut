import 'package:flutter/foundation.dart'; // untuk kIsWeb
import 'package:flutter/material.dart';
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
                    const Tooltip(
                      message: "Klik kartu untuk detail rute",
                      child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // POPUP MENU FILTER
              PopupMenuButton<String>(
                icon: const Icon(Icons.tune),
                tooltip: "Opsi Rute",
                onSelected: (value) {
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

                  onOptionChanged(newModes, newPref);
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOTAL ESTIMASI
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          "Total Estimasi Perjalanan: ${_calculateTotalDuration(transitProvider.routes)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transitProvider.routes.length,
                    itemBuilder: (context, index) {
                      final step = transitProvider.routes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          onTap: () => _showTransitDetail(context, step),
                          // leading: _getAgencyIcon(step["agency"]),
                          title: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildCodeLineBadge(step["codeLine"] ?? step["vehicle"], step["colorLine"]),
                              Text(
                                _formatNavigationInstruction(
                                  step["navigationInstruction"],
                                  step["agency"],
                                  step["codeLine"],
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            "${step["departure"]} (${step["departureTime"]}) → ${step["arrival"]} (${step["arrivalTime"]})\n"
                                "Estimasi: ${step["duration"] ?? '-'} | ${step["stopCount"] ?? '0'} pemberhentian",
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ],
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

  // --- DETAIL MODAL ---

  void _showTransitDetail(BuildContext context, Map step) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final agency = step["agency"] ?? "";
        final vehicle = step["vehicle"] ?? "Transit";
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _getAgencyIcon(agency),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatNavigationInstruction(
                                  step["navigationInstruction"],
                                  step["agency"],
                                  step["codeLine"],
                                ),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(agency, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                            ],
                          ),
                        ),
                        _buildCodeLineBadge(step["codeLine"] ?? step["vehicle"], step["colorLine"]),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1),
                    ),
                    
                    // TIMELINE RUTE
                    _buildTimelineItem(
                      time: step["departureTime"],
                      label: step["departure"],
                      isFirst: true,
                      color: _parseColor(step["colorLine"]),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 19),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: _parseColor(step["colorLine"]), width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Naik $vehicle ${step["line"]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.blue),
                                const SizedBox(width: 6),
                                Text("Durasi: ${step["duration"] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Melewati ${step["stopCount"]} pemberhentian", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            if (step["headsign"] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text("Arah: ${step["headsign"]}", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _buildTimelineItem(
                      time: step["arrivalTime"],
                      label: step["arrival"],
                      isLast: true,
                      color: _parseColor(step["colorLine"]),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required String time,
    required String label,
    bool isFirst = false,
    bool isLast = false,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: color, width: 3.5),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: (isFirst || isLast) ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER FUNCTIONS ---

  String _calculateTotalDuration(List<Map<String, dynamic>> routes) {
    int totalSeconds = 0;
    for (var step in routes) {
      totalSeconds += (step["durationSeconds"] as int? ?? 0);
    }

    if (totalSeconds == 0) return "-";

    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return "$hours jam $minutes menit";
    } else {
      return "$minutes menit";
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#')) return Colors.grey;
    try {
      return Color(int.parse("FF${hex.substring(1)}", radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Widget _buildCodeLineBadge(String? code, String? colorHex) {
    if (code == null || code.trim().isEmpty) return const SizedBox.shrink();
    Color bgColor = _parseColor(colorHex);
    Color textColor = bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(code, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _formatAgencyName(String? agency) {
    if (agency == null || agency.trim().isEmpty) return "";
    final lowerAgency = agency.trim().toLowerCase();
    if (lowerAgency.contains("kereta commuter indonesia")) return "KRL";
    if (lowerAgency.contains("Subway")) return "MRT";
    if (lowerAgency.contains("lrt")) return "LRT";
    if (lowerAgency.contains("transjakarta") || lowerAgency.contains("transportasi jakarta")) return "TransJakarta";
    if (lowerAgency.contains("angkot")) return "Angkot";
    if (lowerAgency.startsWith("kereta")) return "Kereta";
    return agency.replaceAll(RegExp(r"^PT\.?\s*", caseSensitive: false), "");
  }

  Icon _getAgencyIcon(String? agency) {
    final name = _formatAgencyName(agency).toLowerCase();
    print('Agency: $name');
    if (name == "krl") return const Icon(Icons.train, color: Colors.red);
    if (name.contains("mrt")) return const Icon(Icons.subway, color: Colors.blue);
    if (name.contains("lrt")) return const Icon(Icons.tram, color: Colors.green);
    if (name.contains("transjakarta")) return const Icon(Icons.directions_bus, color: Colors.lightBlue);
    if (name.contains("angkot")) return const Icon(Icons.directions_car, color: Colors.orange);
    if (name == "kereta") return const Icon(Icons.train, color: Colors.blueGrey);
    return const Icon(Icons.directions_transit, color: Colors.grey);
  }

  String _formatNavigationInstruction(String? instruction, String? agency, String? codeLine) {
    if (instruction == null || instruction.trim().isEmpty) return "Ikuti rute";

    // Hapus tag HTML
    String cleanInstr = instruction.replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '');

    // Normalisasi Bus
    cleanInstr = cleanInstr.replaceAll(RegExp(r'\b[Bb]as\b', caseSensitive: false), 'Bus');
    cleanInstr = cleanInstr.replaceAll(RegExp(r'\b[Bb]is\b', caseSensitive: false), 'Bus');

    // Normalisasi Kereta Bawah Tanah / Subway -> MRT
    cleanInstr = cleanInstr.replaceAll(RegExp(r'Kereta api bawah tanah', caseSensitive: false), 'MRT');
    cleanInstr = cleanInstr.replaceAll(RegExp(r'\bSubway\b', caseSensitive: false), 'MRT');

    // --- TAMBAHAN BARU: Normalisasi Trem -> LRT ---
    // Google Maps sering mengklasifikasikan LRT (seperti LRT Jabodebek) sebagai "Trem"
    cleanInstr = cleanInstr.replaceAll(RegExp(r'\b[Tt]rem\b', caseSensitive: false), 'LRT');

    final agencyFormatted = _formatAgencyName(agency);
    final isJakLingko = agencyFormatted == "TransJakarta" && (codeLine?.toUpperCase().contains("JAK.") ?? false);

    // print untuk debugging (bisa dihapus jika sudah tidak diperlukan)
    // print("Agency: $agency");
    // print("AgencyFormatted: $agencyFormatted");

    String replaceMenuju(String replacement) {
      return cleanInstr.replaceAllMapped(
        RegExp(r'\bBus\s+menuju\b', caseSensitive: false), (match) => replacement,
      );
    }

    String replaceKereta(String replacement) {
      return cleanInstr.replaceAllMapped(
        RegExp(r'\b[Kk]ereta api\s+menuju\b', caseSensitive: false), (match) => "$replacement menuju",
      );
    }

    // --- Pengecekan Kendaraan Khusus ---
    if (isJakLingko) return replaceMenuju("JakLingko menuju");
    if (agencyFormatted == "Angkot") return replaceMenuju("Angkot menuju");
    if (agencyFormatted == "TransJakarta") return replaceMenuju("TJ menuju");

    // Catatan: Jika teks sudah berubah jadi "MRT menuju" atau "LRT menuju" (akibat normalisasi kata di atas),
    // fungsi replaceKereta di bawah ini tidak akan merusaknya, sehingga aman!
    if (agencyFormatted == "MRT Jakarta") return replaceKereta("MRT");
    if (agencyFormatted == "LRT") return replaceKereta("LRT");
    if (agencyFormatted == "KRL") return replaceKereta("KRL");
    if (agencyFormatted == "Kereta") return replaceKereta("Kereta");

    return cleanInstr;
  }

  String _buildRouteLabel(Map step) {
    return "Rute: ${step["line"] ?? ""}";
  }
}
