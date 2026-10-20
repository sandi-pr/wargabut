import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class StorageCleanupPage extends StatefulWidget {
  const StorageCleanupPage({super.key});

  @override
  State<StorageCleanupPage> createState() => _StorageCleanupPageState();
}

class _StorageCleanupPageState extends State<StorageCleanupPage> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String _loadingStatus = 'Memuat...';

  // Storage stats
  int _totalImages = 0;
  int _totalSizeBytes = 0;
  int _oldEventsStorageSize = 0;

  // Analysis results
  List<Map<String, dynamic>> _orphanedImages = [];
  List<Map<String, dynamic>> _duplicateImages = [];
  List<Map<String, dynamic>> _oldEvents = [];

  // Firestore references
  Set<String> _referencedPaths = {};

  // Selection for bulk delete
  final Set<String> _selectedOrphans = {};
  final Set<String> _selectedDuplicates = {};
  final Set<String> _selectedOldEvents = {};

  bool _isDeleting = false;

  // Filter for old events
  String _oldEventsFilter = 'all'; // 'all', '3months', '6months', '1year'

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isAdmin = prefs.getBool('isAdmin') ?? false;

    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akses ditolak. Hanya admin yang bisa mengakses halaman ini.')),
        );
        context.go('/jeventku');
      }
      return;
    }

    setState(() => _isAdmin = true);
    await _analyzeStorage();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _analyzeStorage() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Mengumpulkan referensi Firestore...';
    });

    try {
      // 1. Collect all poster paths from Firestore
      await _collectFirestoreReferences();

      setState(() => _loadingStatus = 'Membaca daftar file Storage...');

      // 2. List all files in storage
      final storageFiles = await _listStorageFiles();

      setState(() {
        _loadingStatus = 'Menghitung storage...';
      });

      // 3. Calculate stats
      int totalSize = 0;
      for (var file in storageFiles) {
        totalSize += (file['sizeBytes'] as int? ?? 0);
      }

      setState(() => _loadingStatus = 'Mencari orphaned images...');

      // 4. Find orphaned images
      _orphanedImages = storageFiles.where((file) {
        final path = file['path'] as String;
        return !_referencedPaths.contains(path);
      }).toList();

      setState(() => _loadingStatus = 'Mencari duplicate images...');

      // 5. Find duplicate images (same name, different paths)
      _findDuplicates(storageFiles);

      setState(() => _loadingStatus = 'Mencari event lama...');

      // 6. Find old events
      await _findOldEvents();

      // Calculate old events storage size
      int oldEventsSize = 0;
      for (var event in _oldEvents) {
        final posters = event['posters'] as List?;
        if (posters != null) {
          oldEventsSize += _calculatePostersSize(posters, storageFiles);
        }
      }

      setState(() {
        _totalImages = storageFiles.length;
        _totalSizeBytes = totalSize;
        _oldEventsStorageSize = oldEventsSize;
        _isLoading = false;
        _loadingStatus = 'Selesai';
      });

    } catch (e) {
      debugPrint('Error analyzing storage: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menganalisis storage: $e')),
        );
      }
    }
  }

  Future<void> _collectFirestoreReferences() async {
    _referencedPaths.clear();

    final collections = ['jfestchart', 'dfestkonser', 'aninews'];

    for (var collectionName in collections) {
      try {
        final docs = await FirebaseFirestore.instance
            .collection(collectionName)
            .get();

        for (var doc in docs.docs) {
          final data = doc.data();
          if (data.containsKey('posters')) {
            final posters = data['posters'] as List?;
            if (posters != null) {
              for (var poster in posters) {
                if (poster is Map && poster['path'] != null) {
                  _referencedPaths.add(poster['path'].toString());
                }
              }
            }
          }

          // Check for single image field
          if (data.containsKey('poster_path') && data['poster_path'] != null) {
            _referencedPaths.add(data['poster_path'].toString());
          }
        }
      } catch (e) {
        debugPrint('Error collecting refs from $collectionName: $e');
      }
    }

    debugPrint('Total referenced paths: ${_referencedPaths.length}');
  }

  Future<void> _findOldEvents() async {
    _oldEvents.clear();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final collections = ['jfestchart', 'dfestkonser'];

    for (var collectionName in collections) {
      try {
        final docs = await FirebaseFirestore.instance
            .collection(collectionName)
            .get();

        for (var doc in docs.docs) {
          final data = doc.data();
          final dateStr = data['date']?.toString() ?? '';

          if (dateStr.isEmpty) continue;

          // Parse date - handle various formats
          DateTime? eventDate;
          try {
            eventDate = DateFormat('dd MMM yyyy', 'id_ID').parse(dateStr);
          } catch (_) {
            try {
              eventDate = DateFormat('yyyy-MM-dd').parse(dateStr);
            } catch (_) {
              try {
                eventDate = DateFormat('dd/MM/yyyy').parse(dateStr);
              } catch (_) {
                continue;
              }
            }
          }

          if (eventDate != null) {
            final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
            // Event is old if date is before today
            if (eventDateOnly.isBefore(today)) {
              _oldEvents.add({
                'id': doc.id,
                'collection': collectionName,
                'name': data['event_name'] ?? 'Unknown',
                'date': dateStr,
                'posters': data['posters'] ?? [],
                'poster_count': (data['posters'] as List?)?.length ?? 0,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error finding old events from $collectionName: $e');
      }
    }

    // Sort by date (oldest first)
    _oldEvents.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));

    debugPrint('Found ${_oldEvents.length} old events');
  }

  int _calculatePostersSize(List posters, List<Map<String, dynamic>> storageFiles) {
    int totalSize = 0;
    for (var poster in posters) {
      if (poster is Map && poster['path'] != null) {
        final path = poster['path'].toString();
        final file = storageFiles.firstWhere(
          (f) => f['path'] == path,
          orElse: () => {'sizeBytes': 0},
        );
        totalSize += (file['sizeBytes'] as int? ?? 0);
      }
    }
    return totalSize;
  }

  Future<List<Map<String, dynamic>>> _listStorageFiles() async {
    List<Map<String, dynamic>> files = [];

    try {
      final storage = FirebaseStorage.instance;

      // List folders (collections)
      final collections = ['jfestchart', 'dfestkonser', 'aninews'];

      for (var folder in collections) {
        try {
          final ref = storage.ref().child(folder);

          // Handle pagination for folders with many files
          String? pageToken;
          bool hasMore = true;

          while (hasMore) {
            final listOptions = ListOptions(
              maxResults: 500,
              pageToken: pageToken,
            );

            final listResult = await ref.list(listOptions);

            for (var item in listResult.items) {
              try {
                final metadata = await item.getMetadata();
                files.add({
                  'path': item.fullPath,
                  'name': item.name,
                  'folder': folder,
                  'sizeBytes': metadata.size,
                  'updated': metadata.updated,
                  'url': await item.getDownloadURL(),
                });
              } catch (e) {
                debugPrint('Error getting metadata for ${item.fullPath}: $e');
              }
            }

            // Check if there are more pages
            pageToken = listResult.nextPageToken;
            hasMore = pageToken != null;
          }

          debugPrint('Listed ${files.length} files from $folder so far');
        } catch (e) {
          debugPrint('Error listing $folder: $e');
        }
      }

      debugPrint('Total files listed: ${files.length}');
    } catch (e) {
      debugPrint('Error listing storage files: $e');
    }

    return files;
  }

  void _findDuplicates(List<Map<String, dynamic>> files) {
    _duplicateImages.clear();

    // Group by filename (last part of path)
    Map<String, List<Map<String, dynamic>>> byName = {};

    for (var file in files) {
      final name = file['name'] as String;
      if (!byName.containsKey(name)) {
        byName[name] = [];
      }
      byName[name]!.add(file);
    }

    // Find groups with more than 1 file
    for (var entry in byName.entries) {
      if (entry.value.length > 1) {
        _duplicateImages.addAll(entry.value);
      }
    }
  }

  Future<void> _deleteImages(List<Map<String, dynamic>> images, {String? label}) async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Hapus ${label ?? ''}'),
        content: Text(
          'Yakin ingin menghapus ${images.length} gambar? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    int deleted = 0;
    int failed = 0;

    for (var image in images) {
      try {
        await FirebaseStorage.instance.ref(image['path']).delete();
        deleted++;
      } catch (e) {
        debugPrint('Error deleting ${image['path']}: $e');
        failed++;
      }
    }

    setState(() => _isDeleting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil hapus $deleted gambar. Gagal: $failed')),
      );

      // Refresh analysis
      await _analyzeStorage();
    }
  }

  Future<void> _deleteOldEventPosters(Map<String, dynamic> event) async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Poster Saja'),
        content: Text(
          'Hapus poster dari event "${event['name']}"?\n\n'
          'Event akan tetap ada di Firestore tapi tanpa poster.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Hapus Poster Saja'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    final posters = event['posters'] as List?;
    if (posters == null || posters.isEmpty) {
      setState(() => _isDeleting = false);
      return;
    }

    int deleted = 0;
    int failed = 0;

    for (var poster in posters) {
      if (poster is Map && poster['path'] != null) {
        try {
          await FirebaseStorage.instance.ref(poster['path']).delete();
          deleted++;
        } catch (e) {
          debugPrint('Error deleting ${poster['path']}: $e');
          failed++;
        }
      }
    }

    // Remove posters from Firestore document
    try {
      await FirebaseFirestore.instance
          .collection(event['collection'])
          .doc(event['id'])
          .update({
        'posters': [],
        'is_postered': false,
      });
    } catch (e) {
      debugPrint('Error updating Firestore: $e');
    }

    setState(() => _isDeleting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil hapus $deleted poster. Gagal: $failed')),
      );
      await _analyzeStorage();
    }
  }

  Future<void> _deleteOldEventCompletely(Map<String, dynamic> event) async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Event Permanen'),
        content: Text(
          'Hapus event "${event['name']}" beserta SEMUA posternya?\n\n'
          'Tindakan ini tidak dapat dibatalkan!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Event & Poster'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    // Delete all posters from storage
    final posters = event['posters'] as List?;
    int deleted = 0;
    int failed = 0;

    if (posters != null) {
      for (var poster in posters) {
        if (poster is Map && poster['path'] != null) {
          try {
            await FirebaseStorage.instance.ref(poster['path']).delete();
            deleted++;
          } catch (e) {
            debugPrint('Error deleting ${poster['path']}: $e');
            failed++;
          }
        }
      }
    }

    // Delete document from Firestore
    try {
      await FirebaseFirestore.instance
          .collection(event['collection'])
          .doc(event['id'])
          .delete();
    } catch (e) {
      debugPrint('Error deleting Firestore document: $e');
    }

    setState(() => _isDeleting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event dihapus. Poster dihapus: $deleted, gagal: $failed')),
      );
      await _analyzeStorage();
    }
  }

  Future<void> _deleteMultipleOldEvents(List<Map<String, dynamic>> events, {bool deletePostersOnly = true}) async {
    if (_isDeleting) return;

    final action = deletePostersOnly ? 'Hapus Poster' : 'Hapus Event & Poster';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Massal'),
        content: Text(
          '$action dari ${events.length} event?\n\n'
          '${deletePostersOnly ? 'Event akan tetap ada tanpa poster.' : 'Semua event dan poster akan dihapus permanen!'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: deletePostersOnly ? Colors.orange : Colors.red,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    int eventsProcessed = 0;
    int postersDeleted = 0;

    for (var event in events) {
      final posters = event['posters'] as List?;

      if (!deletePostersOnly) {
        // Delete from Firestore
        try {
          await FirebaseFirestore.instance
              .collection(event['collection'])
              .doc(event['id'])
              .delete();
        } catch (e) {
          debugPrint('Error deleting ${event['name']}: $e');
          continue;
        }
      }

      // Delete posters from storage
      if (posters != null) {
        for (var poster in posters) {
          if (poster is Map && poster['path'] != null) {
            try {
              await FirebaseStorage.instance.ref(poster['path']).delete();
              postersDeleted++;
            } catch (e) {
              debugPrint('Error deleting poster: $e');
            }
          }
        }

        // Update Firestore to remove posters (if keeping event)
        if (deletePostersOnly) {
          try {
            await FirebaseFirestore.instance
                .collection(event['collection'])
                .doc(event['id'])
                .update({
              'posters': [],
              'is_postered': false,
            });
          } catch (e) {
            debugPrint('Error updating ${event['name']}: $e');
          }
        }
      }

      eventsProcessed++;
    }

    setState(() => _isDeleting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          deletePostersOnly
              ? 'Berhasil hapus poster dari $eventsProcessed event ($postersDeleted poster)'
              : 'Berhasil hapus $eventsProcessed event dan $postersDeleted poster',
        )),
      );
      await _analyzeStorage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage & Data Cleanup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/jeventku'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _analyzeStorage,
            tooltip: 'Refresh Analisis',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _loadingStatus,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  _buildOldEventsSection(),
                  const SizedBox(height: 24),
                  _buildOrphanedImagesSection(),
                  const SizedBox(height: 24),
                  _buildDuplicateImagesSection(),
                  const SizedBox(height: 24),
                  _buildQuickActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Statistik Storage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Gambar',
                  _totalImages.toString(),
                  Icons.image,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Ukuran Total',
                  _formatBytes(_totalSizeBytes),
                  Icons.sd_storage,
                  Colors.green,
                ),
                _buildStatItem(
                  'Orphaned',
                  _orphanedImages.length.toString(),
                  Icons.warning,
                  _orphanedImages.isEmpty ? Colors.grey : Colors.orange,
                ),
                _buildStatItem(
                  'Duplikat',
                  _duplicateImages.length.toString(),
                  Icons.file_copy,
                  _duplicateImages.isEmpty ? Colors.grey : Colors.red,
                ),
                _buildStatItem(
                  'Event Lama',
                  _oldEvents.length.toString(),
                  Icons.history,
                  _oldEvents.isEmpty ? Colors.grey : Colors.purple,
                ),
              ],
            ),
            if (_oldEventsStorageSize > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.storage, size: 16, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'Storage event lama: ${_formatBytes(_oldEventsStorageSize)}',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildOldEventsSection() {
    final filteredEvents = _filteredOldEvents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: _oldEvents.isEmpty ? Colors.green : Colors.purple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Sudah Terlewat (${filteredEvents.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (_oldEventsStorageSize > 0)
                        Text(
                          'Storage: ${_formatBytes(_oldEventsStorageSize)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                if (_selectedOldEvents.isNotEmpty)
                  Chip(
                    label: Text('${_selectedOldEvents.length} dipilih'),
                    onDeleted: () => setState(() => _selectedOldEvents.clear()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Event yang tanggalnya sudah lewat.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
                // Filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _oldEventsFilter,
                      isDense: true,
                      items: [
                        DropdownMenuItem(value: 'all', child: Text('Semua (${_oldEvents.length})')),
                        DropdownMenuItem(value: '3months', child: Text('> 3 Bulan (${_getFilterCount('3months')})')),
                        DropdownMenuItem(value: '6months', child: Text('> 6 Bulan (${_getFilterCount('6months')})')),
                        DropdownMenuItem(value: '1year', child: Text('> 1 Tahun (${_getFilterCount('1year')})')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _oldEventsFilter = value;
                            _selectedOldEvents.clear(); // Clear selection when filter changes
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (filteredEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      _oldEventsFilter == 'all'
                          ? 'Tidak ada event yang terlewat! 🎉'
                          : 'Tidak ada event yang sesuai filter.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, i) {
                    final event = filteredEvents[i];
                    final eventId = '${event['collection']}_${event['id']}';
                    final isSelected = _selectedOldEvents.contains(eventId);
                    final posterCount = event['poster_count'] as int? ?? 0;

                    return Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedOldEvents.add(eventId);
                              } else {
                                _selectedOldEvents.remove(eventId);
                              }
                            });
                          },
                        ),
                        title: Text(
                          event['name'] ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              event['date'] ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.image,
                              size: 12,
                              color: posterCount > 0 ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$posterCount poster',
                              style: TextStyle(
                                fontSize: 12,
                                color: posterCount > 0 ? Colors.blue : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'view',
                              child: const ListTile(
                                leading: Icon(Icons.visibility),
                                title: Text('Lihat Detail'),
                                dense: true,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_posters',
                              child: const ListTile(
                                leading: Icon(Icons.hide_image, color: Colors.orange),
                                title: Text('Hapus Poster Saja'),
                                dense: true,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_all',
                              child: const ListTile(
                                leading: Icon(Icons.delete_forever, color: Colors.red),
                                title: Text('Hapus Event & Poster'),
                                dense: true,
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'view') {
                              context.push('/${event['collection']}/${event['id']}');
                            } else if (value == 'delete_posters') {
                              _deleteOldEventPosters(event);
                            } else if (value == 'delete_all') {
                              _deleteOldEventCompletely(event);
                            }
                          },
                        ),
                        onTap: () {
                          context.push('/${event['collection']}/${event['id']}');
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Bulk action buttons - use Wrap to prevent overflow on mobile
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedOldEvents.addAll(
                          filteredEvents.map((e) => '${e['collection']}_${e['id']}'),
                        );
                      });
                    },
                    child: const Text('Pilih Semua'),
                  ),
                  FilledButton.icon(
                    onPressed: _isDeleting || _selectedOldEvents.isEmpty
                        ? null
                        : () {
                            final selected = filteredEvents
                                .where((e) => _selectedOldEvents.contains('${e['collection']}_${e['id']}'))
                                .toList();
                            _deleteMultipleOldEvents(selected, deletePostersOnly: true);
                            setState(() => _selectedOldEvents.clear());
                          },
                    icon: const Icon(Icons.hide_image, size: 18),
                    label: Text(
                      _selectedOldEvents.isEmpty
                          ? 'Hapus Poster'
                          : 'Hapus Poster (${_selectedOldEvents.length} event, ${_getSelectedPosterCount(filteredEvents)} poster)',
                    ),
                    style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                  FilledButton.icon(
                    onPressed: _isDeleting || _selectedOldEvents.isEmpty
                        ? null
                        : () {
                            final selected = filteredEvents
                                .where((e) => _selectedOldEvents.contains('${e['collection']}_${e['id']}'))
                                .toList();
                            _deleteMultipleOldEvents(selected, deletePostersOnly: false);
                            setState(() => _selectedOldEvents.clear());
                          },
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: Text(
                      _selectedOldEvents.isEmpty
                          ? 'Hapus Event'
                          : 'Hapus Event (${_selectedOldEvents.length})',
                    ),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _getSelectedPosterCount(List<Map<String, dynamic>> events) {
    int count = 0;
    for (var event in events) {
      if (_selectedOldEvents.contains('${event['collection']}_${event['id']}')) {
        count += event['poster_count'] as int? ?? 0;
      }
    }
    return count;
  }

  Widget _buildOrphanedImagesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: _orphanedImages.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Orphaned Images (${_orphanedImages.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_selectedOrphans.isNotEmpty)
                  Chip(
                    label: Text('${_selectedOrphans.length} dipilih'),
                    onDeleted: () => setState(() => _selectedOrphans.clear()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gambar yang ada di storage tapi tidak punya referensi di Firestore.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const Divider(),
            if (_orphanedImages.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Tidak ada orphaned images! 🎉'),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _orphanedImages.length,
                  itemBuilder: (context, i) {
                    final image = _orphanedImages[i];
                    final path = image['path'] as String;
                    final isSelected = _selectedOrphans.contains(path);

                    return ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedOrphans.add(path);
                            } else {
                              _selectedOrphans.remove(path);
                            }
                          });
                        },
                      ),
                      title: Text(
                        image['name'] ?? path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${image['folder']} • ${_formatBytes(image['sizeBytes'] ?? 0)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteImages([image], label: '1 gambar'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedOrphans.addAll(_orphanedImages.map((e) => e['path'] as String));
                      });
                    },
                    child: const Text('Pilih Semua'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isDeleting || _selectedOrphans.isEmpty
                        ? null
                        : () {
                            final selected = _orphanedImages
                                .where((e) => _selectedOrphans.contains(e['path']))
                                .toList();
                            _deleteImages(selected, label: '${selected.length} orphaned');
                            setState(() => _selectedOrphans.clear());
                          },
                    icon: const Icon(Icons.delete),
                    label: Text('Hapus Terpilih (${_selectedOrphans.length})'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicateImagesSection() {
    // Group duplicates by name for better UX
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var img in _duplicateImages) {
      final name = img['name'] as String;
      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(img);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_copy,
                  color: _duplicateImages.isEmpty ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Duplicate Images (${_duplicateImages.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_selectedDuplicates.isNotEmpty)
                  Chip(
                    label: Text('${_selectedDuplicates.length} dipilih'),
                    onDeleted: () => setState(() => _selectedDuplicates.clear()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gambar dengan nama yang sama tapi di path berbeda.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const Divider(),
            if (_duplicateImages.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Tidak ada duplicate images! 🎉'),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: grouped.length,
                  itemBuilder: (context, i) {
                    final name = grouped.keys.elementAt(i);
                    final files = grouped[name]!;

                    return ExpansionTile(
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${files.length} file • total ${_formatBytes(files.fold(0, (sum, f) => sum + (f['sizeBytes'] as int? ?? 0)))}'),
                      children: files.map((file) {
                        final path = file['path'] as String;
                        final isSelected = _selectedDuplicates.contains(path);

                        return ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedDuplicates.add(path);
                                } else {
                                  _selectedDuplicates.remove(path);
                                }
                              });
                            },
                          ),
                          title: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            _formatBytes(file['sizeBytes'] ?? 0),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      // Select all except first (keep one)
                      for (var entry in grouped.entries) {
                        for (int j = 1; j < entry.value.length; j++) {
                          _selectedDuplicates.add(entry.value[j]['path'] as String);
                        }
                      }
                      setState(() {});
                    },
                    child: const Text('Pilih Duplikat (Keep First)'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isDeleting || _selectedDuplicates.isEmpty
                        ? null
                        : () {
                            final selected = _duplicateImages
                                .where((e) => _selectedDuplicates.contains(e['path']))
                                .toList();
                            _deleteImages(selected, label: '${selected.length} duplikat');
                            setState(() => _selectedDuplicates.clear());
                          },
                    icon: const Icon(Icons.delete),
                    label: Text('Hapus Terpilih (${_selectedDuplicates.length})'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_orphanedImages.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _isDeleting
                        ? null
                        : () => _deleteImages(_orphanedImages, label: 'semua orphaned'),
                    icon: const Icon(Icons.cleaning_services),
                    label: Text('Hapus Semua Orphaned (${_orphanedImages.length})'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                if (_duplicateImages.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _isDeleting
                        ? null
                        : () {
                            // Delete all duplicates except first of each group
                            final toDelete = <Map<String, dynamic>>[];
                            Map<String, bool> firstOfGroup = {};
                            for (var img in _duplicateImages) {
                              final name = img['name'] as String;
                              if (firstOfGroup[name] == null) {
                                firstOfGroup[name] = true;
                              } else {
                                toDelete.add(img);
                              }
                            }
                            _deleteImages(toDelete, label: '${toDelete.length} duplikat');
                          },
                    icon: const Icon(Icons.file_copy_outlined),
                    label: Text('Hapus Duplikat (Keep First - ${_duplicateImages.length - groupedDuplicatesCount()})'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                if (_oldEvents.isNotEmpty) ...[
                  const Divider(),
                  Row(
                    children: [
                      const Text(
                        'Event Lama:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Filter: ${_getFilterLabel(_oldEventsFilter)}',
                          style: const TextStyle(fontSize: 10, color: Colors.purple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isDeleting || _filteredOldEvents.isEmpty
                        ? null
                        : () => _deleteMultipleOldEvents(_filteredOldEvents, deletePostersOnly: true),
                    icon: const Icon(Icons.hide_image, size: 18),
                    label: Text(
                      _filteredOldEvents.isEmpty
                          ? 'Hapus Poster'
                          : 'Hapus Poster (${_filteredOldEvents.length} event, ${_getPosterCount(_filteredOldEvents)} poster)',
                    ),
                    style: FilledButton.styleFrom(backgroundColor: Colors.purple),
                  ),
                  if (_oldEventsFilter == 'all' && _oldEvents.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tip: Gunakan filter untuk pilih event yang lebih tua',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  int groupedDuplicatesCount() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var img in _duplicateImages) {
      final name = img['name'] as String;
      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(img);
    }
    return grouped.length;
  }

  int _getPosterCount(List<Map<String, dynamic>> events) {
    int count = 0;
    for (var event in events) {
      count += event['poster_count'] as int? ?? 0;
    }
    return count;
  }

  List<Map<String, dynamic>> get _filteredOldEvents {
    if (_oldEventsFilter == 'all') return _oldEvents;

    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_oldEventsFilter) {
      case '3months':
        cutoffDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6months':
        cutoffDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1year':
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return _oldEvents;
    }

    return _oldEvents.where((event) {
      final dateStr = event['date']?.toString() ?? '';
      DateTime? eventDate;

      try {
        eventDate = DateFormat('dd MMM yyyy', 'id_ID').parse(dateStr);
      } catch (_) {
        try {
          eventDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        } catch (_) {
          try {
            eventDate = DateFormat('dd/MM/yyyy').parse(dateStr);
          } catch (_) {
            return true; // Include if can't parse
          }
        }
      }

      if (eventDate == null) return true;
      return eventDate.isBefore(cutoffDate);
    }).toList();
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'Semua';
      case '3months':
        return '> 3 Bulan';
      case '6months':
        return '> 6 Bulan';
      case '1year':
        return '> 1 Tahun';
      default:
        return 'Semua';
    }
  }

  int _getFilterCount(String filter) {
    final now = DateTime.now();
    DateTime cutoffDate;

    switch (filter) {
      case '3months':
        cutoffDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6months':
        cutoffDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1year':
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return _oldEvents.length;
    }

    return _oldEvents.where((event) {
      final dateStr = event['date']?.toString() ?? '';
      DateTime? eventDate;

      try {
        eventDate = DateFormat('dd MMM yyyy', 'id_ID').parse(dateStr);
      } catch (_) {
        try {
          eventDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        } catch (_) {
          try {
            eventDate = DateFormat('dd/MM/yyyy').parse(dateStr);
          } catch (_) {
            return false;
          }
        }
      }

      if (eventDate == null) return false;
      return eventDate.isBefore(cutoffDate);
    }).length;
  }
}
