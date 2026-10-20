import 'package:cloud_firestore/cloud_firestore.dart';

class CompanionMember {
  final String uid;
  final String username;
  final String displayName;
  final String avatarUrl;
  final DateTime? joinedAt;

  CompanionMember({
    required this.uid,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
    this.joinedAt,
  });

  factory CompanionMember.fromMap(Map<String, dynamic> map) {
    return CompanionMember(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      displayName: map['display_name'] ?? map['username'] ?? '',
      avatarUrl: map['avatar_url'] ?? '',
      joinedAt: map['joined_at'] is Timestamp
          ? (map['joined_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'joined_at': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
    };
  }
}

class EventCompanionModel {
  final String id;
  final String eventId;
  final String eventName;
  final String creatorUid;
  final String creatorName;
  final String creatorUsername;
  final String creatorAvatar;
  final String title;
  final String type; // 'transit' | 'venue'
  final String transitLine; // e.g. 'KRL Lintas Bogor', 'MRT', etc.
  final String meetingPoint;
  final String meetingTime;
  final String activityTag;
  final String notes;
  final int maxMembers; // 0 = tanpa batas
  final List<CompanionMember> members;
  final String telegramHandle;
  final String instagramHandle;
  final String status; // 'open' | 'full' | 'closed'
  final DateTime? createdAt;

  EventCompanionModel({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.creatorUid,
    required this.creatorName,
    required this.creatorUsername,
    this.creatorAvatar = '',
    required this.title,
    required this.type,
    this.transitLine = '',
    required this.meetingPoint,
    required this.meetingTime,
    this.activityTag = '',
    this.notes = '',
    this.maxMembers = 4,
    this.members = const [],
    this.telegramHandle = '',
    this.instagramHandle = '',
    this.status = 'open',
    this.createdAt,
  });

  bool get isTransit => type == 'transit';
  bool get isVenue => type == 'venue';

  bool get isFull => maxMembers > 0 && members.length >= maxMembers;

  bool isMember(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    return members.any((m) => m.uid == uid) || creatorUid == uid;
  }

  factory EventCompanionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EventCompanionModel.fromMap(data, doc.id);
  }

  factory EventCompanionModel.fromMap(Map<String, dynamic> data, String docId) {
    final rawMembers = data['members'] as List<dynamic>? ?? [];
    final membersList = rawMembers
        .map((m) => CompanionMember.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    return EventCompanionModel(
      id: docId,
      eventId: data['event_id'] ?? '',
      eventName: data['event_name'] ?? '',
      creatorUid: data['creator_uid'] ?? '',
      creatorName: data['creator_name'] ?? '',
      creatorUsername: data['creator_username'] ?? '',
      creatorAvatar: data['creator_avatar'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? 'transit',
      transitLine: data['transit_line'] ?? '',
      meetingPoint: data['meeting_point'] ?? '',
      meetingTime: data['meeting_time'] ?? '',
      activityTag: data['activity_tag'] ?? '',
      notes: data['notes'] ?? '',
      maxMembers: data['max_members'] ?? 4,
      members: membersList,
      telegramHandle: data['telegram_handle'] ?? '',
      instagramHandle: data['instagram_handle'] ?? '',
      status: data['status'] ?? 'open',
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'event_name': eventName,
      'creator_uid': creatorUid,
      'creator_name': creatorName,
      'creator_username': creatorUsername,
      'creator_avatar': creatorAvatar,
      'title': title,
      'type': type,
      'transit_line': transitLine,
      'meeting_point': meetingPoint,
      'meeting_time': meetingTime,
      'activity_tag': activityTag,
      'notes': notes,
      'max_members': maxMembers,
      'members': members.map((m) => m.toMap()).toList(),
      'telegram_handle': telegramHandle,
      'instagram_handle': instagramHandle,
      'status': status,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
