import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  void _showPosterPreview(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header dengan judul dan tombol close
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),
            // Gambar preview dengan zoom
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, color: Colors.white54, size: 64),
                            SizedBox(height: 8),
                            Text('Gagal memuat gambar', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      final isInstagram = url.contains('instagram.com') || url.contains('instagr.am');
      String targetFetchUrl = url;

      if (isInstagram) {
        final regExp = RegExp(r'(?:instagram\.com|instagr\.am)/(?:p|reel|tv)/([A-Za-z0-9_-]+)');
        final match = regExp.firstMatch(url);
        if (match != null) {
          final shortcode = match.group(1);
          targetFetchUrl = 'https://www.instagram.com/p/$shortcode/embed/captioned/';
        }
      }

      http.Response? response;

      if (isInstagram) {
        try {
          print('=== DEBUG IG: Trying Direct GET with SSR User-Agent ===');
          final directRes = await http.get(
            Uri.parse(targetFetchUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
            },
          );
          if (directRes.statusCode == 200 && directRes.body.contains('EmbeddedMediaImage')) {
            print('=== DEBUG IG: Direct GET Success! Found EmbeddedMediaImage ===');
            response = directRes;
          } else {
            print('=== DEBUG IG: Direct GET status: ${directRes.statusCode}, size: ${directRes.body.length} ===');
          }
        } catch (e) {
          print('=== DEBUG IG: Direct GET Exception: $e ===');
        }
      }

      if (response == null) {
        final proxyUrl = 'https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=${Uri.encodeComponent(targetFetchUrl)}';
        print('=== DEBUG: Fetching via Cloud Function Proxy: $proxyUrl ===');

        // Retry otomatis hingga 3 kali jika Instagram embed merespons 500 / error sementara
        final maxRetries = isInstagram ? 3 : 1;
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
          try {
            response = await http.get(Uri.parse(proxyUrl));
            if (response.statusCode == 200 && response.body.contains('Caption')) {
              print('=== DEBUG: Fetch proxy berhasil pada percobaan ke-$attempt ===');
              break;
            } else if (response.statusCode != 200) {
              print('=== DEBUG: Percobaan ke-$attempt status ${response.statusCode}, mencoba ulang... ===');
            }
          } catch (e) {
            print('=== DEBUG: Exception fetch proxy pada percobaan ke-$attempt: $e ===');
          }
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }
      }

      if (response == null || response.statusCode != 200) {
        throw Exception('Gagal mengambil data dari URL. Status: ${response?.statusCode ?? 'error'}. Server Instagram sedang membatasi sementara, silakan coba tekan Auto-Fill kembali.');
      }

      // Pre-process HTML agar tag <br> dan <p> dikonversi menjadi newline (\n)
      // sebelum tag HTML-nya dihapus oleh parser.
      String htmlContent = response.body;
      htmlContent = htmlContent.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
      htmlContent = htmlContent.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
      htmlContent = htmlContent.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

      final rawDoc = parse(response.body);
      String? posterUrl;

      if (isInstagram) {
        final imgElements = rawDoc.querySelectorAll('img.EmbeddedMediaImage, img[src*="fbcdn"], img[src*="cdninstagram"]');
        for (var img in imgElements) {
          final src = img.attributes['src'];
          if (src != null && src.isNotEmpty) {
            final isNotPoster = src.contains('profile_pic') ||
                                src.contains('t51.82787-19') ||
                                src.contains('s100x100') ||
                                src.contains('s150x150') ||
                                src.contains('static.cdninstagram.com') ||
                                src.contains('rsrc.php');
            if (!isNotPoster) {
              posterUrl = src;
              break;
            }
          }
        }

        // Regex fallbacks jika querySelector tidak menemukan poster media
        if (posterUrl == null || posterUrl.isEmpty) {
          final reg1 = RegExp(r'class="EmbeddedMediaImage[^"]*"[^>]*src="([^"]+)"', caseSensitive: false);
          final reg2 = RegExp(r'src="([^"]*(?:fbcdn\.net|cdninstagram\.com)/v/t51\.82787-15/[^"]+)"', caseSensitive: false);
          final reg3 = RegExp(r'"display_url"\s*:\s*"([^"]+)"', caseSensitive: false);

          final m1 = reg1.firstMatch(response.body);
          final m2 = reg2.firstMatch(response.body);
          final m3 = reg3.firstMatch(response.body);

          if (m1 != null && !m1.group(1)!.contains('rsrc.php') && !m1.group(1)!.contains('static.cdninstagram.com')) {
            posterUrl = m1.group(1);
          } else if (m2 != null && !m2.group(1)!.contains('rsrc.php') && !m2.group(1)!.contains('static.cdninstagram.com')) {
            posterUrl = m2.group(1);
          } else if (m3 != null && !m3.group(1)!.contains('rsrc.php') && !m3.group(1)!.contains('static.cdninstagram.com')) {
            posterUrl = m3.group(1);
          }
        }

        // Fallback meta tag og:image (hanya gambar event asli, abaikan aset static login Instagram)
        if (posterUrl == null || posterUrl.isEmpty) {
          final ogImage = rawDoc.querySelector('meta[property="og:image"]');
          if (ogImage != null && ogImage.attributes['content'] != null) {
            final ogContent = ogImage.attributes['content']!;
            if (!ogContent.contains('rsrc.php') && !ogContent.contains('static.cdninstagram.com')) {
              posterUrl = ogContent;
              print('=== DEBUG IG: Poster ditemukan via og:image: $posterUrl ===');
            }
          }
        }

        if (posterUrl != null) {
          posterUrl = posterUrl
              .replaceAll('&amp;', '&')
              .replaceAll(r'\u0026', '&')
              .replaceAll(r'\/', '/');
        }
      } else {
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
      }

      // Jika URL relatif, jadikan absolut
      if (posterUrl != null && !posterUrl.startsWith('http')) {
        posterUrl = Uri.parse(url).resolve(posterUrl).toString();
      }

      // Mengubah resolusi gambar ruangcosplay dari medium (/md/) ke large (/lg/)
      if (posterUrl != null && posterUrl.contains('/images/event/') && posterUrl.contains('/md/')) {
        posterUrl = posterUrl.replaceAll('/md/', '/lg/');
      }

      print('=== DEBUG POSTER URL DITEMUKAN: $posterUrl ===');

      String textToProcess = '';
      if (isInstagram) {
        final captionElem = rawDoc.querySelector('div.Caption, div.CaptionText');
        if (captionElem != null) {
          String capHtml = captionElem.innerHtml.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
          textToProcess = parse(capHtml).body?.text ?? captionElem.text;
        } else {
          final document = parse(htmlContent);
          textToProcess = document.body?.text ?? htmlContent;
        }
      } else {
        final document = parse(htmlContent);
        textToProcess = document.body?.text ?? htmlContent;
      }

      // Bersihkan spasi horizontal, tapi biarkan newline (\n)
      textToProcess = textToProcess.replaceAll(RegExp(r'[ \t]+'), ' ');
      // Rapatkan newline yang terlalu banyak menjadi maksimal 2 newline berurutan
      textToProcess = textToProcess.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();

      if (isInstagram && (textToProcess.toLowerCase() == 'instagram' || textToProcess.length < 20)) {
        throw Exception('Caption Instagram tidak terbaca (Instagram membatasi akses atau meminta login). Silakan coba tekan Auto-Fill kembali.');
      }

      // Bersihkan spasi horizontal, tapi biarkan newline (\n)
      textToProcess = textToProcess.replaceAll(RegExp(r'[ \t]+'), ' ');
      // Rapatkan newline yang terlalu banyak menjadi maksimal 2 newline berurutan
      textToProcess = textToProcess.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();

      // Ensure it's not too long for the model prompt
      if (textToProcess.length > 40000) {
        textToProcess = textToProcess.substring(0, 40000);
      }

  String _cleanDateString(String rawDate) {
    String dateStr = rawDate.trim();
    
    // 1. Hapus nama hari (senin, selasa, rabu, kamis, jumat, sabtu, minggu) di awal
    final dayNamesRegex = RegExp(
      r'^(?:senin|selasa|rabu|kamis|jumat|sabtu|minggu|\s|&|-|,)+[,\s]*',
      caseSensitive: false,
    );
    dateStr = dateStr.replaceAll(dayNamesRegex, '').trim();
    dateStr = dateStr.replaceAll(RegExp(r'^[,\s\-&]+'), '').trim();

    // 2. Format antar tanggal dalam bulan yang sama: hapus spasi di sekitar tanda hubung (misal '8 - 9' -> '8-9')
    dateStr = dateStr.replaceAllMapped(
      RegExp(r'(\d+)\s*-\s*(\d+)'),
      (match) => '${match.group(1)}-${match.group(2)}',
    );

    // 3. Format antar bulan beda: pastikan ada spasi di sekitar tanda hubung (misal '30 Jul-2' -> '30 Jul - 2')
    dateStr = dateStr.replaceAllMapped(
      RegExp(r'([a-zA-Z]{3,})\s*-\s*(\d+)'),
      (match) => '${match.group(1)} - ${match.group(2)}',
    );
    dateStr = dateStr.replaceAllMapped(
      RegExp(r'(\d+)\s*-\s*([a-zA-Z]{3,})'),
      (match) => '${match.group(1)} - ${match.group(2)}',
    );

    return dateStr;
  }

      final prompt = '''
Ekstrak detail event dari teks berikut ke dalam format JSON yang tepat. 
Hanya kembalikan objek JSON tanpa formatting markdown (tanpa ```json ... ```), langsung mulai dengan { dan akhiri dengan }.

Keys yang harus ada:
- "event_name" (string)
- "date" (string, WAJIB HANYA tanggal, bulan, dan tahun TANPA nama hari. Untuk antar tanggal dalam bulan yang sama TANPA SPASI di sekitar tanda hubung, contoh: '8-9 Agu 2026' atau '1-2 Agu 2026'. Untuk antar bulan BEDA DENGAN SPASI di sekitar tanda hubung, contoh: '30 Jul - 2 Agu 2026'. WAJIB singkatan bulan bahasa Indonesia: Jan, Feb, Mar, Apr, Mei, Jun, Jul, Agu, Sep, Okt, Nov, Des. DILARANG MENULISKAN NAMA HARI!)
- "area" (string, HANYA nama Kota atau Kabupatennya saja tanpa nama provinsi, contoh: 'Jakarta', 'Malang', 'Bekasi')
- "location" (string, tempat spesifik event DITAMBAH dengan nama Kota/Kabupatennya, contoh: 'Revo Mall, Bekasi' atau 'JIEXPO Kemayoran, Jakarta')
- "description" (string, ambil secara LENGKAP seluruh isi deskripsi event tanpa dikurangi, dan pastikan mempertahankan format baris baru / paragraf menggunakan karakter "\\n")
- "is_free" (boolean, true jika gratis, false jika berbayar)
- "ticket_price" (string, harga tiket jika berbayar, atau string kosong jika gratis)

Teks web:
$textToProcess
''';

      // Fallback beberapa model Gemini jika salah satu kena limit/quota
      final candidateModels = [
        'gemini-flash-latest',
        'gemini-flash-lite-latest',
        'gemini-2.0-flash',
        'gemini-2.5-flash',
        'gemini-2.0-flash-lite',
      ];

      GenerateContentResponse? result;
      String? lastError;

      for (final modelName in candidateModels) {
        try {
          print('=== Trying Gemini model: $modelName ===');
          final model = GenerativeModel(
            model: modelName,
            apiKey: ApiKeys.geminiApiKey,
          );
          result = await model.generateContent([Content.text(prompt)]);
          if (result.text != null && result.text!.trim().isNotEmpty) {
            print('=== Success with model: $modelName ===');
            break;
          }
        } catch (e) {
          print('Model $modelName error/quota reached: $e');
          lastError = e.toString();
        }
      }

      if (result == null || result.text == null || result.text!.trim().isEmpty) {
        throw Exception('Gagal memproses dengan Gemini AI (Quota Exceeded): $lastError');
      }

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
        final rawDate = data['date']?.toString() ?? '';
        _dateEventController.text = _cleanDateString(rawDate);
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
          if (posterUrl.toLowerCase().contains('.webp')) extension = '.webp';
          else if (posterUrl.toLowerCase().contains('.png')) extension = '.png';

          // Menggunakan wsrv.nl (Images weserv) yang memang khusus dirancang sebagai proxy dan 
          // CDN cache untuk gambar (mendukung CORS dan tidak memblokir tipe konten).
          final imageProxyUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(posterUrl)}';
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
                                labelText: 'Paste Event URL (RuangCosplay, Instagram, dll)',
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
                                  GestureDetector(
                                    onTap: () => _showPosterPreview(
                                      poster['url'],
                                      poster['path'].split('/').last,
                                    ),
                                    child: Stack(
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
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.zoom_in,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                         if (index >= 0 && index < newPosters.length) {
                                           final removed = newPosters.removeAt(index);
                                           if (removed['is_main'] == true && newPosters.isNotEmpty) {
                                             newPosters.first['is_main'] = true;
                                           }
                                           for (int i = 0; i < newPosters.length; i++) {
                                             newPosters[i]['order'] = i;
                                           }
                                           final path = removed['path']?.toString();
                                           if (path != null && path.isNotEmpty && !path.startsWith('http')) {
                                             FirebaseStorage.instance.ref().child(path).delete().catchError((_) {});
                                           }
                                         }
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
                                      labelText: 'Paste Event URL (RuangCosplay, Instagram, dll)',
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
                                        GestureDetector(
                                          onTap: () => _showPosterPreview(
                                            poster['url'],
                                            poster['path'].split('/').last,
                                          ),
                                          child: Stack(
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
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Icon(
                                                    Icons.zoom_in,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                                   if (index >= 0 && index < newPosters.length) {
                                                     final removed = newPosters.removeAt(index);
                                                     if (removed['is_main'] == true && newPosters.isNotEmpty) {
                                                       newPosters.first['is_main'] = true;
                                                     }
                                                     for (int i = 0; i < newPosters.length; i++) {
                                                       newPosters[i]['order'] = i;
                                                     }
                                                     final path = removed['path']?.toString();
                                                     if (path != null && path.isNotEmpty && !path.startsWith('http')) {
                                                       FirebaseStorage.instance.ref().child(path).delete().catchError((_) {});
                                                     }
                                                   }
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
