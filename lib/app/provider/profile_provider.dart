import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_storage.dart';
import '../services/wearable_sync_service.dart';
import '../utils/event_date_utils.dart';

class ProfileProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storageService = StorageService();

  UserProfileModel? _currentProfile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfileModel? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const List<String> reservedUsernames = [
    'admin',
    'komunitas',
    'login',
    'welcome',
    'jeventku',
    'anichekku',
    'dkonser',
    'wguide',
    'api',
    'profile',
    'setting',
    'settings',
    'wargabut',
    'me',
    'dashboard',
    'auth',
    'baru',
  ];

  ProfileProvider() {
    _initListener();
  }

  void _initListener() {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await loadCurrentUserProfile(user.uid);
      } else {
        _currentProfile = null;
        notifyListeners();
      }
    });
  }

  /// Memeriksa apakah username valid dan belum digunakan
  Future<String?> checkUsernameAvailability(String rawUsername) async {
    final username = rawUsername.toLowerCase().trim();
    if (username.isEmpty) return 'Username tidak boleh kosong';
    if (username.length < 3) return 'Username minimal 3 karakter';
    if (username.length > 25) return 'Username maksimal 25 karakter';

    final validCharacters = RegExp(r'^[a-z0-9_.]+$');
    if (!validCharacters.hasMatch(username)) {
      return 'Username hanya boleh huruf, angka, titik (.), dan garis bawah (_)';
    }

    if (reservedUsernames.contains(username)) {
      return 'Username "$username" tidak dapat digunakan (nama sistem terproteksi)';
    }

    try {
      final doc = await _firestore.collection('usernames').doc(username).get();
      if (doc.exists) {
        final currentUid = _auth.currentUser?.uid;
        if (currentUid != null && doc.data()?['uid'] == currentUid) {
          return null; // Milik user sendiri
        }
        return 'Username sudah digunakan orang lain';
      }
      return null; // Tersedia
    } catch (e) {
      return 'Gagal mengecek username: $e';
    }
  }

  /// Registrasi dengan Username + Password murni (tanpa mengekspos email asli)
  Future<bool> registerWithUsername({
    required String username,
    required String password,
    required String displayName,
    String city = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanUsername = username.toLowerCase().trim();
      final checkError = await checkUsernameAvailability(cleanUsername);
      if (checkError != null) {
        _errorMessage = checkError;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'Password minimal 6 karakter';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Format email internal aman untuk Firebase Auth
      final internalEmail = '$cleanUsername@wargabut.local';
      final credential = await _auth.createUserWithEmailAndPassword(
        email: internalEmail,
        password: password,
      );

      final uid = credential.user!.uid;

      // 1. Simpan pemetaan username -> uid
      await _firestore.collection('usernames').doc(cleanUsername).set({
        'uid': uid,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. Buat profil awal user
      final initialProfile = UserProfileModel(
        uid: uid,
        username: cleanUsername,
        displayName: displayName.trim().isEmpty ? cleanUsername : displayName.trim(),
        city: city.trim(),
      );

      await _firestore.collection('users').doc(uid).set(initialProfile.toMap(), SetOptions(merge: true));

      _currentProfile = initialProfile;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _errorMessage = 'Username sudah terdaftar.';
      } else {
        _errorMessage = e.message ?? 'Registrasi gagal.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login fleksibel: Bisa dengan Username ATAU Email
  Future<bool> loginWithUsernameOrEmail({
    required String usernameOrEmail,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final input = usernameOrEmail.trim().toLowerCase();
      String targetEmail;

      if (input.contains('@') && input.contains('.')) {
        // User memasukkan format email asli
        targetEmail = input;
      } else {
        // User memasukkan username murni -> coba cari di usernames mapping
        final userDoc = await _firestore.collection('usernames').doc(input).get();
        if (userDoc.exists) {
          targetEmail = '$input@wargabut.local';
        } else {
          // Fallback coba email wargabut.local
          targetEmail = '$input@wargabut.local';
        }
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: targetEmail,
        password: password,
      );

      await loadCurrentUserProfile(credential.user!.uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _errorMessage = 'Username/email atau password salah.';
      } else {
        _errorMessage = e.message ?? 'Gagal masuk.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  final Map<String, UserProfileModel> _profileCache = {};

  UserProfileModel? getCachedProfile(String uid) {
    if (_profileCache.containsKey(uid)) return _profileCache[uid];
    if (_currentProfile?.uid == uid) return _currentProfile;
    return null;
  }

  /// Muat profil akun yang sedang login
  Future<void> loadCurrentUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentProfile = UserProfileModel.fromFirestore(doc);
        _profileCache[uid] = _currentProfile!;
        if (_currentProfile!.username.isNotEmpty) {
          _profileCache[_currentProfile!.username.toLowerCase()] = _currentProfile!;
        }
      } else {
        // Profil belum dibuat di Firestore, buat placeholder
        final email = _auth.currentUser?.email ?? '';
        final defaultUsername = email.contains('@wargabut.local')
            ? email.replaceAll('@wargabut.local', '')
            : (email.split('@').first);

        _currentProfile = UserProfileModel(
          uid: uid,
          username: defaultUsername,
          displayName: defaultUsername,
        );
      }
      notifyListeners();

      if (_currentProfile != null) {
        WearableSyncService.syncProfile(_currentProfile!);
      }
    } catch (e) {
      debugPrint('Error loading current user profile: $e');
    }
  }

  /// Ambil profil lengkap berdasarkan UID
  Future<UserProfileModel?> getProfileByUid(String uid) async {
    if (uid.isEmpty) return null;
    if (_profileCache.containsKey(uid)) {
      return _profileCache[uid];
    }
    if (_currentProfile?.uid == uid) {
      return _currentProfile;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final profile = UserProfileModel.fromFirestore(doc);
        _profileCache[uid] = profile;
        if (profile.username.isNotEmpty) {
          _profileCache[profile.username.toLowerCase()] = profile;
        }
        return profile;
      }
    } catch (e) {
      debugPrint('Error getting profile by uid: $e');
    }
    return null;
  }

  /// Cari profil publik berdasarkan username (untuk rute /@:username)
  Future<UserProfileModel?> getProfileByUsername(String username) async {
    final cleanUsername = username.toLowerCase().trim();
    if (_profileCache.containsKey(cleanUsername)) {
      return _profileCache[cleanUsername];
    }
    try {
      // 1. Cek dari mapping username
      final mapDoc = await _firestore.collection('usernames').doc(cleanUsername).get();
      if (mapDoc.exists) {
        final uid = mapDoc.data()?['uid'];
        if (uid != null) {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            final profile = UserProfileModel.fromFirestore(userDoc);
            _profileCache[cleanUsername] = profile;
            _profileCache[profile.uid] = profile;
            return profile;
          }
        }
      }

      // 2. Fallback query where username == cleanUsername
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final profile = UserProfileModel.fromFirestore(query.docs.first);
        _profileCache[cleanUsername] = profile;
        _profileCache[profile.uid] = profile;
        return profile;
      }
    } catch (e) {
      debugPrint('Error getting profile by username: $e');
    }
    return null;
  }

  /// Simpan atau perbarui profil
  Future<bool> saveProfile({
    required String displayName,
    required String city,
    required String bio,
    required String instagram,
    String tiktok = '',
    String whatsapp = '',
    String whatsappVisibility = 'community',
    String profileVisibility = 'global',
    required List<String> customTags,
    required List<String> hobbies,
    required List<CosplanItem> cosplans,
    List<UserAttendingEvent>? attendingEvents,
    XFile? avatarImageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = 'Anda harus login terlebih dahulu';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String avatarUrl = _currentProfile?.avatarUrl ?? '';

      // Upload avatar baru jika ada
      if (avatarImageFile != null) {
        final uploaded = await _storageService.uploadImage(
          avatarImageFile,
          'user_avatars',
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (uploaded != null) {
          avatarUrl = uploaded;
        }
      }

      final updatedProfile = UserProfileModel(
        uid: user.uid,
        username: _currentProfile?.username ?? user.uid.substring(0, 8),
        displayName: displayName.trim(),
        avatarUrl: avatarUrl,
        city: city.trim(),
        bio: bio.trim(),
        instagram: instagram.trim(),
        tiktok: tiktok.trim(),
        whatsapp: whatsapp.trim(),
        whatsappVisibility: whatsappVisibility,
        profileVisibility: profileVisibility,
        customTags: customTags,
        hobbies: hobbies,
        cosplans: cosplans,
        joinedCommunityIds: _currentProfile?.joinedCommunityIds ?? [],
        attendingEvents: attendingEvents != null
            ? EventDateUtils.sortEventsByClosestDate(
                attendingEvents,
                dateExtractor: (e) => e.eventDate,
                filterPast: true,
              )
            : (_currentProfile?.upcomingAttendingEvents ?? []),
      );

      await _firestore.collection('users').doc(user.uid).set(
        updatedProfile.toMap(),
        SetOptions(merge: true),
      );

      _currentProfile = updatedProfile;

      // Update data denormalized di seluruh community_members milik user ini
      _syncProfileToCommunityMembers(updatedProfile);

      // Sinkronkan ke smartwatch Wear OS
      WearableSyncService.syncProfile(updatedProfile);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan profil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sinkronkan profil aktif secara manual ke Wear OS smartwatch
  Future<bool> syncToWearable() async {
    if (_currentProfile == null) return false;
    return await WearableSyncService.syncProfile(_currentProfile!);
  }

  /// Cek apakah user yang login berencana hadir di event tertentu
  bool isAttendingEvent(String eventId) {
    if (_currentProfile == null) return false;
    return _currentProfile!.attendingEvents.any((e) => e.eventId == eventId);
  }

  /// Toggle kehadiran pribadi user pada suatu event JEventku
  Future<bool> toggleEventAttendance(Map<String, dynamic> eventData, {String notes = ''}) async {
    final user = _auth.currentUser;
    if (user == null || _currentProfile == null) return false;

    final eventId = (eventData['id'] ?? eventData['event_id'] ?? '').toString();
    if (eventId.isEmpty) return false;

    try {
      List<UserAttendingEvent> currentList = List.from(_currentProfile!.attendingEvents);
      final index = currentList.indexWhere((e) => e.eventId == eventId);

      if (index >= 0) {
        // Hapus kehadiran
        currentList.removeAt(index);
      } else {
        // Ekstrak poster utama
        String posterUrl = '';
        if (eventData['posters'] is List && (eventData['posters'] as List).isNotEmpty) {
          final posters = eventData['posters'] as List;
          final mainPoster = posters.firstWhere(
            (p) => p is Map && p['is_main'] == true,
            orElse: () => posters[0],
          );
          if (mainPoster is Map) {
            posterUrl = mainPoster['url']?.toString() ?? '';
          }
        }
        if (posterUrl.isEmpty) {
          posterUrl = (eventData['poster'] ?? eventData['poster_url'] ?? '').toString();
        }

        final newEvent = UserAttendingEvent(
          eventId: eventId,
          eventName: (eventData['event_name'] ?? eventData['name'] ?? eventData['title'] ?? 'Event').toString(),
          eventDate: (eventData['date'] ?? eventData['date_event'] ?? '').toString(),
          eventLocation: (eventData['location'] ?? '').toString(),
          eventPoster: posterUrl,
          notes: notes.trim(),
        );

        currentList.add(newEvent);
      }

      currentList = EventDateUtils.sortEventsByClosestDate(
        currentList,
        dateExtractor: (e) => e.eventDate,
        filterPast: true,
      );

      await _firestore.collection('users').doc(user.uid).update({
        'attending_events': currentList.map((e) => e.toMap()).toList(),
      });

      _currentProfile = UserProfileModel(
        uid: _currentProfile!.uid,
        username: _currentProfile!.username,
        displayName: _currentProfile!.displayName,
        avatarUrl: _currentProfile!.avatarUrl,
        city: _currentProfile!.city,
        bio: _currentProfile!.bio,
        instagram: _currentProfile!.instagram,
        tiktok: _currentProfile!.tiktok,
        whatsapp: _currentProfile!.whatsapp,
        whatsappVisibility: _currentProfile!.whatsappVisibility,
        profileVisibility: _currentProfile!.profileVisibility,
        customTags: _currentProfile!.customTags,
        hobbies: _currentProfile!.hobbies,
        cosplans: _currentProfile!.cosplans,
        joinedCommunityIds: _currentProfile!.joinedCommunityIds,
        attendingEvents: currentList,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error toggling event attendance: $e');
      return false;
    }
  }

  /// Sinkronisasi nama & avatar di record membership komunitas agar list tetap up-to-date
  Future<void> _syncProfileToCommunityMembers(UserProfileModel profile) async {
    try {
      final memberships = await _firestore
          .collection('community_members')
          .where('uid', isEqualTo: profile.uid)
          .get();

      final batch = _firestore.batch();
      for (var doc in memberships.docs) {
        batch.update(doc.reference, {
          'display_name': profile.displayName,
          'avatar_url': profile.avatarUrl,
          'city': profile.city,
          'custom_tags': profile.customTags,
          'username': profile.username,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error syncing profile to memberships: $e');
    }
  }

  // --- DIREKTORI MEMBER GLOBAL WARGABUT ---
  List<UserProfileModel> _globalMembers = [];
  List<UserProfileModel> _filteredGlobalMembers = [];
  String _memberSearchTerm = '';
  String? _selectedMemberCity;
  String? _selectedMemberTag;
  List<String> _globalMemberCities = [];
  List<String> _globalMemberTags = [];

  List<UserProfileModel> get globalMembers => _globalMembers;
  List<UserProfileModel> get filteredGlobalMembers => _filteredGlobalMembers;
  String get memberSearchTerm => _memberSearchTerm;
  String? get selectedMemberCity => _selectedMemberCity;
  String? get selectedMemberTag => _selectedMemberTag;
  List<String> get globalMemberCities => _globalMemberCities;
  List<String> get globalMemberTags => _globalMemberTags;

  void setMemberSearchTerm(String term) {
    _memberSearchTerm = term;
    _applyMemberFilters();
  }

  void setSelectedMemberCity(String? city) {
    _selectedMemberCity = city;
    _applyMemberFilters();
  }

  void setSelectedMemberTag(String? tag) {
    _selectedMemberTag = tag;
    _applyMemberFilters();
  }

  void clearMemberFilters() {
    _memberSearchTerm = '';
    _selectedMemberCity = null;
    _selectedMemberTag = null;
    _applyMemberFilters();
  }

  void _applyMemberFilters() {
    final term = _memberSearchTerm.toLowerCase().trim();
    _filteredGlobalMembers = _globalMembers.where((m) {
      final matchesSearch = term.isEmpty ||
          m.displayName.toLowerCase().contains(term) ||
          m.username.toLowerCase().contains(term) ||
          m.city.toLowerCase().contains(term) ||
          m.customTags.any((t) => t.toLowerCase().contains(term)) ||
          m.cosplans.any((c) =>
              c.character.toLowerCase().contains(term) || c.series.toLowerCase().contains(term));

      final matchesCity =
          _selectedMemberCity == null || _selectedMemberCity!.isEmpty || m.city == _selectedMemberCity;

      final matchesTag =
          _selectedMemberTag == null || _selectedMemberTag!.isEmpty || m.customTags.contains(_selectedMemberTag);

      return matchesSearch && matchesCity && matchesTag;
    }).toList();

    notifyListeners();
  }

  /// Ambil seluruh member Wargabut yang visibilitasnya 'global'
  Future<void> fetchGlobalMembers({bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('users').get();

      _globalMembers = snapshot.docs
          .map((doc) => UserProfileModel.fromFirestore(doc))
          .where((m) => m.isVisibleGlobally && m.username.isNotEmpty)
          .toList();

      final Set<String> citySet = {};
      final Set<String> tagSet = {};
      for (var m in _globalMembers) {
        if (m.city.isNotEmpty) citySet.add(m.city);
        for (var t in m.customTags) {
          if (t.isNotEmpty) tagSet.add(t);
        }
      }

      _globalMemberCities = citySet.toList()..sort();
      _globalMemberTags = tagSet.toList()..sort();

      _applyMemberFilters();
    } catch (e) {
      debugPrint('Error fetching global members: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
