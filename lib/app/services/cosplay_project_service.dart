import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/cosplay_project_model.dart';

class CosplayProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference get _projectsCol => _firestore.collection('cosplay_projects');
  CollectionReference get _applicationsCol => _firestore.collection('cosplay_project_applications');

  /// Membuat projek cosplay baru
  Future<String> createProject(CosplayProjectModel project) async {
    final docRef = _projectsCol.doc();
    final data = project.toMap();
    await docRef.set(data);
    return docRef.id;
  }

  /// Memperbarui projek cosplay
  Future<void> updateProject(CosplayProjectModel project) async {
    await _projectsCol.doc(project.id).update(project.toMap());
  }

  /// Menghapus projek cosplay dan seluruh aplikasinya
  Future<void> deleteProject(String projectId) async {
    // 1. Hapus dokumen projek
    await _projectsCol.doc(projectId).delete();

    // 2. Bersihkan aplikasi yang terkait dengan projek ini
    try {
      final apps = await _applicationsCol.where('project_id', isEqualTo: projectId).get();
      final batch = _firestore.batch();
      for (final doc in apps.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[CosplayProjectService] Gagal menghapus aplikasi terkait: $e');
    }
  }

  /// Mengambil detail projek sekali panggil
  Future<CosplayProjectModel?> getProjectById(String projectId) async {
    final doc = await _projectsCol.doc(projectId).get();
    if (!doc.exists) return null;
    return CosplayProjectModel.fromFirestore(doc);
  }

  /// Stream daftar projek cosplay dengan berbagai filter
  Stream<List<CosplayProjectModel>> streamProjects({
    String? seriesCategory,
    String? targetEventId,
    bool onlyOpen = false,
  }) {
    Query query = _projectsCol.orderBy('created_at', descending: true);

    if (seriesCategory != null && seriesCategory.isNotEmpty && seriesCategory != 'semua') {
      query = query.where('series_category', isEqualTo: seriesCategory);
    }

    if (targetEventId != null && targetEventId.isNotEmpty) {
      query = query.where('target_event_id', isEqualTo: targetEventId);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => CosplayProjectModel.fromFirestore(doc)).toList();
      if (onlyOpen) {
        return list.where((p) => p.status != 'full' && p.status != 'cancelled' && p.openSlotsCount > 0).toList();
      }
      return list;
    });
  }

  /// Stream sebuah projek realtime
  Stream<CosplayProjectModel?> streamProject(String projectId) {
    return _projectsCol.doc(projectId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CosplayProjectModel.fromFirestore(doc);
    });
  }

  /// Stream projek yang dibuat oleh user tertentu
  Stream<List<CosplayProjectModel>> streamProjectsByCreator(String creatorUid) {
    return _projectsCol
        .where('creator_uid', isEqualTo: creatorUid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => CosplayProjectModel.fromFirestore(d)).toList());
  }

  /// Mengajukan diri untuk mengisi slot karakter (oleh cosplayer)
  Future<String> submitApplication({
    required String projectId,
    required String projectTitle,
    required String slotId,
    required String characterName,
    required String applicantUid,
    required String applicantUsername,
    required String applicantName,
    String applicantAvatar = '',
    String applicantCity = '',
    String applicantInstagram = '',
    String applicantWhatsApp = '',
    String message = '',
    String costumePhotoUrl = '',
  }) async {
    final appId = _uuid.v4();
    final app = ProjectApplicationModel(
      id: appId,
      projectId: projectId,
      projectTitle: projectTitle,
      slotId: slotId,
      characterName: characterName,
      applicantUid: applicantUid,
      applicantUsername: applicantUsername,
      applicantName: applicantName,
      applicantAvatar: applicantAvatar,
      applicantCity: applicantCity,
      applicantInstagram: applicantInstagram,
      applicantWhatsApp: applicantWhatsApp,
      message: message,
      costumePhotoUrl: costumePhotoUrl,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _applicationsCol.doc(appId).set(app.toMap());

    // Perbarui status slot di projek menjadi 'applied' jika sebelumnya masih 'open'
    final project = await getProjectById(projectId);
    if (project != null) {
      final updatedSlots = project.slots.map((s) {
        if (s.slotId == slotId && s.isOpen) {
          return s.copyWith(status: 'applied');
        }
        return s;
      }).toList();

      await _projectsCol.doc(projectId).update({
        'slots': updatedSlots.map((s) => s.toMap()).toList(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    return appId;
  }

  /// Stream seluruh aplikasi/pelamar untuk satu projek (bagi Organizer)
  Stream<List<ProjectApplicationModel>> streamApplicationsForProject(String projectId) {
    return _applicationsCol
        .where('project_id', isEqualTo: projectId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((d) => ProjectApplicationModel.fromFirestore(d)).toList();
          list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          return list;
        });
  }

  /// Stream seluruh aplikasi milik user yang login
  Stream<List<ProjectApplicationModel>> streamMyApplications(String userUid) {
    return _applicationsCol
        .where('applicant_uid', isEqualTo: userUid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((d) => ProjectApplicationModel.fromFirestore(d)).toList();
          list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          return list;
        });
  }

  /// Menyetujui pelamar untuk mengisi slot (Approved by Organizer)
  Future<void> approveApplication({
    required String projectId,
    required ProjectApplicationModel application,
  }) async {
    // 1. Update status aplikasi jadi 'approved'
    await _applicationsCol.doc(application.id).update({
      'status': 'approved',
      'updated_at': FieldValue.serverTimestamp(),
    });

    // 2. Masukkan user ke slot di projek
    final project = await getProjectById(projectId);
    if (project == null) return;

    final updatedSlots = project.slots.map((s) {
      if (s.slotId == application.slotId) {
        return s.copyWith(
          status: 'filled',
          filledUser: SlotFilledUser(
            uid: application.applicantUid,
            username: application.applicantUsername,
            displayName: application.applicantName,
            avatarUrl: application.applicantAvatar,
            instagram: application.applicantInstagram,
            assignedAt: DateTime.now(),
            isExternal: false,
          ),
        );
      }
      return s;
    }).toList();

    // Hitung apakah sudah penuh
    final filledCount = updatedSlots.where((s) => s.isFilled).length;
    final total = updatedSlots.length;
    String newStatus = project.status;
    if (total > 0 && filledCount == total) {
      newStatus = 'full';
    } else if (filledCount > 0 && (total - filledCount) <= 2) {
      newStatus = 'almost_full';
    }

    await _projectsCol.doc(projectId).update({
      'slots': updatedSlots.map((s) => s.toMap()).toList(),
      'filled_slots': filledCount,
      'status': newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // 3. Tolak aplikasi lain untuk slot yang sama (jika ada pelamar lain di slot ini)
    try {
      final otherApps = await _applicationsCol
          .where('project_id', isEqualTo: projectId)
          .where('slot_id', isEqualTo: application.slotId)
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = _firestore.batch();
      for (final doc in otherApps.docs) {
        if (doc.id != application.id) {
          batch.update(doc.reference, {'status': 'rejected'});
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[CosplayProjectService] Gagal update aplikasi lain: $e');
    }
  }

  /// Menolak pelamar
  Future<void> rejectApplication({
    required String applicationId,
    required String projectId,
    required String slotId,
  }) async {
    await _applicationsCol.doc(applicationId).update({
      'status': 'rejected',
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Cek apakah masih ada pelamar pending lain untuk slot ini
    final pendingRemaining = await _applicationsCol
        .where('project_id', isEqualTo: projectId)
        .where('slot_id', isEqualTo: slotId)
        .where('status', isEqualTo: 'pending')
        .get();

    final project = await getProjectById(projectId);
    if (project != null) {
      final updatedSlots = project.slots.map((s) {
        if (s.slotId == slotId && !s.isFilled) {
          return s.copyWith(
            status: pendingRemaining.docs.isEmpty ? 'open' : 'applied',
          );
        }
        return s;
      }).toList();

      await _projectsCol.doc(projectId).update({
        'slots': updatedSlots.map((s) => s.toMap()).toList(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Organizer mengisi slot secara manual (misal teman luar Wargabut atau penugasan langsung)
  Future<void> assignSlotManually({
    required String projectId,
    required String slotId,
    required SlotFilledUser filledUser,
  }) async {
    final project = await getProjectById(projectId);
    if (project == null) return;

    final updatedSlots = project.slots.map((s) {
      if (s.slotId == slotId) {
        return s.copyWith(
          status: 'filled',
          filledUser: filledUser,
        );
      }
      return s;
    }).toList();

    final filledCount = updatedSlots.where((s) => s.isFilled).length;
    final total = updatedSlots.length;
    String newStatus = project.status;
    if (total > 0 && filledCount == total) {
      newStatus = 'full';
    }

    await _projectsCol.doc(projectId).update({
      'slots': updatedSlots.map((s) => s.toMap()).toList(),
      'filled_slots': filledCount,
      'status': newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Mengosongkan slot yang sebelumnya terisi (vacate slot)
  Future<void> vacateSlot({
    required String projectId,
    required String slotId,
  }) async {
    final project = await getProjectById(projectId);
    if (project == null) return;

    final updatedSlots = project.slots.map((s) {
      if (s.slotId == slotId) {
        return s.copyWith(
          status: 'open',
          clearFilledUser: true,
        );
      }
      return s;
    }).toList();

    final filledCount = updatedSlots.where((s) => s.isFilled).length;
    await _projectsCol.doc(projectId).update({
      'slots': updatedSlots.map((s) => s.toMap()).toList(),
      'filled_slots': filledCount,
      'status': 'open',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
