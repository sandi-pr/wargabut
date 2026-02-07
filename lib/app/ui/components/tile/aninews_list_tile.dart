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
              child: SizedBox(
                width: 120,
                height: 140,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      widget.data['date'] == null || widget.data['date'] == ''
                          ? const SizedBox()
                          : ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                elevation: 2.0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
                                widget.data['date'],
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    widget.data['date'] == null || widget.data['date'] == ''
                        ? const SizedBox()
                        : ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              elevation: 2.0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 8.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(
                              widget.data['date'],
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
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
