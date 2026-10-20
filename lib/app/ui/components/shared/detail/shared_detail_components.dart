import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/firebase_storage.dart';

// --- 1. CAROUSEL GAMBAR ---
class DetailImageCarousel extends StatelessWidget {
  final List<Map<String, String>> posters;
  final bool isLoading;

  const DetailImageCarousel({super.key, required this.posters, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AspectRatio(aspectRatio: 1.0, child: Center(child: CircularProgressIndicator()));
    }
    if (posters.isEmpty) return _buildPlaceholder();

    return CarouselSlider(
      options: CarouselOptions(autoPlay: posters.length > 1, aspectRatio: 1.0, enlargeCenterPage: true),
      items: posters.map((poster) {
        return GestureDetector(
          onTap: () => _showZoomDialog(context, poster['url']!),
          child: Image.network(
            poster['url']!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        color: Colors.grey.shade300,
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade600, size: 50),
      ),
    );
  }

  void _showZoomDialog(BuildContext context, String url) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: InteractiveViewer(child: Image.network(url)),
    ));
  }
}

// --- 2. INFO CARD (Tanggal, Lokasi, Deskripsi) ---
class DetailInfoCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const DetailInfoCard({super.key, required this.data});

  @override
  State<DetailInfoCard> createState() => _DetailInfoCardState();
}

class _DetailInfoCardState extends State<DetailInfoCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ticketPrice = widget.data['ticket_price']?.toString().trim();
    String? htmDisplay = ticketPrice;

    // Format mata uang simple
    if (ticketPrice != null && ticketPrice.toLowerCase() != 'gratis') {
      final numeric = ticketPrice.replaceAll('.', '');
      final val = int.tryParse(numeric);
      if(val != null) htmDisplay = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
    }

    return Column(
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _rowIcon(Icons.calendar_today, widget.data['date'] ?? '-', htmDisplay),
                const SizedBox(height: 12),
                _rowIcon(Icons.location_on, widget.data['location'] ?? '-', widget.data['area']),
              ],
            ),
          ),
        ),
        if (widget.data['desc'] != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.data['desc'].replaceAll('\\n', '\n'),
                    maxLines: isExpanded ? null : 4,
                    overflow: isExpanded ? null : TextOverflow.ellipsis,
                  ),
                  if (!isExpanded)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(onPressed: () => setState(() => isExpanded = true), child: const Text("Lihat Selengkapnya")),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _rowIcon(IconData icon, String mainText, String? sideText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(mainText, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (sideText != null && sideText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Text(sideText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
      ],
    );
  }
}

// --- 3. FORM EDIT (Shared Inputs) ---
class DetailEditForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController dateCtrl;
  final TextEditingController areaCtrl;
  final TextEditingController locCtrl;
  final TextEditingController descCtrl;
  final TextEditingController priceCtrl;
  final String htmType;
  final bool isMedpart;
  final Function(String) onHtmChanged;
  final Function(bool) onMedpartChanged;

  const DetailEditForm({
    super.key,
    required this.nameCtrl,
    required this.dateCtrl,
    required this.areaCtrl,
    required this.locCtrl,
    required this.descCtrl,
    required this.priceCtrl,
    required this.htmType,
    required this.isMedpart,
    required this.onHtmChanged,
    required this.onMedpartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Event')),
        const SizedBox(height: 16),
        TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Tanggal')),
        const SizedBox(height: 16),
        TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: 'Area')),
        const SizedBox(height: 16),
        TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Lokasi')),
        const SizedBox(height: 16),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 5),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: htmType,
          decoration: const InputDecoration(labelText: 'HTM', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'free', child: Text('Gratis')),
            DropdownMenuItem(value: 'paid', child: Text('Berbayar')),
          ],
          onChanged: (v) => onHtmChanged(v!),
        ),
        const SizedBox(height: 16),
        if (htmType == 'paid')
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Harga Tiket (Rp)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        SwitchListTile(title: const Text("Media Partner"), value: isMedpart, onChanged: onMedpartChanged),
      ],
    );
  }
}

