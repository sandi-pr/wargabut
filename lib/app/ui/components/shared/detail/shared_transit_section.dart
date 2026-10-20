import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../provider/location_provider.dart';
import '../../../../provider/transit_provider.dart';

// Callback untuk update filter di parent/mixin
typedef OnOptionChanged = void Function(List<String> modes, String? preference);
// Callback untuk trigger pencarian rute
typedef OnSearchRoute = Future<void> Function();

class SharedTransitSection extends StatefulWidget {
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
  State<SharedTransitSection> createState() => _SharedTransitSectionState();
}

class _SharedTransitSectionState extends State<SharedTransitSection> {

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
              const Expanded(
                child: Row(
                  children: [
                    Text("📍 Info Rute Transportasi", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Tooltip(
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
                  final newModes = List<String>.from(widget.allowedTravelModes);
                  String? newPref = widget.routingPreference;

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

                  widget.onOptionChanged(newModes, newPref);
                  if (locationProvider.userPosition != null) {
                    widget.onSearchRoute();
                  }
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: "toggle_bus",
                    checked: widget.allowedTravelModes.contains("BUS"),
                    child: const Text("Sertakan Bus"),
                  ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: "less_walking",
                    checked: widget.routingPreference == "LESS_WALKING",
                    child: const Text("Kurangi Jalan Kaki"),
                  ),
                  CheckedPopupMenuItem(
                    value: "fewer_transfers",
                    checked: widget.routingPreference == "FEWER_TRANSFERS",
                    child: const Text("Kurangi Transit"),
                  ),
                ],
              ),

              ElevatedButton(
                onPressed: locationProvider.isFetching || transitProvider.isFetching
                    ? null
                    : widget.onSearchRoute,
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
                  // TOTAL ESTIMASI & RINGKASAN PERJALANAN (DILENGKAPI TOMBOL BUKA GOOGLE MAPS)
                  _buildJourneySummaryBar(context, transitProvider),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transitProvider.routes.length,
                    separatorBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 2,
                            height: 10,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context, index) {
                      final step = transitProvider.routes[index];
                      if (step["type"] == "WALK") {
                        return _buildWalkCard(context, step, index);
                      }
                      return _buildTransitCard(context, step);
                    },
                  ),
                  const SizedBox(height: 10),
                  // TOMBOL BUKA GOOGLE MAPS DI AKHIR RUTE
                  _buildBottomGoogleMapsAction(context, transitProvider),
                  const SizedBox(height: 16),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
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
                              Text(agency, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15)),
                            ],
                          ),
                        ),
                        _buildCodeLineBadge(step["codeLine"] ?? step["vehicle"], step["colorLine"]),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    ),
                    
                    // TIMELINE RUTE
                    _buildTimelineItem(
                      time: step["departureTime"],
                      label: step["departure"],
                      isFirst: true,
                      color: _parseColor(step["colorLine"]),
                      isDark: isDark,
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
                                Icon(Icons.access_time, size: 14, color: isDark ? const Color(0xFF64B5F6) : Colors.blue),
                                const SizedBox(width: 6),
                                Text(
                                  "Durasi: ${step["duration"] ?? '-'}",
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? const Color(0xFF90CAF9) : Colors.blue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Melewati ${step["stopCount"]} pemberhentian", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                            if (step["headsign"] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text("Arah: ${step["headsign"]}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
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
                      isDark: isDark,
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _openInGoogleMaps(
                            origin: step["startLocation"] as LatLng?,
                            destination: step["endLocation"] as LatLng?,
                            destinationName: "${step["arrival"] ?? ''}",
                            travelMode: "transit",
                          );
                        },
                        icon: const Icon(Icons.directions_transit, size: 16),
                        label: const Text("Buka Rute Transit di Google Maps"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2),
                          side: BorderSide(color: isDark ? const Color(0xFF1E3A5F) : Colors.blue.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- GOOGLE MAPS DEEP LINK ---

  Future<void> _openInGoogleMaps({
    LatLng? origin,
    LatLng? destination,
    String? destinationName,
    String travelMode = "transit",
  }) async {
    String originParam = "";
    if (origin != null) {
      originParam = "${origin.latitude},${origin.longitude}";
    }
    String destParam = "";
    if (destination != null) {
      destParam = "${destination.latitude},${destination.longitude}";
    } else if (destinationName != null && destinationName.isNotEmpty) {
      destParam = Uri.encodeComponent(destinationName);
    }

    String url = "https://www.google.com/maps/dir/?api=1";
    if (originParam.isNotEmpty) {
      url += "&origin=$originParam";
    }
    if (destParam.isNotEmpty) {
      url += "&destination=$destParam";
    }
    url += "&travelmode=$travelMode";

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  // --- JOURNEY SUMMARY BAR ---

  Widget _buildJourneySummaryBar(BuildContext context, TransitProvider transitProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int totalWalkMeters = 0;
    int transitCount = 0;
    List<Widget> modeBadges = [];

    for (var step in transitProvider.routes) {
      if (step["type"] == "WALK") {
        totalWalkMeters += (step["distanceMeters"] as int? ?? 0);
      } else if (step["type"] == "TRANSIT") {
        transitCount++;
        final code = step["codeLine"] ?? step["vehicle"];
        final color = step["colorLine"];
        modeBadges.add(_buildCodeLineBadge(code, color));
      }
    }

    String walkDistText;
    if (totalWalkMeters >= 1000) {
      walkDistText = "${(totalWalkMeters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km";
    } else {
      walkDistText = "$totalWalkMeters m";
    }

    final totalDur = transitProvider.totalDuration ?? _calculateTotalDuration(transitProvider.routes);
    final totalDist = transitProvider.totalDistance;

    final summaryCardBg = isDark ? const Color(0xFF132235) : Colors.blue.shade50.withValues(alpha: 0.65);
    final summaryCardBorder = isDark ? const Color(0xFF1E3857) : Colors.blue.shade100;
    final summaryTitleColor = isDark ? const Color(0xFF90CAF9) : Colors.blue.shade800;
    final timerIconColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;

    final chipBg = isDark ? const Color(0xFF1C2C3D) : Colors.white;
    final chipBorder = isDark ? const Color(0xFF2C4A6F) : Colors.grey.shade300;
    final chipTextColor = isDark ? const Color(0xFFE0E0E0) : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: summaryCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: summaryCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: timerIconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Total Estimasi Perjalanan: $totalDur${totalDist != null ? ' ($totalDist)' : ''}",
                  style: TextStyle(fontWeight: FontWeight.bold, color: summaryTitleColor, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: chipBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk, size: 13, color: isDark ? Colors.amber.shade300 : Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      "Jalan $walkDistText",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: chipTextColor),
                    ),
                  ],
                ),
              ),
              if (transitCount > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: chipBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz, size: 13, color: isDark ? const Color(0xFF9FA8DA) : Colors.indigo),
                      const SizedBox(width: 4),
                      Text(
                        "${transitCount - 1}x Transit",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: chipTextColor),
                      ),
                    ],
                  ),
                ),
              ...modeBadges,
            ],
          ),
          const SizedBox(height: 12),
          // TOMBOL BUKA RUTE DI GOOGLE MAPS
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openInGoogleMaps(
                origin: transitProvider.startLocation,
                destination: transitProvider.endLocation,
                destinationName: widget.destinationName,
                travelMode: "transit",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1565C0) : const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Buka Rute di Google Maps",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.open_in_new, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TOMBOL BUKA GOOGLE MAPS DI BAWAH DAFTAR LANGKAH ---

  Widget _buildBottomGoogleMapsAction(BuildContext context, TransitProvider transitProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161F28) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2C3E50) : Colors.blue.shade200;
    final iconBg = isDark
        ? const Color(0xFF1976D2).withValues(alpha: 0.25)
        : const Color(0xFF1976D2).withValues(alpha: 0.1);
    final primaryColor = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openInGoogleMaps(
            origin: transitProvider.startLocation,
            destination: transitProvider.endLocation,
            destinationName: widget.destinationName,
            travelMode: "transit",
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.directions, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Navigasi Langsung di Google Maps",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Buka petunjuk arah real-time ke ${widget.destinationName.isNotEmpty ? widget.destinationName : 'lokasi tujuan'}",
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, size: 16, color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- KARTU TRANSIT ---

  Widget _buildTransitCard(BuildContext context, Map step) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _showTransitDetail(context, step),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "${step["departure"]} (${step["departureTime"]}) → ${step["arrival"]} (${step["arrivalTime"]})\n"
            "Estimasi: ${step["duration"] ?? '-'} | ${step["stopCount"] ?? '0'} pemberhentian",
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, height: 1.3),
          ),
        ),
        trailing: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.grey.shade500 : Colors.grey),
      ),
    );
  }

  // --- KARTU JALAN KAKI ---

  Widget _buildWalkCard(BuildContext context, Map step, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subType = step["subType"] ?? "WALK";
    final isFirst = subType == "FIRST_MILE";
    final isTransfer = subType == "TRANSFER";
    final isLast = subType == "LAST_MILE";
    final isSameStation = step["isSameStationTransfer"] == true;
    final isSameBusStop = step["isSameBusStopTransfer"] == true;
    final distanceMeters = step["distanceMeters"] as int? ?? 0;
    final hasLongWalk = isLast && distanceMeters >= 1000;

    Color badgeColor;
    Color iconBg;
    Color iconColor;
    String badgeLabel;
    IconData stepIcon;

    if (isFirst) {
      badgeColor = isDark ? const Color(0xFFFFB74D) : Colors.amber.shade900;
      iconBg = isDark ? const Color(0xFF332005) : Colors.amber.shade50;
      iconColor = isDark ? const Color(0xFFFFB74D) : Colors.amber.shade800;
      badgeLabel = "JALAN KAKI AWAL";
      stepIcon = Icons.directions_walk;
    } else if (isTransfer) {
      if (isSameStation) {
        badgeColor = isDark ? const Color(0xFFB39DDB) : Colors.deepPurple.shade700;
        iconBg = isDark ? const Color(0xFF261838) : Colors.deepPurple.shade50;
        iconColor = isDark ? const Color(0xFFB39DDB) : Colors.deepPurple.shade700;
        badgeLabel = "TRANSIT PERON";
        stepIcon = Icons.swap_calls_rounded;
      } else if (isSameBusStop) {
        badgeColor = isDark ? const Color(0xFF90CAF9) : Colors.blue.shade800;
        iconBg = isDark ? const Color(0xFF102338) : Colors.blue.shade50;
        iconColor = isDark ? const Color(0xFF90CAF9) : Colors.blue.shade700;
        badgeLabel = "TRANSIT HALTE";
        stepIcon = Icons.swap_horiz_rounded;
      } else {
        badgeColor = isDark ? const Color(0xFF9FA8DA) : Colors.indigo.shade700;
        iconBg = isDark ? const Color(0xFF181C38) : Colors.indigo.shade50;
        iconColor = isDark ? const Color(0xFF9FA8DA) : Colors.indigo.shade700;
        badgeLabel = "PINDAH MODA / TRANSIT";
        stepIcon = Icons.transfer_within_a_station;
      }
    } else if (isLast) {
      badgeColor = isDark ? const Color(0xFF80CBC4) : Colors.teal.shade800;
      iconBg = isDark ? const Color(0xFF0D2825) : Colors.teal.shade50;
      iconColor = isDark ? const Color(0xFF80CBC4) : Colors.teal.shade700;
      badgeLabel = "MENUJU LOKASI ACARA";
      stepIcon = Icons.pin_drop_outlined;
    } else {
      badgeColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
      iconBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
      iconColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
      badgeLabel = "JALAN KAKI";
      stepIcon = Icons.directions_walk;
    }

    String cardTitle = step["title"] ?? "Jalan kaki";
    if (isLast && widget.destinationName.trim().isNotEmpty) {
      if (cardTitle == "Jalan kaki ke lokasi tujuan" ||
          cardTitle == "Jalan kaki" ||
          cardTitle == "Jalan kaki ke lokasi acara" ||
          !cardTitle.toLowerCase().contains(widget.destinationName.trim().toLowerCase())) {
        cardTitle = "Jalan kaki ke ${widget.destinationName.trim()}";
      }
    }

    final hasTurns = (step["walkingSteps"] is List) && (step["walkingSteps"] as List).isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? iconColor.withValues(alpha: 0.35) : iconColor.withValues(alpha: 0.25), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showWalkDetail(context, step),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(stepIcon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: iconColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cardTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              (isSameStation || isSameBusStop) ? Icons.place_outlined : Icons.straighten,
                              size: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${step["distance"] ?? '-'}",
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.access_time, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              "${step["duration"] ?? '-'}",
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        if (step["transferWaitDuration"] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2D40) : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: isDark ? Border.all(color: const Color(0xFF2C4360)) : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.hourglass_empty, size: 12, color: isDark ? const Color(0xFF90CAF9) : Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Jeda waktu transit: ${step["transferWaitDuration"]}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF90CAF9) : Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasTurns)
                        Text(
                          "Panduan",
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64B5F6) : Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                      Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
              if (hasLongWalk)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2208) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF5A440E) : Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: isDark ? const Color(0xFFFFB74D) : Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Jarak jalan ke venue cukup jauh (${step["distance"]}). Anda dapat memesan ojek online/taksi.",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFFFD54F) : Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DETAIL MODAL JALAN KAKI ---

  void _showWalkDetail(BuildContext context, Map step) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final subType = step["subType"] ?? "WALK";
        final isSameStation = step["isSameStationTransfer"] == true;
        final isSameBusStop = step["isSameBusStopTransfer"] == true;
        final isLast = subType == "LAST_MILE";
        final List walkingTurns = (step["walkingSteps"] is List) ? step["walkingSteps"] : [];

        final destinationVenue = widget.destinationName.trim().isNotEmpty
            ? widget.destinationName.trim()
            : (step["targetVenue"] ?? "lokasi acara");

        String intro = "Ikuti panduan rute jalan kaki di bawah ini.";
        if (subType == "FIRST_MILE") {
          final targetStop = step["targetStopName"] ?? "halte/stasiun pertama";
          intro = "Jalan kaki dari titik awal Anda menuju $targetStop keberangkatan pertama.";
        } else if (subType == "TRANSFER") {
          if (isSameStation) {
            final stName = step["stationName"] ?? "stasiun";
            final targetLine = step["targetLine"] ?? "kereta berikutnya";
            final headsign = step["targetHeadsign"] != null ? " (arah ${step["targetHeadsign"]})" : "";
            intro = "Anda sudah berada di $stName. Silakan transit menuju peron $targetLine$headsign melalui tangga atau jembatan penyeberangan di dalam stasiun. Perhatikan papan pengumuman peron.";
          } else if (isSameBusStop) {
            final targetStop = step["targetStopName"] ?? step["stationName"] ?? "halte";
            final nextL = step["targetLine"] ?? "bus berikutnya";
            final headsign = step["targetHeadsign"] != null ? " (arah ${step["targetHeadsign"]})" : "";
            intro = "Anda sudah berada di $targetStop. Tetap berada di dalam area halte (tidak perlu tap out / keluar halte). Silakan menuju pintu peron tunggu bus untuk naik $nextL$headsign.";
          } else {
            final prevV = step["prevVehicle"] ?? "moda sebelumnya";
            final targetStop = step["targetStopName"] ?? step["stationName"] ?? "halte/stasiun";
            final nextL = step["targetLine"] ?? "moda berikutnya";
            if (step["isNextBus"] == true) {
              intro = "Turun dari $prevV, lalu jalan kaki keluar stasiun menuju $targetStop untuk naik $nextL. Perhatikan rute dan kedatangan bus.";
            } else if (step["isNextRail"] == true) {
              intro = "Turun dari $prevV, lalu jalan kaki menuju $targetStop untuk naik $nextL. Perhatikan peron dan jadwal keberangkatan kereta.";
            } else {
              intro = "Pindah moda transportasi menuju $targetStop untuk melanjutkan perjalanan dengan $nextL. Perhatikan jadwal keberangkatan.";
            }
          }
        } else if (subType == "LAST_MILE") {
          intro = "Jalan kaki dari stasiun/halte akhir menuju lokasi venue acara $destinationVenue.";
        }

        String modalTitle = step["title"] ?? "Panduan Jalan Kaki";
        if (isLast) {
          modalTitle = "Jalan kaki ke $destinationVenue";
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.65,
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
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSameStation
                                ? (isDark ? const Color(0xFF261838) : Colors.deepPurple.shade50)
                                : (isSameBusStop
                                    ? (isDark ? const Color(0xFF102338) : Colors.blue.shade50)
                                    : (isLast
                                        ? (isDark ? const Color(0xFF0D2825) : Colors.teal.shade50)
                                        : (isDark ? const Color(0xFF181C38) : Colors.indigo.shade50))),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSameStation
                                ? Icons.swap_calls_rounded
                                : (isSameBusStop
                                    ? Icons.swap_horiz_rounded
                                    : (isLast ? Icons.pin_drop_outlined : Icons.directions_walk)),
                            color: isSameStation
                                ? (isDark ? const Color(0xFFB39DDB) : Colors.deepPurple.shade700)
                                : (isSameBusStop
                                    ? (isDark ? const Color(0xFF90CAF9) : Colors.blue.shade700)
                                    : (isLast
                                        ? (isDark ? const Color(0xFF80CBC4) : Colors.teal.shade700)
                                        : (isDark ? const Color(0xFF9FA8DA) : Colors.indigo.shade700))),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                modalTitle,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF252B2D) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Jarak: ${step["distance"] ?? '-'}",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF252B2D) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Waktu: ${step["duration"] ?? '-'}",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      intro,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade600, height: 1.4),
                    ),
                    if (step["transferWaitDuration"] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A2238) : Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF2C3B60) : Colors.indigo.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: isDark ? const Color(0xFF9FA8DA) : Colors.indigo.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Jeda waktu transit: ${step["transferWaitDuration"]} (Waktu cukup untuk berpindah dan bersiap).",
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFC5CAE9) : Colors.indigo.shade900, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    ),
                    const Text(
                      "Langkah Panduan Arah",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    if (walkingTurns.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2023) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF2E383E) : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.navigation_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Ikuti petunjuk arah jalan kaki ke tujuan (${step["distance"]}).",
                                style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: walkingTurns.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final turn = walkingTurns[i];
                          final instr = turn["instruction"] ?? "";
                          final maneuver = turn["maneuver"] ?? "";
                          final dist = turn["distance"] ?? "";
                          final dur = turn["duration"] ?? "";

                          IconData turnIcon = Icons.straight;
                          if (maneuver.contains("LEFT")) {
                            turnIcon = Icons.turn_left;
                          } else if (maneuver.contains("RIGHT")) {
                            turnIcon = Icons.turn_right;
                          } else if (instr.toLowerCase().contains("tangga")) {
                            turnIcon = Icons.stairs;
                          } else if (instr.toLowerCase().contains("keluar")) {
                            turnIcon = Icons.exit_to_app;
                          } else if (instr.toLowerCase().contains("masuk")) {
                            turnIcon = Icons.login;
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2E44) : Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(turnIcon, size: 16, color: isDark ? const Color(0xFF64B5F6) : Colors.blue.shade700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      instr,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    if (dist.isNotEmpty || dur.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          [if (dist.isNotEmpty) dist, if (dur.isNotEmpty) dur].join(" • "),
                                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                    if (isSameStation)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _openInGoogleMaps(
                              origin: step["startLocation"] as LatLng?,
                              destination: step["endLocation"] as LatLng?,
                              destinationName: step["stationName"] ?? "Stasiun Transit",
                              travelMode: "walking",
                            );
                          },
                          icon: const Icon(Icons.place_outlined, size: 16),
                          label: Text("Lihat Lokasi ${step["stationName"] ?? 'Stasiun'} di Google Maps"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFFB39DDB) : Colors.deepPurple.shade700,
                            side: BorderSide(color: isDark ? const Color(0xFF4A346E) : Colors.deepPurple.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _openInGoogleMaps(
                              origin: step["startLocation"] as LatLng?,
                              destination: step["endLocation"] as LatLng?,
                              destinationName: isLast
                                  ? destinationVenue
                                  : (step["title"] ?? "Panduan Jalan Kaki"),
                              travelMode: "walking",
                            );
                          },
                          icon: const Icon(Icons.navigation, size: 16),
                          label: const Text("Buka Navigasi Jalan di Google Maps"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1565C0) : Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
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
    bool isDark = false,
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
                color: isDark ? const Color(0xFF1B2023) : Colors.white,
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
}
