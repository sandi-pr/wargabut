import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/models/community_event_model.dart';
import 'package:wargabut/app/models/community_model.dart';
import 'package:wargabut/app/provider/auth_provider.dart';
import 'package:wargabut/app/provider/community_provider.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/provider/profile_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';

// IMPORT SHARED
import '../../components/community/add_community_event_dialog.dart';
import '../../components/companion/event_companion_section.dart';
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
  List<CommunityEventAttendanceModel> _attendingCommunities = [];
  bool _isLoadingCommunities = false;
  List<CommunityModel> _userManagedCommunities = [];

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

    // 5. Load Komunitas yang Hadir & Cek Komunitas User
    _loadAttendingCommunities();
    _checkUserManagedCommunities();
  }

  Future<void> _loadAttendingCommunities() async {
    if (!mounted) return;
    setState(() => _isLoadingCommunities = true);
    try {
      final list = await context
          .read<CommunityProvider>()
          .fetchEventAttendingCommunities(widget.eventId);
      if (mounted) {
        setState(() {
          _attendingCommunities = list;
          _isLoadingCommunities = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attending communities: $e');
      if (mounted) setState(() => _isLoadingCommunities = false);
    }
  }

  Future<void> _checkUserManagedCommunities() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final list = await context
          .read<CommunityProvider>()
          .getCommunitiesManagedByUser(auth.user!.uid);
      if (mounted) {
        setState(() {
          _userManagedCommunities = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading user managed communities: $e');
    }
  }

  void _openAddCommunityDialog() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu.')),
      );
      return;
    }

    if (_userManagedCommunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hanya Founder atau Admin komunitas yang dapat mendaftarkan kehadiran komunitas.',
          ),
        ),
      );
      return;
    }

    String? posterUrl;
    if (_posters.isNotEmpty && _posters.first['url'] != null) {
      posterUrl = _posters.first['url'];
    } else if (_eventData?['poster'] != null) {
      posterUrl = _eventData!['poster'];
    }

    final eventMap = {
      'id': _eventData?['id'] ?? widget.eventId,
      'event_name': _eventData?['event_name'] ?? _eventData?['name'] ?? '',
      'date': _eventData?['date'] ?? '',
      'location': _eventData?['location'] ?? '',
      'area': _eventData?['area'] ?? '',
      'poster': posterUrl ?? '',
    };

    final result = await AddCommunityEventDialog.show(
      context,
      preselectedEvent: eventMap,
    );

    if (result == true) {
      _loadAttendingCommunities();
    }
  }

  Future<void> _confirmRemoveCommunity(CommunityEventAttendanceModel item) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Kehadiran?'),
        content: Text(
          'Hapus kehadiran komunitas "${item.communityName}" dari event ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final success = await context.read<CommunityProvider>().removeEventFromCommunity(
        communityId: item.communityId,
        eventId: item.eventId,
        currentUid: auth.user!.uid,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kehadiran ${item.communityName} berhasil dibatalkan.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadAttendingCommunities();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membatalkan kehadiran komunitas.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
      List<dynamic> rawPosters = List.from(_eventData!['posters'] ?? []);

      // 3b. Handle legacy data & sort by order
      if (rawPosters.isNotEmpty) {
        // Normalize order jika perlu
        bool needsNormalization = rawPosters.every((p) => p['order'] == null || p['order'] == 1);
        if (needsNormalization) {
          for (int i = 0; i < rawPosters.length; i++) {
            rawPosters[i]['order'] = i;
          }
          // Auto-save normalized order
          try {
            await FirebaseFirestore.instance
                .collection(collectionName)
                .doc(_eventData!['id'])
                .update({'posters': rawPosters});
          } catch (e) {
            debugPrint('Error auto-saving normalized order: $e');
          }
        }

        // Sort berdasarkan order
        rawPosters.sort((a, b) {
          final orderA = (a['order'] as num?) ?? 0;
          final orderB = (b['order'] as num?) ?? 0;
          return orderA.compareTo(orderB);
        });
      }

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
    // Sort posters by order before saving (handle legacy data)
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(_eventData!['id'])
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('posters')) {
          List<dynamic> posters = List.from(data['posters']);

          if (posters.isNotEmpty) {
            // Normalize order jika perlu (handle legacy data)
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

            // Update posters yang sudah diurutkan
            await FirebaseFirestore.instance
                .collection(collectionName)
                .doc(_eventData!['id'])
                .update({'posters': posters});
          }
        }
      }
    } catch (e) {
      debugPrint('Error sorting posters: $e');
    }

    // Logika Update Firestore KHUSUS Event
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

  Widget _buildAttendingCommunitiesSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasManagedCommunities = _userManagedCommunities.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Komunitas Hadir',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_attendingCommunities.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasManagedCommunities)
                  FilledButton.tonalIcon(
                    onPressed: _openAddCommunityDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Daftarkan', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Content
            if (_isLoadingCommunities)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_attendingCommunities.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.diversity_3_outlined, size: 36, color: theme.hintColor),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada komunitas terdaftar hadir',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Founder atau Admin komunitas dapat mendaftarkan komunitasnya untuk menghadiri event ini.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor.withValues(alpha: 0.8),
                      ),
                    ),
                    if (hasManagedCommunities) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openAddCommunityDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Daftarkan Komunitas Anda'),
                      ),
                    ],
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendingCommunities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _attendingCommunities[index];
                  final canManage = _userManagedCommunities.any((c) => c.id == item.communityId);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/komunitas/${item.communityId}'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Community Logo
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: colorScheme.primaryContainer,
                            backgroundImage: item.communityLogo.isNotEmpty
                                ? NetworkImage(item.communityLogo)
                                : null,
                            child: item.communityLogo.isEmpty
                                ? Text(
                                    item.communityName.isNotEmpty
                                        ? item.communityName[0].toUpperCase()
                                        : 'K',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Community Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.communityName,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isCommunityVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified,
                                        color: Colors.blue,
                                        size: 14,
                                      ),
                                    ],
                                  ],
                                ),
                                if (item.communityCity.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 12,
                                        color: theme.hintColor,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        item.communityCity,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.hintColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (item.notes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.campaign_outlined,
                                          size: 12,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            item.notes,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Actions
                          if (canManage)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              tooltip: 'Batalkan Kehadiran Komunitas',
                              onPressed: () => _confirmRemoveCommunity(item),
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.hintColor.withValues(alpha: 0.5),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalAttendanceCard() {
    final profileProvider = context.watch<ProfileProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.isLoggedIn;
    final isAttending = profileProvider.isAttendingEvent(widget.eventId);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAttending
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAttending
              ? colorScheme.primary.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAttending ? Icons.check_circle_rounded : Icons.event_available_outlined,
            color: isAttending ? colorScheme.primary : theme.hintColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAttending ? 'Anda Berencana Hadir di Event Ini' : 'Berencana Hadir ke Event Ini?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAttending ? colorScheme.primary : null,
                  ),
                ),
                Text(
                  isAttending
                      ? 'Event ini tersimpan di Member ID Card Anda.'
                      : 'Simpan ke Member ID Card agar teman & komunitas tahu agenda Anda.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: isAttending ? Colors.red.withValues(alpha: 0.1) : null,
              foregroundColor: isAttending ? Colors.red : null,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              if (!isLoggedIn) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Silakan login terlebih dahulu untuk menyimpan agenda event.'),
                    action: SnackBarAction(
                      label: 'Login',
                      onPressed: () => context.push('/login'),
                    ),
                  ),
                );
                return;
              }

              final eventMap = {
                'id': widget.eventId,
                'event_name': _eventData?['event_name'] ?? _eventData?['name'] ?? 'Event',
                'date': _eventData?['date'] ?? '',
                'location': _eventData?['location'] ?? '',
                'poster': _posters.isNotEmpty ? _posters.first['url'] : (_eventData?['poster'] ?? ''),
              };

              final messenger = ScaffoldMessenger.of(context);
              final success = await profileProvider.toggleEventAttendance(eventMap);
              if (mounted && success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(!isAttending
                        ? 'Event berhasil ditambahkan ke Member ID Card Anda!'
                        : 'Kehadiran event berhasil dihapus dari Member ID Card Anda.'),
                    backgroundColor: !isAttending ? Colors.green : Colors.orange,
                  ),
                );
              }
            },
            child: Text(isAttending ? 'Batal Hadir' : 'Saya Akan Hadir'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final postersList = _posters;

    final content = Column(
      children: [
        DetailInfoCard(data: _eventData!),
        const SizedBox(height: 16),
        _buildPersonalAttendanceCard(),
        const Divider(height: 32),
        _buildAttendingCommunitiesSection(),
        const Divider(height: 32),

        // --- SEKSI MANDIRI CARI TEMAN BARENGAN ---
        EventCompanionSection(
          eventId: widget.eventId,
          eventName: _eventData?['event_name'] ?? _eventData?['name'] ?? 'Event',
        ),
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
