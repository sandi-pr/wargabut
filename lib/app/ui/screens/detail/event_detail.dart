import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';

// IMPORT SHARED
import '../../components/shared/detail/detail_logic_mixin.dart';
import '../../components/shared/detail/shared_detail_components.dart';
import '../../components/shared/detail/shared_transit_section.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic>? data;
  final String eventId;
  const EventDetailPage({super.key, required this.eventId, this.data});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage>
    with DetailLogicMixin {
  // CONFIGURATION
  final String collectionName = 'jfestchart';
  final String routePrefix = '/jeventku';

  // STATE LOKAL
  Map<String, dynamic>? _eventData;
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _editMode = false;
  List<Map<String, String>> _posters = [];
  bool _postersAreLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. Load Data
    if (widget.data != null) {
      _eventData = widget.data;
    } else {
      final doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.eventId)
          .get();
      if (doc.exists) _eventData = doc.data()!..['id'] = doc.id;
    }

    // 2. Load ke Controller (via Mixin)
    if (_eventData != null) loadInitialData(_eventData!);

    // 3. Cek Admin
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
      _isLoading = false;
    });

    // 4. Load Poster
    _loadPosters();
  }

  Future<void> _loadPosters() async {
    // 1. Cek apakah ada data event
    if (_eventData == null) return;

    // 2. Mulai loading
    if (mounted) {
      setState(() {
        _postersAreLoading = true;
      });
    }

    try {
      // 3. Ambil array 'posters' dari data event yang sudah ada (tidak perlu fetch ulang ke Firestore)
      List<dynamic> rawPosters = _eventData!['posters'] ?? [];

      // 4. Proses setiap poster secara paralel menggunakan Future.wait
      List<Map<String, String>> loadedPosters = await Future.wait(
        rawPosters.map((poster) async {
          String path = poster["path"]?.toString() ?? "";
          String title = poster["title"]?.toString() ?? "Poster";

          if (path.isEmpty) return {"url": ""};

          try {
            // Minta URL Download ke Firebase Storage
            final ref = FirebaseStorage.instance.ref().child(path);
            String url = await ref.getDownloadURL();
            return {"url": url, "title": title};
          } catch (e) {
            if (kDebugMode) {
              print("Gagal load poster: $path");
            }
            return {"url": ""}; // Return url kosong jika gagal
          }
        }),
      );

      // 5. Filter hasil yang URL-nya kosong (gagal load)
      loadedPosters.removeWhere((p) => p['url'] == null || p['url']!.isEmpty);

      // 6. Simpan ke state
      if (mounted) {
        setState(() {
          _posters = loadedPosters;
          _postersAreLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading posters: $e");
      }
      if (mounted) {
        setState(() => _postersAreLoading = false);
      }
    }
  }

  // --- ACTIONS ---
  Future<void> _saveChanges() async {
    // Logika Update Firestore KHUSUS Event
    // Panggil eventProvider.fetchData()
    // ...
    // Ini tetap di sini karena dependensi ke EventProvider
    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(_eventData!['id'])
        .update({
      'event_name': eventNameController.text,
      'date': dateEventController.text,
      'area': areaController.text,
      'location': locationController.text,
      'desc': descriptionController.text,
      'ticket_price': htmType == 'free' ? 'Gratis' : ticketPriceController.text,
      'is_medpart': isMedpart
    });
    if (mounted) {
      context.read<EventProvider>().fetchData(forceRefresh: true);
      setState(() => _editMode = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Event disimpan")));
    }
  }

  Future<void> _deleteEvent() async {
    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(_eventData!['id'])
        .delete();
    if (mounted) {
      context.read<EventProvider>().fetchData(forceRefresh: true);
      context.go(routePrefix);
    }
  }

  Future<void> _uploadImages() async {
    final picker = ImagePicker();
    // 1. Pilih Gambar dari Galeri
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      // Tampilkan loading jika perlu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sedang mengupload gambar...')),
        );
      }

      // 2. Upload ke Firebase Storage / MinIO
      // 'collectionName' diambil dari variabel class ('jfestchart' atau 'dfestkonser')
      final newPosters = await StorageService()
          .uploadImages(images, collectionName, _eventData!['event_name']);

      // 3. Simpan Referensi ke Firestore
      await _addPostersToFirestore(newPosters);
    }
  }

  // Fungsi helper untuk update data array poster di Firestore
  Future<void> _addPostersToFirestore(
      List<Map<String, dynamic>> newPosters) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(collectionName)
          .doc(_eventData!['id']);
      final docSnapshot = await docRef.get();

      List<dynamic> existingPosters = [];

      // Ambil data poster lama jika ada
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('posters')) {
          existingPosters = List.from(data['posters']);
        }
      }

      // Logika Main Poster:
      // Jika di poster lama belum ada yang 'is_main: true',
      // maka set poster baru pertama sebagai utama.
      bool hasMain = existingPosters.any((p) => p['is_main'] == true);
      if (!hasMain && newPosters.isNotEmpty) {
        newPosters[0]['is_main'] = true;
      }

      // Gabungkan poster lama dan baru
      existingPosters.addAll(newPosters);

      // Update Firestore
      await docRef.update({
        'posters': existingPosters,
        'is_postered': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster berhasil diupload!')),
        );
        // Refresh tampilan poster di UI
        _loadPosters();
      }
    } catch (e) {
      if (kDebugMode) print('Error updating posters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload poster: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_eventData == null) {
      return const Scaffold(body: Center(child: Text("Data tidak ditemukan")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editMode ? "Edit Event" : _eventData!['event_name']),
        leading: _editMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _editMode = false))
            : Navigator.canPop(context)
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go(routePrefix),
                  ),
        actions: [
          if (_editMode)
            TextButton(onPressed: _saveChanges, child: const Text("SIMPAN"))
          else ...[
            IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => shareEvent(
                    title: _eventData!['event_name'],
                    id: _eventData!['id'],
                    pathPrefix: routePrefix)),
            if (_isAdmin)
              PopupMenuButton(
                  onSelected: (v) {
                    if (v == 'edit') setState(() => _editMode = true);
                    if (v == 'del') _deleteEvent();
                  },
                  itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text("Edit")),
                        const PopupMenuItem(
                            value: 'del',
                            child: Text("Hapus",
                                style: TextStyle(color: Colors.red))),
                      ])
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _editMode ? _buildEditMode() : _buildViewMode(),
      ),
    );
  }

  Widget _buildViewMode() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final postersList = _posters;

    final content = Column(
      children: [
        DetailInfoCard(data: _eventData!),
        const Divider(height: 32),

        // --- MEMANGGIL SHARED TRANSIT SECTION ---
        SharedTransitSection(
          destinationName: _eventData!['location'],
          allowedTravelModes: allowedTravelModes, // Dari Mixin
          routingPreference: routingPreference, // Dari Mixin

          // Logic Update Filter (disimpan ke state Mixin)
          onOptionChanged: (modes, pref) {
            setState(() {
              allowedTravelModes = modes;
              routingPreference = pref;
            });
          },

          // Logic Tombol Cari (Panggil fungsi di Mixin)
          onSearchRoute: () async {
            // Panggil fungsi confirmLocationPermission dari Mixin
            // Fungsi ini akan handle permission -> fetch location -> fetch route
            await confirmLocationPermission(_eventData!['location']);
          },
        ),
        // ----------------------------------------
      ],
    );

    if (isDesktop) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: DetailImageCarousel(
                posters: postersList, isLoading: _postersAreLoading)),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: content)
      ]);
    }
    return Column(children: [
      DetailImageCarousel(posters: postersList, isLoading: _postersAreLoading),
      const SizedBox(height: 16),
      content
    ]);
  }

  Widget _buildEditMode() {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final formWidget = DetailEditForm(
      nameCtrl: eventNameController,
      dateCtrl: dateEventController,
      areaCtrl: areaController,
      locCtrl: locationController,
      descCtrl: descriptionController,
      priceCtrl: ticketPriceController,
      htmType: htmType,
      isMedpart: isMedpart,
      onHtmChanged: (v) => setState(() => htmType = v),
      onMedpartChanged: (v) => setState(() => isMedpart = v),
    );

    final posterWidget = DetailPosterManager(
        collectionName: collectionName,
        docId: _eventData!['id'],
        onAddImage: _uploadImages
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: formWidget,
            ),
          ),
          const SizedBox(width: 24.0),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  posterWidget,
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          formWidget,
          const Divider(height: 32, thickness: 1),
          posterWidget,
        ],
      );
    }
  }
}
