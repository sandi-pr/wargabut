import 'package:cloud_firestore/cloud_firestore.dart';

class CompanionMessageModel {
  final String id;
  final String companionId;
  final String senderUid;
  final String senderName;
  final String senderUsername;
  final String senderAvatar;
  final String message;
  final DateTime? createdAt;

  CompanionMessageModel({
    required this.id,
    required this.companionId,
    required this.senderUid,
    required this.senderName,
    required this.senderUsername,
    this.senderAvatar = '',
    required this.message,
    this.createdAt,
  });

  factory CompanionMessageModel.fromFirestore(DocumentSnapshot doc, String companionId) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CompanionMessageModel.fromMap(data, doc.id, companionId);
  }

  factory CompanionMessageModel.fromMap(Map<String, dynamic> data, String docId, String companionId) {
    return CompanionMessageModel(
      id: docId,
      companionId: companionId,
      senderUid: data['sender_uid'] ?? '',
      senderName: data['sender_name'] ?? '',
      senderUsername: data['sender_username'] ?? '',
      senderAvatar: data['sender_avatar'] ?? '',
      message: data['message'] ?? '',
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companion_id': companionId,
      'sender_uid': senderUid,
      'sender_name': senderName,
      'sender_username': senderUsername,
      'sender_avatar': senderAvatar,
      'message': message,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