// --- 4. POSTER MANAGER (Stream dari Firestore) with Drag & Drop Reorder ---
class DetailPosterManager extends StatefulWidget {
  final String collectionName;
  final String docId;
  final VoidCallback onAddImage;

  const DetailPosterManager({super.key, required this.collectionName, required this.docId, required this.onAddImage});

  @override
  State<DetailPosterManager> createState() => _DetailPosterManagerState();
}

class _DetailPosterManagerState extends State<DetailPosterManager> {
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return Column(
      children: [
        // Header dengan tombol tambah dan toggle reorder
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onAddImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Tambah Poster'),
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
        const SizedBox(height: 16),

        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection(widget.collectionName).doc(widget.docId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            List<dynamic> posters = List.from((data?['posters'] as List?) ?? []);

            // Handle legacy data: jika semua order = 1 atau tidak ada order, normalize berdasarkan index
            bool needsNormalization = posters.isEmpty ||
                posters.every((p) => p['order'] == null || p['order'] == 1);

            if (needsNormalization && posters.isNotEmpty) {
              // Normalize order berdasarkan array index (mulai dari 0)
              for (int i = 0; i < posters.length; i++) {
                posters[i]['order'] = i;
              }
              // Auto-save normalized order
              _savePosters(posters);
            }

            if (posters.isEmpty) return const Text("Belum ada poster");

            if (_isReordering) {
              return _buildReorderableList(posters);
            }

            return _buildPosterList(posters, storage);
          },
        )
      ],
    );
  }

  Widget _buildPosterList(List<dynamic> posters, StorageService storage) {
    // Sort berdasarkan order
    final sortedPosters = List.from(posters);
    sortedPosters.sort((a, b) {
      final orderA = (a['order'] as num?) ?? 0;
      final orderB = (b['order'] as num?) ?? 0;
      return orderA.compareTo(orderB);
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedPosters.length,
      itemBuilder: (_, i) {
        final p = sortedPosters[i];
        final isMain = p['is_main'] == true;
        final order = (p['order'] as num?)?.toInt() ?? i;
        final title = p['title']?.toString() ?? p['path'].toString().split('/').last;
        final posterUrl = p['url']?.toString() ?? '';

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
                  // Overlay icon untuk indicate bisa diklik
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
                  onPressed: () => _editPosterTitle(p),
                ),
                IconButton(
                  icon: const Icon(Icons.star_outline, color: Colors.amber),
                  tooltip: 'Jadikan Poster Utama',
                  onPressed: () => _setMainPoster(p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Hapus Poster',
                  onPressed: () => _deletePoster(p),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReorderableList(List<dynamic> posters) {
    // Sort berdasarkan order untuk tampilan
    final sortedPosters = List<Map<String, dynamic>>.from(posters.cast());
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
                  'Seret poster untuk mengubah urutan. Poster utama akan menjadi poster pertama.',
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
          onReorder: (oldIndex, newIndex) => _onReorder(sortedPosters, oldIndex, newIndex),
          itemBuilder: (_, i) {
            final p = sortedPosters[i];
            final isMain = p['is_main'] == true;
            final title = p['title']?.toString() ?? p['path'].toString().split('/').last;
            final posterUrl = p['url']?.toString() ?? '';

            return Card(
              key: ValueKey(p['path'] ?? i),
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
                          // Overlay icon untuk indicate bisa diklik
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
                    // Tombol Edit Nama
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                      tooltip: 'Edit Nama Poster',
                      onPressed: () => _editPosterTitle(p),
                    ),
                    // Tombol Move Up
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 20),
                      tooltip: 'Pindah ke Atas',
                      onPressed: i > 0 ? () => _movePoster(sortedPosters, i, i - 1) : null,
                    ),
                    // Tombol Move Down
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 20),
                      tooltip: 'Pindah ke Bawah',
                      onPressed: i < sortedPosters.length - 1 ? () => _movePoster(sortedPosters, i, i + 1) : null,
                    ),
                    // Toggle Main Poster
                    IconButton(
                      icon: Icon(
                        isMain ? Icons.star : Icons.star_outline,
                        color: Colors.amber,
                      ),
                      tooltip: isMain ? 'Sudah Poster Utama' : 'Jadikan Poster Utama',
                      onPressed: () => _setMainPoster(p),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
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
        ),
      ],
    );
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

    final storage = StorageService();
    await storage.deletePoster(
      context,
      -1,
      widget.collectionName,
      widget.docId,
      targetPoster: targetPoster,
    );
  }

  void _onReorder(List<Map<String, dynamic>> sortedPosters, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = sortedPosters.removeAt(oldIndex);
    sortedPosters.insert(newIndex, item);

    // Update order berdasarkan posisi baru
    for (int i = 0; i < sortedPosters.length; i++) {
      sortedPosters[i]['order'] = i;
    }

    await _savePosters(sortedPosters);
  }

  void _movePoster(List<Map<String, dynamic>> sortedPosters, int currentIndex, int newIndex) async {
    final item = sortedPosters.removeAt(currentIndex);
    sortedPosters.insert(newIndex, item);

    // Update order berdasarkan posisi baru
    for (int i = 0; i < sortedPosters.length; i++) {
      sortedPosters[i]['order'] = i;
    }

    await _savePosters(sortedPosters);
  }

  Future<void> _setMainPoster(Map<String, dynamic> targetPoster) async {
    final ref = FirebaseFirestore.instance.collection(widget.collectionName).doc(widget.docId);
    final doc = await ref.get();

    if (doc.exists) {
      List<Map<String, dynamic>> posters = List.from(doc['posters']).cast<Map<String, dynamic>>();

      // Set semua poster ke is_main: false
      for (var item in posters) {
        item['is_main'] = false;
      }

      final targetPath = targetPoster['path']?.toString();
      final targetUrl = targetPoster['url']?.toString();

      // Set poster yang dipilih sebagai utama
      for (var item in posters) {
        if ((targetPath != null && item['path'] == targetPath) ||
            (targetUrl != null && item['url'] == targetUrl)) {
          item['is_main'] = true;
          break;
        }
      }

      await ref.update({'posters': posters});
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
      final ref = FirebaseFirestore.instance.collection(widget.collectionName).doc(widget.docId);
      final doc = await ref.get();

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

        await ref.update({'posters': posters});

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
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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

  Future<void> _savePosters(List<dynamic> posters) async {
    try {
      final ref = FirebaseFirestore.instance.collection(widget.collectionName).doc(widget.docId);

      // Sort posters by order before saving
      final sortedPosters = List.from(posters);
      sortedPosters.sort((a, b) {
        final orderA = (a['order'] as num?) ?? 0;
        final orderB = (b['order'] as num?) ?? 0;
        return orderA.compareTo(orderB);
      });

      await ref.update({'posters': sortedPosters});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Urutan poster berhasil disimpan!'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint('Error saving poster order: $e');
    }
  }
}

// ==========================================================
// KOMPONEN KHUSUS ANI-NEWS
// ==========================================================

// --- 5. INFO CARD KHUSUS NEWS ---
class NewsInfoCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const NewsInfoCard({super.key, required this.data});

  @override
  State<NewsInfoCard> createState() => _NewsInfoCardState();
}

