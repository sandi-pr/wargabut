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
  List<String> _tags = [];
  List<String> _selectedTags = [];
  bool _isLoading = true;
  bool _forceShowList = false;

  bool get isForceShow => _forceShowList;

  bool get isFilterActive =>
      _forceShowList ||
          _searchTerm.isNotEmpty ||
          _selectedTags.isNotEmpty;

  String get searchTerm => _searchTerm;

  List<Map<String, dynamic>> get allNews => _allNews;

  List<Map<String, dynamic>> get filteredNews => _filteredNews;

  List<String> get tags => _tags;

  List<String> get selectedTags => _selectedTags;

  bool get isLoading => _isLoading;

  void showFullList() {
    _forceShowList = true;
    notifyListeners();
  }

  void clearFilters() {
    _searchTerm = '';
    _selectedTags = [];
    _forceShowList = false;
    _filterNews(); // Panggil _filterNews setelah membersihkan state
  }

  void setSearchTerm(String value) {
    if (kDebugMode) {
      print('AniNewsProvider setSearchTerm: value = $value');
    }
    _searchTerm = value;
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

  List<Map<String, dynamic>> get nearestEvents {
    // 1. Buat salinan dari _allEvents agar tidak mengubah urutan aslinya.
    final List<Map<String, dynamic>> sortedByDate = List.from(_allNews);

    // 2. Urutkan salinan tersebut HANYA berdasarkan tanggal.
    sortedByDate.sort((a, b) {
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // news tanpa tanggal tetap di bawah
      if (dateB == null) return -1; // news tanpa tanggal tetap di bawah

      // --- PERUBAHAN DI SINI ---
      // Urutkan berdasarkan tanggal terbaru (descending/menurun)
      // dengan membalik urutan perbandingan.
      return dateB.compareTo(dateA);
    });

    // 3. Ambil 2 event pertama dari daftar yang sudah terurut.
    return sortedByDate.take(2).toList();
  }

  void _filterNews() {
    // Filter the events based on search term, selected areas, and selected months
    _filteredNews = _allNews.where((news) {
      String newsTitle = news['title'] ?? '';
      String eventDate = news['date'] ?? '';
      String description = news['desc'] ?? '';
      // String area = news['tags'] ?? [];
      bool matchesSearchTerm =
          newsTitle.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              eventDate.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              description.toLowerCase().contains(_searchTerm.toLowerCase());

      // Filter by tags
      // bool matchesTags = _selectedTags.isEmpty || _selectedTags.contains(area);

      return matchesSearchTerm;
    }).toList();

    // Sort the filtered news based on date
    _filteredNews.sort((a, b) {
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // news tanpa tanggal tetap di bawah
      if (dateB == null) return -1; // news tanpa tanggal tetap di bawah

      // --- PERUBAHAN DI SINI ---
      // Urutkan berdasarkan tanggal terbaru (descending/menurun)
      // dengan membalik urutan perbandingan.
      return dateB.compareTo(dateA);
    });

    if (_searchTerm.isEmpty && _selectedTags.isEmpty) {
      _forceShowList = false;
    }

    print("Filtered news length: ${_filteredNews.length}");

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

      // Set<String> tagSet = newsWithId
      //     .map((event) => event['area']?.toString() ?? '')
      //     .where((area) => area.isNotEmpty)
      //     .toSet();

      _allNews = newsWithId;
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