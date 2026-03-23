import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/provider/aninews_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';

// IMPORT SHARED (Sesuaikan path Anda)
import '../../components/shared/detail/aninews_logic_mixin.dart';
import '../../components/shared/detail/shared_detail_components.dart';

class AniNewsDetailPage extends StatefulWidget {
  final Map<String, dynamic>? data;
  final String newsId;
  const AniNewsDetailPage({super.key, required this.newsId, this.data});

  @override
  State<AniNewsDetailPage> createState() => _AniNewsDetailPageState();
}

class _AniNewsDetailPageState extends State<AniNewsDetailPage> with AniNewsLogicMixin {
  // CONFIGURATION
  final String collectionName = 'anichekku';
  final String routePrefix = '/anichekku'; // Sesuaikan dengan route list news Anda

  // STATE LOKAL
  Map<String, dynamic>? _newsData;
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
      _newsData = widget.data;
    } else {
      final doc = await FirebaseFirestore.instance.collection(collectionName).doc(widget.newsId).get();
      if (doc.exists) _newsData = doc.data()!..['id'] = doc.id;
    }

    // 2. Load ke Controller (via Mixin)
    if (_newsData != null) loadInitialData(_newsData!);

    // 3. Cek Admin
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isAdmin = prefs.getBool('isAdmin') ?? false;
        _isLoading = false;
      });
    }

    // 4. Load Poster
    _loadPosters();
  }

  Future<void> _loadPosters() async {
    if (_newsData == null) return;
    if (mounted) setState(() => _postersAreLoading = true);

    try {
      List<dynamic> rawPosters = _newsData!['posters'] ?? [];
      List<Map<String, String>> loadedPosters = await Future.wait(
        rawPosters.map((poster) async {
          String path = poster["path"]?.toString() ?? "";
          String title = poster["title"]?.toString() ?? "Poster";
          if (path.isEmpty) return {"url": ""};
          try {
            final ref = FirebaseStorage.instance.ref().child(path);
            String url = await ref.getDownloadURL();
            return {"url": url, "title": title};
          } catch (e) {
            return {"url": ""};
          }
        }),
      );
      loadedPosters.removeWhere((p) => p['url'] == null || p['url']!.isEmpty);
      if (mounted) {
        setState(() {
          _posters = loadedPosters;
          _postersAreLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _postersAreLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    await FirebaseFirestore.instance.collection(collectionName).doc(_newsData!['id']).update({
      'title': titleController.text,
      'date': dateController.text,
      'desc': descriptionController.text,
      'tags': tags,
      'genres': genres,
      'is_scheduled': isScheduled,
    });
    if (mounted) {
      context.read<AniNewsProvider>().fetchData(forceRefresh: true);
      setState(() {
        _editMode = false;
        // Update local state agar view mode langsung berubah
        _newsData!['title'] = titleController.text;
        _newsData!['date'] = dateController.text;
        _newsData!['desc'] = descriptionController.text;
        _newsData!['tags'] = tags;
        _newsData!['genres'] = genres;
        _newsData!['is_scheduled'] = isScheduled;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berita disimpan")));
    }
  }

  Future<void> _deleteNews() async {
    await FirebaseFirestore.instance.collection(collectionName).doc(_newsData!['id']).delete();
    if (mounted) {
      context.read<AniNewsProvider>().fetchData(forceRefresh: true);
      context.go(routePrefix);
    }
  }

  Future<void> _uploadImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sedang mengupload gambar...')));
      final newPosters = await StorageService().uploadImages(images, collectionName, _newsData!['title']);
      await _addPostersToFirestore(newPosters);
    }
  }

  Future<void> _addPostersToFirestore(List<Map<String, dynamic>> newPosters) async {
    try {
      final docRef = FirebaseFirestore.instance.collection(collectionName).doc(_newsData!['id']);
      final docSnapshot = await docRef.get();
      List<dynamic> existingPosters = [];
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('posters')) existingPosters = List.from(data['posters']);
      }

      bool hasMain = existingPosters.any((p) => p['is_main'] == true);
      if (!hasMain && newPosters.isNotEmpty) newPosters[0]['is_main'] = true;

      existingPosters.addAll(newPosters);
      await docRef.update({'posters': existingPosters, 'is_postered': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poster berhasil diupload!')));
        _loadPosters();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload poster: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_newsData == null) return const Scaffold(body: Center(child: Text("Data tidak ditemukan")));

    return Scaffold(
      appBar: AppBar(
        title: Text(_editMode ? "Edit Berita" : _newsData!['title']),
        leading: _editMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _editMode = false))
            : Navigator.canPop(context)
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(routePrefix)),
        actions: [
          if (_editMode)
            TextButton(onPressed: _saveChanges, child: const Text("SIMPAN"))
          else ...[
            IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => shareNews(title: _newsData!['title'], id: _newsData!['id'], pathPrefix: routePrefix)),
            if (_isAdmin)
              PopupMenuButton(
                  onSelected: (v) {
                    if (v == 'edit') setState(() => _editMode = true);
                    if (v == 'del') _deleteNews();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text("Edit")),
                    const PopupMenuItem(value: 'del', child: Text("Hapus", style: TextStyle(color: Colors.red))),
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

    // Memanggil info card khusus News yang kita buat di shared_detail_components
    final content = NewsInfoCard(data: _newsData!);

    if (isDesktop) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Kita tetap bisa me-reuse DetailImageCarousel dan PosterManager!
        Expanded(flex: 2, child: DetailImageCarousel(posters: _posters, isLoading: _postersAreLoading)),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: content)
      ]);
    }
    return Column(children: [
      DetailImageCarousel(posters: _posters, isLoading: _postersAreLoading),
      const SizedBox(height: 16),
      content
    ]);
  }

  Widget _buildEditMode() {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // Memanggil Form khusus News
    final formWidget = NewsEditForm(
      titleCtrl: titleController,
      dateCtrl: dateController,
      descCtrl: descriptionController,
      tagCtrl: tagController,
      genreCtrl: genreController,
      tags: tags,
      genres: genres,
      isScheduled: isScheduled,
      onTagAdded: (val) => setState(() => tags.add(val)),
      onTagDeleted: (val) => setState(() => tags.remove(val)),
      onGenreAdded: (val) => setState(() => genres.add(val)),
      onGenreDeleted: (val) => setState(() => genres.remove(val)),
      onScheduledChanged: (val) => setState(() => isScheduled = val),
    );

    // Kita tetap me-reuse DetailPosterManager!
    final posterWidget = DetailPosterManager(
        collectionName: collectionName,
        docId: _newsData!['id'],
        onAddImage: _uploadImages
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: formWidget),
          const SizedBox(width: 24.0),
          Expanded(flex: 2, child: posterWidget),
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