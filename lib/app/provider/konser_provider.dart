import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:localstorage/localstorage.dart';

import '../services/transit_maps.dart';
import '../utils/location_utils.dart';

class KonserProvider with ChangeNotifier {
  String _searchTerm = '';
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  List<Map<String, dynamic>> _nearestLocEvents = [];
  List<String> _areas = [];
  List<String> _selectedAreas = [];
  bool _isLoading = true;
  List<String> _selectedMonths = [];
  bool _forceShowList = false;

  Position? _userPosition;

  List<Map<String, dynamic>> get nearestLocEvents =>
      _forceShowList ? _nearestLocEvents : _nearestLocEvents.take(2).toList();

  bool get isForceShow => _forceShowList;

  bool get hasUserLocation => _userPosition != null;

  bool get isFilterActive =>
      _forceShowList ||
          _searchTerm.isNotEmpty ||
          _selectedAreas.isNotEmpty ||
          _selectedMonths.isNotEmpty;

  String get searchTerm => _searchTerm;

  List<Map<String, dynamic>> get allEvents => _allEvents;

  List<Map<String, dynamic>> get filteredEvents => _filteredEvents;

  List<String> get areas => _areas;

  List<String> get selectedAreas => _selectedAreas;

  bool get isLoading => _isLoading;

  List<String> get selectedMonths => _selectedMonths;

  void showFullList() {
    _forceShowList = true;
    notifyListeners();
  }

  void clearFilters() {
    _searchTerm = '';
    _selectedAreas = [];
    _selectedMonths = [];
    _forceShowList = false;
    _filterEvents(); // Panggil _filterEvents setelah membersihkan state
  }

  void setSearchTerm(String value) {
    if (kDebugMode) {
      print('KonserProvider setSearchTerm: value = $value');
    }
    _searchTerm = value;
    _filterEvents();
  }

  void setAllEvents(List<Map<String, dynamic>> events) {
    _allEvents = events;
    notifyListeners();
    _filterEvents();
  }

  void setAreas(List<String> areas) {
    _areas = areas;
    notifyListeners();
    _filterEvents();
  }

  void setSelectedAreas(List<String> selectedAreas) {
    _selectedAreas = selectedAreas;
    notifyListeners();
    _filterEvents();
  }

  void setSelectedMonths(List<String> selectedMonths) {
    _selectedMonths = selectedMonths;
    notifyListeners();
    _filterEvents();
  }

  void showAllNearest() {
    _filteredEvents = _nearestLocEvents;
    _forceShowList = true;
    _selectedAreas = ["Terdekat"];
    notifyListeners();
  }

  DateTime? _parseDate(String dateString) {
    if (dateString.trim().isEmpty) return null;

    // 1. Normalisasi string: trim & ubah semua jenis strip (en-dash/em-dash) jadi hyphen biasa
    String cleanDateString = dateString.trim().replaceAll(RegExp(r'\s*[–—]\s*'), ' - ');
    String dateToParse = cleanDateString;

    // --- Helper untuk mencoba parse tanggal tunggal dengan berbagai format ---
    DateTime? tryParseSingleDate(String input) {
      try {
        return DateFormat('dd MMM yyyy', 'id_ID').parse(input); // Cth: 12 Apr 2026
      } catch (e) { /* Lanjut */ }

      try {
        return DateFormat('dd MMMM yyyy', 'id_ID').parse(input); // Cth: 12 April 2026 (FIX UTAMA)
      } catch (e) { /* Lanjut */ }

      try {
        return DateFormat('MMM yyyy', 'id_ID').parse(input); // Cth: Apr 2026
      } catch (e) { /* Lanjut */ }

      try {
        return DateFormat('MMMM yyyy', 'id_ID').parse(input); // Cth: April 2026
      } catch (e) { /* Lanjut */ }

      return null;
    }

    // 2. Coba parse langsung (untuk kasus bukan rentang, e.g. "12 April 2026")
    DateTime? result = tryParseSingleDate(dateToParse);
    if (result != null) return result;

    // 3. --- LOGIKA RENTANG TANGGAL ---
    if (dateToParse.contains('-')) {
      try {
        // Normalisasi spasi di sekitar strip agar split konsisten
        dateToParse = dateToParse.replaceAll(RegExp(r'\s*-\s*'), ' - ');

        List<String> parts = dateToParse.split(' ');

        if (parts.contains('-')) {
          final separatorIndex = parts.indexOf('-');

          // Ambil bagian tanggal mulai (sebelum tanda hubung)
          List<String> startPartList = parts.sublist(0, separatorIndex);
          String startDateString = startPartList.join(' ');

          // Cek jika bagian awal HANYA berisi angka (Kasus: "12 - 15 Feb 2026")
          bool isStartDayOnly = startPartList.length == 1 && int.tryParse(startPartList[0]) != null;

          if (isStartDayOnly) {
            // Ambil info bulan & tahun dari bagian akhir string
            List<String> endPartList = parts.sublist(separatorIndex + 1);
            if (endPartList.length >= 2) {
              String year = endPartList.last;
              String month = endPartList[endPartList.length - 2];
              dateToParse = "$startDateString $month $year";
            }
          }
          // Kasus Biasa (e.g., "29 Nov - ...")
          else {
            bool startDateHasYear = startPartList.any((part) => part.length == 4 && int.tryParse(part) != null);
            if (!startDateHasYear) {
              String? year = parts.firstWhere(
                      (part) => part.length == 4 && int.tryParse(part) != null,
                  orElse: () => ''
              );
              if (year.isNotEmpty) {
                startDateString = '$startDateString $year';
              }
            }
            dateToParse = startDateString;
          }
        }

        // 4. Parse hasil rekonstruksi rentang (menggunakan helper yang sama)
        // Ini penting agar rentang dengan nama bulan lengkap ("12 - 14 April 2026") juga bisa diparse
        result = tryParseSingleDate(dateToParse);
        if (result != null) return result;

      } catch (e) {
        // Jika logika rentang gagal, biarkan return null di bawah
      }
    }

    // Jika semua format gagal
    if (kDebugMode) {
      print('[PARSE ERROR Konser] Gagal mem-parsing tanggal untuk input: "$dateString"');
    }
    return null;
  }

