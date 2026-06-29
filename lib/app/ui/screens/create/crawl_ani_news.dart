import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:wargabut/app/config/api_keys.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:wargabut/app/provider/aninews_provider.dart';

import 'package:wargabut/app/ui/screens/create/create_ani_news.dart';

class CrawlAniNewsPage extends StatefulWidget {
  const CrawlAniNewsPage({super.key});

  @override
  State<CrawlAniNewsPage> createState() => _CrawlAniNewsPageState();
}

class _CrawlAniNewsPageState extends State<CrawlAniNewsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, String>> _crawledEvents = [];
  Set<String> _existingUrls = {};
  
  int _currentPage = 1;
  bool _isLoadingMore = false;

  bool _isBatchProcessing = false;
  int _currentProcessIndex = 0;
  int _totalProcessCount = 0;
  String _currentProcessName = '';

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  void _loadMore() {
    _currentPage++;
    _fetchEvents(isLoadMore: true);
  }

  Future<void> _fetchEvents({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _currentPage = 1;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final targetUrl = 'https://myanimelist.net/news/tag/new_anime?p=$_currentPage';
      final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(targetUrl)}';
      
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode != 200) throw Exception('Gagal memuat MAL');

      final document = parse(response.body);
      final eventCards = document.querySelectorAll('.news-unit'); // Sesuai DOM MAL

      List<Map<String, String>> fetchedEvents = [];

      for (int i = 0; i < eventCards.length; i++) {
        var card = eventCards[i];
        
        // Cari elemen judul dan URL
        final titleElem = card.querySelector('p.title a') ?? card.querySelector('a.title');
        String url = titleElem?.attributes['href'] ?? '';
        String title = titleElem?.text.trim() ?? 'No Title';
        
        final lowerTitle = title.toLowerCase();
        if (lowerTitle.contains('erotica') || lowerTitle.contains('boys love') || lowerTitle.contains('hentai') || lowerTitle.contains('yaoi') || lowerTitle.contains('yuri') || lowerTitle.contains('girls love')) {
          continue; // Skip restricted news
        }
        
        final dateElem = card.querySelector('.information') ?? card.querySelector('.info');
        String date = dateElem?.text.trim().split('by').first.trim() ?? ''; // Sederhanakan tulisan author dll
        
        final imgElem = card.querySelector('img');
        String posterUrl = imgElem?.attributes['data-src'] ?? imgElem?.attributes['src'] ?? '';
        posterUrl = posterUrl.trim();

        // Bersihkan dan resolusi tinggi gambar MAL
        if (posterUrl.contains('/r/')) {
          final regex = RegExp(r'/r/\d+x\d+');
          posterUrl = posterUrl.replaceAll(regex, '');
          posterUrl = posterUrl.split('?').first; // Buang parameter query
        }

        fetchedEvents.add({
          'id': i.toString(),
          'title': title,
          'date': date,
          'url': url,
          'posterUrl': posterUrl,
        });
      }

      setState(() {
        if (isLoadMore) {
          _crawledEvents.addAll(fetchedEvents);
        } else {
          _crawledEvents = fetchedEvents;
        }
      });

      await _checkExistingEvents();

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

  Future<void> _checkExistingEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('anichekku').get();
      Set<String> existingUrls = {};
      
      print('=== DEBUG: Ditemukan ${snapshot.docs.length} dokumen berita di Firestore ===');
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('source_url')) {
          final url = data['source_url'].toString().trim();
          existingUrls.add(url);
        } else if (data.containsKey('url')) { // Backward compatibility jika ada
          final url = data['url'].toString().trim();
          existingUrls.add(url);
        }
      }

      setState(() {
        _existingUrls = existingUrls;

        _crawledEvents.sort((a, b) {
          // url di _crawledEvents masih relative (e.g. /news/123), tapi yang disimpan bisa absolute
          // Jadi kita cek jika ada url di existingUrls yang berakhiran dengan url berita ini
          final aExists = existingUrls.any((u) => u.endsWith(a['url']!));
          final bExists = existingUrls.any((u) => u.endsWith(b['url']!));

          if (aExists && !bExists) return 1;
          if (!aExists && bExists) return -1;
          
          return int.parse(a['id']!).compareTo(int.parse(b['id']!));
        });
      });
    } catch (e) {
      print('Gagal mengecek berita dari Firestore: $e');
    }
  }

  String _createSlugFromName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), '').replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _importAllNewEvents() async {
    final newEvents = _crawledEvents.where((e) => !_existingUrls.any((u) => u.endsWith(e['url']!))).toList();
    if (newEvents.isEmpty) return;

    setState(() {
      _isBatchProcessing = true;
      _totalProcessCount = newEvents.length;
      _currentProcessIndex = 0;
    });

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiKeys.geminiApiKey,
    );
    final storageService = StorageService();

    for (int i = 0; i < newEvents.length; i++) {
      final ev = newEvents[i];
      setState(() {
        _currentProcessIndex = i + 1;
        _currentProcessName = ev['title'] ?? 'Berita';
      });

      try {
        final url = ev['url']!;
        // Jika URL dari MAL belum ada domainnya
        final absoluteUrl = url.startsWith('http') ? url : 'https://myanimelist.net$url';
        
        final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(absoluteUrl)}';
        final response = await http.get(Uri.parse(proxyUrl));
        if (response.statusCode != 200) throw Exception('Gagal fetch berita: ${response.statusCode}');

        String htmlContent = response.body;
        htmlContent = htmlContent.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
        htmlContent = htmlContent.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
        htmlContent = htmlContent.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

        final document = parse(htmlContent);
        // Mengambil isi spesifik artikel agar prompt AI tidak kebingungan dengan komentar dll
        final articleBody = document.querySelector('.news-container') ?? document.body;
        final rawText = articleBody?.text ?? htmlContent;
        String cleanText = rawText.replaceAll(RegExp(r'[ \t]+'), ' ');
        cleanText = cleanText.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();
        final textToProcess = cleanText.length > 40000 ? cleanText.substring(0, 40000) : cleanText;

        final prompt = '''
Anda adalah jurnalis pop-culture. Terjemahkan berita anime berbahasa Inggris ini ke dalam Bahasa Indonesia dengan gaya penulisan yang rapi dan menarik.
Ekstrak informasinya ke dalam format JSON yang tepat. 
Hanya kembalikan objek JSON tanpa formatting markdown (tanpa ```json ... ```), langsung mulai dengan { dan akhiri dengan }.

Keys yang harus ada:
- "title" (string, judul berita yang diterjemahkan ke Bahasa Indonesia. Buat sesingkat dan sepadat mungkin seperti judul asli, jangan berlebihan atau bergaya clickbait. JANGAN sebutkan platform tayang seperti Netflix/Crunchyroll di judul)
- "date" (string, WAJIB gunakan format tanggal dan 3 huruf singkatan bulan bahasa Indonesia: Jan, Feb, Mar, Apr, Mei, Jun, Jul, Agu, Sep, Okt, Nov, Des. Jika teks asli tidak menyebutkan tahun, gunakan tahun ${DateTime.now().year}. Contoh: 20 Jun ${DateTime.now().year})
- "desc" (string, terjemahan berita LENGKAP ke Bahasa Indonesia, pertahankan karakter \n untuk baris baru antar paragraf)
- "tags" (list of strings, contoh: ["Anime", "Adaptation", "Netflix", "New Anime"])
- "genres" (list of strings, ambil genre jika disebutkan, contoh: ["Comedy", "Action"])

Teks berita berbahasa Inggris:
$textToProcess
''';

        final result = await model.generateContent([Content.text(prompt)]);
        String cleanJson = result.text?.trim() ?? '{}';
        if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
        if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
        if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        
        final data = json.decode(cleanJson.trim()) as Map<String, dynamic>;
        
        String newsTitle = data['title']?.toString() ?? ev['title']!;
        String slug = _createSlugFromName(newsTitle);

        List<Map<String, dynamic>> finalPosters = [];
        if (ev['posterUrl'] != null && ev['posterUrl']!.isNotEmpty) {
           final imageProxyUrl = ev['posterUrl']!; // CDN MAL sudah support CORS (*), wsrv.nl malah diblokir MAL
           final imageResponse = await http.get(Uri.parse(imageProxyUrl));
           if (imageResponse.statusCode == 200) {
             final extension = ev['posterUrl']!.toLowerCase().contains('.png') ? '.png' : '.webp';
             final xFile = XFile.fromData(
               imageResponse.bodyBytes,
               name: 'poster_${DateTime.now().millisecondsSinceEpoch}$extension',
             );
             
             final eventNameForStorage = newsTitle.isNotEmpty ? newsTitle : 'auto_news';
             final uploadedPosters = await storageService.uploadImages([xFile], 'anichekku', eventNameForStorage);
             
             if (uploadedPosters.isNotEmpty) {
               uploadedPosters[0]['is_main'] = true;
               finalPosters.addAll(uploadedPosters);
             }
           }
        }
        
        List<String> tags = [];
        if (data['tags'] is List) {
           tags = List<String>.from(data['tags'].map((x) => x.toString()));
        }
        
        List<String> genres = [];
        if (data['genres'] is List) {
           genres = List<String>.from(data['genres'].map((x) => x.toString()));
        }

        await FirebaseFirestore.instance.collection('anichekku').doc(slug).set({
          'title': newsTitle,
          'date': data['date']?.toString() ?? '',
          'desc': data['desc']?.toString() ?? '',
          'tags': tags,
          'genres': genres,
          'is_postered': finalPosters.isNotEmpty,
          'posters': finalPosters,
          'is_scheduled': false,
          'created_at': DateTime.now(),
          'expire_at': DateTime.now().add(const Duration(days: 30)), // Masa aktif 30 hari
          'source_url': absoluteUrl, // Disimpan untuk cek duplikasi
        });

      } catch (e) {
        print('Error memproses berita ${ev['title']}: $e');
      }
    }

    setState(() {
      _isBatchProcessing = false;
    });

    if (mounted) {
      await context.read<AniNewsProvider>().fetchData(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import Berita Selesai!')),
      );
      Navigator.pop(context); // Kembali ke halaman List
    }
  }

  void _onSelectEvent(String url) {
    // Navigate ke CreateAniNewsPage jika ingin parse manual
    // Bisa lewat argumen jika dibuat constructornya, saat ini jalankan auto saja
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Silakan gunakan Import Semua (Batch Processing) untuk saat ini.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crawl AniNews (MAL)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _crawledEvents.isEmpty
                  ? const Center(child: Text('Tidak ada berita ditemukan.'))
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
                            itemCount: _crawledEvents.length,
                            itemBuilder: (context, index) {
                              final ev = _crawledEvents[index];
                              final isExists = _existingUrls.any((u) => u.endsWith(ev['url']!));

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
                                          ev['posterUrl']!.isNotEmpty
                                              ? Image.network(
                                                  ev['posterUrl']!,
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
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              ev['title']!,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isExists ? Colors.grey : null,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              ev['date']!,
                                              style: const TextStyle(fontSize: 12),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: isExists ? null : () => _onSelectEvent(ev['url']!),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isExists ? Colors.grey : Theme.of(context).primaryColor,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Text(isExists ? 'Sudah Ada' : 'Pilih'),
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
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingMore ? null : _loadMore,
                              icon: _isLoadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.downloading),
                              label: Text(_isLoadingMore ? 'Memuat Halaman $_currentPage...' : 'Load More (Halaman ${_currentPage + 1})'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: (!_isBatchProcessing && _crawledEvents.where((e) => !_existingUrls.any((u) => u.endsWith(e['url']!))).isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _importAllNewEvents,
              icon: const Icon(Icons.download),
              label: Text('Import ${_crawledEvents.where((e) => !_existingUrls.any((u) => u.endsWith(e['url']!))).length} Berita'),
            )
          : null,
      bottomSheet: _isBatchProcessing
          ? Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Memproses terjemahan AI $_currentProcessIndex dari $_totalProcessCount...',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _currentProcessName,
                            style: const TextStyle(color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
