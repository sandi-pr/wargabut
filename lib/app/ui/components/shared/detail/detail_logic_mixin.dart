import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localstorage/localstorage.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wargabut/app/services/share_service_gate.dart';
import '../../../../provider/location_provider.dart';
import '../../../../provider/transit_provider.dart';
import '../../../../services/transit_maps.dart';

// Mixin ini mengharuskan kelas penggunanya adalah State dari StatefulWidget
mixin DetailLogicMixin<T extends StatefulWidget> on State<T> {
  // --- CONTROLLERS (Shared) ---
  final eventNameController = TextEditingController();
  final dateEventController = TextEditingController();
  final areaController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();
  final ticketPriceController = TextEditingController();

  String htmType = 'free';
  bool isMedpart = false;

  // --- TRANSIT STATE ---
  // List<Map<String, dynamic>> routes = [];
  // bool isFetchingRoutes = false;
  String? locationError;
  List<String> allowedTravelModes = ["RAIL"];
  String? routingPreference;

  @override
  void dispose() {
    eventNameController.dispose();
    dateEventController.dispose();
    areaController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    ticketPriceController.dispose();
    super.dispose();
  }

  // --- POPULATE DATA KE CONTROLLER ---
  void loadInitialData(Map<String, dynamic> data) {
    eventNameController.text = data['event_name'] ?? '';
    areaController.text = data['area'] ?? '';
    locationController.text = data['location'] ?? '';
    dateEventController.text = data['date'] ?? '';
    descriptionController.text = data['desc'] ?? '';
    ticketPriceController.text = data['ticket_price'] ?? '';
    htmType = (data['ticket_price'] == 'Gratis') ? 'free' : 'paid';
    isMedpart = data['is_medpart'] ?? false;
  }

  // --- LOGIKA TRANSIT ---
  Future<void> fetchTransitRoutes(String destinationName) async {
    if (!mounted) return;

    // Reset error lokal jika ada
    setState(() {
      locationError = null;
    });

    try {
      final locationProvider = context.read<LocationProvider>();
      final transitProvider = context.read<TransitProvider>(); // Panggil Provider

      // Pastikan lokasi user sudah ada
      await locationProvider.fetchUserLocationWeb();
      final userPos = locationProvider.userPosition;

      if (userPos == null) {
        throw Exception("Lokasi pengguna belum tersedia.");
      }

      // --- PERUBAHAN UTAMA DI SINI ---
      // Jangan panggil Service manual, panggil fungsi di Provider!
      // Agar state di Provider terupdate dan UI (SharedTransitSection) merespons.
      await transitProvider.fetchTransitRoutes(
          userPosition: userPos,
          destinationLocation: destinationName,
          allowedTravelModes: allowedTravelModes,
          routingPreference: routingPreference
      );

    } catch (e) {
      if (mounted) setState(() => locationError = e.toString());
    }
  }

  Future<void> confirmLocationPermission(String destinationName) async {
    final locationProvider = context.read<LocationProvider>();

    // Cek apakah sudah pernah diizinkan sebelumnya
    final asked = localStorage.getItem('locationPermissionAsked') == 'true';

    if (locationProvider.userPosition != null) {
      // Jika lokasi sudah ada, langsung fetch
      await fetchTransitRoutes(destinationName);
      return;
    }

    if (asked) {
      // Jika sudah pernah ditanya (dan mungkin diizinkan), coba fetch langsung
      await fetchTransitRoutes(destinationName);
      return;
    }

    // Jika belum, tampilkan dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Izinkan Akses Lokasi?"),
        content: const Text("Fitur ini memerlukan akses lokasi Anda untuk mencari rute. Data tidak disimpan."),
        actions: [
          TextButton(child: const Text("Batal"), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(child: const Text("Lanjutkan"), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (result == true) {
      localStorage.setItem('locationPermissionAsked', 'true');
      // Panggil fungsi fetchTransitRoutes yang sudah diperbaiki di atas
      await fetchTransitRoutes(destinationName);
    }
  }

  // --- LOGIKA SHARE ---
  Future<void> shareEvent({
    required String title,
    required String id,
    required String pathPrefix, // '/jeventku' atau '/dkonser'
  }) async {
    final String url = "https://wargabut.id$pathPrefix/$id";
    final String text = "Yuk, datang ke '$title'! Cek info lengkapnya di sini:";

    if (kIsWeb) {
      if (isWebShareSupportedPlatform) {
        try {
          await sharePlatform(title: title, text: text, url: url);
        } catch (e) { print(e); }
      } else {
        await Clipboard.setData(ClipboardData(text: '$text\n$url'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link telah disalin!')));
        }
      }
    } else {
      SharePlus.instance.share(ShareParams(text: '$text\n$url'));
    }
  }
}