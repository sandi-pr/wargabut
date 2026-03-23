import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:localstorage/localstorage.dart';

class AniNewsProvider with ChangeNotifier {
  String _searchTerm = '';
  List<Map<String, dynamic>> _allNews = [];
  List<Map<String, dynamic>> _filteredNews = [];
  List<Map<String, dynamic>> _allScheduled = [];
  bool _isLoading = true;
  bool _forceShowList = false;
  String _activeSection = 'news';

  List<String> _tags = [];
  List<String> _genres = [];
  List<String> _selectedTags = [];
  List<String> _selectedGenres = [];

  bool get isForceShow => _forceShowList;

  bool get isFilterActive =>
      _forceShowList ||
          _searchTerm.isNotEmpty ||
          _selectedTags.isNotEmpty ||
          _selectedGenres.isNotEmpty;

  String get searchTerm => _searchTerm;

  List<Map<String, dynamic>> get allNews => _allNews;

  List<Map<String, dynamic>> get filteredNews => _filteredNews;

  List<Map<String, dynamic>> get allScheduled => _allScheduled;

  List<String> get tags => _tags;
  List<String> get genres => _genres;
  List<String> get selectedTags => _selectedTags;
  List<String> get selectedGenres => _selectedGenres;

  bool get isLoading => _isLoading;

  String get activeSection => _activeSection;

  void showFullList(String sectionType) {
    _activeSection = sectionType;
    _forceShowList = true;
    notifyListeners();
  }

  void clearFilters() {
    _searchTerm = '';
    _selectedTags = [];
    _selectedGenres = [];
    _forceShowList = false;
    _activeSection = 'news';
    _filterNews();
  }

  void setSearchTerm(String value) {
    if (kDebugMode) {
      print('AniNewsProvider setSearchTerm: value = $value');
    }
    _searchTerm = value;
    _filterNews(); // Langsung panggil filter saja
  }

  void setSelectedTags(List<String> tags) {
    _selectedTags = tags;
    _filterNews();
  }

  void setSelectedGenres(List<String> genres) {
    _selectedGenres = genres;
    _filterNews();
  }

  DateTime? _parseDate(String dateString) {
    if (dateString.trim().isEmpty) return null;

    String cleanDateString = dateString.trim();
    String dateToParse = cleanDateString;

    // --- Coba parsing format non-rentang terlebih dahulu ---
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').parse(dateToParse);
    } catch (e) { /* Lanjutkan */ }

    try {
      return DateFormat('MMM yyyy', 'id_ID').parse(dateToParse);
    } catch (e) { /* Lanjutkan */ }

    // --- LOGIKA BARU: Penanganan Rentang Tanggal ---
    if (dateToParse.contains('-')) {
      try {
        List<String> parts = dateToParse.split(' ');

        // Kasus 1: "20-21 Des 2025"
        if (parts.length == 3 && parts[0].contains('-')) {
          String firstDate = parts[0].split('-')[0].trim();
          dateToParse = "$firstDate ${parts[1]} ${parts[2]}";
        }
        // Kasus 2: "29 Nov - 02 Des 2025" atau "24 Des 2025 - 04 Jan 2026"
        else if (parts.contains('-')) {
          final separatorIndex = parts.indexOf('-');
          // Ambil bagian tanggal mulai (sebelum tanda hubung)
          String startDateString = parts.sublist(0, separatorIndex).join(' ');

          // Cek jika tanggal mulai tidak mengandung tahun (e.g., "29 Nov")
          bool startDateHasYear = startDateString.split(' ').any((part) => part.length == 4 && int.tryParse(part) != null);

          if (!startDateHasYear) {
            // Cari tahun pertama yang muncul di seluruh string
            String? year = parts.firstWhere((part) => part.length == 4 && int.tryParse(part) != null, orElse: () => '');
            if (year.isNotEmpty) {
              startDateString = '$startDateString $year';
            }
          }
          dateToParse = startDateString;
        }

        // Parse hasil rekonstruksi
        return DateFormat('dd MMM yyyy', 'id_ID').parse(dateToParse);

      } catch (e) {
        // Jika logika rentang gagal, lanjutkan ke fallback terakhir
      }
    }

