// app/provider/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

class ThemeProvider with ChangeNotifier {
  // Hapus 'late' dan beri nilai default. false = mode terang.
  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeProvider() {
    // Saat provider dibuat, langsung muat preferensi tema
    _loadFromPrefs();
  }

  void toggleTheme() {
    _isDark = !_isDark;
    _saveToPrefs();
    notifyListeners();
  }

  // Memuat tema dari localStorage
  void _loadFromPrefs() async {
    // initLocalStorage bisa memakan waktu, jadi kita await
    await initLocalStorage();
    final savedTheme = localStorage.getItem('isDark');
    if (savedTheme != null) {
      _isDark = bool.parse(savedTheme);
    }
    // Beri tahu UI tentang nilai yang benar setelah dimuat
    notifyListeners();
  }

  // Menyimpan tema ke localStorage
  void _saveToPrefs() {
    localStorage.setItem('isDark', _isDark.toString());
  }
}