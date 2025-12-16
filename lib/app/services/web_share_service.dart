// app/services/web_share_service.dart

@JS() // Memberi tahu Dart bahwa ini adalah konteks interop
library web_share_service;

import 'dart:async';
import 'package:js/js.dart';

// 1. Definisikan struktur data yang akan dikirim ke navigator.share
//    '@anonymous' berarti ini adalah objek JS biasa, seperti { title: '...', url: '...' }
@JS()
@anonymous
class ShareData {
  external factory ShareData({String? url, String? text, String? title});

  external String? get url;
  external String? get text;
  external String? get title;
}

// 2. Buat referensi eksternal ke fungsi navigator.share di JavaScript
//    Ini mengembalikan Future, karena navigator.share adalah Promise di JS.
@JS('navigator.share')
external Future<void> share(ShareData data);

// 3. Buat getter untuk memeriksa apakah navigator.share didukung oleh browser
@JS('navigator.share')
external get _webShareApi; // Kita beri nama _webShareApi agar tidak bentrok

/// Pengecekan sederhana untuk ketersediaan Web Share API
bool get isWebShareSupported => _webShareApi != null;