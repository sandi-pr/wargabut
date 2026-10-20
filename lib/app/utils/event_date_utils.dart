import 'package:intl/intl.dart';

/// Utilitas untuk mem-parsing dan mengurutkan tanggal event JEventku
class EventDateUtils {
  /// Mem-parsing tanggal mulai event dari string (cth: "19-20 Sep 2026", "3-4 Okt 2026", "31 Okt - 1 Nov 2026", "12 April 2026")
  static DateTime? parseStartDate(String dateString) {
    if (dateString.trim().isEmpty) return null;

    String clean = dateString.trim().replaceAll(RegExp(r'\s*[–—]\s*'), ' - ');
    // Hapus nama hari jika ada (misal: "Sabtu, ", "Minggu, ")
    clean = clean.replaceAll(RegExp(r'^[a-zA-Z]+,\s*'), '');

    DateTime? tryParseSingle(String input) {
      try {
        return DateFormat('dd MMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('dd MMMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('dd MMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('dd MMMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('MMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('MMMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('MMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('MMMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateTime.tryParse(input);
      } catch (_) {}
      return null;
    }

    DateTime? direct = tryParseSingle(clean);
    if (direct != null) return direct;

    if (clean.contains('-')) {
      try {
        String normalized = clean.replaceAll(RegExp(r'\s*-\s*'), ' - ');
        List<String> parts = normalized.split(' ').where((s) => s.isNotEmpty).toList();

        if (parts.contains('-')) {
          final separatorIndex = parts.indexOf('-');
          List<String> startPartList = parts.sublist(0, separatorIndex);
          String startDateString = startPartList.join(' ');

          bool isStartDayOnly = startPartList.length == 1 && int.tryParse(startPartList[0]) != null;

          if (isStartDayOnly) {
            List<String> endPartList = parts.sublist(separatorIndex + 1);
            if (endPartList.length >= 2) {
              String year = endPartList.last;
              String month = endPartList[endPartList.length - 2];
              startDateString = "$startDateString $month $year";
            }
          } else {
            bool startDateHasYear = startPartList.any((part) => part.length == 4 && int.tryParse(part) != null);
            if (!startDateHasYear) {
              String? year = parts.firstWhere(
                (part) => part.length == 4 && int.tryParse(part) != null,
                orElse: () => '',
              );
              if (year.isNotEmpty) {
                startDateString = '$startDateString $year';
              }
            }
          }
          final parsed = tryParseSingle(startDateString);
          if (parsed != null) return parsed;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Mem-parsing tanggal selesai event dari string (cth: untuk rentang "19-20 Sep 2026" menghasilkan 20 Sep 2026)
  static DateTime? parseEndDate(String dateString) {
    if (dateString.trim().isEmpty) return null;

    String clean = dateString.trim().replaceAll(RegExp(r'\s*[–—]\s*'), ' - ');
    clean = clean.replaceAll(RegExp(r'^[a-zA-Z]+,\s*'), '');

    DateTime? tryParseSingle(String input) {
      try {
        return DateFormat('dd MMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('dd MMMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMMM yyyy', 'id_ID').parse(input);
      } catch (_) {}
      try {
        return DateFormat('dd MMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('dd MMMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      try {
        return DateFormat('d MMMM yyyy', 'en_US').parse(input);
      } catch (_) {}
      // Untuk format nama bulan + tahun saja (tanpa tanggal), akhir event adalah akhir bulan tersebut
      try {
        final d = DateFormat('MMM yyyy', 'id_ID').parse(input);
        return DateTime(d.year, d.month + 1, 0, 23, 59, 59);
      } catch (_) {}
      try {
        final d = DateFormat('MMMM yyyy', 'id_ID').parse(input);
        return DateTime(d.year, d.month + 1, 0, 23, 59, 59);
      } catch (_) {}
      try {
        final d = DateFormat('MMM yyyy', 'en_US').parse(input);
        return DateTime(d.year, d.month + 1, 0, 23, 59, 59);
      } catch (_) {}
      try {
        final d = DateFormat('MMMM yyyy', 'en_US').parse(input);
        return DateTime(d.year, d.month + 1, 0, 23, 59, 59);
      } catch (_) {}
      try {
        return DateTime.tryParse(input);
      } catch (_) {}
      return null;
    }

    if (clean.contains('-')) {
      try {
        String normalized = clean.replaceAll(RegExp(r'\s*-\s*'), ' - ');
        List<String> parts = normalized.split(' ').where((p) => p.isNotEmpty).toList();
        if (parts.contains('-')) {
          final separatorIndex = parts.indexOf('-');
          List<String> endPartList = parts.sublist(separatorIndex + 1);
          String endDateString = endPartList.join(' ');
          bool endDateHasYear = endPartList.any((p) => p.length == 4 && int.tryParse(p) != null);
          if (!endDateHasYear) {
            String? year = parts.firstWhere(
              (p) => p.length == 4 && int.tryParse(p) != null,
              orElse: () => '',
            );
            if (year.isNotEmpty) {
              endDateString = '$endDateString $year';
            }
          }
          final endParsed = tryParseSingle(endDateString);
          if (endParsed != null) return endParsed;
        }
      } catch (_) {}
    }

    return parseStartDate(dateString);
  }

  /// Cek apakah event sudah selesai (tanggal akhir sudah lewat dari awal hari ini)
  static bool isEventPast(String dateString, {DateTime? now}) {
    final endDate = parseEndDate(dateString);
    if (endDate == null) return false;
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);
    return endDate.isBefore(todayStart);
  }

  /// Mengurutkan list event:
  /// - Tanggal terdekat (mendatang / sedang berlangsung) di paling atas (ascending chronological)
  /// - Jika [filterPast] true: event yang sudah lampau (selesai) tidak disertakan
  /// - Jika [filterPast] false: event yang sudah lampau diletakkan di bagian bawah
  /// - Event tanpa tanggal / tidak dapat diparse diletakkan di paling bawah
  static List<T> sortEventsByClosestDate<T>(
    List<T> events, {
    required String Function(T) dateExtractor,
    bool filterPast = true,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);

    List<T> source = List<T>.from(events);

    if (filterPast) {
      source = source.where((item) {
        final dateStr = dateExtractor(item);
        final endDate = parseEndDate(dateStr);
        if (endDate == null) return true;
        return !endDate.isBefore(todayStart);
      }).toList();
    }

    source.sort((a, b) {
      final dateStrA = dateExtractor(a);
      final dateStrB = dateExtractor(b);

      final startA = parseStartDate(dateStrA);
      final startB = parseStartDate(dateStrB);
      final endA = parseEndDate(dateStrA) ?? startA;
      final endB = parseEndDate(dateStrB) ?? startB;

      final isPastA = endA != null && endA.isBefore(todayStart);
      final isPastB = endB != null && endB.isBefore(todayStart);

      // Prioritas 1: Event aktif/mendatang di atas, event lampau di bawah
      if (!isPastA && isPastB) return -1;
      if (isPastA && !isPastB) return 1;

      // Prioritas 2: Keduanya aktif/mendatang, urutkan tanggal mulai terdekat
      if (!isPastA && !isPastB) {
        if (startA == null && startB == null) return 0;
        if (startA == null) return 1;
        if (startB == null) return -1;
        return startA.compareTo(startB);
      }

      // Prioritas 3: Keduanya lampau, urutkan yang paling baru selesai di atas
      if (endA == null && endB == null) return 0;
      if (endA == null) return 1;
      if (endB == null) return -1;
      return endB.compareTo(endA);
    });

    return source;
  }
}
