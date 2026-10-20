import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:wargabut/app/config/api_keys.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:wargabut/app/provider/aninews_provider.dart';

class CrawlScheduledAnimePage extends StatefulWidget {
  const CrawlScheduledAnimePage({super.key});

  @override
  State<CrawlScheduledAnimePage> createState() => _CrawlScheduledAnimePageState();
}

class _CrawlScheduledAnimePageState extends State<CrawlScheduledAnimePage> {
  final TextEditingController _urlController = TextEditingController();

  String _selectedSeason = 'fall';
  int _selectedYear = 2026;
  String _sortBy = 'popular'; // 'popular', 'date', 'title'
  bool _translateWithAI = false;
  bool _hideAlreadyImported = false;

  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _crawledAnimes = [];
  Set<String> _existingUrls = {};
  Set<String> _existingTitles = {};

  bool _isBatchProcessing = false;
  int _currentProcessIndex = 0;
  int _totalProcessCount = 0;
  String _currentProcessName = '';

  final List<String> _seasons = ['winter', 'spring', 'summer', 'fall'];
  final List<int> _years = [2024, 2025, 2026, 2027];

  @override
  void initState() {
    super.initState();
    // Default URL Fall 2026
    _syncUrlFromSeasonYear();
    _fetchAnimes();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _syncUrlFromSeasonYear() {
    _urlController.text = 'https://myanimelist.net/anime/season/$_selectedYear/$_selectedSeason';
  }

  void _syncSeasonYearFromUrl(String url) {
    final reg = RegExp(r'season/(\d{4})/(winter|spring|summer|fall)', caseSensitive: false);
    final match = reg.firstMatch(url);
    if (match != null) {
      setState(() {
        _selectedYear = int.tryParse(match.group(1)!) ?? _selectedYear;
        _selectedSeason = match.group(2)!.toLowerCase();
      });
    }
  }

  String _formatDateToId(String rawDate) {
    if (rawDate.trim().isEmpty) return '';
    String date = rawDate.trim();
    // Match "Oct 2, 2026"
    final match = RegExp(r'([A-Za-z]+)\s+(\d+),\s+(\d{4})').firstMatch(date);
    if (match != null) {
      date = '${match.group(2)} ${match.group(1)} ${match.group(3)}';
    }
    // Ganti nama bulan bahasa Inggris ke bahasa Indonesia
    final months = {
      'Jan': 'Jan', 'Feb': 'Feb', 'Mar': 'Mar', 'Apr': 'Apr',
      'May': 'Mei', 'Jun': 'Jun', 'Jul': 'Jul', 'Aug': 'Agu',
      'Sep': 'Sep', 'Oct': 'Okt', 'Nov': 'Nov', 'Dec': 'Des',
    };
    months.forEach((en, id) {
      date = date.replaceAll(en, id);
    });
    return date;
  }

  Future<void> _fetchAnimes() async {
    final targetUrl = _urlController.text.trim();
    if (targetUrl.isEmpty) return;

    _syncSeasonYearFromUrl(targetUrl);

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _crawledAnimes = [];
    });

    try {
      final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(targetUrl)}';

      http.Response response;
      try {
        response = await http.get(Uri.parse(proxyUrl));
        if (response.statusCode != 200) {
          // Fallback direct request
          response = await http.get(Uri.parse(targetUrl));
        }
      } catch (_) {
        response = await http.get(Uri.parse(targetUrl));
      }

      if (response.statusCode != 200) {
        throw Exception('Gagal memuat halaman MyAnimeList (Status: ${response.statusCode})');
      }

      final document = parse(response.body);
      final animeCards = document.querySelectorAll('.seasonal-anime.js-seasonal-anime');

      if (animeCards.isEmpty) {
        throw Exception('Tidak ada anime ditemukan di halaman tersebut.');
      }

      final seasonLabel = '${_selectedSeason[0].toUpperCase()}${_selectedSeason.substring(1)} $_selectedYear';

      List<Map<String, dynamic>> parsedList = [];