  String? extractMonthName(String eventDate) {
    final monthMap = {
      'Jan': 'Januari',
      'Feb': 'Februari',
      'Mar': 'Maret',
      'Apr': 'April',
      'Mei': 'Mei',
      'Jun': 'Juni',
      'Jul': 'Juli',
      'Agu': 'Agustus',
      'Sep': 'September',
      'Okt': 'Oktober',
      'Nov': 'November',
      'Des': 'Desember',
    };

    // Cari singkatan atau nama lengkap
    final monthRegex = RegExp(
      r'(Jan|Feb|Mar|Apr|Mei|Jun|Jul|Agu|Sep|Okt|Nov|Des|Januari|Februari|Maret|April|Juni|Juli|Agustus|September|Oktober|November|Desember)',
      caseSensitive: false,
    );

    final match = monthRegex.firstMatch(eventDate);
    if (match != null) {
      String found = match.group(0)!;
      String formatted = toBeginningOfSentenceCase(found)!;

      // Jika sudah nama lengkap, langsung return
      if (monthMap.containsValue(formatted)) return formatted;

      // Jika singkatan, mapping ke nama lengkap
      return monthMap[formatted];
    }

    return null;
  }

  List<Map<String, dynamic>> get nearestEvents {
    // 1. Buat salinan dari _allEvents agar tidak mengubah urutan aslinya.
    final List<Map<String, dynamic>> sortedByDate = List.from(_allEvents);

    // 2. Urutkan salinan tersebut HANYA berdasarkan tanggal.
    sortedByDate.sort((a, b) {
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      // Logika sorting tanggal (event tanpa tanggal ditaruh di akhir)
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });

    // 3. Ambil 2 event pertama dari daftar yang sudah terurut.
    return sortedByDate.take(2).toList();
  }

