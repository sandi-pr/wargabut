// auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State yang akan disimpan oleh provider
  User? _user;
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  // Getter agar UI bisa mengakses state ini
  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _isAdmin;

  // Constructor akan langsung memasang listener
  AuthProvider() {
    _listenToAuthChanges();
  }

  // Fungsi listener yang terpusat
  void _listenToAuthChanges() {
    _auth.authStateChanges().listen((User? user) async {
      final prefs = await SharedPreferences.getInstance();
      _user = user;

      if (user == null) {
        // Jika user logout
        _isLoggedIn = false;
        _isAdmin = false;
        await prefs.setBool('isLoggedIn', false);
        await prefs.setBool('isAdmin', false);
      } else {
        // Jika user login
        _isLoggedIn = true;
        await prefs.setBool('isLoggedIn', true);

        // Cek status admin di Firestore
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _isAdmin = true;
          await prefs.setBool('isAdmin', true);
        } else {
          _isAdmin = false;
          await prefs.setBool('isAdmin', false);
        }
      }

      // Beri tahu seluruh aplikasi (termasuk GoRouter) tentang perubahan status
      notifyListeners();
    });
  }

  // Anda juga bisa menambahkan fungsi untuk login dan logout di sini
  Future<void> signOut() async {
    await _auth.signOut();
  }
}