      for (var card in animeCards) {
        final titleAnchor = card.querySelector('a.link-title');
        final title = titleAnchor?.text.trim() ?? '';
        final url = titleAnchor?.attributes['href'] ?? '';
        if (title.isEmpty) continue;

        // Skip restricted categories
        final lowerTitle = title.toLowerCase();
        if (lowerTitle.contains('erotica') ||
            lowerTitle.contains('hentai') ||
            lowerTitle.contains('yaoi') ||
            lowerTitle.contains('yuri')) {
          continue;
        }

        // 1. Members count (angka murni dari span.js-members)
        final membersSpan = card.querySelector('span.js-members');
        final membersCount = int.tryParse(membersSpan?.text.trim() ?? '') ?? 0;

        // 2. Members formatted (format singkat seperti "139K" dari .scormem-item.member)
        final membersFormattedElem = card.querySelector('.scormem-item.member');
        String membersFormatted = membersFormattedElem?.text.trim() ?? '';
        if (membersFormatted.isEmpty) {
          if (membersCount >= 1000) {
            membersFormatted = '${(membersCount / 1000).toStringAsFixed(membersCount >= 10000 ? 0 : 1)}K';
          } else {
            membersFormatted = '$membersCount';
          }
        }

        // 3. Score
        final scoreElem = card.querySelector('.scormem-item.score');
        final score = scoreElem?.text.trim() ?? 'N/A';

        // 4. Tanggal rilis
        final dateElem = card.querySelector('.prodsrc .info .item');
        final rawDate = dateElem?.text.trim() ?? '';
        final dateId = _formatDateToId(rawDate);

        // Angka tanggal rilis untuk sorting (format YYYYMMDD)
        final startDateSpan = card.querySelector('span.js-start_date');
        final startDateNum = startDateSpan?.text.trim() ?? '';

        // 5. Gambar sampul poster
        final imgElem = card.querySelector('.image img');
        String imgUrl = imgElem?.attributes['src'] ?? imgElem?.attributes['data-src'] ?? '';
        if (imgUrl.contains('/r/')) {
          imgUrl = imgUrl.replaceAll(RegExp(r'/r/\d+x\d+'), '').split('?').first;
        }
        // Upgrade langsung ke format resolusi tinggi resmi MyAnimeList (...l.jpg)
        if (imgUrl.contains('/images/anime/')) {
          final lastDot = imgUrl.lastIndexOf('.');
          if (lastDot != -1) {
            final base = imgUrl.substring(0, lastDot);
            if (!base.endsWith('l')) {
              imgUrl = '${base}l.jpg';
            }
          }
        }

        // 6. Genres & Themes
        final genreElems = card.querySelectorAll('.genres-inner .genre a');
        final genres = genreElems.map((g) => g.text.trim()).toList();

        // 7. Studio
        final studioElem = card.querySelector('.properties .property span.item a');
        final studio = studioElem?.text.trim() ?? '';
        List<String> studios = studio.isNotEmpty ? [studio] : [];

        // 8. Source
        final sourceElem = card.querySelector('.properties .property:nth-child(2) span.item') ??
            card.querySelector('.property span.item');
        final source = sourceElem?.text.trim() ?? '';

        // 9. Themes
        final themeElems = card.querySelectorAll('.properties .property a[href*="/genre/"]');
        List<String> themes = themeElems
            .map((t) => t.text.trim())
            .where((t) => !genres.contains(t))
            .toList();

        // 10. Sinopsis
        final synopsisElem = card.querySelector('.synopsis .preline');
        String synopsis = synopsisElem?.text.trim() ?? '';
        if (synopsis.contains('(Source:')) {
          final lastParen = synopsis.lastIndexOf('(Source:');
          if (lastParen != -1) {
            synopsis = synopsis.substring(0, lastParen).trim();
          }
        }

        parsedList.add({
          'title': title,
          'url': url,
          'members': membersCount,
          'members_formatted': membersFormatted,
          'score': score,
          'date': dateId,
          'raw_date': rawDate,
          'start_date_num': startDateNum,
          'img_url': imgUrl,
          'genres': genres,
          'themes': themes,
          'studios': studios,
          'source': source,
          'synopsis': synopsis,
          'premiered': seasonLabel,
          'tags': [seasonLabel, ...themes],
        });
      }

