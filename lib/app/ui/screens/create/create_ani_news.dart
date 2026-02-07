import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wargabut/app/provider/aninews_provider.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class CreateAniNewsPage extends StatefulWidget {
  const CreateAniNewsPage({super.key});

  @override
  State<CreateAniNewsPage> createState() => _CreateAniNewsPageState();
}

class _CreateAniNewsPageState extends State<CreateAniNewsPage> {

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();

  final _tagController = TextEditingController();
  final List<String> _tags = [];

  List<Map<String, dynamic>> newPosters = [];



  List<Map<String, dynamic>> guestStars = [];
  String? selectedGuestStarId;

  final StorageService _storageService = StorageService();
  XFile? _imageFile;
  String? _downloadURL;

  @override
  void initState() {
    super.initState();
  }

  String formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }


  Future<void> _uploadImage(String eventName) async {
    if (_imageFile == null) return;
    String? url = await _storageService.uploadImage(_imageFile, 'anicheckku', eventName);
    setState(() {
      _downloadURL = url;
    });
  }

  Future<void> _uploadImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? selectedImages = await picker.pickMultiImage();

    if (selectedImages != null && selectedImages.isNotEmpty) {
      List<Map<String, dynamic>> uploadedPosters =
          await _storageService.uploadImages(
        selectedImages,
        'anicheckku',
        _titleController.text,
      );

      uploadedPosters[0]['is_main'] = true;

      print("poster: $uploadedPosters");

      setState(() {
        newPosters.addAll(uploadedPosters);
      });
    }
  }

  Future<void> _addPostersToFirestore(
      String eventId, List<Map<String, dynamic>> posters) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore.collection('anichekku').doc(eventId).update({
      'posters': posters,
      'is_postered': posters.isNotEmpty,
    });
  }

  String _createSlugFromName(String name) {
    // 1. Ubah ke huruf kecil
    String slug = name.toLowerCase();

    // 2. Hapus karakter spesial selain huruf, angka, dan spasi
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');

    // 3. Ganti spasi dengan tanda hubung (-)
    slug = slug.replaceAll(RegExp(r'\s+'), '-');

    // 4. Hapus tanda hubung berlebih di awal atau akhir
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');

    // 5. Batasi panjang slug jika perlu (opsional, tapi baik untuk performa)
    if (slug.length > 100) {
      slug = slug.substring(0, 100);
    }

    return slug;
  }

  Future<void> _saveEventToFirestore(BuildContext context) async {
    final eventProvider = Provider.of<AniNewsProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Pastikan nama berita tidak kosong
    if (_titleController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nama berita tidak boleh kosong!')),
      );
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String titleNews = _titleController.text;

      print('title: $titleNews');

      // 1. Buat 'slug' dari nama event menggunakan fungsi yang kita buat
      String newsIdSlug = _createSlugFromName(titleNews);

      print('slug: $newsIdSlug');

      // 2. Tentukan DocumentReference dengan slug kustom
      DocumentReference eventRef = firestore.collection('anichekku').doc(newsIdSlug);

      print('eventRef: $eventRef');

      // 3. (SANGAT PENTING) Cek apakah dokumen dengan ID ini sudah ada
      final docSnapshot = await eventRef.get();
      if (docSnapshot.exists) {
        // Jika sudah ada, beri peringatan dan batalkan penyimpanan
        messenger.showSnackBar(
          const SnackBar(content: Text('Gagal: Berita dengan nama yang mirip sudah ada! Coba ganti nama berita.')),
        );
        return; // Hentikan fungsi
      }

      try {
        // 4. Gunakan .set() untuk menyimpan data dengan ID kustom
        print('title: $titleNews, date: ${_dateController.text}, desc: ${_descriptionController.text}, tags: $_tags');
        await eventRef.set({
          'title': titleNews,
          'date': _dateController.text,
          'desc': _descriptionController.text,
          'tags': _tags,
          'is_postered': newPosters.isNotEmpty,
          'posters': [],
          'created_at': DateTime.now(),
        });
      } catch (e) {
        print('Gagal menambahkan berita ke Firestore: $e');
        return;
      }

      // Jika ada poster yang diunggah, tambahkan ke Firestore
      if (newPosters.isNotEmpty) {
        await _addPostersToFirestore(eventRef.id, newPosters);
        print('Poster berhasil ditambahkan ke Firestore.');
      }

      if (!mounted) return;

      await eventProvider.fetchData(forceRefresh: true);

      messenger.showSnackBar(
        const SnackBar(content: Text('Berita berhasil dibuat!')),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      print('Gagal menambahkan berita: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menambahkan berita: $e')),
      );
    }
  }

  Widget _buildTagInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _tagController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Tag Berita',
            hintText: 'Contoh: Anime, Movie, Spring 2025',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              setState(() {
                _tags.add(value.trim());
                _tagController.clear();
              });
            }
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _tags
              .map(
                (tag) => Chip(
              label: Text(tag),
              onDeleted: () {
                setState(() {
                  _tags.remove(tag);
                });
              },
            ),
          )
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _saveEventToFirestore(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaQuery.of(context).size.width < 720
                ? Column(
              children: [
                Text(
                  "Detail Berita Anime",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),

                // Judul Berita
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Judul Berita',
                  ),
                ),

                const SizedBox(height: 16),

                // Tanggal Berita
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Tanggal Berita / Tayang',
                    hintText: 'Contoh: 20 Januari 2025',
                  ),
                ),

                const SizedBox(height: 16),

                // Tag Berita
                _buildTagInput(),

                const SizedBox(height: 16),

                // Deskripsi
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Berita',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),

                const SizedBox(height: 16),

                // Upload Poster
                ElevatedButton.icon(
                  onPressed: _uploadImages,
                  icon: const Icon(Icons.image),
                  label: const Text('Tambah Poster Berita'),
                ),

                const SizedBox(height: 16),

                // Preview Poster
                if (newPosters.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: newPosters.length,
                    itemBuilder: (context, index) {
                      final poster = newPosters[index];
                      return ListTile(
                        leading: Image.network(
                          poster['url'],
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                        title: Text(poster['path'].split('/').last),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              newPosters.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
              ],
            )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kolom Kiri: Form Event
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Judul Berita',
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _dateController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Tanggal Berita / Tayang',
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildTagInput(),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Deskripsi Berita',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 5,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16.0),

                      // Kolom Kanan: Tombol Tambah Poster + List Poster
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _uploadImages,
                              icon: const Icon(Icons.image),
                              label: const Text('Tambah Poster Berita'),
                            ),

                            const SizedBox(height: 16),

                            if (newPosters.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: newPosters.length,
                                itemBuilder: (context, index) {
                                  final poster = newPosters[index];
                                  return Card(
                                    child: ListTile(
                                      leading: Image.network(
                                        poster['url'],
                                        width: 80,
                                        fit: BoxFit.cover,
                                      ),
                                      title: Text(poster['path'].split('/').last),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            newPosters.removeAt(index);
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
          ],
        ),
      ),
    );
  }
}