    // Jika semua format gagal, kembalikan null dan cetak error
    if (kDebugMode) {
      print('[PARSE ERROR] Gagal mem-parsing tanggal untuk input: "$dateString"');
    }
    return null;
  }

  List<Map<String, dynamic>> get latestNews {
    // 1. Ambil HANYA berita biasa (bukan scheduled)
    final List<Map<String, dynamic>> newsOnly =
    _allNews.where((news) => news['is_scheduled'] != true).toList();

    // 2. Urutkan berdasarkan tanggal terbaru (Descending)
    newsOnly.sort((a, b) {
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;  // news tanpa tanggal di bawah
      if (dateB == null) return -1;

      // Descending: Tanggal terbaru di atas
      return dateB.compareTo(dateA);
    });

    // 3. Ambil 2 berita pertama (Bisa disesuaikan angkanya)
    return newsOnly.take(2).toList();
  }

  List<Map<String, dynamic>> get upcomingScheduled {
    // 1. Ambil HANYA yang dijadwalkan (scheduled)
    final List<Map<String, dynamic>> scheduledOnly =
    _allNews.where((news) => news['is_scheduled'] == true).toList();

    // 2. Urutkan berdasarkan tanggal terdekat (Ascending)
    scheduledOnly.sort((a, b) {
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // item tanpa tanggal di bawah
      if (dateB == null) return -1;

      // Ascending: Tanggal paling dekat dengan hari ini di atas
      return dateA.compareTo(dateB);
    });

    // 3. Ambil 2 jadwal pertama (Bisa disesuaikan angkanya)
    return scheduledOnly.take(2).toList();
  }

  // Helper untuk mengubah "Winter 2026" menjadi skor angka agar mudah diurutkan
  int _getSeasonScore(String tag) {
    final regex = RegExp(r'^(Winter|Spring|Summer|Fall)\s+(\d{4})$', caseSensitive: false);
    final match = regex.firstMatch(tag.trim());

    if (match == null) return -1; // Bukan tag musim

    String season = match.group(1)!.toLowerCase();
    int year = int.parse(match.group(2)!);

    int quarter = 0;
    if (season == 'winter') {
      quarter = 0;
    } else if (season == 'spring') {
      quarter = 1;
    }
    else if (season == 'summer') {
      quarter = 2;
    }
    else if (season == 'fall') {
      quarter = 3;
    }

    return (year * 4) + quarter;
  }

  void _filterNews() {
    // 1. Ambil data yang cocok dengan pencarian (Search & Tags)
    List<Map<String, dynamic>> searchResults = _allNews.where((news) {
      String newsTitle = news['title'] ?? '';
      String eventDate = news['date'] ?? '';
      String description = news['desc'] ?? '';
      List<dynamic> newsTags = news['tags'] ?? [];
      List<dynamic> newsGenres = news['genres'] ?? [];

      // 1. Pengecekan Kata Kunci Pencarian (Search Bar)
      String searchLower = _searchTerm.toLowerCase();
      bool matchesText = newsTitle.toLowerCase().contains(searchLower) ||
          eventDate.toLowerCase().contains(searchLower) ||
          description.toLowerCase().contains(searchLower);
      bool matchesSearchTags = newsTags.any((t) => t.toString().toLowerCase().contains(searchLower));
      bool matchesSearchGenres = newsGenres.any((g) => g.toString().toLowerCase().contains(searchLower));

      bool passSearch = matchesText || matchesSearchTags || matchesSearchGenres;

      // 2. Pengecekan Filter Chip (Tag & Genre dari Filter Sheet)
      bool passSelectedTags = _selectedTags.isEmpty ||
          newsTags.any((t) => _selectedTags.contains(t.toString()));

      bool passSelectedGenres = _selectedGenres.isEmpty ||
          newsGenres.any((g) => _selectedGenres.contains(g.toString()));

      // Harus lolos pencarian teks DAN lolos filter chip
      return passSearch && passSelectedTags && passSelectedGenres;
    }).toList();

    // 2. Pisahkan data menjadi 2 list berdasarkan 'is_scheduled'
    _allScheduled = searchResults.where((news) => news['is_scheduled'] == true).toList();
    _filteredNews = searchResults.where((news) => news['is_scheduled'] != true).toList();

    // 3. Urutkan _allScheduled (Jadwal Mendatang)
    // Aturan: Tanggal terdekat dengan hari ini di paling atas (Ascending)
    _allScheduled.sort((a, b) {
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;  // Item tanpa tanggal ditaruh di bawah
      if (dateB == null) return -1;

      return dateA.compareTo(dateB); // Ascending
    });

    // 4. Urutkan _filteredNews (Berita/Artikel Biasa)
    // Aturan: Tanggal terbaru/paling update di paling atas (Descending)
    _filteredNews.sort((a, b) {
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;  // Item tanpa tanggal ditaruh di bawah
      if (dateB == null) return -1;

      return dateB.compareTo(dateA); // Descending (dateB duluan)
    });

    if (isFilterActive) {
      // Jika hasil Berita kosong, tapi Jadwal ada isinya -> Pindah otomatis ke Jadwal
      if (_filteredNews.isEmpty && _allScheduled.isNotEmpty) {
        _activeSection = 'scheduled';
      }
      // Sebaliknya, jika Jadwal kosong, tapi Berita ada isinya -> Pindah ke Berita
      else if (_allScheduled.isEmpty && _filteredNews.isNotEmpty) {
        _activeSection = 'news';
      }
    }

    if (!isFilterActive) {
      _forceShowList = false;
      // Opsional: Kembalikan ke tab default jika filter dihapus semua
      _activeSection = 'news';
    }

    if (kDebugMode) {
      print("Scheduled news length: ${_allScheduled.length}");
      print("Filtered news length: ${_filteredNews.length}");
      print("Active Section: $_activeSection"); // Cek di log pindah ke mana
    }

    notifyListeners();
  }

  Future<void> fetchData({bool forceRefresh = false}) async {
    await initLocalStorage();
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      // Check cache only if not forceRefresh
      // Check for cache expiration (1 day)
      late int lastFetchTime;
      if (kIsWeb) {
        lastFetchTime = int.parse(localStorage.getItem('lastFetchAniTime')?.toString() ?? '0');
      } else {
        lastFetchTime = prefs.getInt('lastFetchAniTime') ?? 0;
      }

      DateTime now = DateTime.now();
      DateTime lastFetchDate = DateTime.fromMillisecondsSinceEpoch(lastFetchTime);

      // Bandingkan hanya tahun, bulan, dan hari
      bool isSameDay = now.year == lastFetchDate.year &&
          now.month == lastFetchDate.month &&
          now.day == lastFetchDate.day;

      if (isSameDay) {
        // Load from cache
        _allNews = jsonDecode(localStorage.getItem('cachedAnichekku')!)
            .cast<Map<String, dynamic>>();
        if (kIsWeb) {
          _allNews = jsonDecode(localStorage.getItem('cachedAnichekku')!)
              .cast<Map<String, dynamic>>();

        } else {
          _allNews = jsonDecode(prefs.getString('cachedAnichekku')!)
              .cast<Map<String, dynamic>>();
          if (kDebugMode) {
            print("News loaded from prefs: ${_allNews.length}");
          }
        }

        _isLoading = false;
        notifyListeners();
        _filterNews();
        return; // Exit early
      }
    }

    try {
      if (kDebugMode) {
        print("Fetching data from Firestore...");
      }
      QuerySnapshot eventSnapshot =
      await FirebaseFirestore.instance.collection('anichekku').get();

      List<Map<String, dynamic>> newsWithId = eventSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      Set<String> tagSet = {};
      Set<String> genreSet = {};
      for (var news in newsWithId) {
        if (news['tags'] != null) {
          tagSet.addAll((news['tags'] as List).map((e) => e.toString()));
        }
        if (news['genres'] != null) {
          genreSet.addAll((news['genres'] as List).map((e) => e.toString()));
        }
      }
      _tags = tagSet.toList();
      _genres = genreSet.toList();

      _allNews = newsWithId;

      DateTime now = DateTime.now();
      // Kuartal saat ini: Jan-Mar (0), Apr-Jun (1), Jul-Sep (2), Okt-Des (3)
      int currentQuarter = (now.month - 1) ~/ 3;
      int currentScore = (now.year * 4) + currentQuarter;

      _tags.sort((a, b) {
        int scoreA = _getSeasonScore(a);
        int scoreB = _getSeasonScore(b);

        bool isSeasonA = scoreA != -1;
        bool isSeasonB = scoreB != -1;

        // Prioritas 1: Tag Musim selalu di atas tag biasa
        if (isSeasonA && !isSeasonB) return -1;
        if (!isSeasonA && isSeasonB) return 1;

        // Prioritas 2: Jika KEDUANYA adalah Tag Musim
        if (isSeasonA && isSeasonB) {
          bool aIsPast = scoreA < currentScore; // Apakah ini musim lalu?
          bool bIsPast = scoreB < currentScore;

          // Jika A masa lalu dan B masa sekarang/depan -> B ditarik ke atas
          if (aIsPast && !bIsPast) return 1;
          if (!aIsPast && bIsPast) return -1;

          // Jika KEDUANYA masa sekarang/depan -> Urutkan secara kronologis (Menaik)
          // Contoh: Winter 2026 -> Spring 2026 -> Summer 2026
          if (!aIsPast && !bIsPast) {
            return scoreA.compareTo(scoreB);
          }

          // Jika KEDUANYA masa lalu -> Urutkan terbalik (Menurun)
          // Agar masa lalu yang paling dekat (misal: Fall 2025) ada di atas masa lalu yang jauh (Spring 2024)
          if (aIsPast && bIsPast) {
            return scoreB.compareTo(scoreA);
          }
        }

        // Prioritas 3: Tag biasa diurutkan sesuai abjad (A-Z)
        return a.compareTo(b);
      });

      // (Opsional) Urutkan genre sesuai abjad agar rapi
      _genres.sort((a, b) => a.compareTo(b));

      // _tags = tagSet.toList();
      _isLoading = false;
      notifyListeners();
      await initLocalStorage();
      localStorage.clear();
      _filterNews();
      if (kIsWeb) {
        await initLocalStorage();
        localStorage.setItem('cachedAnichekku', jsonEncode(_allNews));
        localStorage.setItem(
            'lastFetchAniTime', DateTime.now().millisecondsSinceEpoch.toString());
      } else {
        await prefs.setString('cachedAnichekku', jsonEncode(_allNews));
        await prefs.setInt(
            'lastFetchAniTime', DateTime.now().millisecondsSinceEpoch);
      }
      if (kDebugMode) {
        print("✅ Data fetched and cached");
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
    }
  }
}