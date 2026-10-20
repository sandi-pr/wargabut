import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Data pengguna/cosplayer yang mengisi slot
class SlotFilledUser {
  final String uid;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String instagram;
  final DateTime? assignedAt;
  final bool isExternal;
  final String? externalContact;

  SlotFilledUser({
    required this.uid,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
    this.instagram = '',
    this.assignedAt,
    this.isExternal = false,
    this.externalContact,
  });

  factory SlotFilledUser.fromMap(Map<String, dynamic> map) {
    return SlotFilledUser(
      uid: (map['uid'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      displayName: (map['display_name'] ?? map['username'] ?? '').toString(),
      avatarUrl: (map['avatar_url'] ?? '').toString(),
      instagram: (map['instagram'] ?? '').toString(),
      assignedAt: map['assigned_at'] is Timestamp
          ? (map['assigned_at'] as Timestamp).toDate()
          : null,
      isExternal: map['is_external'] == true,
      externalContact: map['external_contact']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'instagram': instagram,
      'assigned_at': assignedAt != null ? Timestamp.fromDate(assignedAt!) : FieldValue.serverTimestamp(),
      'is_external': isExternal,
      'external_contact': externalContact,
    };
  }

  SlotFilledUser copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? instagram,
    DateTime? assignedAt,
    bool? isExternal,
    String? externalContact,
  }) {
    return SlotFilledUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      instagram: instagram ?? this.instagram,
      assignedAt: assignedAt ?? this.assignedAt,
      isExternal: isExternal ?? this.isExternal,
      externalContact: externalContact ?? this.externalContact,
    );
  }
}

/// Slot karakter spesifik dalam satu projekan
class CosplayProjectSlot {
  final String slotId;
  final String characterName;
  final String characterVersion;
  final String categoryGroup;
  final String referenceImageUrl;
  final String imageAlignment; // 'top', 'center', 'bottom'
  final String notes;
  final String status; // 'open', 'applied', 'filled'
  final SlotFilledUser? filledUser;

  CosplayProjectSlot({
    required this.slotId,
    required this.characterName,
    this.characterVersion = '',
    this.categoryGroup = 'Umum',
    this.referenceImageUrl = '',
    this.imageAlignment = 'top',
    this.notes = '',
    this.status = 'open',
    this.filledUser,
  });

  bool get isFilled => status == 'filled' || filledUser != null;
  bool get isOpen => status == 'open' && filledUser == null;
  bool get isApplied => status == 'applied';

  /// Alignment untuk BoxFit.cover agar preview karakter portrait/lonjong fokus ke wajah (top), badan (center), atau bawah (bottom)
  Alignment get parsedAlignment {
    switch (imageAlignment.toLowerCase()) {
      case 'bottom':
        return Alignment.bottomCenter;
      case 'center':
        return Alignment.center;
      case 'top':
      default:
        return Alignment.topCenter;
    }
  }