  void _filterEvents() {
    // Filter the events based on search term, selected areas, and selected months
    _filteredEvents = _allEvents.where((event) {
      String eventName = event['event_name'] ?? '';
      String eventDate = event['date'] ?? '';
      String location = event['location'] ?? '';
      String description = event['desc'] ?? '';
      String area = event['area'] ?? '';
      bool matchesSearchTerm =
          eventName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              eventDate.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              location.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              description.toLowerCase().contains(_searchTerm.toLowerCase());

      // Filter by area
      bool matchesArea = _selectedAreas.isEmpty || _selectedAreas.contains(area);
      if (_selectedAreas.contains('Jakarta') && area.toLowerCase().startsWith('jakarta')) {
        matchesArea = true;
      }

      // Filter by month
      bool matchesMonth = true;
      if (_selectedMonths.isNotEmpty) {
        String? monthName = extractMonthName(eventDate);
        if (monthName != null) {
          matchesMonth = _selectedMonths.contains(monthName);
        } else {
          matchesMonth = false; // gagal ekstrak bulan
        }
      }

      return matchesSearchTerm && matchesArea && matchesMonth;
    }).toList();

    // Sort the filtered events based on date
    _filteredEvents.sort((a, b) {
      // Ambil status medpart dan poster untuk kedua event
      final bool isMedpartA = a['is_medpart'] ?? false;
      final bool isMedpartB = b['is_medpart'] ?? false;
      final bool isPosteredA = a['is_postered'] ?? false;
      final bool isPosteredB = b['is_postered'] ?? false;

      // Prioritas 1: Event Media Partner selalu di atas
      if (isMedpartA && !isMedpartB) return -1; // a (medpart) comes before b
      if (!isMedpartA && isMedpartB) return 1;  // b (medpart) comes before a

      // Prioritas 2: Jika status medpart sama, utamakan yang berposter
      // Ini hanya akan dijalankan jika keduanya medpart atau keduanya bukan medpart
      if (isPosteredA && !isPosteredB) return -1; // a (postered) comes before b
      if (!isPosteredA && isPosteredB) return 1;  // b (postered) comes before a

      // Prioritas 3: Jika semua status sama, urutkan berdasarkan tanggal
      DateTime? dateA = _parseDate(a['date']);
      DateTime? dateB = _parseDate(b['date']);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // event tanpa tanggal ke bawah
      if (dateB == null) return -1;
      return dateA.compareTo(dateB); // urutkan tanggal terdekat
    });

    // Count the number of events for each area
    Map<String, int> areaEventCount = {};
    for (var event in _allEvents) {
      String area = event['area'] ?? '';
      if (areaEventCount.containsKey(area)) {
        areaEventCount[area] = areaEventCount[area]! + 1;
      } else {
        areaEventCount[area] = 1;
      }
    }

    // Sort the areas
    List<String> jabodetabek = [
      'Jakarta',
      'Jakarta Pusat',
      'Jakarta Utara',
      'Jakarta Barat',
      'Jakarta Timur',
      'Jakarta Selatan',
      'Bogor',
      'Depok',
      'Tangerang',
      'Tangerang Selatan',
      'Bekasi',
    ];

    _areas.sort((a, b) {
      bool isSelectedA = _selectedAreas.contains(a);
      bool isSelectedB = _selectedAreas.contains(b);
      bool isOnlineA = a.toLowerCase().contains('online');
      bool isOnlineB = b.toLowerCase().contains('online');

      // Selected areas come first
      if (isSelectedA && !isSelectedB) return -1;
      if (!isSelectedA && isSelectedB) return 1;

      // Online areas come last
      if (!isOnlineA && isOnlineB) return -1;
      if (isOnlineA && !isOnlineB) return 1;

      // Sort by number of events
      int indexA = jabodetabek.indexOf(a);
      int indexB = jabodetabek.indexOf(b);
      if (indexA != -1 && indexB != -1) {
        // Both are jabodetabek, sort by index
        return indexA.compareTo(indexB);
      } else if (indexA != -1) {
        // a is jabodetabek, b is not
        return -1;
      } else if (indexB != -1) {
        // b is jabodetabek, a is not
        return 1;
      } else {
        // Both are not jabodetabek, sort by number of events
        int countA = areaEventCount[a] ?? 0;
        int countB = areaEventCount[b] ?? 0;
        return countB.compareTo(countA);
      }
    });

    if (_searchTerm.isEmpty && _selectedAreas.isEmpty && _selectedMonths.isEmpty) {
      _forceShowList = false;
    }

    notifyListeners();
  }

  Future<void> fetchNearestEvents(Position userPosition) async {
    _userPosition = userPosition;

    _nearestLocEvents = _allEvents.where((event) {
      if (event['lat'] == null || event['lng'] == null) return false;

      final distance = calculateDistanceKm(
        userPosition.latitude,
        userPosition.longitude,
        event['lat'],
        event['lng'],
      );

      event['distance_km'] = distance;
      return distance <= 30;
    }).toList()
      ..sort((a, b) =>
          (a['distance_km'] as double).compareTo(b['distance_km']));

    notifyListeners();
  }

  Future<void> geocodeAllEventsOnce({
    Duration delay = const Duration(milliseconds: 1200),
  }) async {
    for (final event in _allEvents) {
      final hasLat = event['lat'] != null;
      final hasLng = event['lng'] != null;

      if (hasLat && hasLng) continue;

      final location = event['location'];
      final eventId = event['id'];

      if (location == null || location.toString().isEmpty) continue;

      try {
        final coords =
        await GeocodingService.getLatLngFromLocationName(location);

        if (coords == null) continue;

        await FirebaseFirestore.instance
            .collection('dfestkonser')
            .doc(eventId)
            .update({
          'lat': coords.latitude,
          'lng': coords.longitude,
        });

        // Update local cache agar tidak dipanggil ulang
        event['lat'] = coords.latitude;
        event['lng'] = coords.longitude;

        // Delay agar aman dari rate limit
        await Future.delayed(delay);
      } catch (e) {
        debugPrint(
            '[GEOCODE ERROR] eventId=$eventId location=$location => $e');
      }
    }

    notifyListeners();
  }

