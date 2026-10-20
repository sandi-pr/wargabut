import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/event_date_utils.dart';

class CosplanItem {
  final String character;
  final String series;
  final String targetEventOrCity;

  CosplanItem({
    required this.character,
    required this.series,
    this.targetEventOrCity = '',
  });

  factory CosplanItem.fromMap(Map<String, dynamic> map) {
    return CosplanItem(
      character: map['character'] ?? '',
      series: map['series'] ?? '',
      targetEventOrCity: map['target_event_or_city'] ?? map['target'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'character': character,
      'series': series,
      'target_event_or_city': targetEventOrCity,
    };
  }

  String toDisplayString() {
    if (series.isNotEmpty) {
      return '$character ($series)';
    }
    return character;
  }
}

class UserAttendingEvent {
  final String eventId;
  final String eventName;
  final String eventDate;
  final String eventLocation;
  final String eventPoster;
  final String notes;

  UserAttendingEvent({
    required this.eventId,
    required this.eventName,
    this.eventDate = '',
    this.eventLocation = '',
    this.eventPoster = '',
    this.notes = '',
  });

  DateTime? get parsedStartDate => EventDateUtils.parseStartDate(eventDate);
  DateTime? get parsedEndDate => EventDateUtils.parseEndDate(eventDate);
  bool get isPast => EventDateUtils.isEventPast(eventDate);

  UserAttendingEvent copyWith({
    String? eventId,
    String? eventName,
    String? eventDate,
    String? eventLocation,
    String? eventPoster,
    String? notes,
  }) {
    return UserAttendingEvent(
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      eventLocation: eventLocation ?? this.eventLocation,
      eventPoster: eventPoster ?? this.eventPoster,
      notes: notes ?? this.notes,
    );
  }