class _NewsInfoCardState extends State<NewsInfoCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> tags = widget.data['tags'] ?? [];
    final List<dynamic> genres = widget.data['genres'] ?? [];
    final bool isScheduled = widget.data['is_scheduled'] ?? false;

    return Column(
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tanggal & Status Jadwal
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.data['date'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isScheduled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Jadwal Tayang",
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15), // Warna hijau untuk membedakan
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Berita", // Teks pengganti jika bukan jadwal tayang
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                          ),
                        ),
                      ),
                  ],
                ),

                if (widget.data['air_time'] != null && widget.data['air_time'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled, size: 18, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        "Jam Tayang: ${widget.data['air_time']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ],

                // Metadata Tambahan: Studio, Members, Score
                if (widget.data['studios'] != null ||
                    widget.data['members_formatted'] != null ||
                    widget.data['members'] != null ||
                    (widget.data['score'] != null && widget.data['score'] != 'N/A' && widget.data['score'] != '0')) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.data['members_formatted'] != null || widget.data['members'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.data['members_formatted'] ?? widget.data['members']} Anggota',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.data['studios'] is List && (widget.data['studios'] as List).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business, size: 14, color: Colors.purple.shade700),
                              const SizedBox(width: 4),
                              Text(
                                (widget.data['studios'] as List).join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.data['score'] != null &&
                          widget.data['score'] != 'N/A' &&
                          widget.data['score'] != '0')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'Skor ${widget.data['score']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],

                // Genres
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("Genre:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: genres.map((g) => Chip(
                      label: Text(g.toString(), style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],

                // Tags
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(widget.data['is_scheduled'] ? "Musim:" : "Tag:", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tags.map((t) => Chip(
                      label: Text(t.toString(), style: const TextStyle(fontSize: 12)),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Deskripsi
        if (widget.data['desc'] != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.data['desc'].replaceAll('\\n', '\n'),
                    maxLines: isExpanded ? null : 4,
                    overflow: isExpanded ? null : TextOverflow.ellipsis,
                  ),
                  if (!isExpanded)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                          onPressed: () => setState(() => isExpanded = true),
                          child: const Text("Lihat Selengkapnya")
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --- 6. WIDGET INPUT CHIP (Tag/Genre) ---
class ChipInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final List<String> items;
  final Function(String) onAdded;
  final Function(String) onDeleted;

  const ChipInputWidget({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.items,
    required this.onAdded,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: label,
            hintText: hint,
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              onAdded(value.trim());
              controller.clear();
            }
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: items.map((item) => Chip(
            label: Text(item),
            onDeleted: () => onDeleted(item),
          )).toList(),
        ),
      ],
    );
  }
}

// --- 7. FORM EDIT KHUSUS NEWS ---
class NewsEditForm extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController dateCtrl;
  final TextEditingController? airTimeCtrl;
  final TextEditingController descCtrl;
  final TextEditingController tagCtrl;
  final TextEditingController genreCtrl;
  final List<String> tags;
  final List<String> genres;
  final bool isScheduled;
  final Function(String) onTagAdded;
  final Function(String) onTagDeleted;
  final Function(String) onGenreAdded;
  final Function(String) onGenreDeleted;
  final Function(bool) onScheduledChanged;
  final VoidCallback? onTranslatePressed;

  const NewsEditForm({
    super.key,
    required this.titleCtrl,
    required this.dateCtrl,
    this.airTimeCtrl,
    required this.descCtrl,
    required this.tagCtrl,
    required this.genreCtrl,
    required this.tags,
    required this.genres,
    required this.isScheduled,
    required this.onTagAdded,
    required this.onTagDeleted,
    required this.onGenreAdded,
    required this.onGenreDeleted,
    required this.onScheduledChanged,
    this.onTranslatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Judul Berita', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Tanggal Tayang / Berita', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        if (airTimeCtrl != null) ...[
          TextField(
            controller: airTimeCtrl,
            decoration: const InputDecoration(
              labelText: 'Jam Tayang (Air Time)',
              hintText: 'Contoh: 22:00 WIB / 23:30 JST',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.access_time),
            ),
          ),
          const SizedBox(height: 16),
        ],

        ChipInputWidget(
          controller: tagCtrl,
          label: 'Tag Berita / Anime',
          hint: 'Contoh: Anime, Spring 2026',
          items: tags,
          onAdded: onTagAdded,
          onDeleted: onTagDeleted,
        ),
        const SizedBox(height: 16),

        ChipInputWidget(
          controller: genreCtrl,
          label: 'Genre',
          hint: 'Contoh: Action, Comedy',
          items: genres,
          onAdded: onGenreAdded,
          onDeleted: onGenreDeleted,
        ),
        const SizedBox(height: 16),

        Stack(
          children: [
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()), maxLines: 5),
            if (onTranslatePressed != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton(
                  icon: const Icon(Icons.translate, color: Colors.blue),
                  onPressed: onTranslatePressed,
                  tooltip: 'Translate to Indonesia',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        SwitchListTile(
          title: const Text("Jadwal Tayang (Scheduled)"),
          value: isScheduled,
          onChanged: onScheduledChanged,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}