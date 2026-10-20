import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/api_keys.dart';
import '../models/tanya_maps_models.dart';
import '../utils/location_utils.dart';

class TanyaMapsService {
  static const String _prefCustomApiKey = 'custom_gemini_api_key';
  static const _uuid = Uuid();

  /// Mengambil API Key yang aktif (custom dari settings atau bawaan config)
  static Future<String> getActiveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString(_prefCustomApiKey);
    if (customKey != null && customKey.trim().isNotEmpty) {
      return customKey.trim();
    }
    return ApiKeys.geminiApiKey;
  }

  /// Menyimpan API Key kustom dari pengguna
  static Future<void> setCustomApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_prefCustomApiKey);
    } else {
      await prefs.setString(_prefCustomApiKey, key.trim());
    }
  }

  /// Memproses pertanyaan "Tanya Wargabut" dari pengguna
  static Future<TanyaMapsMessage> queryAskMaps({
    required String userPrompt,
    double? userLat,
    double? userLng,
    List<Map<String, dynamic>>? cachedEvents,
  }) async {
    // 1. Dapatkan daftar event dari cache atau Firestore
    List<Map<String, dynamic>> allEvents = [];
    if (cachedEvents != null && cachedEvents.isNotEmpty) {
      allEvents = List<Map<String, dynamic>>.from(cachedEvents);
    } else {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('jfestchart')
            .limit(100)
            .get();
        allEvents = snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        debugPrint('[TanyaMapsService] Error fetching from firestore: $e');
      }
    }

    final apiKey = await getActiveApiKey();
    bool hasValidKeyFormat = apiKey.startsWith('AIzaSy') || apiKey.length >= 20;
    final bool wantsWebSearch = _shouldSearchInternet(userPrompt);
    debugPrint('[TanyaWargabut] Pertanyaan: "$userPrompt" (Deteksi butuh internet: $wantsWebSearch)');

    // Coba gunakan Gemini AI jika API key berformat wajar
    if (hasValidKeyFormat) {
      try {
        // 1. Jika pertanyaan membutuhkan internet, coba Google Search Grounding
        if (wantsWebSearch) {
          final searchResult = await _queryWithGoogleSearchGrounding(
            apiKey: apiKey,
            prompt: userPrompt,
            userLat: userLat,
            userLng: userLng,
            events: allEvents,
          );
          if (searchResult != null) {
            return searchResult;
          }
        }

        // 2. Query Utama / Direct Generative Model (Sangat Cepat, Tanpa Hambatan Quota)
        final aiResult = await _queryWithGemini(
          apiKey: apiKey,
          prompt: userPrompt,
          userLat: userLat,
          userLng: userLng,
          events: allEvents,
        );
        if (aiResult != null) {
          return aiResult;
        }

        // 3. Jika query belum terjawab dan belum mencoba web search, coba sebagai fallback
        if (!wantsWebSearch) {
          final searchFallback = await _queryWithGoogleSearchGrounding(
            apiKey: apiKey,
            prompt: userPrompt,
            userLat: userLat,
            userLng: userLng,
            events: allEvents,
          );
          if (searchFallback != null) {
            return searchFallback;
          }
        }
      } catch (e) {
        debugPrint('[TanyaMapsService] Gemini API call error: $e. Using local smart fallback.');
      }
    }

    // 2. Fallback cerdas: Rule-based Semantic Search lokal
    return _localSmartSearch(
      userPrompt: userPrompt,
      userLat: userLat,
      userLng: userLng,
      events: allEvents,
      apiKeyValid: hasValidKeyFormat,
    );
  }

  /// Deteksi apakah pengguna menanyakan hal yang membutuhkan pencarian internet
  static bool _shouldSearchInternet(String prompt) {
    final lower = prompt.toLowerCase();
    final webKeywords = [
      'internet', 'google', 'web', 'online', 'browsing', 'cari di',
      'guest star', 'bintang tamu', 'line up', 'lineup', 'artis',
      'rundown', 'tiket presale', 'presale', 'tour', 'tur', 'konser',
      'lagu', 'seiyuu', 'pengisi suara', 'vocalist', 'vokalis',
      'kapan rilis', 'berita', 'anime', 'manga', 'kreator', 'author',
      'creator', 'komik', 'yoasobi', 'ado', 'jepang', 'cosplayer',
      'coswalk', 'comifuro', 'cf', 'tiket', 'harga tiket',
      'history', 'sejarah', 'riwayat', 'edisi', 'kapan saja', 'daftar'
    ];
    for (final kw in webKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  /// Format tanggal hari ini dalam bahasa Indonesia sebagai patokan waktu real-time
  static String _getFormattedTodayDate() {
    final now = DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  /// Pemrosesan Hybrid: Database Event + Google Search Grounding (Live Internet)
  static Future<TanyaMapsMessage?> _queryWithGoogleSearchGrounding({
    required String apiKey,
    required String prompt,
    double? userLat,
    double? userLng,
    required List<Map<String, dynamic>> events,
  }) async {
    // Siapkan ringkasan event untuk konteks AI
    final compactList = events.take(60).map((raw) {
      final docId = (raw['id'] ?? '').toString();
      final ev = TanyaMapsEvent.fromFirestore(docId, raw);
      return {
        'id': ev.id,
        'nama': ev.title,
        'lokasi': ev.locationName,
        'tanggal': ev.date,
        'htm': ev.htm,
        'kategori': ev.category,
      };
    }).toList();

    final todayStr = _getFormattedTodayDate();
    final currentYear = DateTime.now().year;

    final systemPrompt =
        'Kamu adalah WGuide - Tanya Wargabut AI asisten cerdas dan serba tahu untuk wargabut.id.\n'
        'INFORMASI WAKTU HARI INI: $todayStr (Tahun $currentYear).\n'
        'Jadikan waktu hari ini sebagai patokan waktu mutlak saat menjawab waktu (kapan, tahun ini, masa lalu, atau masa depan):\n'
        '- Jika ada konser/event yang berlangsung di tahun sebelum $currentYear (seperti 2024 atau 2025), sebutkan secara jelas bahwa konser/event tersebut SUDAH BERLALU di masa lalu.\n'
        '- WAJIB SELALU GUNAKAN Google Search untuk mencari data terkini dan riwayat lengkap dari internet (Wikipedia, web resmi, berita) agar informasimu 100% akurat dan update hingga tahun $currentYear. JANGAN mengandalkan ingatan lama karena data event/konser terus bertambah setiap tahunnya.\n'
        '- Jika pengguna menanyakan riwayat/sejarah atau edisi event (seperti Comifuro, Anime Festival Asia, konser musisi, dsb), telusuri Google Search untuk mendapatkan daftar lengkap seluruh edisi dari awal hingga edisi terbaru di tahun $currentYear.\n'
        '- Jika pengguna menanyakan konser/event tanpa menyebutkan tahun secara spesifik, prioritaskan menginfokan apakah ada pengumuman konser di tahun $currentYear atau yang akan datang, dan jelaskan juga riwayat konser PALING TERAKHIR yang pernah diadakan sebelumnya di Jakarta (termasuk konser terbaru tahun 2025 maupun 2024) beserta harga tiketnya secara lengkap sebagai referensi.\n'
        '- Kamu memiliki 2 sumber data utama:\n'
        '1. Database Resmi wargabut.id (terlampir di bawah).\n'
        '2. Google Search (pencarian web real-time yang terhubung langsung).\n\n'
        'Aturan menjawab:\n'
        '- Gunakan database wargabut.id untuk merekomendasikan event dan menentukan pin lokasi di peta.\n'
        '- Kamu BISA menjawab pertanyaan apa pun seputar event, konser, info guest star, tiket, artis/seiyuu, anime, budaya jejepangan, maupun informasi terkini di internet secara informatif, ramah, santai, dan seru!\n'
        '- PENTING: Jika pengguna menanyakan info detail yang tidak ada di database, LANGSUNG berikan jawaban lengkap & detail dari Google Search di pesan yang sama! JANGAN PERNAH hanya menjawab "aku coba carikan info ya" atau berjanji akan mencari, melainkan langsung jelaskan rincian hasil temuannya sekarang juga.\n'
        '- Di baris paling akhir jawabanmu, WAJIB tuliskan ID event dari database wargabut.id yang relevan (jika ada) dalam format persis:\n'
        'MATCHED_IDS: [id1, id2]\n'
        'Jika tidak ada event dari database yang cocok, tuliskan:\n'
        'MATCHED_IDS: []';

    final fullPrompt =
        'Waktu saat ini: $todayStr (Tahun $currentYear)\n\n'
        'Daftar event di database wargabut.id:\n'
        '${jsonEncode(compactList)}\n\n'
        'Pertanyaan pengguna:\n'
        '"$prompt"';

    const searchModels = ['gemini-2.5-flash'];

    for (final modelName in searchModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
        );

        final requestBody = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': fullPrompt}
              ]
            }
          ],
          'system_instruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
          'tools': [
            {'google_search': {}}
          ],
          'generationConfig': {
            'temperature': 0.35,
          }
        };

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 14));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final partsList = (json['candidates']?[0]?['content']?['parts'] as List<dynamic>?) ?? [];
          if (partsList.isEmpty) continue;

          String rawText = '';
          if (partsList.length == 1) {
            rawText = partsList[0]['text'] as String? ?? '';
          } else {
            // Ketika ada multiple parts saat Google Search Grounding:
            // Seringkali part awal adalah pemikiran/pengantar, dan part berikutnya adalah jawaban tergrounding lengkap.
            final textParts = partsList
                .map((p) => (p['text'] as String? ?? '').trim())
                .where((t) => t.isNotEmpty)
                .toList();

            final lastPart = textParts.isNotEmpty ? textParts.last : '';
            // Jika part terakhir memiliki MATCHED_IDS atau adalah jawaban utama (> 80 karakter)
            if (lastPart.contains('MATCHED_IDS') || lastPart.length > 80) {
              final firstPart = textParts.first;
              if (firstPart.contains('coba carikan') ||
                  firstPart.contains('mencari di internet') ||
                  firstPart.contains('mencari info')) {
                rawText = lastPart;
              } else {
                rawText = textParts.join('\n\n');
              }
            } else {
              rawText = textParts.join('\n\n');
            }
          }

          if (rawText.trim().isEmpty) continue;

          // Ekstraksi MATCHED_IDS
          final matchedIds = <String>{};
          String cleanMessage = rawText;
          final regExp = RegExp(r'MATCHED_IDS:\s*\[(.*?)\]', multiLine: true);
          final match = regExp.firstMatch(rawText);
          if (match != null) {
            final idsString = match.group(1) ?? '';
            for (var item in idsString.split(',')) {
              final trimmed = item.trim().replaceAll('"', '').replaceAll("'", '');
              if (trimmed.isNotEmpty) matchedIds.add(trimmed);
            }
            cleanMessage = rawText.replaceAll(match.group(0)!, '').trim();
          }

          // Cek apakah Google Search Grounding aktif melakukan pencarian web
          final grounding = json['candidates']?[0]?['groundingMetadata'] as Map<String, dynamic>?;
          final webQueries = (grounding?['webSearchQueries'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          if (webQueries.isNotEmpty) {
            debugPrint('[TanyaWargabut] 🌐 Google Search Grounding BERHASIL! Kueri web yang dicari: $webQueries');
            cleanMessage = '$cleanMessage\n\n_🌐 Ditelusuri via Google Search_';
          } else {
            debugPrint('[TanyaWargabut] ℹ️ Google Search Grounding terhubung.');
          }

          List<TanyaMapsEvent> recommended = [];
          if (matchedIds.isNotEmpty) {
            recommended = events
                .where((raw) => matchedIds.contains((raw['id'] ?? '').toString()))
                .map((raw) {
                  final docId = (raw['id'] ?? '').toString();
                  double? dist;
                  if (userLat != null && userLng != null) {
                    final ev = TanyaMapsEvent.fromFirestore(docId, raw);
                    if (ev.latitude != 0.0 && ev.longitude != 0.0) {
                      dist = calculateDistanceKm(userLat, userLng, ev.latitude, ev.longitude);
                    }
                  }
                  return TanyaMapsEvent.fromFirestore(docId, raw, distance: dist);
                })
                .toList();
          } else if (webQueries.isEmpty) {
            // Hanya jalankan filter lokal jika BUKAN hasil pencarian murni internet
            final isGreeting = prompt.trim().toLowerCase().startsWith('halo') ||
                prompt.trim().toLowerCase().startsWith('hai') ||
                prompt.trim().toLowerCase() == 'tes';
            if (!isGreeting) {
              recommended = _filterEvents(
                events: events,
                keyword: prompt,
                userLat: userLat,
                userLng: userLng,
              );
            }
          }

          return TanyaMapsMessage(
            id: _uuid.v4(),
            isUser: false,
            text: cleanMessage.isNotEmpty ? cleanMessage : 'Berikut informasi yang aku temukan!',
            recommendedEvents: recommended,
            timestamp: DateTime.now(),
          );
        } else {
          debugPrint('[TanyaMapsService] Google Search Grounding ($modelName) returned ${response.statusCode}, switching to direct AI.');
          if (response.statusCode == 429) {
            // Kuota pencarian Google search habis pada akun API, langsung beralih ke direct AI
            break;
          }
        }
      } catch (e) {
        debugPrint('[TanyaMapsService] Note: Google Search ($modelName) bypassed: $e');
      }
    }

    return null;
  }

  static const List<String> _candidateModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
  ];

  /// Pemrosesan via Google Gemini dengan konteks database event & JSON parsing
  static Future<TanyaMapsMessage?> _queryWithGemini({
    required String apiKey,
    required String prompt,
    double? userLat,
    double? userLng,
    required List<Map<String, dynamic>> events,
  }) async {
    // Siapkan ringkasan event untuk konteks AI (maksimal 60 event agar hemat token dan cepat)
    final compactList = events.take(60).map((raw) {
      final docId = (raw['id'] ?? '').toString();
      final ev = TanyaMapsEvent.fromFirestore(docId, raw);
      return {
        'id': ev.id,
        'nama': ev.title,
        'lokasi': ev.locationName,
        'tanggal': ev.date,
        'htm': ev.htm,
        'kategori': ev.category,
      };
    }).toList();

    final todayStr = _getFormattedTodayDate();
    final currentYear = DateTime.now().year;

    final systemPrompt =
        'Kamu adalah WGuide - asisten AI Tanya Wargabut untuk wargabut.id.\n'
        'INFORMASI WAKTU HARI INI: $todayStr (Tahun $currentYear).\n'
        'Gunakan patokan waktu ini saat pengguna menanyakan event (misal hari ini, besok, weekend ini, bulan ini, atau tahun ini).\n'
        'Bantu pengguna menemukan event wibu, cosplay, anime matsuri, idol festival, komik, atau konser musik Jepang di peta maupun internet. '
        'Karaktermu: ramah, santai, seru, wibu-friendly, dan sangat membantu. '
        'Tugasmu:\n'
        '1. Pahami pertanyaan pengguna (apakah mencari rekomendasi event, tanya sejarah/riwayat, info seiyuu/artis, rekomendasi tempat, dsb).\n'
        '2. Jika pengguna menanyakan riwayat/sejarah, info artis, anime, atau pertanyaan informatif lainnya, jelaskan informasinya secara ramah, lengkap, dan informatif menggunakan pengetahuanmu.\n'
        '3. Pilihkan event yang paling relevan dari daftar database yang diberikan (jika ada event yang berkaitan).\n'
        '4. Tulis jawaban dalam bahasa Indonesia yang luwes, natural, dan interaktif (jelaskan secara singkat mengapa event itu cocok/seru, sebutkan tanggal, venue, dan HTM-nya).\n'
        '5. Kembalikan respons dalam format JSON valid persis seperti ini:\n'
        '{\n'
        '  "message": "isi teks jawaban ramah & natural untuk pengguna",\n'
        '  "matched_ids": ["id1", "id2"]\n'
        '}\n'
        'Catatan penting:\n'
        '- "matched_ids" adalah array string berisi id event dari database yang cocok dan direkomendasikan.\n'
        '- Jika pengguna hanya menyapa (halo/pagi/dsb) atau bertanya hal umum, jawab ramah, jelaskan kamu asisten Tanya Wargabut yang siap mencarikan event seru di peta & internet, dan kosongkan "matched_ids": [].\n'
        '- Jika tidak ada event yang cocok di database, sampaikan informasinya dengan santai dan beri alternatif pencarian, dan isi "matched_ids": [].';

    final fullPrompt =
        'Waktu saat ini: $todayStr (Tahun $currentYear)\n\n'
        'Daftar event di database wargabut.id:\n'
        '${jsonEncode(compactList)}\n\n'
        'Pertanyaan pengguna: "$prompt"';

    for (final modelName in _candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: Content.system(systemPrompt),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.35,
          ),
        );

        final response = await model.generateContent([Content.text(fullPrompt)]);
        final text = response.text;
        if (text == null || text.trim().isEmpty) continue;

        final decoded = jsonDecode(text) as Map<String, dynamic>;
        final messageText = (decoded['message'] as String? ?? '').trim();
        final matchedIds = (decoded['matched_ids'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((id) => id.isNotEmpty)
                .toSet() ??
            <String>{};

        List<TanyaMapsEvent> recommended = [];
        if (matchedIds.isNotEmpty) {
          recommended = events
              .where((raw) => matchedIds.contains((raw['id'] ?? '').toString()))
              .map((raw) {
                final docId = (raw['id'] ?? '').toString();
                double? dist;
                if (userLat != null && userLng != null) {
                  final ev = TanyaMapsEvent.fromFirestore(docId, raw);
                  if (ev.latitude != 0.0 && ev.longitude != 0.0) {
                    dist = calculateDistanceKm(userLat, userLng, ev.latitude, ev.longitude);
                  }
                }
                return TanyaMapsEvent.fromFirestore(docId, raw, distance: dist);
              })
              .toList();
        }

        // Jika user bertanya mencari event tapi model belum mengembalikan matched_ids,
        // cocokkan dengan pencarian cerdas lokal
        final isGreeting = prompt.trim().toLowerCase().startsWith('halo') ||
            prompt.trim().toLowerCase().startsWith('hai') ||
            prompt.trim().toLowerCase() == 'tes';
        if (recommended.isEmpty && !isGreeting) {
          recommended = _filterEvents(
            events: events,
            keyword: prompt,
            userLat: userLat,
            userLng: userLng,
          );
        }

        return TanyaMapsMessage(
          id: _uuid.v4(),
          isUser: false,
          text: messageText.isNotEmpty ? messageText : 'Berikut beberapa rekomendasi event di peta untukmu!',
          recommendedEvents: recommended,
          timestamp: DateTime.now(),
        );
      } catch (e) {
        debugPrint('[TanyaMapsService] Model $modelName failed: $e. Trying next candidate model...');
      }
    }

    return null;
  }

  /// Filter cerdas event berdasarkan kriteria
  static List<TanyaMapsEvent> _filterEvents({
    required List<Map<String, dynamic>> events,
    String? keyword,
    String? cityOrArea,
    bool onlyFree = false,
    bool nearTransit = false,
    double? maxDistanceKm,
    double? userLat,
    double? userLng,
  }) {
    List<TanyaMapsEvent> results = [];

    for (final raw in events) {
      final title = (raw['event_name'] ?? raw['nama_event'] ?? raw['title'] ?? '').toString().toLowerCase();
      final loc = (raw['location'] ?? raw['lokasi'] ?? '').toString().toLowerCase();
      final htm = (raw['htm'] ?? raw['price'] ?? '').toString().toLowerCase();

      // Cek apakah punya koordinat valid
      double lat = 0.0;
      double lng = 0.0;
      if (raw['lat'] is num) lat = (raw['lat'] as num).toDouble();
      if (raw['lng'] is num) lng = (raw['lng'] as num).toDouble();

      // Hitung jarak jika koordinat user tersedia
      double? dist;
      if (userLat != null && userLng != null && lat != 0.0 && lng != 0.0) {
        dist = calculateDistanceKm(userLat, userLng, lat, lng);
      }

      // Filter: Free
      if (onlyFree) {
        final isFree = htm.contains('gratis') ||
            htm.contains('free') ||
            htm == '0' ||
            htm.contains('rp 0') ||
            htm.contains('rp. 0');
        if (!isFree) continue;
      }

      // Filter: Kota / Area
      if (cityOrArea != null && cityOrArea.trim().isNotEmpty) {
        final cleanArea = cityOrArea.toLowerCase().trim();
        final matchArea = loc.contains(cleanArea) ||
            title.contains(cleanArea) ||
            (raw['area']?.toString().toLowerCase().contains(cleanArea) ?? false);
        if (!matchArea) continue;
      }

      // Filter: Keyword (nama/kategori)
      if (keyword != null && keyword.trim().isNotEmpty) {
        final words = keyword.toLowerCase().split(' ').where((w) => w.length > 2);
        bool matchKeyword = words.isEmpty;
        for (final w in words) {
          if (title.contains(w) || loc.contains(w) || (raw['tags']?.toString().toLowerCase().contains(w) ?? false)) {
            matchKeyword = true;
            break;
          }
        }
        if (!matchKeyword) continue;
      }

      // Filter: Jarak Maksimal
      if (maxDistanceKm != null && dist != null && dist > maxDistanceKm) {
        continue;
      }

      final docId = raw['id']?.toString() ?? _uuid.v4();
      results.add(TanyaMapsEvent.fromFirestore(docId, raw, distance: dist));
    }

    // Urutkan: jika ada info jarak, prioritaskan yang terdekat
    if (userLat != null && userLng != null) {
      results.sort((a, b) {
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    }

    // Ambil maksimal 8 event terbaik
    return results.take(8).toList();
  }

  /// Engine pencarian cerdas lokal saat offline / limit AI
  static TanyaMapsMessage _localSmartSearch({
    required String userPrompt,
    double? userLat,
    double? userLng,
    required List<Map<String, dynamic>> events,
    required bool apiKeyValid,
  }) {
    final lower = userPrompt.toLowerCase();

    // Deteksi kriteria otomatis dari teks
    final bool onlyFree = lower.contains('gratis') || lower.contains('free') || lower.contains('0 rupiah');
    final bool nearTransit = lower.contains('krl') || lower.contains('mrt') || lower.contains('stasiun') || lower.contains('transit');

    String? detectedArea;
    final areaCandidates = [
      'jakarta selatan', 'jaksel', 'jakarta pusat', 'jakpus', 'jakarta barat', 'jakbar',
      'jakarta timur', 'jaktim', 'jakarta utara', 'jakut', 'bogor', 'depok',
      'tangerang selatan', 'tangsel', 'tangerang', 'bekasi', 'bandung', 'jakarta'
    ];
    for (final a in areaCandidates) {
      if (lower.contains(a)) {
        detectedArea = a.replaceAll('jaksel', 'jakarta selatan')
            .replaceAll('jakpus', 'jakarta pusat')
            .replaceAll('jakbar', 'jakarta barat')
            .replaceAll('jaktim', 'jakarta timur')
            .replaceAll('jakut', 'jakarta utara')
            .replaceAll('tangsel', 'tangerang selatan');
        break;
      }
    }

    String? keyword;
    final keywords = ['cosplay', 'matsuri', 'anime', 'wibu', 'idol', 'konser', 'j-pop', 'gigs'];
    for (final k in keywords) {
      if (lower.contains(k)) {
        keyword = k;
        break;
      }
    }

    var matched = _filterEvents(
      events: events,
      keyword: keyword,
      cityOrArea: detectedArea,
      onlyFree: onlyFree,
      nearTransit: nearTransit,
      userLat: userLat,
      userLng: userLng,
    );

    // Jika filter terlalu ketat sehingga tidak ada hasil, ambil event terdekat
    if (matched.isEmpty && events.isNotEmpty) {
      matched = _filterEvents(
        events: events,
        userLat: userLat,
        userLng: userLng,
      );
    }

    // Bangun teks balasan yang ramah dan interaktif
    final StringBuffer sb = StringBuffer();
    if (matched.isEmpty) {
      sb.writeln('Maaf, belum ada event yang cocok dengan kriteria tersebut di database saat ini.');
      sb.writeln('Coba tanyakan dengan kota lain (misal: "Event di Jakarta Selatan") atau hapus filter gratis!');
    } else {
      sb.writeln('🗺️ Ditemukan **${matched.length} event** di peta yang cocok untukmu!');
      if (onlyFree) sb.writeln('✨ Filter aktif: **HTM Gratis**');
      if (detectedArea != null) sb.writeln('📍 Wilayah: **$detectedArea**');
      if (nearTransit) sb.writeln('🚆 Prioritas: **Dekat Akses Transportasi Umum**');
      sb.writeln('\nKetuk salah satu kartu di bawah atau pin di peta untuk melihat posisi & rute transitnya!');
    }

    return TanyaMapsMessage(
      id: _uuid.v4(),
      isUser: false,
      text: sb.toString().trim(),
      recommendedEvents: matched,
      timestamp: DateTime.now(),
    );
  }
}
