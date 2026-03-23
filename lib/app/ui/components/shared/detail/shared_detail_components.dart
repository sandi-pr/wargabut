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
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
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

// --- 4. POSTER MANAGER (Stream dari Firestore) ---
class DetailPosterManager extends StatelessWidget {
  final String collectionName;
  final String docId;
  final VoidCallback onAddImage;

  const DetailPosterManager({super.key, required this.collectionName, required this.docId, required this.onAddImage});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return Column(
      children: [
        ElevatedButton.icon(onPressed: onAddImage, icon: const Icon(Icons.image), label: const Text('Tambah Poster')),
        const SizedBox(height: 16),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection(collectionName).doc(docId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final posters = (data?['posters'] as List?) ?? [];

            if (posters.isEmpty) return const Text("Belum ada poster");

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posters.length,
              itemBuilder: (_, i) {
                final p = posters[i];
                return ListTile(
                  leading: Image.network(p['url'], width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(p['path'].toString().split('/').last),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(p['is_main'] == true ? Icons.star : Icons.star_border, color: Colors.amber),
                        onPressed: () => _setMainPoster(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => storage.deletePoster(context, i, collectionName, docId),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        )
      ],
    );
  }

  Future<void> _setMainPoster(int index) async {
    final ref = FirebaseFirestore.instance.collection(collectionName).doc(docId);
    final doc = await ref.get();
    if(doc.exists) {
      List p = List.from(doc['posters']);
      for(var item in p) {
        item['is_main'] = false;
      }
      p[index]['is_main'] = true;
      await ref.update({'posters': p});
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
                  const Text("Tag:", style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  const NewsEditForm({
    super.key,
    required this.titleCtrl,
    required this.dateCtrl,
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Judul Berita', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Tanggal Tayang / Berita', border: OutlineInputBorder())),
        const SizedBox(height: 16),

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

        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()), maxLines: 5),
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