  Future<List<String>> getAreas() async {
    QuerySnapshot eventSnapshot =
    await FirebaseFirestore.instance.collection('dfestkonser').get();

    // Ekstrak semua area dari dokumen event dan buat daftar unik
    Set<String> areaSet = eventSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['area'] as String)
        .where((area) => area.isNotEmpty)
        .toSet();

    // if (kDebugMode) {
    //   print('Number of areas: ${areaSet.length}');
    //   print('Areas: $areaSet');
    // }

    return areaSet.toList();
  }

  Future<void> fetchData({bool forceRefresh = false}) async {
    await initLocalStorage();
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      // Check cache only if not forceRefresh
      // Check for cache expiration (1 day)
      late int lastFetchTime;
      if (kIsWeb) {
        lastFetchTime = int.parse(localStorage.getItem('lastFetchFestTime')?.toString() ?? '0');
      } else {
        lastFetchTime = prefs.getInt('lastFetchFestTime') ?? 0;
      }

      DateTime now = DateTime.now();
      DateTime lastFetchDate = DateTime.fromMillisecondsSinceEpoch(lastFetchTime);

      // Bandingkan hanya tahun, bulan, dan hari
      bool isSameDay = now.year == lastFetchDate.year &&
          now.month == lastFetchDate.month &&
          now.day == lastFetchDate.day;

      // if (DateTime.now()
      //         .difference(DateTime.fromMillisecondsSinceEpoch(lastFetchTime))
      //         .inDays <
      //     1) {
      if (isSameDay) {
        // Load from cache
        if (kIsWeb) {
          _allEvents = jsonDecode(localStorage.getItem('cachedKonsers')!)
              .cast<Map<String, dynamic>>();

          // if (kDebugMode) {
          //   print("Event loaded from localStorage: ${_allEvents.length}");
          // }

          String? cachedAreasString = localStorage.getItem('cachedKonserAreas');
          if (cachedAreasString != null) {
            _areas = jsonDecode(cachedAreasString).cast<String>();
            // if (kDebugMode) {
            //   print("Area loaded from localStorage: ${_areas.length}");
            // }
            notifyListeners();
          }
        } else {
          _allEvents = jsonDecode(prefs.getString('cachedKonsers')!)
              .cast<Map<String, dynamic>>();
          if (kDebugMode) {
            print("Event loaded from prefs: ${_allEvents.length}");
          }

          List<String>? cachedAreas = prefs.getStringList('cachedKonserAreas');
          if (cachedAreas != null) {
            _areas = cachedAreas;
            if (kDebugMode) {
              print("Area loaded from prefs: ${_areas.length}");
            }
            notifyListeners();
          }
        }

        _isLoading = false;
        notifyListeners();
        _filterEvents();
        return; // Exit early
      }
    }

    try {
      if (kDebugMode) {
        print("Fetching data from Firestore...");
      }
      QuerySnapshot eventSnapshot =
      await FirebaseFirestore.instance.collection('dfestkonser').get();

      // List<Map<String, dynamic>> eventsWithId = eventSnapshot.docs.map((doc) {
      //   return {
      //     'id': doc.id, // Include the document ID
      //     ...doc.data() as Map<String, dynamic>, // Spread the document data
      //   };
      // }).toList();

      List<Map<String, dynamic>> eventsWithId = eventSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).where((event) {
        // Pastikan event memiliki field 'date'
        if (event.containsKey('date')) {
          try {
            String rawDate = event['date']?.toString().trim() ?? '';

            // Jika tanggal kosong, tetap tampilkan eventnya (dianggap relevan)
            if (rawDate.isEmpty) {
              return true;
            }

            DateTime now = DateTime.now();
            DateTime todayOnly = DateTime(now.year, now.month, now.day);

            // --- 1. NORMALISASI STRING (Handler En-dash/Em-dash) ---
            // Mengubah tanda '–' (en-dash) atau '—' (em-dash) menjadi '-' (strip biasa)
            String dateString = rawDate.replaceAll('–', '-').replaceAll('—', '-');
            String dateToParse = dateString;

            // Cek apakah ini format rentang
            if (dateString.contains('-')) {
              List<String> parts = dateString.split(' ');

              // --- LOGIKA MENDAPATKAN TANGGAL AKHIR ---

              // Kasus 1: "20-21 Des 2025" atau "23-24 Jan 2026"
              if (parts.length == 3 && parts[0].contains('-')) {
                // Ambil tanggal akhir dari rentang, e.g., "21" dari "20-21"
                String endDate = parts[0].split('-')[1].trim();
                // Rekonstruksi menjadi "21 Des 2025"
                dateToParse = "$endDate ${parts[1]} ${parts[2]}";

              }
              // Kasus 2: "29 Nov - 02 Des 2025"
              else if (parts.contains('-')) { // Note: contains('-') sekarang aman karena sudah dinormalisasi
                final separatorIndex = parts.indexOf('-');

                // Pastikan index valid dan ada bagian setelahnya
                if (separatorIndex != -1 && separatorIndex < parts.length - 1) {
                  // Ambil semua bagian setelah tanda hubung
                  List<String> endDateParts = parts.sublist(separatorIndex + 1);

                  // Jika bagian tanggal akhir tidak mengandung tahun (e.g., "02 Des")
                  if (endDateParts.length == 2) {
                    // Cari tahun dari akhir string asli (biasanya elemen terakhir)
                    String year = parts.lastWhere((part) => part.length == 4 && int.tryParse(part) != null, orElse: () => '');
                    if (year.isNotEmpty) {
                      endDateParts.add(year); // Tambahkan tahun -> ["02", "Des", "2025"]
                    }
                  }
                  // Gabungkan kembali menjadi string tanggal akhir
                  dateToParse = endDateParts.join(' ');
                }
              }
            }
            // Kasus 3: Format "MMM yyyy" (e.g., "Jul 2025") tanpa tanggal spesifik
            else if (dateString.split(' ').length == 2) {
              try {
                final eventMonthDate = DateFormat('MMM yyyy', 'id_ID').parse(dateString);
                final endOfMonth = DateTime(eventMonthDate.year, eventMonthDate.month + 1, 0);
                return !endOfMonth.isBefore(todayOnly);
              } catch (e) {
                // Lanjut ke logika parsing standar jika gagal
              }
            }

            // --- 2. PARSING TANGGAL (Handler Full Month Name) ---
            DateTime eventDate;
            try {
              // Coba format singkatan bulan (misal: "12 Apr 2026")
              eventDate = DateFormat('dd MMM yyyy', 'id_ID').parse(dateToParse);
            } catch (e) {
              try {
                // Coba format nama bulan lengkap (misal: "12 April 2026")
                eventDate = DateFormat('dd MMMM yyyy', 'id_ID').parse(dateToParse);
              } catch (e2) {
                // Jika masih gagal, lempar error asli untuk ditangkap di luar
                throw e;
              }
            }

            DateTime eventOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);

            // Tampilkan hanya event yang tanggal akhirnya belum lewat dari hari ini
            return !eventOnly.isBefore(todayOnly);

          } catch (e) {
            if (kDebugMode) {
              // Gunakan event['date'] asli untuk log agar tahu sumber masalahnya
              print('[FILTER-ERROR Konser] Gagal parse tanggal: "${event['date']}" -> $e');
            }
            // Jika gagal parse, anggap event tidak relevan (atau return true jika ingin permissive)
            return false;
          }
        }
        return false;
      }).toList();

      Set<String> areaSet = eventsWithId
          .map((event) => event['area']?.toString() ?? '')
          .where((area) => area.isNotEmpty)
          .toSet();

      _allEvents = eventsWithId;
      _areas = areaSet.toList();
      _isLoading = false;
      notifyListeners();
      await initLocalStorage();
      localStorage.clear();
      _filterEvents();
      if (kIsWeb) {
        await initLocalStorage();
        localStorage.setItem('cachedKonsers', jsonEncode(_allEvents));
        localStorage.setItem('cachedKonserAreas', jsonEncode(_areas));
        localStorage.setItem(
            'lastFetchFestTime', DateTime.now().millisecondsSinceEpoch.toString());
      } else {
        await prefs.setString('cachedKonsers', jsonEncode(_allEvents));
        await prefs.setStringList('cachedKonserAreas', _areas);
        await prefs.setInt(
            'lastFetchFestTime', DateTime.now().millisecondsSinceEpoch);
      }
      if (kDebugMode) {
        print("✅ Data fetched and cached");
        print("📍 Jumlah area aktif: ${_areas.length}");
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