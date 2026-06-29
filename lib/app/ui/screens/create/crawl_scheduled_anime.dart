import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
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
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _crawledAnimes = [];
  Set<String> _existingUrls = {};
  
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;

  bool _isBatchProcessing = false;
  int _currentProcessIndex = 0;
  int _totalProcessCount = 0;
  String _currentProcessName = '';

  @override
  void initState() {
    super.initState();
    _fetchAnimes();
  }

  void _loadMore() {
    if (!_hasNextPage) return;
    _currentPage++;
    _fetchAnimes(isLoadMore: true);
  }

  Future<void> _fetchAnimes({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _currentPage = 1;
        _crawledAnimes = [];
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final now = DateTime.now();
      int month = now.month;
      int year = now.year;
      String targetSeason = '';

      if (month >= 1 && month <= 3) {
        targetSeason = 'spring';
      } else if (month >= 4 && month <= 6) {
        targetSeason = 'summer';
      } else if (month >= 7 && month <= 9) {
        targetSeason = 'fall';
      } else {
        targetSeason = 'winter';
        year = year + 1;
      }

      final targetUrl = 'https://api.jikan.moe/v4/seasons/$year/$targetSeason?page=$_currentPage'; // DIBATASI 6 DULU UNTUK TESTING
      
      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode != 200) throw Exception('Gagal memuat Jikan API');

      final data = json.decode(response.body);
      final List<dynamic> animes = data['data'] ?? [];
      final pagination = data['pagination'] ?? {};
      _hasNextPage = pagination['has_next_page'] ?? false;

      setState(() {
        final List<dynamic> filteredAnimes = [];
        for (var anime in animes) {
          final genres = anime['genres'] as List<dynamic>? ?? [];
          final explicitGenres = anime['explicit_genres'] as List<dynamic>? ?? [];
          final allGenres = [...genres, ...explicitGenres];
          
          bool isRestricted = false;
          for (var g in allGenres) {
            final name = g['name']?.toString().toLowerCase() ?? '';
            if (name == 'erotica' || name == 'boys love' || name == 'hentai' || name == 'yaoi' || name == 'yuri' || name == 'girls love') {
              isRestricted = true;
              break;
            }
          }
          
          if (!isRestricted) {
            filteredAnimes.add(anime);
          }
        }

        if (isLoadMore) {
          for (var anime in filteredAnimes) {
            bool exists = _crawledAnimes.any((existing) => existing['mal_id'] == anime['mal_id'] || existing['title'] == anime['title']);
            if (!exists) {
              _crawledAnimes.add(anime);
            }
          }
        } else {
          _crawledAnimes = [];
          for (var anime in filteredAnimes) {
            bool exists = _crawledAnimes.any((existing) => existing['mal_id'] == anime['mal_id'] || existing['title'] == anime['title']);
            if (!exists) {
              _crawledAnimes.add(anime);
            }
          }
        }
      });

      await _checkExistingAnimes();

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _checkExistingAnimes() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('anichekku').get();
      Set<String> existingUrls = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('source_url')) {
          final url = data['source_url'].toString().trim();
          existingUrls.add(url);
        }
      }

      setState(() {
        _existingUrls = existingUrls;

        _crawledAnimes.sort((a, b) {
          final aUrl = a['url']?.toString() ?? '';
          final bUrl = b['url']?.toString() ?? '';
          final aExists = existingUrls.contains(aUrl);
          final bExists = existingUrls.contains(bUrl);

          if (aExists && !bExists) return 1;
          if (!aExists && bExists) return -1;
          
          return 0;
        });
      });
    } catch (e) {
      print('Gagal mengecek anime dari Firestore: $e');
    }
  }

  String _createSlugFromName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), '').replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _importAllNewAnimes() async {
    final newAnimes = _crawledAnimes.where((e) => !_existingUrls.contains(e['url']?.toString() ?? '')).toList();
    if (newAnimes.isEmpty) return;

    setState(() {
      _isBatchProcessing = true;
      _totalProcessCount = newAnimes.length;
      _currentProcessIndex = 0;
    });

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiKeys.geminiApiKey,
    );
    final storageService = StorageService();

    for (int i = 0; i < newAnimes.length; i++) {
      final anime = newAnimes[i];
      final title = anime['title'] ?? 'Unknown Anime';
      final url = anime['url']?.toString() ?? '';
      
      setState(() {
        _currentProcessIndex = i + 1;
        _currentProcessName = title;
      });

      try {
        // Fetch all pictures
        final malId = anime['mal_id'];
        List<String> imageUrls = [];
        
        // Selalu sertakan poster utama sebagai gambar pertama
        final mainImageUrl = anime['images']?['jpg']?['large_image_url'] ?? anime['images']?['jpg']?['image_url'];
        if (mainImageUrl != null) imageUrls.add(mainImageUrl);

        if (malId != null) {
          try {
            // Delay sedikit agar tidak di-rate-limit Jikan API (maks 3 request per detik)
            await Future.delayed(const Duration(milliseconds: 500));
            final picsResponse = await http.get(Uri.parse('https://api.jikan.moe/v4/anime/$malId/pictures'));
            if (picsResponse.statusCode == 200) {
              final picsData = json.decode(picsResponse.body);
              final List<dynamic> picsList = picsData['data'] ?? [];
              for (var pic in picsList) {
                final picUrl = pic['jpg']?['large_image_url'] ?? pic['jpg']?['image_url'];
                if (picUrl != null && !imageUrls.contains(picUrl)) {
                  imageUrls.add(picUrl);
                }
              }
            }
          } catch (e) {
            print('Gagal memuat ekstra gambar untuk $title: $e');
          }
        }

        // Terjemahkan Synopsis
        final rawSynopsis = anime['synopsis'] ?? '';
        String translatedDesc = '';
        if (rawSynopsis.isNotEmpty) {
          final prompt = '''
Anda adalah penerjemah handal. Terjemahkan sinopsis anime berikut ke dalam Bahasa Indonesia dengan gaya penulisan yang rapi dan menarik.
Hanya kembalikan teks terjemahannya saja, tanpa tambahan kata pengantar.

Sinopsis:
$rawSynopsis
''';
          try {
            final result = await model.generateContent([Content.text(prompt)]);
            translatedDesc = result.text?.trim() ?? rawSynopsis;
          } catch (e) {
            print("ERROR TRANSLATION: $e");
            translatedDesc = rawSynopsis;
          }
        }

        String slug = _createSlugFromName(title);

        List<Map<String, dynamic>> finalPosters = [];
        for (int j = 0; j < imageUrls.length; j++) {
           final imageResponse = await http.get(Uri.parse(imageUrls[j]));
           if (imageResponse.statusCode == 200) {
             final extension = imageUrls[j].toLowerCase().contains('.png') ? '.png' : '.jpg';
             final xFile = XFile.fromData(
               imageResponse.bodyBytes,
               name: 'poster_${DateTime.now().millisecondsSinceEpoch}_$j$extension',
             );
             
             final uploadedPosters = await storageService.uploadImages([xFile], 'anichekku', title);
             
             if (uploadedPosters.isNotEmpty) {
               uploadedPosters[0]['is_main'] = j == 0; // Gambar pertama selalu jadi main
               finalPosters.addAll(uploadedPosters);
             }
           }
        }
        
        List<String> tags = [];
        List<String> genres = [];
        if (anime['genres'] is List) {
           genres = List<String>.from(anime['genres'].map((x) => x['name'].toString()));
        }
        if (anime['themes'] is List) {
           genres.addAll(List<String>.from(anime['themes'].map((x) => x['name'].toString())));
        }
        
        List<String> studios = [];
        if (anime['studios'] is List) {
           studios = List<String>.from(anime['studios'].map((x) => x['name'].toString()));
        }

        String broadcastDate = '';
        if (anime['aired'] != null && anime['aired']['string'] != null) {
           broadcastDate = anime['aired']['string'];
           // Ambil bagian pertama sebelum " to "
           broadcastDate = broadcastDate.split(' to ')[0].trim();
           // Ubah format "Jul 8, 2026" menjadi "8 Jul 2026"
           final match = RegExp(r'([A-Za-z]+)\s(\d+),\s(\d+)').firstMatch(broadcastDate);
           if (match != null) {
              broadcastDate = '${match.group(2)} ${match.group(1)} ${match.group(3)}';
           }
           // Format bulan ke singkatan bahasa Indonesia
           broadcastDate = broadcastDate.replaceAll('May', 'Mei')
                                        .replaceAll('Aug', 'Agu')
                                        .replaceAll('Oct', 'Okt')
                                        .replaceAll('Dec', 'Des');
        }
        
        String premiered = '';
        if (anime['season'] != null && anime['year'] != null) {
            String season = anime['season'].toString();
            String year = anime['year'].toString();
            premiered = '${season[0].toUpperCase()}${season.substring(1)} $year';
            tags.add(premiered);
        }

        await FirebaseFirestore.instance.collection('anichekku').doc(slug).set({
          'title': title,
          'date': broadcastDate,
          'desc': translatedDesc,
          'tags': tags,
          'genres': genres,
          'studios': studios,
          'type': anime['type']?.toString() ?? '',
          'premiered': premiered,
          'is_postered': finalPosters.isNotEmpty,
          'posters': finalPosters,
          'is_scheduled': true, // Selalu true untuk crawler ini
          'created_at': DateTime.now(),
          'expire_at': DateTime.now().add(const Duration(days: 30)), 
          'source_url': url, 
        });

      } catch (e) {
        print('Error memproses anime $title: $e');
      }
    }

    setState(() {
      _isBatchProcessing = false;
    });

    if (mounted) {
      await context.read<AniNewsProvider>().fetchData(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import Jadwal Anime Selesai!')),
      );
      Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crawl Jadwal Anime (Jikan)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnimes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _crawledAnimes.isEmpty
                  ? const Center(child: Text('Tidak ada anime ditemukan.'))
                  : Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _crawledAnimes.length + (_hasNextPage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _crawledAnimes.length) {
                                return Center(
                                  child: _isLoadingMore 
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: _loadMore,
                                        child: Text('Load More (Hal ${_currentPage + 1})'),
                                      ),
                                );
                              }

                              final anime = _crawledAnimes[index];
                              final url = anime['url']?.toString() ?? '';
                              final title = anime['title'] ?? 'No Title';
                              final isExists = _existingUrls.contains(url);
                              final posterUrl = anime['images']?['jpg']?['large_image_url'] ?? '';

                              return Card(
                                clipBehavior: Clip.antiAlias,
                                elevation: 4,
                                color: isExists ? Colors.grey.shade200 : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          posterUrl.isNotEmpty
                                              ? Image.network(
                                                  posterUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, error, ___) {
                                                    return const Icon(Icons.broken_image, size: 50);
                                                  },
                                                )
                                              : const Icon(Icons.image, size: 50),
                                          if (isExists)
                                            Container(
                                              color: Colors.black.withOpacity(0.6),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'SUDAH ADA\nDI DATABASE',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isExists ? Colors.grey : null,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (anime['aired']?['string'] ?? '').replaceAll('May', 'Mei').replaceAll('Aug', 'Agu').replaceAll('Oct', 'Okt').replaceAll('Dec', 'Des'),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: Text(
                                                anime['synopsis'] ?? 'Tidak ada sinopsis.',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                overflow: TextOverflow.fade,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (_isBatchProcessing)
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.blue.shade50,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Mengimport: $_currentProcessName'),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: _currentProcessIndex / _totalProcessCount),
                                const SizedBox(height: 8),
                                Text('$_currentProcessIndex / $_totalProcessCount'),
                              ],
                            ),
                          ),
                      ],
                    ),
      floatingActionButton: _isBatchProcessing || _crawledAnimes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _importAllNewAnimes,
              label: const Text('Import Semua'),
              icon: const Icon(Icons.download),
            ),
    );
  }
}