  factory CosplayProjectSlot.fromMap(Map<String, dynamic> map) {
    return CosplayProjectSlot(
      slotId: (map['slot_id'] ?? '').toString(),
      characterName: (map['character_name'] ?? '').toString(),
      characterVersion: (map['character_version'] ?? '').toString(),
      categoryGroup: (map['category_group'] ?? 'Umum').toString(),
      referenceImageUrl: (map['reference_image_url'] ?? '').toString(),
      imageAlignment: (map['image_alignment'] ?? 'top').toString(),
      notes: (map['notes'] ?? '').toString(),
      status: (map['status'] ?? 'open').toString(),
      filledUser: map['filled_user'] != null && map['filled_user'] is Map<String, dynamic>
          ? SlotFilledUser.fromMap(map['filled_user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slot_id': slotId,
      'character_name': characterName,
      'character_version': characterVersion,
      'category_group': categoryGroup,
      'reference_image_url': referenceImageUrl,
      'image_alignment': imageAlignment,
      'notes': notes,
      'status': status,
      'filled_user': filledUser?.toMap(),
    };
  }

  CosplayProjectSlot copyWith({
    String? slotId,
    String? characterName,
    String? characterVersion,
    String? categoryGroup,
    String? referenceImageUrl,
    String? imageAlignment,
    String? notes,
    String? status,
    SlotFilledUser? filledUser,
    bool clearFilledUser = false,
  }) {
    return CosplayProjectSlot(
      slotId: slotId ?? this.slotId,
      characterName: characterName ?? this.characterName,
      characterVersion: characterVersion ?? this.characterVersion,
      categoryGroup: categoryGroup ?? this.categoryGroup,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      imageAlignment: imageAlignment ?? this.imageAlignment,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      filledUser: clearFilledUser ? null : (filledUser ?? this.filledUser),
    );
  }
}

/// Model Induk Projek Cosplay (Projekan)
class CosplayProjectModel {
  final String id;
  final String title;
  final String seriesTitle;
  final String seriesCategory; // 'anime', 'game', 'vtuber', 'manga', 'tokusatsu', 'other'
  final String bannerUrl;
  final String description;
  final String rules;

  // Target Pelaksanaan
  final String targetType; // 'event', 'photoshoot', 'gathering', 'flexible'
  final String? targetEventId;
  final String? targetEventName;
  final String? targetEventPoster;
  final String targetDate;
  final String targetCityOrVenue;

  // Penyelenggara / Organizer
  final String creatorUid;
  final String creatorName;
  final String creatorUsername;
  final String creatorAvatar;
  final String creatorWhatsApp;
  final String creatorInstagram;

  // Status & Akses
  final String status; // 'open', 'almost_full', 'full', 'completed', 'cancelled'
  final bool isPrivate;
  final String coordinationLink; // Link grup WA / Discord yang hanya tampil bagi member yang diterima

  final List<CosplayProjectSlot> slots;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CosplayProjectModel({
    required this.id,
    required this.title,
    required this.seriesTitle,
    this.seriesCategory = 'anime',
    this.bannerUrl = '',
    this.description = '',
    this.rules = '',
    this.targetType = 'event',
    this.targetEventId,
    this.targetEventName,
    this.targetEventPoster,
    this.targetDate = '',
    this.targetCityOrVenue = '',
    required this.creatorUid,
    required this.creatorName,
    required this.creatorUsername,
    this.creatorAvatar = '',
    this.creatorWhatsApp = '',
    this.creatorInstagram = '',
    this.status = 'open',
    this.isPrivate = false,
    this.coordinationLink = '',
    this.slots = const [],
    this.createdAt,
    this.updatedAt,
  });

  int get totalSlots => slots.length;
  int get filledSlotsCount => slots.where((s) => s.isFilled).length;
  int get openSlotsCount => slots.where((s) => s.isOpen).length;
  bool get isFull => totalSlots > 0 && openSlotsCount == 0;
  double get progressPercentage => totalSlots == 0 ? 0.0 : (filledSlotsCount / totalSlots).clamp(0.0, 1.0);

  /// Kategori/grup karakter yang unik dalam projek ini (misal: ['Hero Party', 'Villains'])
  List<String> get uniqueCategories {
    final set = <String>{};
    for (final s in slots) {
      if (s.categoryGroup.trim().isNotEmpty) {
        set.add(s.categoryGroup.trim());
      }
    }
    if (set.isEmpty) return ['Umum'];
    return set.toList();
  }

  factory CosplayProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CosplayProjectModel.fromMap(data, doc.id);
  }

  factory CosplayProjectModel.fromMap(Map<String, dynamic> data, String docId) {
    final rawSlots = data['slots'] as List<dynamic>? ?? [];
    return CosplayProjectModel(
      id: docId,
      title: (data['title'] ?? '').toString(),
      seriesTitle: (data['series_title'] ?? '').toString(),
      seriesCategory: (data['series_category'] ?? 'anime').toString(),
      bannerUrl: (data['banner_url'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      rules: (data['rules'] ?? '').toString(),
      targetType: (data['target_type'] ?? 'event').toString(),
      targetEventId: data['target_event_id']?.toString(),
      targetEventName: data['target_event_name']?.toString(),
      targetEventPoster: data['target_event_poster']?.toString(),
      targetDate: (data['target_date'] ?? '').toString(),
      targetCityOrVenue: (data['target_city_or_venue'] ?? data['location'] ?? '').toString(),
      creatorUid: (data['creator_uid'] ?? '').toString(),
      creatorName: (data['creator_name'] ?? '').toString(),
      creatorUsername: (data['creator_username'] ?? '').toString(),
      creatorAvatar: (data['creator_avatar'] ?? '').toString(),
      creatorWhatsApp: (data['creator_whatsapp'] ?? '').toString(),
      creatorInstagram: (data['creator_instagram'] ?? '').toString(),
      status: (data['status'] ?? 'open').toString(),
      isPrivate: data['is_private'] == true,
      coordinationLink: (data['coordination_link'] ?? '').toString(),
      slots: rawSlots.map((s) => CosplayProjectSlot.fromMap(s as Map<String, dynamic>)).toList(),
      createdAt: (data['created_at'] is Timestamp) ? (data['created_at'] as Timestamp).toDate() : null,
      updatedAt: (data['updated_at'] is Timestamp) ? (data['updated_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'series_title': seriesTitle,
      'series_category': seriesCategory,
      'banner_url': bannerUrl,
      'description': description,
      'rules': rules,
      'target_type': targetType,
      'target_event_id': targetEventId,
      'target_event_name': targetEventName,
      'target_event_poster': targetEventPoster,
      'target_date': targetDate,
      'target_city_or_venue': targetCityOrVenue,
      'creator_uid': creatorUid,
      'creator_name': creatorName,
      'creator_username': creatorUsername,
      'creator_avatar': creatorAvatar,
      'creator_whatsapp': creatorWhatsApp,
      'creator_instagram': creatorInstagram,
      'status': status,
      'is_private': isPrivate,
      'coordination_link': coordinationLink,
      'slots': slots.map((s) => s.toMap()).toList(),
      'total_slots': totalSlots,
      'filled_slots': filledSlotsCount,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  CosplayProjectModel copyWith({
    String? id,
    String? title,
    String? seriesTitle,
    String? seriesCategory,
    String? bannerUrl,
    String? description,
    String? rules,
    String? targetType,
    String? targetEventId,
    String? targetEventName,
    String? targetEventPoster,
    String? targetDate,
    String? targetCityOrVenue,
    String? creatorUid,
    String? creatorName,
    String? creatorUsername,
    String? creatorAvatar,
    String? creatorWhatsApp,
    String? creatorInstagram,
    String? status,
    bool? isPrivate,
    String? coordinationLink,
    List<CosplayProjectSlot>? slots,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CosplayProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesCategory: seriesCategory ?? this.seriesCategory,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      targetType: targetType ?? this.targetType,
      targetEventId: targetEventId ?? this.targetEventId,
      targetEventName: targetEventName ?? this.targetEventName,
      targetEventPoster: targetEventPoster ?? this.targetEventPoster,
      targetDate: targetDate ?? this.targetDate,
      targetCityOrVenue: targetCityOrVenue ?? this.targetCityOrVenue,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorName: creatorName ?? this.creatorName,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      creatorAvatar: creatorAvatar ?? this.creatorAvatar,
      creatorWhatsApp: creatorWhatsApp ?? this.creatorWhatsApp,
      creatorInstagram: creatorInstagram ?? this.creatorInstagram,
      status: status ?? this.status,
      isPrivate: isPrivate ?? this.isPrivate,
      coordinationLink: coordinationLink ?? this.coordinationLink,
      slots: slots ?? this.slots,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Pengajuan cosplayer untuk mengisi slot
class ProjectApplicationModel {
  final String id;
  final String projectId;
  final String projectTitle;
  final String slotId;
  final String characterName;

  // Snapshot Pelamar dari Biodata Wargabut
  final String applicantUid;
  final String applicantUsername;
  final String applicantName;
  final String applicantAvatar;
  final String applicantCity;
  final String applicantInstagram;
  final String applicantWhatsApp;

  final String message;
  final String costumePhotoUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? createdAt;

  ProjectApplicationModel({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.slotId,
    required this.characterName,
    required this.applicantUid,
    required this.applicantUsername,
    required this.applicantName,
    this.applicantAvatar = '',
    this.applicantCity = '',
    this.applicantInstagram = '',
    this.applicantWhatsApp = '',
    this.message = '',
    this.costumePhotoUrl = '',
    this.status = 'pending',
    this.createdAt,
  });

  factory ProjectApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProjectApplicationModel.fromMap(data, doc.id);
  }

  factory ProjectApplicationModel.fromMap(Map<String, dynamic> data, String docId) {
    return ProjectApplicationModel(
      id: docId,
      projectId: (data['project_id'] ?? '').toString(),
      projectTitle: (data['project_title'] ?? '').toString(),
      slotId: (data['slot_id'] ?? '').toString(),
      characterName: (data['character_name'] ?? '').toString(),
      applicantUid: (data['applicant_uid'] ?? '').toString(),
      applicantUsername: (data['applicant_username'] ?? '').toString(),
      applicantName: (data['applicant_name'] ?? '').toString(),
      applicantAvatar: (data['applicant_avatar'] ?? '').toString(),
      applicantCity: (data['applicant_city'] ?? '').toString(),
      applicantInstagram: (data['applicant_instagram'] ?? '').toString(),
      applicantWhatsApp: (data['applicant_whatsapp'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      costumePhotoUrl: (data['costume_photo_url'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      createdAt: (data['created_at'] is Timestamp) ? (data['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'project_id': projectId,
      'project_title': projectTitle,
      'slot_id': slotId,
      'character_name': characterName,
      'applicant_uid': applicantUid,
      'applicant_username': applicantUsername,
      'applicant_name': applicantName,
      'applicant_avatar': applicantAvatar,
      'applicant_city': applicantCity,
      'applicant_instagram': applicantInstagram,
      'applicant_whatsapp': applicantWhatsApp,
      'message': message,
      'costume_photo_url': costumePhotoUrl,
      'status': status,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