      _crawledAnimes = parsedList;
      _sortCrawledAnimes();
      await _checkExistingAnimes();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortCrawledAnimes() {
    if (_sortBy == 'popular') {
      _crawledAnimes.sort((a, b) {
        final aMem = (a['members'] as int?) ?? 0;
        final bMem = (b['members'] as int?) ?? 0;
        return bMem.compareTo(aMem); // Terbanyak di atas
      });
    } else if (_sortBy == 'date') {
      _crawledAnimes.sort((a, b) {
        final aDate = a['start_date_num']?.toString() ?? '';
        final bDate = b['start_date_num']?.toString() ?? '';
        if (aDate.isEmpty && bDate.isEmpty) return 0;
        if (aDate.isEmpty) return 1;
        if (bDate.isEmpty) return -1;
        return aDate.compareTo(bDate);
      });
    } else if (_sortBy == 'title') {
      _crawledAnimes.sort((a, b) {
        final aTitle = a['title']?.toString().toLowerCase() ?? '';
        final bTitle = b['title']?.toString().toLowerCase() ?? '';
        return aTitle.compareTo(bTitle);
      });
    }
  }

  Future<void> _checkExistingAnimes() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('anichekku').get();
      Set<String> existingUrls = {};
      Set<String> existingTitles = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('source_url')) {
          existingUrls.add(data['source_url'].toString().trim());
        }
        if (data.containsKey('title')) {
          existingTitles.add(data['title'].toString().trim().toLowerCase());
        }
      }

      setState(() {
        _existingUrls = existingUrls;
        _existingTitles = existingTitles;
      });
    } catch (e) {
      debugPrint('Gagal mengecek anime dari Firestore: $e');
    }
  }

  String _createSlugFromName(String name) {
    String slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), '').replaceAll(RegExp(r'\s+'), '-');
    if (slug.trim().isEmpty) {
      slug = 'anime_${DateTime.now().millisecondsSinceEpoch}';
    }
    return slug;
  }

  String _toHighResMalImage(String url) {
    if (url.isEmpty) return '';
    if (url.contains('/images/anime/')) {
      final lastDot = url.lastIndexOf('.');
      if (lastDot != -1) {
        final base = url.substring(0, lastDot);
        if (!base.endsWith('l')) {
          return '${base}l.jpg';
        }
      }
    }
    return url;
  }

  Future<List<String>> _fetchHdPosters(String mainImgUrl, String animeUrl) async {
    List<String> posterUrls = [];

    // 1. Tambahkan poster utama beresolusi tinggi (...l.jpg)
    String mainHd = _toHighResMalImage(mainImgUrl);
    if (mainHd.isNotEmpty) {
      posterUrls.add(mainHd);
    }

    // 2. Ambil poster-poster HD lainnya dari halaman /pics resmi MyAnimeList
    if (animeUrl.isNotEmpty) {
      try {
        final cleanUrl = animeUrl.replaceAll(RegExp(r'/+$'), '');
        final picsUrl = '$cleanUrl/pics';
        final proxyPicsUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(picsUrl)}';
        final res = await http.get(Uri.parse(proxyPicsUrl)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final regex = RegExp(r'https://cdn\.myanimelist\.net/images/anime/\d+/\d+l\.(?:jpg|webp)');
          final matches = regex.allMatches(res.body);
          for (final m in matches) {
            final foundUrl = m.group(0);
            if (foundUrl != null && !posterUrls.contains(foundUrl)) {
              posterUrls.add(foundUrl);
            }
            if (posterUrls.length >= 4) break; // Batasi maksimal 4 poster resmi HD terbaik
          }
        }
      } catch (e) {
        debugPrint('Gagal fetch poster dari /pics untuk $animeUrl: $e');
      }
    }

    return posterUrls;
  }

  Future<Uint8List?> _downloadImageBytes(String imageUrl) async {
    // 1. Coba download via Cloud Function Proxy (Bebas kendala CORS di Flutter Web)
    try {
      final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(imageUrl)}';
      final res = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error proxy download image: $e');
    }

    // 2. Direct fetch fallback
    try {
      final res = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}

    return null;
  }

  Future<String> _translateSynopsis(String rawSynopsis) async {
    if (rawSynopsis.trim().isEmpty) return rawSynopsis;

    final candidateModels = [
      'gemini-flash-lite-latest',
      'gemini-flash-latest',
      'gemini-2.0-flash-lite',
      'gemini-2.5-flash',
    ];

    final prompt = '''
Terjemahkan sinopsis anime berikut ke Bahasa Indonesia yang mengalir, rapi, dan menarik untuk dibaca.
Hanya berikan teks terjemahannya saja langsung tanpa kata pengantar, tanpa tanda kutip pembuka/penutup, dan tanpa catatan tambahan apapun.

Sinopsis:
$rawSynopsis
''';

    for (final modelName in candidateModels) {
      try {
        debugPrint('Mencoba terjemahan dengan model: $modelName');
        final genModel = GenerativeModel(
          model: modelName,
          apiKey: ApiKeys.geminiApiKey,
        );
        final result = await genModel.generateContent([Content.text(prompt)]);
        String? text = result.text?.trim();
        if (text != null && text.isNotEmpty) {
          if (text.startsWith('"') && text.endsWith('"') && text.length > 2) {
            text = text.substring(1, text.length - 1).trim();
          }
          debugPrint('Terjemahan berhasil dengan model $modelName');
          return text;
        }
      } catch (e) {
        debugPrint('Model $modelName error/quota: $e');
      }
    }

    return rawSynopsis;
  }

  Future<bool> _importSingleAnime(
    Map<String, dynamic> anime, {
    StorageService? storage,
  }) async {
    final storageService = storage ?? StorageService();
    final title = anime['title'] ?? 'Unknown';
    final url = anime['url']?.toString() ?? '';
    final imgUrl = anime['img_url']?.toString() ?? '';
    final rawSynopsis = anime['synopsis']?.toString() ?? '';

    // 1. Terjemahkan dengan AI jika toggle aktif
    String desc = rawSynopsis;
    if (_translateWithAI && rawSynopsis.isNotEmpty) {
      desc = await _translateSynopsis(rawSynopsis);
    }

    // 2. Ambil daftar poster resolusi tinggi (dari poster utama & halaman /pics)
    final posterUrls = await _fetchHdPosters(imgUrl, url);
    List<XFile> xFilesToUpload = [];

    for (int i = 0; i < posterUrls.length; i++) {
      final pUrl = posterUrls[i];
      final bytes = await _downloadImageBytes(pUrl);
      if (bytes != null) {
        final ext = pUrl.toLowerCase().contains('.png') ? '.png' : '.jpg';
        xFilesToUpload.add(XFile.fromData(
          bytes,
          name: 'poster_${DateTime.now().millisecondsSinceEpoch}_$i$ext',
        ));
      }
    }

    // 3. Upload ke Firebase Storage
    List<Map<String, dynamic>> finalPosters = [];
    if (xFilesToUpload.isNotEmpty) {
      try {
        final uploaded = await storageService.uploadImages(xFilesToUpload, 'anichekku', title);
        if (uploaded.isNotEmpty) {
          for (int i = 0; i < uploaded.length; i++) {
            uploaded[i]['is_main'] = (i == 0);
            uploaded[i]['order'] = i;
          }
          finalPosters.addAll(uploaded);
        }
      } catch (e) {
        debugPrint('Error uploading poster for $title: $e');
      }
    }

    String slug = _createSlugFromName(title);

    await FirebaseFirestore.instance.collection('anichekku').doc(slug).set({
      'title': title,
      'date': anime['date'] ?? '',
      'desc': desc,
      'tags': anime['tags'] ?? [],
      'genres': anime['genres'] ?? [],
      'studios': anime['studios'] ?? [],
      'source': anime['source'] ?? '',
      'type': 'TV (New)',
      'premiered': anime['premiered'] ?? '',
      'members': anime['members'] ?? 0,
      'members_formatted': anime['members_formatted'] ?? '',
      'score': anime['score'] ?? 'N/A',
      'is_postered': finalPosters.isNotEmpty,
      if (finalPosters.isNotEmpty) 'posters': finalPosters,
      'is_scheduled': true,
      'created_at': DateTime.now(),
      'expire_at': DateTime.now().add(const Duration(days: 90)),
      'source_url': url,
    }, SetOptions(merge: true));

    return true;
  }

  Future<void> _importIndividualAnime(Map<String, dynamic> anime, {bool isUpdate = false}) async {
    final title = anime['title'] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isUpdate ? 'Mengupdate data & poster HD "$title"...' : 'Mengimport "$title"...')),
    );

    try {
      await _importSingleAnime(anime);
      if (mounted) {
        setState(() {
          if (anime['url'] != null) _existingUrls.add(anime['url']);
          _existingTitles.add(title.toLowerCase());
        });
        context.read<AniNewsProvider>().fetchData(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isUpdate ? 'Berhasil memperbarui "$title" dengan poster HD & terjemahan!' : 'Berhasil mengimport "$title"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  Future<void> _importAllNewAnimes() async {
    final newAnimes = _crawledAnimes.where((e) {
      final url = e['url']?.toString() ?? '';
      final title = (e['title']?.toString() ?? '').toLowerCase();
      return !_existingUrls.contains(url) && !_existingTitles.contains(title);
    }).toList();

    if (newAnimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua anime sudah ada di database!')),
      );
      return;
    }

    setState(() {
      _isBatchProcessing = true;
      _totalProcessCount = newAnimes.length;
      _currentProcessIndex = 0;
    });

    final storageService = StorageService();
    int successCount = 0;

    for (int i = 0; i < newAnimes.length; i++) {
      final anime = newAnimes[i];
      final title = anime['title'] ?? 'Unknown Anime';

      setState(() {
        _currentProcessIndex = i + 1;
        _currentProcessName = title;
      });

      try {
        final ok = await _importSingleAnime(anime, storage: storageService);
        if (ok) {
          successCount++;
          if (anime['url'] != null) _existingUrls.add(anime['url']);
          _existingTitles.add(title.toLowerCase());
        }
      } catch (e) {
        debugPrint('Error memproses anime $title: $e');
      }
    }

    setState(() {
      _isBatchProcessing = false;
    });

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      await context.read<AniNewsProvider>().fetchData(forceRefresh: true);
      messenger.showSnackBar(
        SnackBar(content: Text('Berhasil mengimport $successCount anime!')),
      );
    }
  }

  bool _isAnimeExists(Map<String, dynamic> anime) {
    final url = anime['url']?.toString() ?? '';
    final title = (anime['title']?.toString() ?? '').toLowerCase();
    return _existingUrls.contains(url) || _existingTitles.contains(title);
  }

  @override
  Widget build(BuildContext context) {
    final displayedAnimes = _hideAlreadyImported
        ? _crawledAnimes.where((a) => !_isAnimeExists(a)).toList()
        : _crawledAnimes;

    final unimportedCount = _crawledAnimes.where((a) => !_isAnimeExists(a)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crawl Jadwal Anime (MAL)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh / Crawl Ulang',
            onPressed: _isLoading || _isBatchProcessing ? null : _fetchAnimes,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Panel Kontrol: Input URL, Musim & Tahun
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris Input URL
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'URL MyAnimeList Seasonal',
                            hintText: 'https://myanimelist.net/anime/season/2026/fall',
                            prefixIcon: const Icon(Icons.link),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (_) => _fetchAnimes(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isLoading || _isBatchProcessing ? null : _fetchAnimes,
                        icon: const Icon(Icons.search),
                        label: const Text('Crawl'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick Season & Year Selector Chips
                  Row(
                    children: [
                      const Text(
                        'Musim:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _seasons.map((season) {
                              final isSelected = _selectedSeason == season;
                              final seasonName = '${season[0].toUpperCase()}${season.substring(1)}';
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(seasonName),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedSeason = season;
                                        _syncUrlFromSeasonYear();
                                      });
                                      _fetchAnimes();
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Text(
                        'Tahun:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _years.map((year) {
                              final isSelected = _selectedYear == year;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text('$year'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedYear = year;
                                        _syncUrlFromSeasonYear();
                                      });
                                      _fetchAnimes();
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Bar Opsi Sortir & Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Total
                Text(
                  '${_crawledAnimes.length} Anime ($unimportedCount belum diimport)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),

                // Controls dalam Wrap agar responsive dan tidak pernah overflow
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Sort Dropdown
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Urutkan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        DropdownButton<String>(
                          value: _sortBy,
                          isDense: true,
                          underline: const SizedBox(),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                          items: const [
                            DropdownMenuItem(
                              value: 'popular',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text('Populer (Members)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'date',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today, size: 15, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text('Tanggal Rilis'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'title',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text('Judul (A-Z)'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _sortBy = val;
                                _sortCrawledAnimes();
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    // Filter toggle sembunyikan yang sudah ada
                    FilterChip(
                      label: const Text('Belum Diimport Saja', style: TextStyle(fontSize: 11)),
                      selected: _hideAlreadyImported,
                      onSelected: (v) => setState(() => _hideAlreadyImported = v),
                    ),

                    // Toggle AI Translation
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Terjemahkan AI', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Switch(
                          value: _translateWithAI,
                          onChanged: (v) => setState(() => _translateWithAI = v),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. Grid Daftar Anime
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _fetchAnimes,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : displayedAnimes.isEmpty
                        ? const Center(child: Text('Tidak ada anime yang sesuai.'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 320,
                              childAspectRatio: 0.68,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: displayedAnimes.length,
                            itemBuilder: (context, index) {
                              final anime = displayedAnimes[index];
                              final title = anime['title'] ?? 'No Title';
                              final posterUrl = anime['img_url']?.toString() ?? '';
                              final isExists = _isAnimeExists(anime);
                              final membersFormatted = anime['members_formatted']?.toString() ?? '';
                              final dateStr = anime['date']?.toString() ?? '';
                              final studio = (anime['studios'] as List<dynamic>?)?.isNotEmpty == true
                                  ? anime['studios'][0]
                                  : '';
                              final genres = (anime['genres'] as List<dynamic>? ?? []).take(2).toList();
                              final score = anime['score']?.toString() ?? 'N/A';

                              return Card(
                                clipBehavior: Clip.antiAlias,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: isExists
                                      ? BorderSide(color: Colors.grey.shade400)
                                      : BorderSide.none,
                                ),
                                color: isExists ? Colors.grey.shade100 : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Bagian Gambar (Mengambil ruang atas, sejajar dari atas agar wajah karakter tidak terpotong)
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          posterUrl.isNotEmpty
                                              ? Image.network(
                                                  posterUrl,
                                                  fit: BoxFit.cover,
                                                  alignment: Alignment.topCenter,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(Icons.broken_image, size: 40),
                                                )
                                              : const Icon(Icons.image, size: 40),

                                          // Badge Members (Top-Right)
                                          if (membersFormatted.isNotEmpty)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.75),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.white24),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.person, size: 14, color: Colors.blueAccent),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      membersFormatted,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                          // Score Badge (Top-Left)
                                          if (score != 'N/A' && score != '0')
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade700,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.star, size: 12, color: Colors.white),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      score,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                          // Overlay Jika Sudah Ada di Database
                                          if (isExists)
                                            Container(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              alignment: Alignment.center,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade700,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'SUDAH DIIMPORT',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Bagian Info Text (Kompak dan pas, tanpa ruang kosong berlebih)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isExists ? Colors.grey.shade600 : null,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),

                                          // Tanggal & Studio
                                          Row(
                                            children: [
                                              if (dateStr.isNotEmpty) ...[
                                                const Icon(Icons.calendar_today_outlined, size: 11, color: Colors.blue),
                                                const SizedBox(width: 3),
                                                Text(
                                                  dateStr,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue),
                                                ),
                                              ],
                                              if (studio.isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '• $studio',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),

                                          // Baris Bawah: Genre Chips di Kiri, Tombol Import di Kanan
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Genre Chips
                                              Expanded(
                                                child: genres.isNotEmpty
                                                    ? Wrap(
                                                        spacing: 4,
                                                        runSpacing: 2,
                                                        children: genres.map((g) => Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey.shade200,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            g.toString(),
                                                            style: TextStyle(fontSize: 9, color: Colors.grey.shade800),
                                                          ),
                                                        )).toList(),
                                                      )
                                                    : const SizedBox(),
                                              ),
                                              const SizedBox(width: 4),

                                              // Tombol Import Satuan / Status Update Jika Sudah Ada
                                              isExists
                                                  ? SizedBox(
                                                      height: 26,
                                                      child: OutlinedButton(
                                                        onPressed: _isBatchProcessing ? null : () => _importIndividualAnime(anime, isUpdate: true),
                                                        style: OutlinedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                                          visualDensity: VisualDensity.compact,
                                                          side: BorderSide(color: Colors.green.shade600),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.refresh, size: 12, color: Colors.green.shade700),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'Update',
                                                              style: TextStyle(
                                                                color: Colors.green.shade700,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )
                                                  : SizedBox(
                                                      height: 26,
                                                      child: FilledButton.tonal(
                                                        onPressed: _isBatchProcessing ? null : () => _importIndividualAnime(anime),
                                                        style: FilledButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.add, size: 13),
                                                            SizedBox(width: 2),
                                                            Text(
                                                              'Import',
                                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),

          // 4. Progress Indicator jika Batch Import sedang berjalan
          if (_isBatchProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mengimport: $_currentProcessName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _totalProcessCount > 0 ? _currentProcessIndex / _totalProcessCount : null,
                  ),
                  const SizedBox(height: 6),
                  Text('$_currentProcessIndex / $_totalProcessCount anime'),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _isBatchProcessing || _crawledAnimes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _importAllNewAnimes,
              icon: const Icon(Icons.download),
              label: Text('Import Semua ($unimportedCount)'),
            ),
    );
  }
}
