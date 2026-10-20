import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/community_model.dart';
import '../models/community_event_model.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_storage.dart';
import '../utils/event_date_utils.dart';

class CommunityProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  List<CommunityModel> _communities = [];
  List<CommunityModel> _filteredCommunities = [];
  List<CommunityModel> _pendingVerificationCommunities = [];

  bool _isLoading = false;
  String _searchTerm = '';
  String? _selectedCity;
  String? _selectedCategory;
  List<String> _availableCities = [];

  List<CommunityModel> get communities => _communities;
  List<CommunityModel> get filteredCommunities => _filteredCommunities;
  List<CommunityModel> get pendingVerificationCommunities => _pendingVerificationCommunities;
  bool get isLoading => _isLoading;
  String get searchTerm => _searchTerm;
  String? get selectedCity => _selectedCity;
  String? get selectedCategory => _selectedCategory;
  List<String> get availableCities => _availableCities;

  static const List<String> defaultCategories = [
    'Cosplay',
    'Anime & Manga',
    'Fotografer & Videografer',
    'Anisong & Dance Cover',
    'Gaming & Esports',
    'Komunitas Regional',
    'Kolektor & Merchandise',
  ];

  CommunityProvider() {
    fetchCommunities();
  }

  void setSearchTerm(String term) {
    _searchTerm = term;
    _applyFilters();
  }

  void setSelectedCity(String? city) {
    _selectedCity = city;
    _applyFilters();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void clearFilters() {
    _searchTerm = '';
    _selectedCity = null;
    _selectedCategory = null;
    _applyFilters();
  }

  void _applyFilters() {
    _filteredCommunities = _communities.where((c) {
      final matchesSearch = _searchTerm.isEmpty ||
          c.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          c.cityOrArea.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          c.shortDesc.toLowerCase().contains(_searchTerm.toLowerCase());

      final matchesCity = _selectedCity == null || _selectedCity!.isEmpty || c.cityOrArea == _selectedCity;

      final matchesCategory = _selectedCategory == null ||
          _selectedCategory!.isEmpty ||
          c.categories.contains(_selectedCategory);

      return matchesSearch && matchesCity && matchesCategory;
    }).toList();

    notifyListeners();
  }

  /// Ambil seluruh komunitas yang sudah diverifikasi untuk publik
  Future<void> fetchCommunities({bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('communities')
          .where('status', isEqualTo: 'verified')
          .get();

      _communities = snapshot.docs.map((doc) => CommunityModel.fromFirestore(doc)).toList();

      // Ekstrak daftar kota unik
      final Set<String> citySet = {};
      for (var c in _communities) {
        if (c.cityOrArea.isNotEmpty) citySet.add(c.cityOrArea);
      }
      _availableCities = citySet.toList()..sort();

      _applyFilters();
    } catch (e) {
      debugPrint('Error fetching communities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ambil komunitas yang berstatus pending_verification (khusus Admin Wargabut)
  Future<void> fetchPendingCommunities() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('communities')
          .where('status', isEqualTo: 'pending_verification')
          .get();

      _pendingVerificationCommunities =
          snapshot.docs.map((doc) => CommunityModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching pending communities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dapatkan satu komunitas berdasarkan slug / ID
  Future<CommunityModel?> getCommunityBySlug(String slug) async {
    try {
      final doc = await _firestore.collection('communities').doc(slug).get();
      if (doc.exists) {
        return CommunityModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting community by slug $slug: $e');
    }
    return null;
  }

  /// Helper untuk generate slug ramah URL dari nama komunitas
  String createSlug(String name) {
    String slug = name.toLowerCase().trim();
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    slug = slug.replaceAll(RegExp(r'\s+'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length > 50) slug = slug.substring(0, 50);
    return slug.isEmpty ? 'komunitas-${DateTime.now().millisecondsSinceEpoch}' : slug;
  }

  /// Pendaftaran Komunitas Baru (membutuhkan login)
  Future<String?> createCommunity({
    required String name,
    required String cityOrArea,
    required String shortDesc,
    required String description,
    required String instagram,
    String tiktok = '',
    String whatsappGroupLink = '',
    required List<String> categories,
    required UserProfileModel creatorProfile,
    XFile? logoImage,
    XFile? bannerImage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final slug = createSlug(name);

      // Cek apakah slug sudah terpakai
      final existingDoc = await _firestore.collection('communities').doc(slug).get();
      if (existingDoc.exists) {
        _isLoading = false;
        notifyListeners();
        return 'Nama komunitas ini sudah ada atau terlalu mirip. Silakan gunakan nama lain.';
      }

      String logoUrl = '';
      String bannerUrl = '';

      if (logoImage != null) {
        final uploadedLogo = await _storageService.uploadImage(
          logoImage,
          'community_logos',
          '${slug}_logo_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (uploadedLogo != null) logoUrl = uploadedLogo;
      }

      if (bannerImage != null) {
        final uploadedBanner = await _storageService.uploadImage(
          bannerImage,
          'community_banners',
          '${slug}_banner_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (uploadedBanner != null) bannerUrl = uploadedBanner;
      }

      final newCommunity = CommunityModel(
        id: slug,
        name: name.trim(),
        cityOrArea: cityOrArea.trim(),
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        shortDesc: shortDesc.trim(),
        description: description.trim(),
        instagram: instagram.trim(),
        tiktok: tiktok.trim(),
        whatsappGroupLink: whatsappGroupLink.trim(),
        categories: categories,
        creatorUid: creatorProfile.uid,
        adminUids: [creatorProfile.uid],
        status: 'pending_verification',
        memberCount: 1, // Founder dihitung 1
        createdAt: DateTime.now(),
      );

      final batch = _firestore.batch();

      // 1. Simpan dokumen komunitas
      batch.set(_firestore.collection('communities').doc(slug), newCommunity.toMap());

      // 2. Tambahkan Founder otomatis ke community_members dengan status 'active' dan role 'Founder'
      final memberDocRef = _firestore.collection('community_members').doc('${slug}_${creatorProfile.uid}');
      final founderMembership = CommunityMemberModel(
        id: '${slug}_${creatorProfile.uid}',
        communityId: slug,
        uid: creatorProfile.uid,
        role: 'Founder',
        status: 'active',
        joinedAt: DateTime.now(),
        username: creatorProfile.username,
        displayName: creatorProfile.displayName,
        avatarUrl: creatorProfile.avatarUrl,
        city: creatorProfile.city,
        customTags: creatorProfile.customTags,
      );
      batch.set(memberDocRef, founderMembership.toMap());

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return null; // Sukses
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Gagal mendaftarkan komunitas: $e';
    }
  }

  /// Memperbarui informasi komunitas oleh Founder / Admin Komunitas
  Future<String?> updateCommunity({
    required String communityId,
    required String name,
    required String cityOrArea,
    required String shortDesc,
    required String description,
    required String instagram,
    String tiktok = '',
    String whatsappGroupLink = '',
    required List<String> categories,
    XFile? logoImage,
    XFile? bannerImage,
    String? existingLogoUrl,
    String? existingBannerUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String logoUrl = existingLogoUrl ?? '';
      String bannerUrl = existingBannerUrl ?? '';

      if (logoImage != null) {
        final uploadedLogo = await _storageService.uploadImage(
          logoImage,
          'community_logos',
          '${communityId}_logo_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (uploadedLogo != null) logoUrl = uploadedLogo;
      }

      if (bannerImage != null) {
        final uploadedBanner = await _storageService.uploadImage(
          bannerImage,
          'community_banners',
          '${communityId}_banner_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (uploadedBanner != null) bannerUrl = uploadedBanner;
      }

      await _firestore.collection('communities').doc(communityId).update({
        'name': name.trim(),
        'city_or_area': cityOrArea.trim(),
        'short_desc': shortDesc.trim(),
        'description': description.trim(),
        'instagram': instagram.trim(),
        'tiktok': tiktok.trim(),
        'whatsapp_group_link': whatsappGroupLink.trim(),
        'categories': categories,
        'logo_url': logoUrl,
        'banner_url': bannerUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Muat ulang daftar komunitas lokal
      await fetchCommunities(forceRefresh: true);

      _isLoading = false;
      notifyListeners();
      return null; // Sukses
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Gagal memperbarui komunitas: $e';
    }
  }

  /// Mengambil daftar anggota aktif suatu komunitas
  Future<List<CommunityMemberModel>> fetchActiveMembers(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('community_members')
          .where('community_id', isEqualTo: communityId)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) => CommunityMemberModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching active members: $e');
      return [];
    }
  }

  /// Mengambil permintaan gabung yang masih pending (khusus PIC Komunitas)
  Future<List<CommunityMemberModel>> fetchPendingRequests(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('community_members')
          .where('community_id', isEqualTo: communityId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) => CommunityMemberModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      return [];
    }
  }

  /// Cek keanggotaan user saat ini di komunitas
  Future<CommunityMemberModel?> getUserMembership(String communityId, String uid) async {
    try {
      final doc = await _firestore.collection('community_members').doc('${communityId}_$uid').get();
      if (doc.exists) {
        return CommunityMemberModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error checking user membership: $e');
    }
    return null;
  }

  /// User mengajukan permohonan bergabung ke komunitas (Status: pending)
  Future<String?> requestToJoin(String communityId, UserProfileModel profile) async {
    try {
      final docRef = _firestore.collection('community_members').doc('${communityId}_${profile.uid}');
      final existing = await docRef.get();
      if (existing.exists) {
        final status = existing.data()?['status'];
        if (status == 'active') return 'Anda sudah menjadi anggota komunitas ini.';
        if (status == 'pending') return 'Permintaan bergabung Anda masih menunggu persetujuan admin.';
      }

      final membership = CommunityMemberModel(
        id: '${communityId}_${profile.uid}',
        communityId: communityId,
        uid: profile.uid,
        role: 'Member',
        status: 'pending',
        requestedAt: DateTime.now(),
        username: profile.username,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
        city: profile.city,
        customTags: profile.customTags,
      );

      await docRef.set(membership.toMap());
      return null; // Berhasil
    } catch (e) {
      return 'Gagal mengajukan permohonan gabung: $e';
    }
  }

  /// PIC Komunitas menyetujui permintaan gabung
  Future<bool> approveJoinRequest(String membershipDocId, String communityId) async {
    try {
      final batch = _firestore.batch();
      final memberRef = _firestore.collection('community_members').doc(membershipDocId);
      final communityRef = _firestore.collection('communities').doc(communityId);

      batch.update(memberRef, {
        'status': 'active',
        'joined_at': FieldValue.serverTimestamp(),
      });

      batch.update(communityRef, {
        'member_count': FieldValue.increment(1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error approving join request: $e');
      return false;
    }
  }

  /// PIC Komunitas menolak permintaan gabung
  Future<bool> rejectJoinRequest(String membershipDocId) async {
    try {
      await _firestore.collection('community_members').doc(membershipDocId).delete();
      return true;
    } catch (e) {
      debugPrint('Error rejecting join request: $e');
      return false;
    }
  }

  /// Admin Wargabut: Verifikasi komunitas agar tampil di publik
  Future<bool> verifyCommunity(String communityId) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'status': 'verified',
      });
      _pendingVerificationCommunities.removeWhere((c) => c.id == communityId);
      await fetchCommunities(forceRefresh: true);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error verifying community: $e');
      return false;
    }
  }

  /// Admin Wargabut: Tolak / Hapus komunitas
  Future<bool> rejectCommunity(String communityId) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'status': 'rejected',
      });
      _pendingVerificationCommunities.removeWhere((c) => c.id == communityId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error rejecting community: $e');
      return false;
    }
  }

  /// Angkat anggota aktif menjadi Admin komunitas
  Future<bool> promoteMemberToAdmin({required String communityId, required String uid}) async {
    try {
      final batch = _firestore.batch();
      final memberRef = _firestore.collection('community_members').doc('${communityId}_$uid');
      final communityRef = _firestore.collection('communities').doc(communityId);

      batch.update(memberRef, {'role': 'Admin'});
      batch.update(communityRef, {
        'admin_uids': FieldValue.arrayUnion([uid]),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error promoting member to admin: $e');
      return false;
    }
  }

  /// Turunkan Admin komunitas menjadi Member biasa
  Future<bool> demoteAdminToMember({required String communityId, required String uid}) async {
    try {
      final batch = _firestore.batch();
      final memberRef = _firestore.collection('community_members').doc('${communityId}_$uid');
      final communityRef = _firestore.collection('communities').doc(communityId);

      batch.update(memberRef, {'role': 'Member'});
      batch.update(communityRef, {
        'admin_uids': FieldValue.arrayRemove([uid]),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error demoting admin to member: $e');
      return false;
    }
  }

  /// Tambahkan admin baru berdasarkan username Wargabut
  Future<String?> addAdminByUsername({required String communityId, required String username}) async {
    try {
      final cleanUsername = username.toLowerCase().trim().replaceAll('@', '');
      if (cleanUsername.isEmpty) return 'Username tidak boleh kosong';

      // 1. Cari user di Firestore
      UserProfileModel? targetUser;
      final mapDoc = await _firestore.collection('usernames').doc(cleanUsername).get();
      if (mapDoc.exists) {
        final uid = mapDoc.data()?['uid'];
        if (uid != null) {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            targetUser = UserProfileModel.fromFirestore(userDoc);
          }
        }
      }
      if (targetUser == null) {
        final query = await _firestore.collection('users').where('username', isEqualTo: cleanUsername).limit(1).get();
        if (query.docs.isNotEmpty) {
          targetUser = UserProfileModel.fromFirestore(query.docs.first);
        }
      }

      if (targetUser == null) {
        return 'Pengguna dengan username @$cleanUsername tidak ditemukan di Wargabut.';
      }

      // 2. Cek komunitas
      final comDoc = await _firestore.collection('communities').doc(communityId).get();
      if (!comDoc.exists) return 'Komunitas tidak ditemukan.';
      final comData = comDoc.data() ?? {};
      final creatorUid = comData['creator_uid'] ?? '';
      final List<dynamic> adminUids = List.from(comData['admin_uids'] ?? []);

      if (targetUser.uid == creatorUid) {
        return '@$cleanUsername sudah menjadi Founder komunitas ini.';
      }
      if (adminUids.contains(targetUser.uid)) {
        return '@$cleanUsername sudah berstatus sebagai Admin di komunitas ini.';
      }

      final batch = _firestore.batch();
      final memberRef = _firestore.collection('community_members').doc('${communityId}_${targetUser.uid}');
      final memberDoc = await memberRef.get();

      if (memberDoc.exists) {
        // Sudah ada di members (status pending atau active)
        batch.update(memberRef, {
          'role': 'Admin',
          'status': 'active',
          'joined_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Belum jadi member, tambahkan langsung sebagai active Admin
        final newMembership = CommunityMemberModel(
          id: '${communityId}_${targetUser.uid}',
          communityId: communityId,
          uid: targetUser.uid,
          role: 'Admin',
          status: 'active',
          joinedAt: DateTime.now(),
          username: targetUser.username,
          displayName: targetUser.displayName,
          avatarUrl: targetUser.avatarUrl,
          city: targetUser.city,
          customTags: targetUser.customTags,
        );
        batch.set(memberRef, newMembership.toMap());
        batch.update(comDoc.reference, {
          'member_count': FieldValue.increment(1),
        });
      }

      batch.update(comDoc.reference, {
        'admin_uids': FieldValue.arrayUnion([targetUser.uid]),
      });

      await batch.commit();
      return null; // Sukses
    } catch (e) {
      debugPrint('Error adding admin: $e');
      return 'Gagal menambahkan admin: $e';
    }
  }

  /// Keluarkan anggota dari komunitas
  Future<bool> removeMember({required String communityId, required String uid}) async {
    try {
      final batch = _firestore.batch();
      final memberRef = _firestore.collection('community_members').doc('${communityId}_$uid');
      final comRef = _firestore.collection('communities').doc(communityId);

      batch.delete(memberRef);
      batch.update(comRef, {
        'admin_uids': FieldValue.arrayRemove([uid]),
        'member_count': FieldValue.increment(-1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error removing member: $e');
      return false;
    }
  }

  // ==========================================
  // MANAJEMEN AGENDA EVENT KOMUNITAS (JEVENTKU)
  // ==========================================

  /// Mengambil daftar event yang akan dihadiri oleh suatu komunitas
  Future<List<CommunityEventAttendanceModel>> fetchCommunityEvents(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('community_events')
          .where('community_id', isEqualTo: communityId)
          .get();

      final list = snapshot.docs
          .map((doc) => CommunityEventAttendanceModel.fromFirestore(doc))
          .toList();

      // Filter & urutkan berdasarkan tanggal event terdekat di paling atas
      return EventDateUtils.sortEventsByClosestDate(
        list,
        dateExtractor: (e) => e.eventDate,
        filterPast: true,
      );
    } catch (e) {
      debugPrint('Error fetching community events: $e');
      return [];
    }
  }

  /// Mengambil daftar komunitas yang akan hadir di suatu event
  Future<List<CommunityEventAttendanceModel>> fetchEventAttendingCommunities(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('community_events')
          .where('event_id', isEqualTo: eventId)
          .get();

      return snapshot.docs
          .map((doc) => CommunityEventAttendanceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching event attending communities: $e');
      return [];
    }
  }

  /// Tambah event yang akan dihadiri komunitas (hanya Founder & Admin Komunitas)
  Future<String?> addEventToCommunity({
    required CommunityModel community,
    required String currentUid,
    required Map<String, dynamic> eventData,
    String notes = '',
  }) async {
    if (!community.isAdmin(currentUid)) {
      return 'Hanya Founder atau Admin komunitas yang dapat menambahkan agenda event.';
    }

    try {
      final eventId = eventData['id']?.toString() ?? '';
      if (eventId.isEmpty) return 'Data event tidak valid.';

      final docId = '${community.id}_$eventId';
      final docRef = _firestore.collection('community_events').doc(docId);

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
        posterUrl = eventData['poster']?.toString() ?? eventData['poster_url']?.toString() ?? '';
      }

      final attendance = CommunityEventAttendanceModel(
        id: docId,
        communityId: community.id,
        communityName: community.name,
        communityLogo: community.logoUrl,
        communityCity: community.cityOrArea,
        isCommunityVerified: community.isVerified,
        eventId: eventId,
        eventName: eventData['event_name']?.toString() ?? eventData['name']?.toString() ?? eventData['title']?.toString() ?? 'Event',
        eventDate: eventData['date']?.toString() ?? eventData['date_event']?.toString() ?? '',
        eventLocation: eventData['location']?.toString() ?? '',
        eventArea: eventData['area']?.toString() ?? '',
        eventPoster: posterUrl,
        notes: notes.trim(),
        addedByUid: currentUid,
        createdAt: DateTime.now(),
      );

      await docRef.set(attendance.toMap());
      notifyListeners();
      return null; // Sukses
    } catch (e) {
      debugPrint('Error adding event to community: $e');
      return 'Gagal menambahkan event ke agenda komunitas: $e';
    }
  }

  /// Hapus event dari agenda komunitas
  Future<bool> removeEventFromCommunity({
    required String communityId,
    required String eventId,
    required String currentUid,
  }) async {
    try {
      // Cek apakah user adalah admin/founder
      final com = await getCommunityBySlug(communityId);
      if (com == null || !com.isAdmin(currentUid)) {
        return false;
      }

      final docId = '${communityId}_$eventId';
      await _firestore.collection('community_events').doc(docId).delete();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing event from community: $e');
      return false;
    }
  }

  /// Ambil komunitas yang dikelola oleh user (Founder atau Admin)
  Future<List<CommunityModel>> getCommunitiesManagedByUser(String uid) async {
    try {
      final createdSnap = await _firestore
          .collection('communities')
          .where('creator_uid', isEqualTo: uid)
          .get();

      final adminSnap = await _firestore
          .collection('communities')
          .where('admin_uids', arrayContains: uid)
          .get();

      final Map<String, CommunityModel> map = {};
      for (var doc in createdSnap.docs) {
        final com = CommunityModel.fromFirestore(doc);
        map[com.id] = com;
      }
      for (var doc in adminSnap.docs) {
        final com = CommunityModel.fromFirestore(doc);
        map[com.id] = com;
      }

      return map.values.toList();
    } catch (e) {
      debugPrint('Error fetching managed communities: $e');
      return [];
    }
  }

  /// Mengambil semua komunitas yang diikuti oleh user (status active sebagai Member, Admin, atau Founder)
  Future<List<CommunityModel>> fetchUserCommunities(String uid) async {
    try {
      final memberships = await _firestore
          .collection('community_members')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (memberships.docs.isEmpty) return [];

      final List<CommunityModel> result = [];
      for (var mDoc in memberships.docs) {
        final communityId = mDoc.data()['community_id']?.toString() ?? '';
        if (communityId.isEmpty) continue;

        CommunityModel? found;
        for (var c in _communities) {
          if (c.id == communityId) {
            found = c;
            break;
          }
        }

        if (found != null) {
          result.add(found);
        } else {
          final comDoc = await _firestore.collection('communities').doc(communityId).get();
          if (comDoc.exists) {
            result.add(CommunityModel.fromFirestore(comDoc));
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error fetching user communities: $e');
      return [];
    }
  }
}
