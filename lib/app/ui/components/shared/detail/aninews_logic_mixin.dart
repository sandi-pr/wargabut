import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wargabut/app/services/share_service_gate.dart';

mixin AniNewsLogicMixin<T extends StatefulWidget> on State<T> {
  // --- CONTROLLERS ---
  final titleController = TextEditingController();
  final dateController = TextEditingController();
  final descriptionController = TextEditingController();

  final tagController = TextEditingController();
  final genreController = TextEditingController();

  List<String> tags = [];
  List<String> genres = [];
  bool isScheduled = false;

  @override
  void dispose() {
    titleController.dispose();
    dateController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    genreController.dispose();
    super.dispose();
  }

  // --- POPULATE DATA ---
  void loadInitialData(Map<String, dynamic> data) {
    titleController.text = data['title'] ?? '';
    dateController.text = data['date'] ?? '';
    descriptionController.text = data['desc'] ?? '';
    isScheduled = data['is_scheduled'] ?? false;

    // Casting List<dynamic> ke List<String>
    tags = (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    genres = (data['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
  }

  // --- SHARE LOGIC ---
  Future<void> shareNews({required String title, required String id, required String pathPrefix}) async {
    final String url = "https://wargabut.id$pathPrefix/$id";
    final String text = "Cek berita terbaru '$title' di sini:";

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