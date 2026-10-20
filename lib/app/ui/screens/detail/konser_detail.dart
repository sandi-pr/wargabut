import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:localstorage/localstorage.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:wargabut/app/services/transit_maps.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wargabut/app/services/share_service_gate.dart';

import '../../../provider/konser_provider.dart';
import '../../../provider/location_provider.dart';
import '../../../provider/transit_provider.dart';

class KonserDetailPage extends StatefulWidget {
  final Map<String, dynamic>? data;
  final String eventId;

  const KonserDetailPage({
    super.key,
    required this.eventId,
    this.data,
  });

  @override
  State<KonserDetailPage> createState() => _KonserDetailPageState();
}

class _KonserDetailPageState extends State<KonserDetailPage> {
  bool _isLoading = true;
  bool _postersAreLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _eventData;

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _editMode = false;
  bool _isExpanded = false;
  bool _isReordering = false;

  final _eventNameController = TextEditingController();
  final _dateEventController = TextEditingController();
  final _areaController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketPriceController = TextEditingController();

  String _htmType = 'free';

  bool _isMedpart = false;


  File? _selectedImage; // Gambar yang dipilih
  Uint8List webImage = Uint8List(10);
  Uint8List? _imageBytes;
  Uint8List? _cachedImageBytes;
  String? _fileName;
  final ImagePicker _picker = ImagePicker(); // Untuk memilih gambar

  final StorageService _storageService = StorageService();
  XFile? _imageFile;
  String? _downloadURL;

  late LocationSettings locationSettings;

  Position? _userPosition;
  String? _userAddress;
  String? _locationError;
  List<Map<String, dynamic>> _routes = [];
  bool _isFetchingRoutes = false;

  List<String> allowedTravelModes = ["RAIL"];
  String? routingPreference; // null, LESS_WALKING, FEWER_TRANSFERS

  List<Map<String, String>> posters = [];

  List<Map<String, dynamic>> uploadedPosters = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    // Jangan lupa dispose semua controller
    _eventNameController.dispose();
    _dateEventController.dispose();
    _areaController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _ticketPriceController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // Cek apakah data sudah diberikan melalui widget (navigasi dari list)
    if (widget.data != null) {
      // Jika ya, langsung gunakan data tersebut
      setState(() {
        _eventData = widget.data;
        _isLoading = false;
      });
    } else {
      // Jika tidak (dibuka via URL), fetch dari Firestore
      try {
        final doc = await FirebaseFirestore.instance
            .collection('dfestkonser')
            .doc(widget.eventId)
            .get();

        if (doc.exists) {
          setState(() {
            _eventData = doc.data()!..['id'] = doc.id;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = "Festival tidak ditemukan.";
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = "Gagal memuat data: $e";
          _isLoading = false;
        });
      }
    }

    // Setelah _eventData diisi, jalankan fungsi-fungsi lainnya
    if (_eventData != null) {
      _loadInitialDataIntoControllers();
      _checkLoginAndAdminStatus();
      fetchImage();
      loadPosters();
    }
  }

  void _loadInitialDataIntoControllers() {
    if (_eventData == null) return;
    _eventNameController.text = _eventData!['event_name'];
    _areaController.text = _eventData!['area'];
    _locationController.text = _eventData!['location'];
    _dateEventController.text = _eventData!['date'];
    _descriptionController.text = _eventData!['desc'] ?? '';
    _ticketPriceController.text = _eventData!['ticket_price'] ?? '';
    _htmType = _eventData!['ticket_price'] == 'Gratis' ? 'free' : 'paid';
    _isMedpart = _eventData!['is_medpart'] ?? false;
  }

