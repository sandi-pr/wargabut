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

class EventListTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const EventListTile({
    super.key,
    required this.data,
  });

  @override
  State<EventListTile> createState() => _EventListTileState();
}

class _EventListTileState extends State<EventListTile> {
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndAdminStatus();
  }

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(widget.data['event_link']);

    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  final minio = Minio(
    endPoint: 'is3.cloudhost.id',
    accessKey: 'DDSMHQO0Q07A29VFR4R7',
    secretKey: 'WXMBoEj6zlClflAhDcTvw9u8sJzYCAqBavLBToqE',
    useSSL: true,
  );

  Future<Uint8List> fetchImageFromMinio() async {
    if (kDebugMode) {
      print("Start fetch image");
    }
    try {
      final stream = await minio.getObject(
        'jeventku',
        '${widget.data['event_name']}.jpg', // Gunakan data['event_name']
      );
      if (kDebugMode) {
        print("Start process image");
      }
      final List<int> byteList =
          (await stream.toList()).expand((chunk) => chunk).toList();
      if (kDebugMode) {
        print("Success fetch image");
      }
      return Uint8List.fromList(byteList);
    } catch (e) {
      if (kDebugMode) {
        print('error fetch image from minio: $e');
      }
      return Uint8List(10);
    }
  }

  Future<void> _checkLoginAndAdminStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _isAdmin = prefs.getBool('isAdmin') ?? false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMedpart = widget.data['is_medpart'] ?? false;
    return isMedpart
        ? Card.outlined(
            clipBehavior: Clip.hardEdge,
            child: Banner(
              color: Theme.of(context).colorScheme.primaryContainer,
              shadow: const BoxShadow(
                color: Colors.transparent,
              ),
              textStyle: TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              message: "Medpart",
              location: BannerLocation.topEnd,
              child: InkWell(
                child: TemplateCard(
                  data: widget.data,
                  isAdmin: _isAdmin,
                ),
              ),
            ),
          )
        : Card.outlined(
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
  // bool _isLoggedIn = false;
  // bool _isAdmin = false;
  Uint8List? _cachedImageBytes;
  bool isExpanded = false; // Untuk toggle tata letak

  @override
  void initState() {
    super.initState();
    // _loadCachedImage();
    // _checkLoginAndAdminStatus();
  }

  // Future<void> _checkLoginAndAdminStatus() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  //     _isAdmin = prefs.getBool('isAdmin') ?? false;
  //
  //     print('isLoggedIn: $_isLoggedIn, isAdmin: $_isAdmin');
  //   });
  // }

  void navigateToDetailPage(BuildContext context, Map<String, dynamic> data) {
    // 1. Pastikan 'data' map Anda memiliki 'id' dari dokumen Firestore.
    //    Jika nama kuncinya berbeda, sesuaikan.
    final String eventId = data['id'];

    // 2. Gunakan context.go untuk navigasi dengan go_router.
    //    - Kirim ID di dalam path URL sesuai dengan konfigurasi router.
    //    - Kirim seluruh map 'data' melalui parameter 'extra'.
    context.go('/jeventku/$eventId', extra: data);
  }

  Future<void> _loadCachedImage() async {
    if (widget.data['is_postered'] == true) {
      final cachedImage =
          await _storageService.getCachedImage(widget.data['event_name']);
      if (cachedImage != null) {
        print('Loaded cached image for ${widget.data['event_name']}');
        setState(() {
          _cachedImageBytes = cachedImage;
        });
      }
    }
  }

  Future<void> _cacheNetworkImage(String imageUrl, String eventName) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        _storageService.cacheImage(eventName, response.bodyBytes);
        print('Successfully cached image');
      } else {
        print('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error caching image: $e');
    }
  }

  Future<Uint8List?> fetchImageAsBytes(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes; // Mengembalikan data sebagai Uint8List
      } else {
        print("Failed to load image: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching image: $e");
      return null;
    }
  }

  String createPlaceholderAvatar(String organizer) {
    List<String> words = organizer.split(' ');
    List<String> initials = words.map((word) => word[0]).toList();

    initials = initials.sublist(0, 2);

    return initials.join('');
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
              tag: widget.data['event_name'] +
                  widget.data['date'], // Hero animation identifier
              child: SizedBox(
                width: 120,
                height: 140,
                child: _cachedImageBytes != null
                    ? Image.memory(
                        _cachedImageBytes!,
                        fit: BoxFit.cover,
                      )
                    : FutureBuilder<String?>(
                        future: widget.data['posters'] != null
                            ? getPosters()
                            : _storageService
                                .getImageUrl(widget.data['event_name']),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasData &&
                              snapshot.data != null) {
                            // Cache the image
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              fetchImageAsBytes(snapshot.data!).then((bytes) {
                                if (bytes != null) {
                                  // _cacheNetworkImage(snapshot.data!,
                                  //     widget.data['event_name']);
                                }
                              });
                              // _cacheNetworkImage(snapshot.data!, widget.data['event_name']);
                            });
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
                    widget.data['event_name'].replaceAll('\\n', '\n'),
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
                              // onPressed: () {
                              //   // Dapatkan instance EventProvider dari context
                              //   final eventProvider =
                              //       Provider.of<EventProvider>(context,
                              //           listen: false);
                              //
                              //   // Atur _searchTerm dengan nilai data['date']
                              //   eventProvider
                              //       .setSearchTerm(widget.data['date']);
                              //
                              //   // _filterEvents() akan otomatis dipanggil di dalam setSearchTerm
                              //   // karena kita sudah memanggil notifyListeners() di dalam setSearchTerm
                              // },
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
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: AutoSizeText(
                          widget.data['location'],
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.end,
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
              tag: widget.data['event_name'] +
                  widget.data['date'], // Hero animation identifier
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: _cachedImageBytes != null
                    ? Image.memory(
                        _cachedImageBytes!,
                        fit: BoxFit.cover,
                      )
                    : FutureBuilder<String?>(
                        future: widget.data['posters'] != null
                            ? getPosters()
                            : _storageService
                                .getImageUrl(widget.data['event_name']),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasData &&
                              snapshot.data != null) {
                            // Cache the image
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              fetchImageAsBytes(snapshot.data!).then((bytes) {
                                if (bytes != null) {
                                  // _cacheNetworkImage(snapshot.data!,
                                  //     widget.data['event_name']);
                                }
                              });
                              // _cacheNetworkImage(snapshot.data!, widget.data['event_name']);
                            });
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
                  widget.data['event_name'].replaceAll('\\n', '\n'),
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
                            // onPressed: () {
                            //   // Dapatkan instance EventProvider dari context
                            //   final eventProvider = Provider.of<EventProvider>(
                            //       context,
                            //       listen: false);
                            //
                            //   // Atur _searchTerm dengan nilai data['date']
                            //   eventProvider.setSearchTerm(widget.data['date']);
                            //
                            //   // _filterEvents() akan otomatis dipanggil di dalam setSearchTerm
                            //   // karena kita sudah memanggil notifyListeners() di dalam setSearchTerm
                            // },
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
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: AutoSizeText(
                        widget.data['location'],
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.end,
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
