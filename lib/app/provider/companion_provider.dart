import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/event_companion_model.dart';
import '../models/companion_message_model.dart';

class CompanionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _companionsCol => _firestore.collection('event_companions');

  /// Mendengarkan daftar rombongan aktif untuk event tertentu
  Stream<List<EventCompanionModel>> getCompanionsStream(String eventId) {
    return _companionsCol
        .where('event_id', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => EventCompanionModel.fromFirestore(doc))
              .toList();

          // Urutkan: rombongan open di atas, kemudian berdasarkan created_at terbaru
          list.sort((a, b) {
            if (a.status == 'open' && b.status != 'open') return -1;
            if (a.status != 'open' && b.status == 'open') return 1;
            final dateA = a.createdAt ?? DateTime(2000);
            final dateB = b.createdAt ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });
          return list;
        });
  }

  /// Membuat rombongan ajakan barengan baru
  Future<String?> createCompanion(EventCompanionModel companion) async {
    try {
      final docRef = await _companionsCol.add(companion.toMap());
      notifyListeners();
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating companion: $e');
      return null;
    }
  }

  /// Bergabung ke dalam rombongan
  Future<bool> joinCompanion(String companionId, CompanionMember member) async {
    try {
      final docRef = _companionsCol.doc(companionId);
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>? ?? {};
      final rawMembers = data['members'] as List<dynamic>? ?? [];
      final maxMembers = data['max_members'] as int? ?? 4;

      // Cek apakah sudah bergabung
      final alreadyJoined = rawMembers.any((m) => m['uid'] == member.uid);
      if (alreadyJoined) return true;

      // Cek kuota
      if (maxMembers > 0 && rawMembers.length >= maxMembers) {
        return false;
      }

      final updatedMembers = List<dynamic>.from(rawMembers)..add(member.toMap());
      final isNowFull = maxMembers > 0 && updatedMembers.length >= maxMembers;

      await docRef.update({
        'members': updatedMembers,
        if (isNowFull) 'status': 'full',
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error joining companion: $e');
      return false;
    }
  }

  /// Keluar dari rombongan
  Future<bool> leaveCompanion(String companionId, String uid) async {
    try {
      final docRef = _companionsCol.doc(companionId);
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>? ?? {};
      final rawMembers = data['members'] as List<dynamic>? ?? [];

      final updatedMembers = rawMembers.where((m) => m['uid'] != uid).toList();

      await docRef.update({
        'members': updatedMembers,
        'status': 'open', // Jika keluar, kuota kembali tersedia
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error leaving companion: $e');
      return false;
    }
  }

  /// Memperbarui rombongan ajakan barengan (khusus pembuat atau admin)
  Future<bool> updateCompanion(String companionId, Map<String, dynamic> data) async {
    try {
      await _companionsCol.doc(companionId).update(data);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating companion: $e');
      return false;
    }
  }

  /// Menghapus rombongan (khusus pembuat atau admin)
  Future<bool> deleteCompanion(String companionId) async {
    try {
      await _companionsCol.doc(companionId).delete();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting companion: $e');
      return false;
    }
  }

  /// Mendengarkan pesan tanya jawab / koordinasi di dalam rombongan
  Stream<List<CompanionMessageModel>> getMessagesStream(String companionId) {
    return _companionsCol
        .doc(companionId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CompanionMessageModel.fromFirestore(doc, companionId))
              .toList();
        });
  }

  /// Mengirim pesan koordinasi ke dalam rombongan
  Future<bool> sendMessage(String companionId, CompanionMessageModel message) async {
    try {
      await _companionsCol
          .doc(companionId)
          .collection('messages')
          .add(message.toMap());
      return true;
    } catch (e) {
      debugPrint('Error sending companion message: $e');
      return false;
    }
  }
}