  Future<void> _checkLoginAndAdminStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _isAdmin = prefs.getBool('isAdmin') ?? false;
    });
    if (kDebugMode) {
      print('isLoggedIn: $_isLoggedIn, isAdmin: $_isAdmin');
    }
  }

  Future<void> fetchImage() async {
    if (_eventData?['is_postered'] == true) {
      final cachedImage =
      await _storageService.getCachedImage(_eventData!['event_name']);
      if (cachedImage != null && mounted) {
        setState(() {
          _cachedImageBytes = cachedImage;
        });
      }
    }
  }

  Future<void> _updateEventToFirestore(BuildContext context) async {
    final eventProvider = context.read<KonserProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      // Assuming you have a way to get the document ID of the event
      final String documentId = _eventData!['id'];

      bool isImage = false;

      DocumentSnapshot doc =
      await firestore.collection('dfestkonser').doc(documentId).get();

      if (doc.exists &&
          doc.data() != null &&
          (doc.data() as Map<String, dynamic>).containsKey('posters')) {
        isImage = true;

        // Sort posters by order before saving
        List<dynamic> posters = List.from((doc.data() as Map<String, dynamic>)['posters'] ?? []);
        if (posters.isNotEmpty) {
          // Normalize order jika perlu
          bool needsNormalization = posters.every((p) => p['order'] == null || p['order'] == 1);
          if (needsNormalization) {
            for (int i = 0; i < posters.length; i++) {
              posters[i]['order'] = i;
            }
          }

          // Sort berdasarkan order
          posters.sort((a, b) {
            final orderA = (a['order'] as num?) ?? 0;
            final orderB = (b['order'] as num?) ?? 0;
            return orderA.compareTo(orderB);
          });

          // Update dengan posters yang sudah diurutkan
          await firestore.collection('dfestkonser').doc(documentId).update({
            'posters': posters,
          });
        }
      }

      if (isImage || _eventData!['is_postered'] == true) {
        // await _uploadImage();
        isImage = true;
      }

      await firestore.collection('dfestkonser').doc(documentId).update({
        'event_name': _eventNameController.text,
        'date': _dateEventController.text,
        'area': _areaController.text,
        'location': _locationController.text,
        'desc': _descriptionController.text,
        'ticket_price': _htmType == 'free' ? 'Gratis' : _ticketPriceController.text,
        'is_postered': isImage,
        'is_medpart': _isMedpart
      });

      if (!mounted) return;

      // 🔥 Ambil provider dan perbarui daftar event
      await eventProvider.fetchData(forceRefresh: true);

      messenger.showSnackBar(
        const SnackBar(content: Text('Festival berhasil diperbarui!')),
      );

      setState(() {
        _editMode = false; // Keluar dari mode edit
      });
    } catch (e) {
      if (!mounted) return;
      // Handle errors, e.g., show an error message
      if (kDebugMode) {
        print('Error updating festival: $e');
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to update festival.')),
      );
    }
  }

  Future<void> _deleteEventFromFirestore(BuildContext context) async {
    final eventProvider = Provider.of<KonserProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      // Hapus semua gambar terkait dari Firebase Storage
      final List<dynamic> posters = _eventData?['posters'] ?? [];
      for (var p in posters) {
        if (p is Map && p['path'] != null) {
          try {
            await FirebaseStorage.instance.ref(p['path']).delete();
          } catch (e) {
            debugPrint('Error deleting image from storage: $e');
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('dfestkonser')
          .doc(_eventData!['id']) // Gunakan _eventData
          .delete();

      if (!mounted) return;

      router.go('/dkonser');

      messenger.showSnackBar(
        const SnackBar(content: Text('Festival berhasil dihapus')),
      );


      await eventProvider.fetchData(forceRefresh: true);
    } catch (e) {
      print('Error deleting festival: $e');
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus festival: $e')),
      );
    }
  }

  Future<void> pickImageWeb() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        setState(() {
          _imageBytes = file.bytes;
        });
      } else {
        print('User canceled the picker');
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> _cacheNetworkImage(String imageUrl, String eventName) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        _storageService.cacheImage(eventName, response.bodyBytes);
        print('Successfully cached image');
      } else {
        print('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error caching image: $e');
    }
  }

  Future<Uint8List?> fetchImageAsBytes(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes; // Mengembalikan data sebagai Uint8List
      } else {
        print("Failed to load image: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching image: $e");
      return null;
    }
  }

  Future<void> _uploadImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? selectedImages = await picker.pickMultiImage();

    if (selectedImages != null && selectedImages.isNotEmpty) {
      List<Map<String, dynamic>> newPosters = await _storageService
          .uploadImages(selectedImages, 'dkonser', _eventData!['event_name']);

      await addPostersToFirestore(newPosters); // Menambahkan bukan mengganti
    }
  }

  Future<void> updatePostersToFirestore(List<Map<String, dynamic>> posters) async {
    try {
      final String documentId = _eventData!['id'];
      await FirebaseFirestore.instance
          .collection('dfestkonser')
          .doc(documentId)
          .update({
        'posters': posters,
        'is_postered': posters.isNotEmpty, // Update status poster
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster berhasil diupload!')),
        );
        // setState(() {
        //   _editMode = false;
        // });
      }
    } catch (e) {
      print('Error updating posters: $e');
    }
  }

  Future<void> addPostersToFirestore(List<Map<String, dynamic>> newPosters) async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String documentId = _eventData!['id'];
      DocumentSnapshot doc =
          await firestore.collection('dfestkonser').doc(documentId).get();

      List<dynamic> existingPosters = [];
      if (doc.exists &&
          doc.data() != null &&
          (doc.data() as Map<String, dynamic>).containsKey('posters')) {
        existingPosters = List.from(doc['posters']);
      }

      print("poster: $existingPosters");

      // Jika tidak ada poster utama, set salah satu sebagai utama
      bool hasMainPoster = existingPosters.any((p) => p['is_main'] == true);
      print("poster has main: $hasMainPoster");
      if (!hasMainPoster && newPosters.isNotEmpty) {
        newPosters.first['is_main'] = true;
      } else if (!hasMainPoster) {
        // Jika tidak ada poster utama, set poster pertama sebagai utama
        newPosters[0]['is_main'] = true;

        print("Poster pertama: ${newPosters[0]['is_main']}");
      }

      existingPosters.addAll(newPosters);

      await firestore.collection('dfestkonser').doc(documentId).update({
        'posters': existingPosters,
        'is_postered': true,
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Poster berhasil diupload!')),
      );
    } catch (e) {
      print('Error updating posters: $e');
    }
  }

  Future<void> setMainPoster(dynamic target) async {
    try {
      final firestore = FirebaseFirestore.instance;
      DocumentReference docRef =
          firestore.collection('dfestkonser').doc(_eventData!['id']);
      DocumentSnapshot doc = await docRef.get();

      if (doc.exists) {
        List<dynamic> posters = List.from(doc['posters'] ?? []);

        // Set semua poster ke "is_main: false"
        for (var poster in posters) {
          poster['is_main'] = false;
        }

        if (target is Map<String, dynamic>) {
          final targetPath = target['path']?.toString();
          final targetUrl = target['url']?.toString();
          for (var poster in posters) {
            if ((targetPath != null && poster['path'] == targetPath) ||
                (targetUrl != null && poster['url'] == targetUrl)) {
              poster['is_main'] = true;
              break;
            }
          }
        } else if (target is int && target >= 0 && target < posters.length) {
          posters[target]['is_main'] = true;
        }

        // Update Firestore
        await docRef.update({'posters': posters});
      }
    } catch (e) {
      print('Error setting main poster: $e');
    }
  }

  Future<void> _deletePoster(Map<String, dynamic> targetPoster) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Poster'),
        content: const Text('Apakah Anda yakin ingin menghapus poster ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _storageService.deletePoster(
      context,
      -1,
      'dfestkonser',
      _eventData!['id'],
      targetPoster: targetPoster,
    );
  }

  Future<List<Map<String, String>>> fetchPosters(String eventId) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('dfestkonser')
          .doc(eventId)
          .get();

      if (!snapshot.exists) return [];

      // print("Snapshot data: ${snapshot.data()}");

      var data = snapshot.data() as Map<String, dynamic>;
      List<dynamic> posters = List.from(data['posters'] ?? []);

      // Handle legacy data & sort by order
      if (posters.isNotEmpty) {
        // Normalize order jika perlu
        bool needsNormalization = posters.every((p) => p['order'] == null || p['order'] == 1);
        if (needsNormalization) {
          for (int i = 0; i < posters.length; i++) {
            posters[i]['order'] = i;
          }
          // Auto-save normalized order
          try {
            await FirebaseFirestore.instance
                .collection('dfestkonser')
                .doc(eventId)
                .update({'posters': posters});
          } catch (e) {
            print('Error auto-saving normalized order: $e');
          }
        }

        // Sort berdasarkan order
        posters.sort((a, b) {
          final orderA = (a['order'] as num?) ?? 0;
          final orderB = (b['order'] as num?) ?? 0;
          return orderA.compareTo(orderB);
        });
      }

      Future<String> getDownloadUrl(String path) async {
        final ref = FirebaseStorage.instance.ref().child(path);
        return await ref.getDownloadURL();
      }

      // Gunakan Future.wait agar bisa menangani async dengan benar
      List<Map<String, String>> postersWithUrls = await Future.wait(
        posters.map((poster) async {
          String title =
              poster["title"]?.toString() ?? "Untitled"; // Cast ke String
          String path = poster["path"]?.toString() ?? ""; // Cast ke String

          if (path.isEmpty) return {"title": title, "url": ""};

          String imageUrl = await getDownloadUrl(path);
          return {"title": title, "url": imageUrl};
        }),
      );

      return postersWithUrls;
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching posters: $e");
      }
      return [];
    }
  }

  Future<void> loadPosters() async {
    // Pastikan state diatur ke loading saat fungsi ini dimulai
    if (!mounted) return;
    setState(() {
      _postersAreLoading = true;
    });

    if (_eventData == null) {
      if (!mounted) return;
      setState(() => _postersAreLoading = false);
      return;
    }

    List<Map<String, String>> data = await fetchPosters(_eventData!['id']);

    if (!mounted) return;

    // Setelah data didapat, atur state loading ke false dan isi posternya
    setState(() {
      posters = data;
      _postersAreLoading = false;
    });
  }

  Future<void> _fetchTransitRoutes() async {
    try {
      final destLatLng = await GeocodingService.getLatLngFromLocationName(
          _eventData!['location']);

      if (destLatLng == null || _userPosition == null) {
        setState(() {
          _errorMessage =
              "❌ Lokasi tujuan atau posisi pengguna tidak ditemukan.";
        });
        return;
      } else {
        // print("📍 Lokasi tujuan: $destLatLng");
      }

      var transitDetails = await TransitService.getTransitDetails(
          _userPosition!.latitude,
          _userPosition!.longitude,
          destLatLng.latitude,
          destLatLng.longitude,
          allowedTravelModes: allowedTravelModes,
          routingPreference: routingPreference);

      // print("🚆 Detail rute transit: $transitDetails");

      setState(() {
        _routes = List<Map<String, dynamic>>.from(transitDetails);
        _isFetchingRoutes = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error di UI: $e");
      }
      setState(() {
        _routes = [];
      });
    }
  }

  Future<void> _getTransitDirections() async {
    // 1. Mulai proses loading dan bersihkan error lama
    if (!mounted) return;
    setState(() {
      _isFetchingRoutes = true;
      _locationError = null;
    });

    try {
      // 2. Minta izin dan dapatkan lokasi pengguna saat ini
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
          throw Exception("Izin lokasi ditolak oleh pengguna.");
        }
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _userPosition = position;
      });

      // 3. Dapatkan Lat/Lng dari nama lokasi event
      final destLatLng = await GeocodingService.getLatLngFromLocationName(_eventData!['location']);
      if (destLatLng == null) {
        throw Exception("Lokasi festival tidak dapat ditemukan.");
      }

      // 4. Panggil service Anda untuk mendapatkan detail rute transit
      final transitDetails = await TransitService.getTransitDetails(
        position.latitude,
        position.longitude,
        destLatLng.latitude,
        destLatLng.longitude,
      );

      if (!mounted) return;
      setState(() {
        _routes = List<Map<String, dynamic>>.from(transitDetails);
      });

    } catch (e) {
      // Tangani semua kemungkinan error di sini
      if (!mounted) return;
      setState(() {
        _locationError = "Gagal mendapatkan rute: ${e.toString()}";
      });
    } finally {
      // 5. Apapun hasilnya, hentikan proses loading
      if (!mounted) return;
      setState(() {
        _isFetchingRoutes = false;
      });
    }
  }

  void _showZoomDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true, // Bisa ditutup dengan tap di luar
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(10),
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _buildPosterPlaceholder(),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String formatNavigationInstruction(
      String? instruction,
      String? agency,
      String? codeLine,
      ) {
    if (instruction == null || instruction.trim().isEmpty) return "";

    // Bersihkan tag HTML (jika ada)
    instruction = instruction.replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '');

    final agencyFormatted = formatAgencyName(agency);
    final lowerInstruction = instruction.toLowerCase();
    final isJakLingko = agencyFormatted == "TransJakarta" &&
        (codeLine?.toUpperCase().contains("JAK.") ?? false);

    // Helper: ganti "Bus/Bas menuju ..." menjadi yang sesuai
    String replaceMenuju(String replacement) {
      return instruction!.replaceAllMapped(
        RegExp(r'\b([Bb]us|[Bb]as)\s+menuju\b', caseSensitive: false),
            (match) => replacement,
      );
    }

    if (isJakLingko) {
      return replaceMenuju("JakLingko menuju");
    }

    if (agencyFormatted == "Angkot") {
      return replaceMenuju("Angkot menuju");
    }

    if (agencyFormatted == "TransJakarta") {
      return replaceMenuju("TransJakarta menuju");
    }

    if (agencyFormatted == "MRT Jakarta") {
      return instruction.replaceAllMapped(
        RegExp(r'\b[Kk]ereta api\b'),
            (match) => "MRT",
      );
    }

    if (agencyFormatted == "LRT") {
      return instruction.replaceAllMapped(
        RegExp(r'\b[Kk]ereta api\b'),
            (match) => "LRT",
      );
    }

    return instruction;
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

  String formatAgencyName(String? agency) {
    if (agency == null || agency.trim().isEmpty) return "";

    agency = agency.trim();

    // Ubah ke lowercase untuk pengecekan fleksibel
    final lowerAgency = agency.toLowerCase();

    if (lowerAgency.contains("kereta commuter indonesia")) {
      return "KRL";
    } else if (lowerAgency.contains("mrt")) {
      return "MRT Jakarta";
    } else if (lowerAgency.contains("lrt")) {
      return "LRT";
    } else if (lowerAgency.contains("transjakarta")) {
      return "TransJakarta";
    } else if (lowerAgency.contains("angkot")) {
      return "Angkot";
    } else if (lowerAgency.contains("trem")) {
      return "LRT";
    }

    // Hilangkan "PT.", "PT", atau titik di awal jika ada
    final cleaned =
        agency.replaceAll(RegExp(r"^PT\.?\s*", caseSensitive: false), "");


    return cleaned;
  }

  Icon getAgencyIcon(String? agency) {
    final name = formatAgencyName(agency).toLowerCase();

    if (name == "krl") {
      return const Icon(Icons.train, color: Colors.red);
    } else if (name.contains("mrt")) {
      return const Icon(Icons.subway, color: Colors.blue);
    } else if (name.contains("lrt")) {
      return const Icon(Icons.tram, color: Colors.green);
    } else if (name.contains("transjakarta")) {
      return const Icon(Icons.directions_bus, color: Colors.lightBlue);
    } else if (name.contains("angkot")) {
      return const Icon(Icons.directions_car, color: Colors.orange);
    }

    return const Icon(Icons.directions_transit, color: Colors.grey); // default
  }

  Future<void> _confirmLocationPermission() async {
    final locationProvider = context.read<LocationProvider>();
    final transitProvider = context.read<TransitProvider>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Izinkan Akses Lokasi?"),
        content: const Text(
          "Fitur ini memerlukan akses lokasi Anda untuk mencari rute transportasi publik dari posisi Anda saat ini. Data lokasi tidak disimpan.",
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text("Lanjutkan"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (result == true) {
      localStorage.setItem('locationPermissionAsked', 'true');
      await locationProvider.fetchUserLocationWeb();
      final userPos = locationProvider.userPosition;
      if (userPos != null) {
        await transitProvider.fetchTransitRoutes(
          userPosition: userPos,
          destinationLocation: _eventData!['location'],
          allowedTravelModes: allowedTravelModes,
          routingPreference: routingPreference,
        );
      }
    } else {
      // Dibatalkan oleh pengguna
      setState(() {
        _locationError = "Akses lokasi dibatalkan oleh pengguna.";
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Akses lokasi dibatalkan."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _shareEvent(BuildContext context) async {
    if (_eventData == null) return;

    final String eventName = _eventData!['event_name'];
    final String eventId = _eventData!['id'];

    final String eventUrl = "https://wargabut.id/dkonser/$eventId";
    final String shareText = "Yuk, datang ke festival '$eventName'! Cek info lengkapnya di sini:";
    final String shareTitle = eventName;

    if (kIsWeb) {
      // Sekarang memanggil variabel dari hasil conditional import
      if (isWebShareSupportedPlatform) {
        try {
          await sharePlatform(
            title: shareTitle,
            text: shareText,
            url: eventUrl,
          );
        } catch (e) {
          debugPrint('Error sharing: $e');
        }
      } else {
        // Fallback copy to clipboard
        final String textToCopy = '$shareText\n$eventUrl';
        await Clipboard.setData(ClipboardData(text: textToCopy));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link event telah disalin!'),
            behavior: SnackBarBehavior.floating,
            width: 250, // Sesuaikan lebar SnackBar
          ),
        );
      }
    } else {
      // Mobile menggunakan share_plus
      SharePlus.instance.share(
          ShareParams(text: '$shareText\n$eventUrl')
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text(_errorMessage!)),
      );
    }
    return Scaffold(
      appBar: _editMode
          ? _buildEditModeAppBar(context)
          : _buildViewModeAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: _editMode
            ? _buildEditModeBody(context)
            : _buildViewModeBody(context),
      ),
    );
  }

  // ===========================================================================
  // UI BUILDERS: APP BAR
  // ===========================================================================

  AppBar _buildViewModeAppBar(BuildContext context) {
    return AppBar(
      title: AutoSizeText(_eventData!['event_name'], maxLines: 1),
      leading: Navigator.canPop(context) ? null : IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/dkonser'),
      ),
      actions: [
        // =======================================================
        // PENAMBAHAN TOMBOL SHARE DI SINI
        // =======================================================
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _shareEvent(context),
          tooltip: 'Bagikan Festival',
        ),

        // Tombol menu untuk admin tetap ada setelahnya
        if (_isAdmin)
          PopupMenuButton<String>(
            onSelected: (item) {
              if (item == 'edit') {
                setState(() => _editMode = true);
              } else if (item == 'delete') {
                _showDeleteConfirmationDialog(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
              PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
      ],
    );
  }

  AppBar _buildEditModeAppBar(BuildContext context) {
    return AppBar(
      title: const Text("Edit Festival"),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => _editMode = false),
      ),
      actions: [
        TextButton(
          onPressed: () => _updateEventToFirestore(context),
          child: const Text("SIMPAN"),
        )
      ],
    );
  }


  // ===========================================================================
  // UI BUILDERS: BODY
  // ===========================================================================

  Widget _buildViewModeBody(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    // Logika responsif sekarang hanya mengatur Row atau Column
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _buildImageCarousel(context)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildEventDetailsColumn(context)),
        ],
      );
    } else {
      // Mobile
      return Column(
        children: [
          _buildImageCarousel(context),
          const SizedBox(height: 16.0),
          _buildEventDetailsColumn(context),
        ],
      );
    }
  }

  Widget _buildEditModeBody(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildEventForm()),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildPosterManager()),
        ],
      );
    } else {
      // Mobile
      return Column(
        children: [
          _buildEventForm(),
          const Divider(height: 32),
          _buildPosterManager(),
        ],
      );
    }
  }


  // ===========================================================================
  // UI BUILDERS: KOMPONEN-KOMPONEN KECIL
  // ===========================================================================

  Widget _buildImageCarousel(BuildContext context) {
    // Tahap 1: Tampilkan loading indicator jika poster sedang diambil
    if (_postersAreLoading) {
      return const AspectRatio(
        aspectRatio: 1.0,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Tahap 2: Jika loading selesai dan poster memang kosong, tampilkan placeholder
    if (posters.isEmpty) {
      return _buildPosterPlaceholder();
    }

    // Tahap 3: Jika loading selesai dan ada poster, tampilkan CarouselSlider
    return CarouselSlider(
      options: CarouselOptions(
        autoPlay: posters.length > 1,
        aspectRatio: 1.0,
        enlargeCenterPage: true,
      ),
      items: posters.map((poster) {
        final imageUrl = poster['url'];
        if (imageUrl == null || imageUrl.isEmpty) {
          return _buildPosterPlaceholder(); // Placeholder jika URL poster kosong
        }
        return GestureDetector(
          onTap: () => _showZoomDialog(context, imageUrl),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            // Tampilkan placeholder saat gambar di dalam carousel sedang loading
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            // Tampilkan placeholder jika gambar gagal dimuat
            errorBuilder: (context, error, stackTrace) {
              return _buildPosterPlaceholder();
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEventDetailsColumn(BuildContext context) {
    final ticketPrice = _eventData!['ticket_price']?.toString().trim();
    String? htmDisplay;

    if (ticketPrice != null && ticketPrice.isNotEmpty) {
      if (ticketPrice.toLowerCase() == 'gratis') {
        htmDisplay = 'Gratis';
      } else {
        // Coba parsing angka dari string (contoh: "75.000" → 75000)
        final numeric = ticketPrice.replaceAll('.', '');
        final priceValue = int.tryParse(numeric);

        if (priceValue != null && priceValue > 0) {
          htmDisplay = NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(priceValue);
        } else {
          htmDisplay = ticketPrice; // fallback
        }
      }
    }
    return Column(
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 🔸 Baris pertama: Tanggal + HTM di kanan
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _eventData!['date'] ?? 'Tanggal tidak tersedia',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (htmDisplay != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: htmDisplay == 'Gratis'
                              ? Colors.green.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          htmDisplay,
                          style: TextStyle(
                            color: htmDisplay == 'Gratis' ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 🔸 Baris kedua: Lokasi dan area
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _eventData!['location'] ?? 'Lokasi tidak tersedia',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (_eventData!['area'] != null && _eventData!['area'].isNotEmpty)
                            Text(
                              _eventData!['area'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_eventData!['desc'] != null && _eventData!['desc'].isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventData!['desc'] != null
                        ? _eventData!['desc']
                        .replaceAll('\\n', '\n')
                        : '',
                    softWrap: true,
                    maxLines: _isExpanded
                        ? null
                        : 4, // Default 4 baris
                    overflow: _isExpanded
                        ? null
                        : TextOverflow.ellipsis,
                  ),
                  if (!_isExpanded) // Tampilkan tombol hanya jika belum diperluas
                    Align(
                      alignment:
                      Alignment.bottomRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isExpanded = true;
                          });
                        },
                        child: const Text(
                            "Lihat Selengkapnya"),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const Divider(height: 32.0),
        // ... (Widget untuk info rute transit bisa ditambahkan di sini)
        // if (_isAdmin)
          _buildTransitSection(context),

        const SizedBox(height: 32.0),
      ],
    );
  }

  Widget _buildEventForm() {
    return Column(
      children: [
        TextField(controller: _eventNameController, decoration: const InputDecoration(labelText: 'Nama Festival')),
        const SizedBox(height: 16),
        TextField(controller: _dateEventController, decoration: const InputDecoration(labelText: 'Tanggal')),
        const SizedBox(height: 16),
        TextField(controller: _areaController, decoration: const InputDecoration(labelText: 'Area')),
        const SizedBox(height: 16),
        TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Lokasi')),
        const SizedBox(height: 16),
        TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 5),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _htmType,
          decoration: const InputDecoration(
            labelText: 'HTM',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'free', child: Text('Gratis')),
            DropdownMenuItem(value: 'paid', child: Text('Berbayar')),
          ],
          onChanged: (value) {
            setState(() {
              _htmType = value!;
              if (_htmType == 'free') {
                _ticketPriceController.clear();
              }
            });
          },
        ),
        const SizedBox(height: 16),

        // 🔹 Muncul hanya jika HTM "berbayar"
        if (_htmType == 'paid')
          TextField(
            controller: _ticketPriceController,
            decoration: const InputDecoration(
              labelText: 'Harga Tiket (Rp)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text("Media Partner"),
          value: _isMedpart,
          onChanged: (value) => setState(() => _isMedpart = value),
        ),
      ],
    );
  }

  Widget _buildPosterManager() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _uploadImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Tambah Poster Baru'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() => _isReordering = !_isReordering),
              icon: Icon(_isReordering ? Icons.check : Icons.reorder),
              tooltip: _isReordering ? 'Selesai Reorder' : 'Ubah Urutan Poster',
              style: IconButton.styleFrom(
                backgroundColor: _isReordering ? Colors.green : null,
                foregroundColor: _isReordering ? Colors.white : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        const Text("Daftar Poster Saat Ini:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),

        // --- PERBAIKAN DIMULAI DI SINI ---
        // Mengganti placeholder dengan StreamBuilder yang sesungguhnya.
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('dfestkonser')
              .doc(_eventData!['id']) // Menggunakan _eventData yang sudah pasti ada
              .snapshots(),
          builder: (context, snapshot) {
            // Tampilkan loading indicator jika data belum siap
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Jika tidak ada data atau error
            if (!snapshot.hasData || snapshot.data?.data() == null) {
              return const Center(child: Text('Tidak dapat memuat poster.'));
            }

            // Ambil daftar poster dari dokumen
            final data = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> postersData = List.from(data['posters'] ?? []);

            // Handle legacy data: jika semua order = 1 atau tidak ada order, normalize berdasarkan index
            bool needsNormalization = postersData.isEmpty ||
                postersData.every((p) => p['order'] == null || p['order'] == 1);

            if (needsNormalization && postersData.isNotEmpty) {
              // Normalize order berdasarkan array index (mulai dari 0)
              for (int i = 0; i < postersData.length; i++) {
                postersData[i]['order'] = i;
              }
              // Auto-save normalized order
              _savePosterOrder(postersData);
            }

            if (postersData.isEmpty) {
              return const Center(child: Text('Belum ada poster.'));
            }

            if (_isReordering) {
              return _buildReorderablePosterList(postersData);
            }

            return _buildPosterListView(postersData);
          },
        ),
      ],
    );
  }

  Widget _buildPosterListView(List<dynamic> postersData) {
    // Sort berdasarkan order
    final sortedPosters = List<Map<String, dynamic>>.from(postersData.cast());
    sortedPosters.sort((a, b) {
      final orderA = (a['order'] as num?) ?? 0;
      final orderB = (b['order'] as num?) ?? 0;
      return orderA.compareTo(orderB);
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedPosters.length,
      itemBuilder: (context, i) {
        final poster = sortedPosters[i];
        final isMain = poster['is_main'] == true;
        final order = (poster['order'] as num?)?.toInt() ?? i;
        final title = poster['title']?.toString() ?? poster['path'].toString().split('/').last;
        final posterUrl = poster['url']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: GestureDetector(
              onTap: posterUrl.isNotEmpty ? () => _showPosterPreview(posterUrl, title) : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      posterUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  if (isMain)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, size: 12, color: Colors.white),
                      ),
                    ),
                  if (posterUrl.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.zoom_in, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            title: Text(
              '#${order + 1} - $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: isMain
                ? const Text('Poster Utama', style: TextStyle(color: Colors.amber))
                : Text('Order: ${order + 1}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  tooltip: 'Edit Nama Poster',
                  onPressed: () => _editPosterTitle(poster),
                ),
                IconButton(
                  icon: const Icon(Icons.star_outline, color: Colors.amber),
                  tooltip: 'Jadikan Poster Utama',
                  onPressed: () => setMainPoster(poster),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Hapus Poster',
                  onPressed: () => _deletePoster(poster),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReorderablePosterList(List<dynamic> postersData) {
    // Sort berdasarkan order untuk tampilan
    final sortedPosters = List<Map<String, dynamic>>.from(postersData.cast());
    sortedPosters.sort((a, b) {
      final orderA = (a['order'] as num?) ?? 0;
      final orderB = (b['order'] as num?) ?? 0;
      return orderA.compareTo(orderB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seret poster untuk mengubah urutan.',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedPosters.length,
          onReorder: (oldIndex, newIndex) => _onPosterReorder(sortedPosters, oldIndex, newIndex),
          itemBuilder: (_, i) {
            final poster = sortedPosters[i];
            final isMain = poster['is_main'] == true;
            final title = poster['title']?.toString() ?? poster['path'].toString().split('/').last;
            final posterUrl = poster['url']?.toString() ?? '';

            return Card(
              key: ValueKey(poster['path'] ?? i),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: posterUrl.isNotEmpty ? () => _showPosterPreview(posterUrl, title) : null,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              posterUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image, size: 20),
                              ),
                            ),
                          ),
                          if (posterUrl.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: const Icon(Icons.zoom_in, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMain ? Colors.amber : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isMain ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (isMain) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      const Text('Utama', style: TextStyle(fontSize: 12, color: Colors.amber)),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                      tooltip: 'Edit Nama Poster',
                      onPressed: () => _editPosterTitle(poster),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 20),
                      tooltip: 'Pindah ke Atas',
                      onPressed: i > 0 ? () => _movePosterUp(sortedPosters, i) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 20),
                      tooltip: 'Pindah ke Bawah',
                      onPressed: i < sortedPosters.length - 1 ? () => _movePosterDown(sortedPosters, i) : null,
                    ),
                    IconButton(
                      icon: Icon(
                        isMain ? Icons.star : Icons.star_outline,
                        color: Colors.amber,
                      ),
                      tooltip: isMain ? 'Sudah Poster Utama' : 'Jadikan Poster Utama',
                      onPressed: () => setMainPoster(poster),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _isReordering = false),
            icon: const Icon(Icons.check),
            label: const Text('Selesai'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
            ),
          ),
        ),
      ],
    );
  }

  void _onPosterReorder(List<Map<String, dynamic>> sortedPosters, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = sortedPosters.removeAt(oldIndex);
    sortedPosters.insert(newIndex, item);

    // Update order berdasarkan posisi baru
    for (int i = 0; i < sortedPosters.length; i++) {
      sortedPosters[i]['order'] = i;
    }

    await _savePosterOrder(sortedPosters);
  }

  void _movePosterUp(List<Map<String, dynamic>> sortedPosters, int currentIndex) async {
    if (currentIndex > 0) {
      final item = sortedPosters.removeAt(currentIndex);
      sortedPosters.insert(currentIndex - 1, item);

      // Update order
      for (int i = 0; i < sortedPosters.length; i++) {
        sortedPosters[i]['order'] = i;
      }

      await _savePosterOrder(sortedPosters);
    }
  }

  void _movePosterDown(List<Map<String, dynamic>> sortedPosters, int currentIndex) async {
    if (currentIndex < sortedPosters.length - 1) {
      final item = sortedPosters.removeAt(currentIndex);
      sortedPosters.insert(currentIndex + 1, item);

      // Update order
      for (int i = 0; i < sortedPosters.length; i++) {
        sortedPosters[i]['order'] = i;
      }

      await _savePosterOrder(sortedPosters);
    }
  }

  Future<void> _savePosterOrder(List<dynamic> posters) async {
    try {
      final String documentId = _eventData!['id'];
      await FirebaseFirestore.instance
          .collection('dfestkonser')
          .doc(documentId)
          .update({
        'posters': posters,
      });

      // Refresh poster list
      loadPosters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Urutan poster berhasil disimpan!'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('Error saving poster order: $e');
    }
  }

  Future<void> _editPosterTitle(Map<String, dynamic> targetPoster) async {
    final controller = TextEditingController(
      text: targetPoster['title']?.toString() ?? targetPoster['path'].toString().split('/').last,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nama Poster'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nama Poster',
            hintText: 'Contoh: Poster Depan, Poster Belakang',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _savePosterTitle(targetPoster, result);
    }
  }

  Future<void> _savePosterTitle(Map<String, dynamic> targetPoster, String newTitle) async {
    try {
      final String documentId = _eventData!['id'];
      final doc = await FirebaseFirestore.instance
          .collection('dfestkonser')
          .doc(documentId)
          .get();

      if (doc.exists) {
        List<Map<String, dynamic>> posters = List.from(doc['posters']).cast<Map<String, dynamic>>();

        final targetPath = targetPoster['path']?.toString();
        final targetUrl = targetPoster['url']?.toString();

        // Update title poster yang dipilih
        for (var item in posters) {
          if ((targetPath != null && item['path'] == targetPath) ||
              (targetUrl != null && item['url'] == targetUrl)) {
            item['title'] = newTitle;
            break;
          }
        }

        await FirebaseFirestore.instance
            .collection('dfestkonser')
            .doc(documentId)
            .update({'posters': posters});

        // Refresh poster list
        loadPosters();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nama poster diubah menjadi "$newTitle"')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving poster title: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah nama poster')),
        );
      }
    }
  }

  void _showPosterPreview(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header dengan judul dan tombol close
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),
            // Gambar preview dengan zoom
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, color: Colors.white54, size: 64),
                            SizedBox(height: 8),
                            Text('Gagal memuat gambar', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return AspectRatio(
      aspectRatio: 1.0, // Sesuaikan dengan aspect ratio Carousel Anda
      child: Container(
        margin: const EdgeInsets.all(5.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: const BorderRadius.all(Radius.circular(5.0)),
        ),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade600,
            size: 50,
          ),
        ),
      ),
    );
  }

  // Di dalam kelas _EventDetailPageState

  Widget _buildTransitSection(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final transitProvider = context.watch<TransitProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- BAGIAN HEADER ---
          Row(
            children: [
              // Judul
              Expanded(
                child: Row(
                  children: [
                    const Text("📍 Info Rute Transportasi"),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        if (kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
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

              // Tombol Opsi (PopupMenuButton)
              PopupMenuButton<String>(
                icon: const Icon(Icons.tune),
                tooltip: "Opsi Rute",
                onSelected: (value) {
                  // Update state berdasarkan pilihan user
                  setState(() {
                    if (value == "toggle_bus") {
                      if (allowedTravelModes.contains("BUS")) {
                        allowedTravelModes.remove("BUS");
                      } else {
                        allowedTravelModes.add("BUS");
                      }
                    } else if (value == "less_walking") {
                      routingPreference = routingPreference == "LESS_WALKING" ? null : "LESS_WALKING";
                    } else if (value == "fewer_transfers") {
                      routingPreference = routingPreference == "FEWER_TRANSFERS" ? null : "FEWER_TRANSFERS";
                    }
                  });
                  // Jika lokasi pengguna sudah ada, langsung fetch ulang rute dengan opsi baru
                  if (locationProvider.userPosition != null) {
                    _fetchTransitRoutes();
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

              // Tombol Aksi Utama
              ElevatedButton(
                onPressed: locationProvider.isFetching
                    ? null
                    : () async {
                  final asked = localStorage.getItem('locationPermissionAsked') == 'true';

                  if (locationProvider.userPosition == null && !asked) {
                    await _confirmLocationPermission(); // tampilkan dialog
                  } else {
                    await locationProvider.fetchUserLocationWeb();
                    final userPos = locationProvider.userPosition;
                    if (userPos != null) {
                      await transitProvider.fetchTransitRoutes(
                        userPosition: userPos,
                        destinationLocation: _eventData!['location'],
                        allowedTravelModes: allowedTravelModes,
                        routingPreference: routingPreference,
                      );
                    } // langsung ambil lokasi
                  }
                },
                child: Text(locationProvider.userPosition == null ? "Cari Rute" : "Perbarui"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- BAGIAN KONTEN (HASIL RUTE) ---
          // Tampilan konten berdasarkan state
          if (transitProvider.isFetching)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ))
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
                      leading: step["type"] == "WALK"
                          ? const Icon(Icons.directions_walk, color: Colors.orange)
                          : getAgencyIcon(step["agency"]),
                      title: Text(
                        step["type"] == "WALK"
                            ? (step["title"] ?? "Jalan kaki")
                            : (step["navigationInstruction"] != null
                                ? formatNavigationInstruction(step["navigationInstruction"], step["agency"], step["codeLine"])
                                : "Instruksi tidak tersedia"),
                      ),
                      subtitle: Text(
                        step["type"] == "WALK"
                            ? "Jarak: ${step["distance"] ?? '-'} • Estimasi: ${step["duration"] ?? '-'}"
                            : "${step["departure"]} (${step["departureTime"]}) → ${step["arrival"]} (${step["arrivalTime"]})\n"
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

  // Method untuk menampilkan dialog konfirmasi hapus
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text('Apakah Anda yakin ingin menghapus festival ini? Aksi ini tidak dapat dibatalkan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteEventFromFirestore(context);
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
