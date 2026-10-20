import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/tanya_maps_models.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/event_provider.dart';
import '../../../provider/location_provider.dart';
import '../../../services/firebase_storage.dart';
import '../../../services/tanya_maps_service.dart';

class TanyaMapsPage extends StatefulWidget {
  const TanyaMapsPage({super.key});

  @override
  State<TanyaMapsPage> createState() => _TanyaMapsPageState();
}

class _TanyaMapsPageState extends State<TanyaMapsPage> {
  GoogleMapController? _mapController;
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  final List<TanyaMapsMessage> _messages = [];
  List<TanyaMapsEvent> _currentRecommendedEvents = [];
  TanyaMapsEvent? _selectedEvent;
  bool _isLoading = false;
  bool _isSheetExpanded = false;
  bool _showCards = true;
  ScrollController? _activeSheetScrollController;

  // Default coordinate: Monas / Pusat Jakarta
  static const LatLng _defaultLocation = LatLng(-6.175392, 106.827153);
  LatLng _currentMapCenter = _defaultLocation;

  final Set<Marker> _markers = {};

  final List<String> _quickPrompts = [
    'Event cosplay gratis weekend ini',
    'Event jejepangan dekat stasiun KRL',
    'Festival matsuri di Jakarta Selatan',
    'Event terdekat dari lokasi saya',
    'Konser musik & gigs di Jabodetabek',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fitur Tanya Wargabut saat ini masih dalam tahap pengembangan (khusus Admin).'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/jeventku');
      }
    });
    _sheetController.addListener(_onSheetSizeChanged);
    _initInitialState();
  }

  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    final isExp = _sheetController.size >= 0.65;
    if (isExp != _isSheetExpanded) {
      setState(() {
        _isSheetExpanded = isExp;
      });
    }
  }

  void _toggleSheetExpansion() {
    if (!_sheetController.isAttached) return;
    final target = _isSheetExpanded ? 0.45 : 0.90;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _promptController.dispose();
    _chatScrollController.dispose();
    _sheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initInitialState() async {
    // Ambil posisi user dari LocationProvider jika ada
    final locProv = context.read<LocationProvider>();
    if (locProv.userPosition != null) {
      _currentMapCenter = LatLng(
        locProv.userPosition!.latitude,
        locProv.userPosition!.longitude,
      );
    }

    // Pesan sambutan pertama
    _messages.add(
      TanyaMapsMessage(
        id: const Uuid().v4(),
        isUser: false,
        text: 'Halo! Aku **WGuide - Tanya Wargabut** ✨\n'
            'Tanyakan apa saja seputar event jejepangan, cosplay, matsuri, info konser artis Jepang, tiket, maupun rute di peta & internet!\n\n'
            'Contoh: *"Ada event cosplay gratis apa weekend ini?"* atau *"Guest star Comifuro 23 siapa?"*',
        recommendedEvents: [],
        timestamp: DateTime.now(),
      ),
    );

    // Ambil event terdekat sebagai preview awal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialMarkers();
    });
  }

  void _loadInitialMarkers() {
    final eventProv = context.read<EventProvider>();
    final locProv = context.read<LocationProvider>();
    final pos = locProv.userPosition;

    if (eventProv.allEvents.isNotEmpty) {
      final initialEvents = eventProv.allEvents
          .where((e) => e['lat'] != null && e['lng'] != null)
          .take(5)
          .map((e) {
        double? dist;
        if (pos != null) {
          final lat = (e['lat'] as num).toDouble();
          final lng = (e['lng'] as num).toDouble();
          dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng) / 1000;
        }
        return TanyaMapsEvent.fromFirestore(e['id'] ?? '', e, distance: dist);
      }).toList();

      setState(() {
        _currentRecommendedEvents = initialEvents;
        _updateMapMarkers(initialEvents);
      });
    }
  }

  void _updateMapMarkers(List<TanyaMapsEvent> events) {
    final Set<Marker> newMarkers = {};
    final locProv = context.read<LocationProvider>();

    // 1. Marker lokasi user jika ada
    if (locProv.userPosition != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            locProv.userPosition!.latitude,
            locProv.userPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(
            title: '📍 Lokasi Kamu',
            snippet: 'Posisi saat ini',
          ),
        ),
      );
    }

    // 2. Marker event-event rekomendasi
    for (int i = 0; i < events.length; i++) {
      final ev = events[i];
      if (ev.latitude == 0.0 || ev.longitude == 0.0) continue;

      final isSelected = _selectedEvent?.id == ev.id;

      newMarkers.add(
        Marker(
          markerId: MarkerId(ev.id),
          position: LatLng(ev.latitude, ev.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueRose,
          ),
          infoWindow: InfoWindow(
            title: ev.title,
            snippet: '${ev.date} • ${ev.htm}',
            onTap: () => _onSelectEvent(ev),
          ),
          onTap: () => _onSelectEvent(ev),
        ),
      );
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });

    _zoomToFitMarkers(events);
  }

  void _zoomToFitMarkers(List<TanyaMapsEvent> events) {
    if (_mapController == null || events.isEmpty) return;

    final validEvents = events.where((e) => e.latitude != 0.0 && e.longitude != 0.0).toList();
    if (validEvents.isEmpty) return;

    if (validEvents.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(validEvents.first.latitude, validEvents.first.longitude),
          14.5,
        ),
      );
      return;
    }

    double minLat = validEvents.first.latitude;
    double maxLat = validEvents.first.latitude;
    double minLng = validEvents.first.longitude;
    double maxLng = validEvents.first.longitude;

    for (final e in validEvents) {
      minLat = min(minLat, e.latitude);
      maxLat = max(maxLat, e.latitude);
      minLng = min(minLng, e.longitude);
      maxLng = max(maxLng, e.longitude);
    }

    // Tambahkan posisi user ke bounds jika ada
    final pos = context.read<LocationProvider>().userPosition;
    if (pos != null) {
      minLat = min(minLat, pos.latitude);
      maxLat = max(maxLat, pos.latitude);
      minLng = min(minLng, pos.longitude);
      maxLng = max(maxLng, pos.longitude);
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60.0,
      ),
    );
  }

  void _onSelectEvent(TanyaMapsEvent event) {
    setState(() {
      _selectedEvent = event;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(event.latitude, event.longitude),
        15.0,
      ),
    );

    // Buka sheet ke ukuran medium agar card terlihat jelas
    if (_sheetController.isAttached && _sheetController.size < 0.4) {
      _sheetController.animateTo(
        0.45,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendPrompt([String? presetText]) async {
    final text = presetText ?? _promptController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _promptController.clear();
    FocusScope.of(context).unfocus();

    final userMsg = TanyaMapsMessage(
      id: const Uuid().v4(),
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    // Auto-perluas sheet agar pengguna langsung dapat membaca respons chat
    if (_sheetController.isAttached && _sheetController.size < 0.65) {
      _sheetController.animateTo(
        0.85,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    _scrollToBottom();

    final locProv = context.read<LocationProvider>();
    final eventProv = context.read<EventProvider>();

    try {
      final aiResponse = await TanyaMapsService.queryAskMaps(
        userPrompt: text,
        userLat: locProv.userPosition?.latitude,
        userLng: locProv.userPosition?.longitude,
        cachedEvents: eventProv.allEvents,
      );

      if (mounted) {
        setState(() {
          _messages.add(aiResponse);
          if (aiResponse.recommendedEvents.isNotEmpty) {
            _currentRecommendedEvents = aiResponse.recommendedEvents;
            _selectedEvent = aiResponse.recommendedEvents.first;
            _updateMapMarkers(aiResponse.recommendedEvents);
          }
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            TanyaMapsMessage(
              id: const Uuid().v4(),
              isUser: false,
              text: 'Terjadi kendala saat memproses: $e\nSilakan coba pertanyaan lain!',
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sc = _activeSheetScrollController ?? _chatScrollController;
      if (sc.hasClients) {
        sc.animateTo(
          sc.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showApiKeyDialog() async {
    final currentKey = await TanyaMapsService.getActiveApiKey();
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.amber),
            SizedBox(width: 8),
            Text('Pengaturan Gemini API'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gunakan Google Gemini Flash gratis dari Google AI Studio tanpa khawatir biaya!',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dapatkan gratis di: aistudio.google.com/app/apikey',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final newKey = controller.text.trim();
              await TanyaMapsService.setCustomApiKey(newKey);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key berhasil disimpan!')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locProv = context.watch<LocationProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fullscreen Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentMapCenter,
              zoom: 12.0,
            ),
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              if (_currentRecommendedEvents.isNotEmpty) {
                _zoomToFitMarkers(_currentRecommendedEvents);
              }
            },
            markers: _markers,
            myLocationEnabled: locProv.userPosition != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Floating Top Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/wargabut_mascot_chibi.png',
                            width: 28,
                            height: 28,
                            errorBuilder: (_, __, ___) => const Icon(Icons.explore, color: Colors.blue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Tanya Wargabut',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.amber, width: 0.8),
                                      ),
                                      child: const Text(
                                        'Admin Dev',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  locProv.userPosition != null ? '📍 Lokasi GPS Aktif' : '📍 Jabodetabek',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Pengaturan API',
                      onPressed: _showApiKeyDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Map Floating Action Buttons (Fit Markers & GPS)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.50,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_fit_markers',
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.primary,
                  onPressed: () => _zoomToFitMarkers(_currentRecommendedEvents),
                  tooltip: 'Tampilkan semua pin event',
                  child: const Icon(Icons.zoom_out_map),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_my_loc',
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.primary,
                  onPressed: () async {
                    if (locProv.userPosition == null) {
                      await locProv.fetchUserLocationWeb();
                    }
                    if (locProv.userPosition != null && _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(
                            locProv.userPosition!.latitude,
                            locProv.userPosition!.longitude,
                          ),
                          14.0,
                        ),
                      );
                    }
                  },
                  tooltip: 'Ke lokasi saya',
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // 4. Draggable Bottom Sheet (Ask Maps Chat & Event Cards)
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.52,
            minChildSize: 0.20,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.20, 0.52, 0.92],
            builder: (context, scrollController) {
              _activeSheetScrollController = scrollController;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool canShowCarousel = constraints.maxHeight >= 210 &&
                      _currentRecommendedEvents.isNotEmpty &&
                      _showCards;

                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Interactive Header Bar (Tap or Drag anywhere to expand/collapse)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleSheetExpansion,
                          onVerticalDragUpdate: (details) {
                            if (!_sheetController.isAttached) return;
                            final screenHeight = MediaQuery.of(context).size.height;
                            if (screenHeight <= 0) return;
                            final currentSize = _sheetController.size;
                            final newSize = (currentSize - (details.primaryDelta! / screenHeight)).clamp(0.20, 0.92);
                            _sheetController.jumpTo(newSize);
                          },
                          onVerticalDragEnd: (details) {
                            if (!_sheetController.isAttached) return;
                            final current = _sheetController.size;
                            if (current > 0.65) {
                              _sheetController.animateTo(0.92, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                            } else if (current > 0.35) {
                              _sheetController.animateTo(0.52, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                            } else {
                              _sheetController.animateTo(0.20, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Handle Bar Pill
                                Center(
                                  child: Container(
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outlineVariant,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Header Title Row with Expand / Collapse Button
                                Row(
                                  children: [
                                    Icon(
                                      _currentRecommendedEvents.isNotEmpty ? Icons.map_outlined : Icons.chat_bubble_outline,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _currentRecommendedEvents.isNotEmpty
                                            ? '${_currentRecommendedEvents.length} Event di Peta'
                                            : 'Tanya Wargabut',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (_currentRecommendedEvents.isNotEmpty)
                                      IconButton(
                                        icon: Icon(
                                          _showCards ? Icons.view_carousel : Icons.view_carousel_outlined,
                                          size: 18,
                                          color: _showCards ? theme.colorScheme.primary : theme.colorScheme.outline,
                                        ),
                                        tooltip: _showCards ? 'Sembunyikan Kartu' : 'Tampilkan Kartu',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(() {
                                            _showCards = !_showCards;
                                          });
                                        },
                                      ),
                                    TextButton.icon(
                                      onPressed: _toggleSheetExpansion,
                                      icon: Icon(
                                        _isSheetExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                        size: 20,
                                      ),
                                      label: Text(
                                        _isSheetExpanded ? 'Kecilkan' : 'Perluas Chat',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Event Carousel (Hanya jika ada ruang cukup dan kartu diaktifkan)
                        if (canShowCarousel)
                          _buildEventCarousel(theme),

                        // Scrollable Chat & Content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          // Quick Suggestion Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _quickPrompts.map((prompt) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                                  child: ActionChip(
                                    avatar: const Icon(Icons.auto_awesome, size: 14),
                                    label: Text(
                                      prompt,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => _handleSendPrompt(prompt),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const Divider(height: 16),

                          // Chat Dialogue
                          ..._messages.map((msg) => _buildChatBubble(msg, theme)),

                          if (_isLoading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Mencari event terbaik di peta...',
                                    style: TextStyle(
                                      color: theme.colorScheme.outline,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Input Bar
                    _buildInputBar(theme),
                  ],
                ),
              );
            },
          );
        },
      ),
    ],
  ),
);
}

  Widget _buildEventCarousel(ThemeData theme) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _currentRecommendedEvents.length,
        itemBuilder: (context, index) {
          final event = _currentRecommendedEvents[index];
          final isSelected = _selectedEvent?.id == event.id;

          return GestureDetector(
            onTap: () => _onSelectEvent(event),
            child: Container(
              width: 260,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Poster Thumbnail
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                    child: Container(
                      width: 74,
                      height: double.infinity,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: _buildPosterThumbnail(event, theme),
                    ),
                  ),

                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 7, 9, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.locationName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.2,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: event.htm.toLowerCase().contains('gratis')
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  event.htm,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: event.htm.toLowerCase().contains('gratis')
                                        ? Colors.green[800]
                                        : Colors.amber[900],
                                  ),
                                ),
                              ),
                              if (event.distanceKm != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '• ${event.distanceKm!.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                              const Spacer(),
                              InkWell(
                                onTap: () => context.push('/jeventku/${event.id}'),
                                child: Text(
                                  'Detail >',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPosterThumbnail(TanyaMapsEvent event, ThemeData theme) {
    if (event.posterUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: event.posterUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
          ),
        ),
        errorWidget: (_, __, ___) => _buildStoragePosterFallback(event),
      );
    }
    return _buildStoragePosterFallback(event);
  }

  Widget _buildStoragePosterFallback(TanyaMapsEvent event) {
    return FutureBuilder<String?>(
      future: StorageService().getImageUrl('jfestchart', event.title),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: snapshot.data!,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => const Center(child: Icon(Icons.event, size: 28)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return const Center(child: Icon(Icons.event, size: 28));
      },
    );
  }

  Widget _buildChatBubble(TanyaMapsMessage message, ThemeData theme) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/wargabut_mascot_chibi.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.explore, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    )
                  : GptMarkdown(
                      message.text,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _promptController,
                  style: const TextStyle(fontSize: 13),
                  onTap: () {
                    if (_sheetController.isAttached && _sheetController.size < 0.6) {
                      _sheetController.animateTo(
                        0.85,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Tanya apa saja ke Wargabut...',
                    hintStyle: TextStyle(fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _handleSendPrompt(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isLoading ? null : () => _handleSendPrompt(),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
