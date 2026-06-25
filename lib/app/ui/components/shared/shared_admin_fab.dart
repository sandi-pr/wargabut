import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class SharedAdminFab extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  // Opsional: jika mau tambah tombol lain di masa depan
  final VoidCallback? onGeocode;
  final VoidCallback? onCrawl;

  const SharedAdminFab({
    super.key,
    required this.isAdmin,
    required this.onRefresh,
    required this.onAdd,
    this.onGeocode,
    this.onCrawl,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();

    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.refresh),
          label: 'Refresh Data',
          onTap: onRefresh,
        ),
        if (onGeocode != null)
          SpeedDialChild(
            child: const Icon(Icons.location_on),
            label: 'Geocode (Admin Only)',
            onTap: onGeocode,
          ),
        SpeedDialChild(
          child: const Icon(Icons.add),
          label: 'Tambah Baru',
          onTap: onAdd,
        ),
        if (onCrawl != null)
          SpeedDialChild(
            child: const Icon(Icons.travel_explore),
            label: 'Crawl Event Baru',
            onTap: onCrawl,
          ),
      ],
    );
  }
}