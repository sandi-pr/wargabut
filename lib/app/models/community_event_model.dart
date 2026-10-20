import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityEventAttendanceModel {
  final String id; // format: ${communityId}_${eventId}
  final String communityId;
  final String communityName;
  final String communityLogo;
  final String communityCity;
  final bool isCommunityVerified;
  final String eventId;
  final String eventName;
  final String eventDate;
  final String eventLocation;
  final String eventArea;
  final String eventPoster;
  final String notes; // Catatan khusus kehadiran (misal: "Buka booth di Hall B", "Kumpul member jam 13:00")
  final String addedByUid;
  final DateTime? createdAt;

  CommunityEventAttendanceModel({
    required this.id,
    required this.communityId,
    required this.communityName,
    this.communityLogo = '',
    this.communityCity = '',
    this.isCommunityVerified = false,
    required this.eventId,
    required this.eventName,
    this.eventDate = '',
    this.eventLocation = '',
    this.eventArea = '',
    this.eventPoster = '',
    this.notes = '',
    required this.addedByUid,
    this.createdAt,
  });

  factory CommunityEventAttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityEventAttendanceModel.fromMap(data, doc.id);
  }

  factory CommunityEventAttendanceModel.fromMap(Map<String, dynamic> data, String docId) {
    return CommunityEventAttendanceModel(
      id: docId,
      communityId: data['community_id'] ?? '',
      communityName: data['community_name'] ?? '',
      communityLogo: data['community_logo'] ?? '',
      communityCity: data['community_city'] ?? '',
      isCommunityVerified: data['is_community_verified'] ?? false,
      eventId: data['event_id'] ?? '',
      eventName: data['event_name'] ?? '',
      eventDate: data['event_date'] ?? '',
      eventLocation: data['event_location'] ?? '',
      eventArea: data['event_area'] ?? '',
      eventPoster: data['event_poster'] ?? '',
      notes: data['notes'] ?? '',
      addedByUid: data['added_by_uid'] ?? '',
      createdAt: (data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'community_id': communityId,
      'community_name': communityName,
      'community_logo': communityLogo,
      'community_city': communityCity,
      'is_community_verified': isCommunityVerified,
      'event_id': eventId,
      'event_name': eventName,
      'event_date': eventDate,
      'event_location': eventLocation,
      'event_area': eventArea,
      'event_poster': eventPoster,
      'notes': notes,
      'added_by_uid': addedByUid,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
