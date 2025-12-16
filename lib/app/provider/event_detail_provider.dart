// event_detail_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventDetailProvider with ChangeNotifier {
  Map<String, dynamic>? _eventData;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? get eventData => _eventData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fungsi utama untuk mengambil satu event berdasarkan ID
  Future<void> fetchEvent(String eventId) async {
    // Reset state sebelum fetch baru
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('jfestchart')
          .doc(eventId)
          .get();

      if (doc.exists) {
        // Simpan data dan tambahkan ID untuk konsistensi
        _eventData = doc.data()!;
        _eventData!['id'] = doc.id;
      } else {
        _error = "Event dengan ID '$eventId' tidak ditemukan.";
      }
    } catch (e) {
      _error = "Gagal mengambil data event: $e";
      print(_error);
    } finally {
      // Apapun hasilnya, loading selesai
      _isLoading = false;
      notifyListeners();
    }
  }
}