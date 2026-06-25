import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minio/minio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:wargabut/app/ui/screens/detail/event_detail.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class AniNewsListTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const AniNewsListTile({
    super.key,
    required this.data,
  });

  @override
  State<AniNewsListTile> createState() => _AniNewsListTileState();
}

class _AniNewsListTileState extends State<AniNewsListTile> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndAdminStatus();
  }

  Future<void> _checkLoginAndAdminStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        child: TemplateCard(
          data: widget.data,
          isAdmin: _isAdmin,
        ),
      ),
    );
  }
}

class TemplateCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isAdmin;
  const TemplateCard({
    super.key,
    required this.data,
    required this.isAdmin,
  });

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  final StorageService _storageService = StorageService();
  bool isExpanded = false; // Untuk toggle tata letak

  @override
  void initState() {
    super.initState();
  }

  void navigateToDetailPage(BuildContext context, Map<String, dynamic> data) {
    final String newsId = data['id'];

    print('Navigating to detail page with ID: $newsId');

    context.go('/anichekku/$newsId', extra: data);
  }

  Future<String?> getPosters() async {
    List<dynamic> posters = widget.data['posters'];
    var mainPoster = posters.firstWhere(
      (poster) => poster['is_main'] == true,
      orElse: () => null,
    );
    if (mainPoster != null && mainPoster['url'] != null) {
      return mainPoster['url']; // Gunakan poster utama
    } else {
      return null; // Tidak ada poster utama
    }
  }

  // Fungsi untuk mencari tag yang formatnya "Musim + Spasi + Tahun (4 digit)"
  String? _getSeasonTag() {
    final List<dynamic>? tags = widget.data['tags'];
    if (tags == null || tags.isEmpty) return null;

    // RegEx: (Winter|Spring|Summer|Fall) diikuti 1 spasi atau lebih, lalu 4 angka
    // caseSensitive: false agar bisa mendeteksi "spring 2026" maupun "Spring 2026"
    final regex = RegExp(r'^(Winter|Spring|Summer|Fall)\s+\d{4}$', caseSensitive: false);

    for (var tag in tags) {
      final tagString = tag.toString().trim();
      if (regex.hasMatch(tagString)) {
        return tagString; // Kembalikan tag jika cocok (misal: "Winter 2026")
      }
    }
    return null; // Jika tidak ada yang cocok
  }

  // Fungsi murni untuk merender Tag / Genre (Maksimal 2 buah)
  List<Widget> _buildTagsAndGenres(BuildContext context, int maxItems) {
    final bool isScheduled = widget.data['is_scheduled'] == true;
    final List<dynamic> rawList = isScheduled
        ? (widget.data['genres'] ?? [])
        : (widget.data['tags'] ?? []);

    final String? seasonTag = _getSeasonTag();

    // Bersihkan data: Hapus yang kosong dan sembunyikan tag musim dari daftar genre
    final List<String> items = rawList
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != seasonTag?.toLowerCase())
        .toList();

    List<Widget> widgets = [];

    // Masukkan Genre / Tag biasa
    for (int i = 0; i < items.length && i < maxItems; i++) {
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            items[i],
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Indikator sisa tag
    if (items.length > maxItems) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            '+${items.length - maxItems}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  void toggleLayout() {
    setState(() {
      isExpanded = !isExpanded; // Toggle antara Row dan Column
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300), // Animasi transisi
      child: isExpanded
          ? buildExpandedLayout() // Jika diklik, ubah menjadi Column
          : buildCompactLayout(), // Layout awal (Row)
    );
  }

  Widget buildCompactLayout() {
    return Row(
      // Change to Row
      key: const ValueKey("rowLayout"),
      crossAxisAlignment: CrossAxisAlignment.center, // Align items to the top
      children: [
        // Image on the left
        if (widget.data['is_postered'] == true)
          GestureDetector(
            onTap: toggleLayout, // Klik gambar untuk expand
            child: Hero(
              tag: widget.data['title'] +
                  widget.data['date'], // Hero animation identifier
              child: FutureBuilder<String?>(
                future: widget.data['posters'] != null
                    ? getPosters()
                    : _storageService
                    .getImageUrl('anichekku', widget.data['title']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  } else if (snapshot.hasData &&
                      snapshot.data != null) {
                    return Image.network(
                      width: 120.0,
                      height: 150.0,
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  } else {
                    return const SizedBox();
                  }
                },
              ),
            ),
          )
        else
          const SizedBox(), // Placeholder for no image
        // Content on the right
        Expanded(
          // Use Expanded to take the remaining space
          child: GestureDetector(
            onTap: widget.data['is_postered'] == true || widget.isAdmin == true
                ? () => navigateToDetailPage(context, widget.data)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    widget.data['title'].replaceAll('\\n', '\n'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize:
                          widget.data['is_postered'] == true ? 18.0 : 22.0,
                      fontWeight: FontWeight.w400,
                    ),
                    softWrap: true,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: _buildTagsAndGenres(context, 3),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Tanggal
                      if (widget.data['date'] != null && widget.data['date'].toString().trim().isNotEmpty)
                        Row(
                          children: [
                            Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              widget.data['date'],
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(), // Placeholder jika tidak ada tanggal

                      // Badge Musim (Terpisah di kanan)
                      if (_getSeasonTag() != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5)),
                          ),
                          child: Text(
                            _getSeasonTag()!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildExpandedLayout() {
    return Column(
      key: const ValueKey("columnLayout"), // Key untuk animasi transisi
      crossAxisAlignment: CrossAxisAlignment.center, // Align items to the top
      children: [
        // Image on the left
        if (widget.data['is_postered'] == true)
          GestureDetector(
            onTap: toggleLayout, // Klik gambar untuk expand
            child: Hero(
              tag: widget.data['title'] +
                  widget.data['date'], // Hero animation identifier
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: FutureBuilder<String?>(
                  future: widget.data['posters'] != null
                      ? getPosters()
                      : _storageService
                      .getImageUrl('anichekku', widget.data['title']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    } else if (snapshot.hasData &&
                        snapshot.data != null) {
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    } else {
                      return const SizedBox();
                    }
                  },
                ),
              ),
            ),
          )
        else
          const SizedBox(), // Placeholder for no image
        // Content on the right
        GestureDetector(
          onTap: widget.data['is_postered'] == true || widget.isAdmin == true
              ? () => navigateToDetailPage(context, widget.data)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  widget.data['title'].replaceAll('\\n', '\n'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: widget.data['is_postered'] == true ? 18.0 : 22.0,
                    fontWeight: FontWeight.w400,
                  ),
                  softWrap: true,
                  maxLines: 2,
                ),
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _buildTagsAndGenres(context, 6),
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Tanggal
                    if (widget.data['date'] != null && widget.data['date'].toString().trim().isNotEmpty)
                      Row(
                        children: [
                          Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.outline
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            widget.data['date'],
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(), // Placeholder jika tidak ada tanggal

                    // Badge Musim (Terpisah di kanan)
                    if (_getSeasonTag() != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5)),
                        ),
                        child: Text(
                          _getSeasonTag()!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
    );
  }
}
