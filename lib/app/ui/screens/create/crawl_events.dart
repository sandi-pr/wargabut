import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wargabut/app/ui/screens/create/create_event.dart';
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:wargabut/app/provider/event_provider.dart';

class CrawlEventsPage extends StatefulWidget {
  const CrawlEventsPage({super.key});

  @override
  State<CrawlEventsPage> createState() => _CrawlEventsPageState();
}

class _CrawlEventsPageState extends State<CrawlEventsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, String>> _crawledEvents = [];
  Set<String> _existingEventNames = {};

  bool _isBatchProcessing = false;
  int _currentProcessIndex = 0;
  int _totalProcessCount = 0;
  String _currentProcessName = '';

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Fetch HTML list event via proxy
      final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent('https://ruangcosplay.com/event')}';
      final response = await http.get(Uri.parse(proxyUrl));

      if (response.statusCode != 200) {
        throw Exception('Gagal memuat halaman ruangcosplay. Status: ${response.statusCode}');
      }

      final document = parse(response.body);
      final eventCards = document.querySelectorAll('.col.mb-3');

      List<Map<String, String>> fetchedEvents = [];
      List<String> eventNamesToCheck = [];

      for (var card in eventCards) {
        final aTag = card.querySelector('a.text-decoration-none');
        if (aTag == null) continue;

        final url = aTag.attributes['href'] ?? '';
        final titleElem = card.querySelector('.fw-bold.clamp-2');
        final title = titleElem?.text.trim() ?? 'No Title';
        
        final dateElems = card.querySelectorAll('.fst-italic.fs-08-rem');
        String date = '';
        if (dateElems.isNotEmpty) {
          date = dateElems.first.text.trim();
        }

        final locationElem = card.querySelector('.card-footer small');
        final location = locationElem?.text.trim() ?? '';

        final imgElem = card.querySelector('img.card-img-top');
        String posterUrl = imgElem?.attributes['data-src'] ?? imgElem?.attributes['src'] ?? '';
        posterUrl = posterUrl.trim(); // Penting: Hapus spasi di awal/akhir URL

        // Jika URL relatif, jadikan absolut
        if (url.isNotEmpty && !url.startsWith('http')) {
          // url = 'https://ruangcosplay.com$url';
        }
        if (posterUrl.isNotEmpty && !posterUrl.startsWith('http')) {
          posterUrl = 'https://ruangcosplay.com$posterUrl';
        }

        // Ubah dari resolusi small (/sm/) ke large (/lg/) agar kualitas gambar maksimal
        if (posterUrl.contains('/images/event/') && posterUrl.contains('/sm/')) {
          posterUrl = posterUrl.replaceAll('/sm/', '/lg/');
        }

        // print('URL Poster Event [$title]: $posterUrl');

        fetchedEvents.add({
          'id': fetchedEvents.length.toString(), // Untuk mempertahankan urutan tanggal asli
          'title': title,
          'url': url,
          'date': date,
          'location': location,
          'posterUrl': posterUrl,
        });

        eventNamesToCheck.add(title.toLowerCase());
      }

      setState(() {
        _crawledEvents = fetchedEvents;
      });

      // Cek duplikasi di Firestore secara batch
      await _checkExistingEvents(eventNamesToCheck);

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

  Future<void> _checkExistingEvents(List<String> titles) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('jfestchart').get();
      Set<String> existingNames = {};
      
      print('=== DEBUG: Ditemukan ${snapshot.docs.length} dokumen event di Firestore ===');
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('event_name')) {
          final name = data['event_name'].toString().toLowerCase().trim();
          existingNames.add(name);
        }
      }
      print('=== DEBUG: Total unique event_name di Firestore: ${existingNames.length} ===');

      setState(() {
        _existingEventNames = existingNames;

        // Mengurutkan list: Event yang belum ada di database berada di atas
        _crawledEvents.sort((a, b) {
          final aExists = existingNames.contains(a['title']!.toLowerCase());
          final bExists = existingNames.contains(b['title']!.toLowerCase());

          if (aExists && !bExists) return 1;   // a ditaruh di bawah b
          if (!aExists && bExists) return -1;  // a ditaruh di atas b
          
          // Jika statusnya sama, urutkan berdasarkan urutan asli (tanggal terdekat)
          return int.parse(a['id']!).compareTo(int.parse(b['id']!));
        });
      });
    } catch (e) {
      print('Gagal mengecek event dari Firestore: $e');
    }
  }

  String _createSlugFromName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), '').replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _importAllNewEvents() async {
    final newEvents = _crawledEvents.where((e) => !_existingEventNames.contains(e['title']!.toLowerCase())).toList();
    if (newEvents.isEmpty) return;

    setState(() {
      _isBatchProcessing = true;
      _totalProcessCount = newEvents.length;
      _currentProcessIndex = 0;
    });

    final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-3.5-flash');
    final storageService = StorageService();

    for (int i = 0; i < newEvents.length; i++) {
      final ev = newEvents[i];
      setState(() {
        _currentProcessIndex = i + 1;
        _currentProcessName = ev['title'] ?? 'Event';
      });

      try {
        final url = ev['url']!;
        final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(url)}';
        final response = await http.get(Uri.parse(proxyUrl));
        if (response.statusCode != 200) throw Exception('Gagal fetch');

        String htmlContent = response.body;
        htmlContent = htmlContent.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
        htmlContent = htmlContent.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
        htmlContent = htmlContent.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

        final document = parse(htmlContent);
        final rawText = document.body?.text ?? htmlContent;
        String cleanText = rawText.replaceAll(RegExp(r'[ \t]+'), ' ');
        cleanText = cleanText.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();
        final textToProcess = cleanText.length > 40000 ? cleanText.substring(0, 40000) : cleanText;

        final prompt = '''
Ekstrak detail event dari teks berikut ke dalam format JSON yang tepat. 
Hanya kembalikan objek JSON tanpa formatting markdown (tanpa ```json ... ```), langsung mulai dengan { dan akhiri dengan }.

Keys yang harus ada:
- "event_name" (string)
- "date" (string, WAJIB gunakan format tanggal dan bulan bahasa Indonesia. Contoh singkatan: Jan, Feb, Mar, Apr, Mei, Jun, Jul, Agu, Sep, Okt, Nov, Des. Jangan gunakan Oct, May, atau Aug)
- "area" (string, HANYA nama Kota atau Kabupatennya saja tanpa nama provinsi)
- "location" (string)
- "description" (string, ambil utuh pertahankan \n)
- "is_free" (boolean)
- "ticket_price" (string)

Teks web:
$textToProcess
''';

        final result = await model.generateContent([Content.text(prompt)]);
        String cleanJson = result.text?.trim() ?? '{}';
        if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
        if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
        if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        
        final data = json.decode(cleanJson.trim()) as Map<String, dynamic>;
        
        String eventName = data['event_name']?.toString() ?? ev['title']!;
        String slug = _createSlugFromName(eventName);

        List<Map<String, dynamic>> finalPosters = [];
        if (ev['posterUrl'] != null && ev['posterUrl']!.isNotEmpty) {
           final imageProxyUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(ev['posterUrl']!)}';
           final imageResponse = await http.get(Uri.parse(imageProxyUrl));
           if (imageResponse.statusCode == 200) {
             final extension = ev['posterUrl']!.toLowerCase().contains('.png') ? '.png' : '.webp';
             final xFile = XFile.fromData(
               imageResponse.bodyBytes,
               name: 'poster_${DateTime.now().millisecondsSinceEpoch}$extension',
             );
             
             final eventNameForStorage = eventName.isNotEmpty ? eventName : 'auto_event';
             final uploadedPosters = await storageService.uploadImages([xFile], 'jfestchart', eventNameForStorage);
             
             if (uploadedPosters.isNotEmpty) {
               // Jadikan poster pertama sebagai poster utama
               uploadedPosters[0]['is_main'] = true;
               finalPosters.addAll(uploadedPosters);
             }
           }
        }

        final isFree = data['is_free'] == true;
        
        await FirebaseFirestore.instance.collection('jfestchart').doc(slug).set({
          'event_name': eventName,
          'date': data['date']?.toString() ?? '',
          'area': data['area']?.toString() ?? '',
          'location': data['location']?.toString() ?? '',
          'desc': data['description']?.toString() ?? '',
          'ticket_price': isFree ? 'Gratis' : data['ticket_price']?.toString() ?? '',
          'is_postered': finalPosters.isNotEmpty,
          'posters': finalPosters,
          'is_medpart': false,
          'rundown': [],
        });

      } catch (e) {
        print('Error memproses event ${ev['title']}: $e');
      }
    }

    setState(() {
      _isBatchProcessing = false;
    });

    if (mounted) {
      context.read<EventProvider>().fetchData(forceRefresh: true);
    }

    // Refresh daftar status existing
    _fetchEvents();
  }

  void _onSelectEvent(String url) {
    // Navigate ke CreateEventPage dengan membawa initialUrl
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEventPage(initialUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crawl Event RuangCosplay'),
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
                  ? const Center(child: Text('Tidak ada event ditemukan.'))
                  : GridView.builder(
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
                        final isExists = _existingEventNames.contains(ev['title']!.toLowerCase());

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
                                            'https://wsrv.nl/?url=${Uri.encodeComponent(ev['posterUrl']!)}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, error, ___) {
                                              print('Gagal meload gambar: $error');
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
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ev['date']!,
                                            style: const TextStyle(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            ev['location']!,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: isExists ? null : () => _onSelectEvent(ev['url']!),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isExists ? Colors.grey : Theme.of(context).primaryColor,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(isExists ? 'Sudah Ada' : 'Pilih & Auto-Fill'),
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
      floatingActionButton: (!_isBatchProcessing && _crawledEvents.where((e) => !_existingEventNames.contains(e['title']!.toLowerCase())).isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _importAllNewEvents,
              icon: const Icon(Icons.download),
              label: Text('Import ${_crawledEvents.where((e) => !_existingEventNames.contains(e['title']!.toLowerCase())).length} Event Baru'),
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
                            'Memproses $_currentProcessIndex dari $_totalProcessCount...',
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
