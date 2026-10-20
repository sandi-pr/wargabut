import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  final String id; // Slug atau Document ID
  final String name;
  final String cityOrArea;
  final String logoUrl;
  final String bannerUrl;
  final String shortDesc;
  final String description;
  final String instagram;
  final String tiktok;
  final String whatsappGroupLink;
  final List<String> categories;
  final String creatorUid;
  final List<String> adminUids;
  final String status; // 'pending_verification', 'verified', 'rejected'
  final int memberCount;
  final DateTime? createdAt;

  CommunityModel({
    required this.id,
    required this.name,
    required this.cityOrArea,
    this.logoUrl = '',
    this.bannerUrl = '',
    this.shortDesc = '',
    this.description = '',
    this.instagram = '',
    this.tiktok = '',
    this.whatsappGroupLink = '',
    this.categories = const [],
    required this.creatorUid,
    this.adminUids = const [],
    this.status = 'pending_verification',
    this.memberCount = 0,
    this.createdAt,
  });

  bool get isVerified => status == 'verified';

  bool isAdmin(String? uid) {
    if (uid == null) return false;
    return creatorUid == uid || adminUids.contains(uid);
  }

  bool isFounder(String? uid) {
    if (uid == null) return false;
    return creatorUid == uid;
  }

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityModel.fromMap(data, doc.id);
  }

  factory CommunityModel.fromMap(Map<String, dynamic> data, String docId) {
    return CommunityModel(
      id: docId,
      name: data['name'] ?? '',
      cityOrArea: data['city_or_area'] ?? data['city'] ?? '',
      logoUrl: data['logo_url'] ?? '',
      bannerUrl: data['banner_url'] ?? '',
      shortDesc: data['short_desc'] ?? '',
      description: data['description'] ?? '',
      instagram: data['instagram'] ?? '',
      tiktok: data['tiktok'] ?? '',
      whatsappGroupLink: data['whatsapp_group_link'] ?? '',
      categories: List<String>.from(data['categories'] ?? []),
      creatorUid: data['creator_uid'] ?? '',
      adminUids: List<String>.from(data['admin_uids'] ?? []),
      status: data['status'] ?? 'pending_verification',
      memberCount: (data['member_count'] as num?)?.toInt() ?? 0,
      createdAt: (data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city_or_area': cityOrArea,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'short_desc': shortDesc,
      'description': description,
      'instagram': instagram,
      'tiktok': tiktok,
      'whatsapp_group_link': whatsappGroupLink,
      'categories': categories,
      'creator_uid': creatorUid,
      'admin_uids': adminUids,
      'status': status,
      'member_count': memberCount,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