  factory UserAttendingEvent.fromMap(Map<String, dynamic> map) {
    return UserAttendingEvent(
      eventId: (map['event_id'] ?? map['id'] ?? '').toString(),
      eventName: (map['event_name'] ?? map['name'] ?? map['title'] ?? '').toString(),
      eventDate: (map['event_date'] ?? map['date'] ?? '').toString(),
      eventLocation: (map['event_location'] ?? map['location'] ?? '').toString(),
      eventPoster: (map['event_poster'] ?? map['poster'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'event_name': eventName,
      'event_date': eventDate,
      'event_location': eventLocation,
      'event_poster': eventPoster,
      'notes': notes,
    };
  }
}

class UserProfileModel {
  final String uid;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;
  final String bio;
  final String instagram;
  final String tiktok;
  final String whatsapp;
  /// Visibilitas no WA: 'global' / 'public', 'community' / 'members_only', 'admin_only', 'private' / 'hidden'
  final String whatsappVisibility;
  /// Visibilitas profil member: 'global' (publik/tampil di direktori global), 'community' (hanya di grup komunitas), 'private' (sembunyi dari pencarian)
  final String profileVisibility;
  final List<String> customTags;
  final List<String> hobbies;
  final List<CosplanItem> cosplans;
  final List<String> joinedCommunityIds;
  final List<UserAttendingEvent> attendingEvents;
  final DateTime? updatedAt;

  UserProfileModel({
    required this.uid,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
    this.city = '',
    this.bio = '',
    this.instagram = '',
    this.tiktok = '',
    this.whatsapp = '',
    this.whatsappVisibility = 'community',
    this.profileVisibility = 'global',
    this.customTags = const [],
    this.hobbies = const [],
    this.cosplans = const [],
    this.joinedCommunityIds = const [],
    this.attendingEvents = const [],
    this.updatedAt,
  });

  bool get isVisibleGlobally => profileVisibility == 'global';
  bool get isVisibleInCommunity => profileVisibility == 'global' || profileVisibility == 'community';

  /// Mengambil daftar event yang akan dihadiri: hanya yang aktif / mendatang, diurutkan tanggal paling dekat di paling atas
  List<UserAttendingEvent> get upcomingAttendingEvents {
    return EventDateUtils.sortEventsByClosestDate(
      attendingEvents,
      dateExtractor: (e) => e.eventDate,
      filterPast: true,
    );
  }

  /// Mengambil seluruh event yang dihadiri, diurutkan tanggal terdekat di atas (event lampau ditaruh di bawah)
  List<UserAttendingEvent> get allSortedAttendingEvents {
    return EventDateUtils.sortEventsByClosestDate(
      attendingEvents,
      dateExtractor: (e) => e.eventDate,
      filterPast: false,
    );
  }

  /// Apakah member sudah pernah mengisi/melengkapi data kartu biodatanya
  bool get hasFilledBiodata {
    if (updatedAt != null) return true;
    if (bio.trim().isNotEmpty) return true;
    if (instagram.trim().isNotEmpty) return true;
    if (tiktok.trim().isNotEmpty) return true;
    if (whatsapp.trim().isNotEmpty) return true;
    if (avatarUrl.trim().isNotEmpty) return true;
    if (hobbies.isNotEmpty) return true;
    if (cosplans.isNotEmpty) return true;
    if (customTags.isNotEmpty) return true;
    if (attendingEvents.isNotEmpty) return true;
    return false;
  }

  /// Apakah nomor WA boleh dilihat oleh penonton berdasarkan konteks?
  bool canViewWhatsApp({
    required bool isSelf,
    required bool isCommunityAdmin,
    required bool isFellowMember,
    required bool isLoggedIn,
  }) {
    if (whatsapp.trim().isEmpty) return false;
    if (isSelf) return true;

    switch (whatsappVisibility) {
      case 'global':
      case 'public':
        return true;
      case 'community':
      case 'members_only':
        return isFellowMember || isCommunityAdmin;
      case 'admin_only':
        return isCommunityAdmin;
      case 'private':
      case 'hidden':
      default:
        return false;
    }
  }

  String get visibilityLabel {
    switch (whatsappVisibility) {
      case 'global':
      case 'public':
        return 'Publik (Semua Pengguna Wargabut)';
      case 'community':
      case 'members_only':
        return 'Hanya Sesama Anggota Komunitas';
      case 'admin_only':
        return 'Hanya Pengurus/Admin Komunitas';
      case 'private':
      case 'hidden':
      default:
        return 'Sembunyikan / Privat';
    }
  }

  String get profileVisibilityLabel {
    switch (profileVisibility) {
      case 'community':
        return 'Hanya di Komunitas yang Diikuti';
      case 'private':
        return 'Privat (Sembunyi dari Pencarian)';
      case 'global':
      default:
        return 'Global (Tampil di Direktori Wargabut)';
    }
  }

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfileModel.fromMap(data, doc.id);
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> data, String uid) {
    final rawCosplans = data['cosplans'] as List<dynamic>? ?? [];
    final rawAttendingEvents = data['attending_events'] as List<dynamic>? ?? [];
    return UserProfileModel(
      uid: uid,
      username: (data['username'] ?? '').toString().toLowerCase().trim(),
      displayName: data['display_name'] ?? data['name'] ?? '',
      avatarUrl: data['avatar_url'] ?? '',
      city: data['city'] ?? data['askot'] ?? '',
      bio: data['bio'] ?? '',
      instagram: data['instagram'] ?? '',
      tiktok: data['tiktok'] ?? '',
      whatsapp: data['whatsapp'] ?? '',
      whatsappVisibility: data['whatsapp_visibility'] ?? 'community',
      profileVisibility: data['profile_visibility'] ?? 'global',
      customTags: List<String>.from(data['custom_tags'] ?? []),
      hobbies: List<String>.from(data['hobbies'] ?? []),
      cosplans: rawCosplans.map((e) => CosplanItem.fromMap(Map<String, dynamic>.from(e))).toList(),
      joinedCommunityIds: List<String>.from(data['joined_communities'] ?? []),
      attendingEvents: EventDateUtils.sortEventsByClosestDate(
        rawAttendingEvents
            .map((e) => UserAttendingEvent.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        dateExtractor: (e) => e.eventDate,
        filterPast: true,
      ),
      updatedAt: (data['updated_at'] is Timestamp)
          ? (data['updated_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username.toLowerCase().trim(),
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'city': city,
      'bio': bio,
      'instagram': instagram,
      'tiktok': tiktok,
      'whatsapp': whatsapp,
      'whatsapp_visibility': whatsappVisibility,
      'profile_visibility': profileVisibility,
      'custom_tags': customTags,
      'hobbies': hobbies,
      'cosplans': cosplans.map((e) => e.toMap()).toList(),
      'joined_communities': joinedCommunityIds,
      'attending_events': attendingEvents.map((e) => e.toMap()).toList(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// Membuat format teks perkenalan (intro) yang siap di-copy ke WhatsApp / Discord
  String generateIntroText({String? communityName}) {
    final buffer = StringBuffer();
    buffer.writeln('🌸 *PERKENALAN MEMBER ${communityName != null ? "DI $communityName" : "WARGABUT"}* 🌸');
    buffer.writeln('----------------------------------');
    buffer.writeln('✨ *Nama / Panggilan:* $displayName (@$username)');
    if (city.isNotEmpty) buffer.writeln('📍 *Asal Kota:* $city');
    if (customTags.isNotEmpty) buffer.writeln('🏷️ *Role / Tag:* ${customTags.join(" ")}');
    if (hobbies.isNotEmpty) buffer.writeln('🎮 *Hobi:* ${hobbies.join(", ")}');
    if (cosplans.isNotEmpty) {
      buffer.writeln('🎭 *Cosplan:*');
      for (var c in cosplans) {
        buffer.writeln('   • ${c.toDisplayString()}${c.targetEventOrCity.isNotEmpty ? " [${c.targetEventOrCity}]" : ""}');
      }
    }
    if (attendingEvents.isNotEmpty) {
      buffer.writeln('🎟️ *Event Selanjutnya:*');
      for (var ev in attendingEvents) {
        buffer.writeln('   • ${ev.eventName}${ev.eventDate.isNotEmpty ? " (${ev.eventDate})" : ""}${ev.notes.isNotEmpty ? " - [${ev.notes}]" : ""}');
      }
    }
    if (instagram.isNotEmpty) {
      final cleanIg = instagram.replaceAll('@', '');
      buffer.writeln('📸 *Instagram:* https://instagram.com/$cleanIg');
    }
    if (tiktok.isNotEmpty) {
      final cleanTt = tiktok.replaceAll('@', '');
      buffer.writeln('🎵 *TikTok:* https://tiktok.com/@$cleanTt');
    }
    buffer.writeln('----------------------------------');
    buffer.writeln('Salam kenal semuanya! Jangan ragu buat sapa yaa ✨');
    buffer.writeln('🔗 *Profil Wargabut:* https://wargabut.id/@$username');
    return buffer.toString();
  }
}

class CommunityMemberModel {
  final String id; // usually "$communityId\_$uid"
  final String communityId;
  final String uid;
  final String role; // 'Founder', 'Admin', 'Member'
  final String status; // 'pending', 'active', 'rejected'
  final DateTime? requestedAt;
  final DateTime? joinedAt;
  // Denormalized snapshot of member for quick display
  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;
  final List<String> customTags;

  CommunityMemberModel({
    required this.id,
    required this.communityId,
    required this.uid,
    this.role = 'Member',
    this.status = 'active',
    this.requestedAt,
    this.joinedAt,
    this.username = '',
    this.displayName = '',
    this.avatarUrl = '',
    this.city = '',
    this.customTags = const [],
  });

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isFounder => role == 'Founder';
  bool get isAdminRole => role == 'Admin' || role == 'Founder';

  factory CommunityMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityMemberModel.fromMap(data, doc.id);
  }

  factory CommunityMemberModel.fromMap(Map<String, dynamic> data, String docId) {
    return CommunityMemberModel(
      id: docId,
      communityId: data['community_id'] ?? '',
      uid: data['uid'] ?? '',
      role: data['role'] ?? 'Member',
      status: data['status'] ?? 'active',
      requestedAt: (data['requested_at'] is Timestamp)
          ? (data['requested_at'] as Timestamp).toDate()
          : null,
      joinedAt: (data['joined_at'] is Timestamp)
          ? (data['joined_at'] as Timestamp).toDate()
          : null,
      username: data['username'] ?? '',
      displayName: data['display_name'] ?? '',
      avatarUrl: data['avatar_url'] ?? '',
      city: data['city'] ?? '',
      customTags: List<String>.from(data['custom_tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'community_id': communityId,
      'uid': uid,
      'role': role,
      'status': status,
      'requested_at': requestedAt != null ? Timestamp.fromDate(requestedAt!) : FieldValue.serverTimestamp(),
      'joined_at': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'city': city,
      'custom_tags': customTags,
    };
  }
}
