import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:wargabut/app/config/api_keys.dart';
import 'package:wargabut/app/ui/screens/create/crawl_events.dart';

class CreateEventPage extends StatefulWidget {
  final String? initialUrl;
  const CreateEventPage({super.key, this.initialUrl});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _eventNameController = TextEditingController();
  final _dateEventController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketPriceController = TextEditingController();

  final _linkController = TextEditingController();
  bool _isLoadingScrape = false;

  String _htmType = 'free';

  final List<Map<String, dynamic>> _rundownList = [];

  List<Map<String, dynamic>> guestStars = [];
  String? selectedGuestStarId;

  bool _isMedpart = false;

  File? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  XFile? _imageFile;
  String? _downloadURL;

  @override
  void initState() {
    super.initState();
    // getGuestStars();
    _addRundown(); // mulai dengan 1 rundown

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _linkController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFillFromLink();
      });
    }
  }

  void _addRundown() {
    setState(() {
      _rundownList.add({
        'time': null,
        'activity': '',
        'guestId': ''
      });
      selectedGuestStarId = null;
    });
  }

  void _removeRundown(int index) {
    setState(() {
      _rundownList.removeAt(index);
    });
  }

  Future<void> getGuestStars() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('guestStars')
        .get();

    setState(() {
      guestStars = snapshot.docs.map((doc) {
        return {
          'guestId': doc['guestId'],
          'name': doc['name'] ?? '',
        };
      }).toList();

      print('Guest Stars: $guestStars');
    });
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _dateController.text = DateFormat('dd MMM yyyy').format(picked);
    }
  }

  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _rundownList[index]['time'] = formatTimeOfDay(picked);
      });
    }
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

  List<Map<String, dynamic>> newPosters = [];

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Uint8List imageBytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = imageBytes;
      });
    }
  }

  Future<void> _uploadImage(String eventName) async {
    if (_imageFile == null) return;
    String? url = await _storageService.uploadImage(_imageFile, 'jfestchart', eventName);
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
        'jfestchart',
        _eventNameController.text,
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
    await firestore.collection('jfestchart').doc(eventId).update({
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
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Pastikan nama event tidak kosong
    if (_eventNameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nama event tidak boleh kosong!')),
      );
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String eventName = _eventNameController.text;

      // 1. Buat 'slug' dari nama event menggunakan fungsi yang kita buat
      String eventIdSlug = _createSlugFromName(eventName);

      // 2. Tentukan DocumentReference dengan slug kustom
      DocumentReference eventRef = firestore.collection('jfestchart').doc(eventIdSlug);

      // 3. (SANGAT PENTING) Cek apakah dokumen dengan ID ini sudah ada
      final docSnapshot = await eventRef.get();
      if (docSnapshot.exists) {
        // Jika sudah ada, beri peringatan dan batalkan penyimpanan
        messenger.showSnackBar(
          const SnackBar(content: Text('Gagal: Event dengan nama yang mirip sudah ada! Coba ganti nama event.')),
        );
        return; // Hentikan fungsi
      }

      // Jika belum ada, lanjutkan penyimpanan
      String? imageUrl;
      if (_imageFile != null) {
        await _uploadImage(eventName);
        imageUrl = _downloadURL;
      }

      // 4. Gunakan .set() untuk menyimpan data dengan ID kustom
      await eventRef.set({
        'event_name': eventName,
        'date': _dateEventController.text,
        'area': _areaController.text,
        'location': _locationController.text,
        'desc': _descriptionController.text,
        'ticket_price': _htmType == 'free' ? 'Gratis' : _ticketPriceController.text,
        'is_postered': imageUrl != null,
        'posters': [],
        'is_medpart': _isMedpart,
        'rundown': _rundownList,
      });

      // Jika ada poster yang diunggah, tambahkan ke Firestore
      if (newPosters.isNotEmpty) {
        await _addPostersToFirestore(eventRef.id, newPosters);
      }

      if (!mounted) return;

      await eventProvider.fetchData(forceRefresh: true);

      messenger.showSnackBar(
        const SnackBar(content: Text('Event berhasil dibuat!')),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      print('Gagal menambahkan event: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menambahkan event: $e')),
      );
    }
  }

  Future<void> _autoFillFromLink() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan URL terlebih dahulu!')),
      );
      return;
    }

    setState(() {
      _isLoadingScrape = true;
    });

    try {
      // Menggunakan Firebase Cloud Function pribadi untuk menghindari block CORS di production
      final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(url)}';
      final response = await http.get(Uri.parse(proxyUrl));

      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil data dari URL. Status: ${response.statusCode}');
      }

      // Pre-process HTML agar tag <br> dan <p> dikonversi menjadi newline (\n)
      // sebelum tag HTML-nya dihapus oleh parser.
      String htmlContent = response.body;
      htmlContent = htmlContent.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
      htmlContent = htmlContent.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
      htmlContent = htmlContent.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

      // Extract plain text from HTML
      final document = parse(htmlContent);
      
      // Coba cari URL poster dari metadata OG Image (menggunakan response asli)
      final rawDoc = parse(response.body);
      String? posterUrl;
      
      // Prioritas 1: Gambar yang path-nya spesifik event (seperti di ruangcosplay)
      final eventImg = rawDoc.querySelector('img[src*="/images/event/"]');
      final ogImage = rawDoc.querySelector('meta[property="og:image"]');
      
      print('=== DEBUG eventImg ditemukan: ${eventImg != null} ===');
      print('=== DEBUG ogImage ditemukan: ${ogImage != null} ===');

      if (eventImg != null) {
        posterUrl = eventImg.attributes['src'];
        print('=== DEBUG MENGGUNAKAN PRIORITAS 1 (eventImg): $posterUrl ===');
      } else if (ogImage != null) {
        // Prioritas 2: Open Graph Image
        posterUrl = ogImage.attributes['content'];
        print('=== DEBUG MENGGUNAKAN PRIORITAS 2 (ogImage): $posterUrl ===');
      } else {
        // Prioritas 3: Fallback mencari gambar pertama
        final img = rawDoc.querySelector('img');
        if (img != null) {
          posterUrl = img.attributes['src'];
          print('=== DEBUG MENGGUNAKAN PRIORITAS 3 (fallback img): $posterUrl ===');
        } else {
          print('=== DEBUG TIDAK ADA GAMBAR SAMA SEKALI DI HTML ===');
        }
      }
      
      // Jika URL relatif, jadikan absolut
      if (posterUrl != null && !posterUrl.startsWith('http')) {
        posterUrl = Uri.parse(url).resolve(posterUrl).toString();
      }
      
      // Mengubah resolusi gambar ruangcosplay dari medium (/md/) ke large (/lg/)
      if (posterUrl != null && posterUrl!.contains('/images/event/') && posterUrl!.contains('/md/')) {
        posterUrl = posterUrl!.replaceAll('/md/', '/lg/');
      }
      
      print('=== DEBUG POSTER URL DITEMUKAN: $posterUrl ===');

      final rawText = document.body?.text ?? htmlContent;
      
      // Bersihkan spasi horizontal, tapi biarkan newline (\n)
      String cleanText = rawText.replaceAll(RegExp(r'[ \t]+'), ' ');
      // Rapatkan newline yang terlalu banyak menjadi maksimal 2 newline berurutan
      cleanText = cleanText.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();

      // Ensure it's not too long for the model prompt
      final textToProcess = cleanText.length > 40000 ? cleanText.substring(0, 40000) : cleanText;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ApiKeys.geminiApiKey,
      );
      final prompt = '''
Ekstrak detail event dari teks berikut ke dalam format JSON yang tepat. 
Hanya kembalikan objek JSON tanpa formatting markdown (tanpa ```json ... ```), langsung mulai dengan { dan akhiri dengan }.

Keys yang harus ada:
- "event_name" (string)
- "date" (string, WAJIB gunakan format tanggal dan bulan bahasa Indonesia. Contoh singkatan: Jan, Feb, Mar, Apr, Mei, Jun, Jul, Agu, Sep, Okt, Nov, Des. Jangan gunakan Oct, May, atau Aug)
- "area" (string, HANYA nama Kota atau Kabupatennya saja tanpa nama provinsi, contoh: 'Jakarta', 'Malang', 'Bekasi')
- "location" (string, tempat spesifik event DITAMBAH dengan nama Kota/Kabupatennya, contoh: 'Revo Mall, Bekasi' atau 'JIEXPO Kemayoran, Jakarta')
- "description" (string, ambil secara LENGKAP seluruh isi deskripsi event tanpa dikurangi, dan pastikan mempertahankan format baris baru / paragraf menggunakan karakter "\\n")
- "is_free" (boolean, true jika gratis, false jika berbayar)
- "ticket_price" (string, harga tiket jika berbayar, atau string kosong jika gratis)

Teks web:
$textToProcess
''';

      final result = await model.generateContent([Content.text(prompt)]);
      final jsonText = result.text?.trim() ?? '';
      
      // Clean potential markdown blocks just in case the AI still returns them
      String cleanJson = jsonText;
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final data = json.decode(cleanJson) as Map<String, dynamic>;

      setState(() {
        _eventNameController.text = data['event_name']?.toString() ?? '';
        _dateEventController.text = data['date']?.toString() ?? '';
        _areaController.text = data['area']?.toString() ?? '';
        _locationController.text = data['location']?.toString() ?? '';
        _descriptionController.text = data['description']?.toString() ?? '';
        
        final isFree = data['is_free'] == true;
        _htmType = isFree ? 'free' : 'paid';
        if (!isFree) {
          _ticketPriceController.text = data['ticket_price']?.toString() ?? '';
        } else {
          _ticketPriceController.clear();
        }
      });

      // Proses pengunduhan dan upload poster
      if (posterUrl != null && posterUrl.isNotEmpty) {
        try {
          String extension = '.jpg';
          if (posterUrl!.toLowerCase().contains('.webp')) extension = '.webp';
          else if (posterUrl!.toLowerCase().contains('.png')) extension = '.png';

          // Menggunakan wsrv.nl (Images weserv) yang memang khusus dirancang sebagai proxy dan 
          // CDN cache untuk gambar (mendukung CORS dan tidak memblokir tipe konten).
          final imageProxyUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(posterUrl!)}';
          print('=== DEBUG MENGUNDUH POSTER DENGAN WSRV.NL: $imageProxyUrl ===');
          final imageResponse = await http.get(Uri.parse(imageProxyUrl));
          
          print('=== DEBUG STATUS DOWNLOAD POSTER: ${imageResponse.statusCode} ===');
          
          if (imageResponse.statusCode == 200) {
            print('=== DEBUG POSTER BERHASIL DIUNDUH (Size: ${imageResponse.bodyBytes.length} bytes), MEMULAI UPLOAD... ===');
            final xFile = XFile.fromData(
              imageResponse.bodyBytes,
              name: 'poster_${DateTime.now().millisecondsSinceEpoch}$extension',
            );
            
            final eventNameForStorage = _eventNameController.text.isNotEmpty 
                ? _eventNameController.text 
                : 'auto_event_${DateTime.now().millisecondsSinceEpoch}';

            List<Map<String, dynamic>> uploadedPosters = await _storageService.uploadImages(
              [xFile],
              'jfestchart',
              eventNameForStorage,
            );
            
            if (uploadedPosters.isNotEmpty) {
              print('=== DEBUG POSTER BERHASIL DIUPLOAD KE FIREBASE ===');
              setState(() {
                // Nonaktifkan is_main pada poster lain
                for (var p in newPosters) {
                  p['is_main'] = false;
                }
                uploadedPosters[0]['is_main'] = true;
                newPosters.addAll(uploadedPosters);
              });
            } else {
              print('=== DEBUG POSTER GAGAL DIUPLOAD (Hasil kosong) ===');
            }
          } else {
            print('=== DEBUG GAGAL DOWNLOAD POSTER (RESPONSE BODY): ${imageResponse.body} ===');
          }
        } catch (e) {
          print('=== DEBUG GAGAL PROSES POSTER (CATCH BLOCK): $e ===');
        }
      } else {
        print('=== DEBUG POSTER URL KOSONG, SKIP PROSES UNDUH ===');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-Fill berhasil!')),
      );

    } catch (e) {
      if (!mounted) return;
      print('Gagal Auto-Fill: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal Auto-Fill: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingScrape = false;
        });
      }
    }
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
                      Text("Detail Event", style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8.0),
                      // Auto-fill Section
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _linkController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Paste Event URL (RuangCosplay, dll)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.travel_explore),
                            color: Theme.of(context).primaryColor,
                            tooltip: 'Crawl Event RuangCosplay',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CrawlEventsPage()),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _isLoadingScrape 
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _autoFillFromLink,
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Auto-Fill'),
                                ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _eventNameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Nama Event',
                          hintText: 'Masukkan nama event',
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _dateEventController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Tanggal',
                          hintText: 'Masukkan tanggal event',
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _areaController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Area',
                          hintText: 'Masukkan area event',
                          helperText: 'Contoh: Jakarta, Surabaya, Bandung (wilayah umum)',
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Lokasi',
                          hintText: 'Masukkan lokasi event',
                          helperText: 'Contoh: JIEXPO Kemayoran, ICE BSD (nama venue)',
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      DropdownButtonFormField<String>(
                        value: _htmType,
                        decoration: const InputDecoration(
                          labelText: 'HTM',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'free', child: Text('Gratis')),
                          DropdownMenuItem(value: 'paid', child: Text('Berbayar')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _htmType = value!;
                            if (_htmType == 'free') {
                              _ticketPriceController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Muncul hanya jika HTM "berbayar"
                      if (_htmType == 'paid')
                        TextField(
                          controller: _ticketPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Harga Tiket (Rp)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi',
                          hintText: 'Masukkan deskripsi event',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                      ),

                      const SizedBox(height: 16.0),

                      const SizedBox(height: 16.0),
                      Row(
                        children: [
                          const Text('Medpart'),
                          Switch(
                            value: _isMedpart,
                            onChanged: (value) {
                              setState(() {
                                _isMedpart = value;
                              });
                            },
                          ),
                        ],
                      ),

                      // Tombol Pilih Gambar
                      ElevatedButton.icon(
                        onPressed: _uploadImages,
                        icon: const Icon(Icons.image),
                        label: const Text('Tambah Poster Baru'),
                      ),

                      const SizedBox(height: 16.0),

                      // Preview poster sebelum disimpan ke Firestore
                      if (newPosters.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: newPosters.length,
                          itemBuilder: (context, index) {
                            final poster = newPosters[index];

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      poster['url'],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          poster['path'].split('/').last,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 28),
                                    onPressed: () {
                                      setState(() {
                                        newPosters.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 24.0),
                      // Section Rundown Event
                      // Text("Rundown Event",
                      //     style: Theme.of(context).textTheme.headlineSmall),
                      // const SizedBox(height: 8.0),
                      // ..._rundownList.asMap().entries.map((entry) {
                      //   int index = entry.key;
                      //   Map<String, dynamic> rundown = entry.value;
                      //   return Card(
                      //     margin: const EdgeInsets.symmetric(vertical: 5),
                      //     child: Padding(
                      //       padding: const EdgeInsets.all(8.0),
                      //       child: Column(
                      //         children: [
                      //           Row(
                      //             children: [
                      //               Expanded(
                      //                 child: InkWell(
                      //                   onTap: () => _pickTime(index),
                      //                   child: InputDecorator(
                      //                     decoration: const InputDecoration(
                      //                       labelText: "Waktu",
                      //                       border: OutlineInputBorder(),
                      //                     ),
                      //                     child: Text(
                      //                       rundown['time'] != null && rundown['time'].toString().isNotEmpty
                      //                           ? rundown['time']
                      //                           : 'Pilih Waktu',
                      //                     ),
                      //                   ),
                      //                 ),
                      //               ),
                      //               const SizedBox(width: 8),
                      //               Expanded(
                      //                 flex: 2,
                      //                 child: TextFormField(
                      //                   decoration: const InputDecoration(
                      //                     labelText: 'Nama Aktivitas',
                      //                     border: OutlineInputBorder(),
                      //                   ),
                      //                   onChanged: (val) {
                      //                     _rundownList[index]['activity'] = val;
                      //                   },
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //           const SizedBox(height: 8),
                      //           Row(
                      //             children: [
                      //               Expanded(
                      //                 child: DropdownButtonFormField<String>(
                      //                   value: _rundownList[index]['guestId'] != '' &&
                      //                       guestStars.any((guest) => guest['guestId'] == _rundownList[index]['guestId'])
                      //                       ? _rundownList[index]['guestId']
                      //                       : null,
                      //                   decoration: const InputDecoration(
                      //                     labelText: 'Guest Star',
                      //                     border: OutlineInputBorder(),
                      //                   ),
                      //                   items: guestStars.map((guest) {
                      //                     return DropdownMenuItem<String>(
                      //                       value: guest['guestId'] as String,
                      //                       child: Text(guest['name'] as String),
                      //                     );
                      //                   }).toList(),
                      //                   onChanged: (value) {
                      //                     setState(() {
                      //                       selectedGuestStarId = value;
                      //                       _rundownList[index]['guestId'] = selectedGuestStarId; // simpan ID ke rundown
                      //                     });
                      //                   },
                      //                 ),
                      //               ),
                      //               IconButton(
                      //                 icon: const Icon(Icons.delete, color: Colors.red),
                      //                 onPressed: () => _removeRundown(index),
                      //               ),
                      //             ],
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   );
                      // }),
                      // TextButton.icon(
                      //   icon: const Icon(Icons.add),
                      //   label: const Text("Tambah Rundown"),
                      //   onPressed: _addRundown,
                      // ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kolom Kiri: Form Event
                      Expanded(
                        flex: 3, // Lebih lebar dibanding daftar poster
                        child: Column(
                          children: [
                            // Auto-fill Section
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _linkController,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Paste Event URL (RuangCosplay, dll)',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.travel_explore),
                                  color: Theme.of(context).primaryColor,
                                  tooltip: 'Crawl Event RuangCosplay',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CrawlEventsPage()),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                _isLoadingScrape 
                                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                                    : ElevatedButton.icon(
                                        onPressed: _autoFillFromLink,
                                        icon: const Icon(Icons.auto_awesome),
                                        label: const Text('Auto-Fill'),
                                      ),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            TextField(
                              controller: _eventNameController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Nama Event',
                                hintText: 'Masukkan nama event',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            TextField(
                              controller: _dateEventController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Tanggal',
                                hintText: 'Masukkan tanggal event',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            TextField(
                              controller: _areaController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Area',
                                hintText: 'Masukkan area event',
                                helperText: 'Contoh: Jakarta, Surabaya, Bandung (wilayah umum)',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Lokasi',
                                hintText: 'Masukkan lokasi event',
                                helperText: 'Contoh: JIEXPO Kemayoran, ICE BSD (nama venue)',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            DropdownButtonFormField<String>(
                              value: _htmType,
                              decoration: const InputDecoration(
                                labelText: 'HTM',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'free', child: Text('Gratis')),
                                DropdownMenuItem(value: 'paid', child: Text('Berbayar')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _htmType = value!;
                                  if (_htmType == 'free') {
                                    _ticketPriceController.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // 🔹 Muncul hanya jika HTM "berbayar"
                            if (_htmType == 'paid')
                              TextField(
                                controller: _ticketPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Harga Tiket (Rp)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Deskripsi',
                                hintText: 'Masukkan deskripsi event',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                              keyboardType: TextInputType.multiline,
                            ),
                            const SizedBox(height: 16.0),
                            Row(
                              children: [
                                const Text('Medpart'),
                                Switch(
                                  value: _isMedpart,
                                  onChanged: (value) {
                                    setState(() {
                                      _isMedpart = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16.0),

                      // Kolom Kanan: Tombol Tambah Poster + List Poster
                      Expanded(
                        flex: 2, // Lebih kecil dari form
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tombol Pilih Gambar
                            ElevatedButton.icon(
                              onPressed: _uploadImages,
                              icon: const Icon(Icons.image),
                              label: const Text('Tambah Poster Baru'),
                            ),

                            const SizedBox(height: 16.0),

                            // Preview poster sebelum disimpan ke Firestore
                            if (newPosters.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: newPosters.length,
                                itemBuilder: (context, index) {
                                  final poster = newPosters[index];

                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            poster['url'],
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                poster['path'].split('/').last,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                newPosters[index]['is_main']
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: newPosters[index]
                                                        ['is_main']
                                                    ? Colors.amber
                                                    : Colors.grey,
                                                size: 32,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  for (var poster
                                                      in newPosters) {
                                                    poster['is_main'] = false;
                                                  }
                                                  newPosters[index]['is_main'] =
                                                      true;
                                                });
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red, size: 28),
                                              onPressed: () {
                                                setState(() {
                                                  newPosters.removeAt(index);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
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
