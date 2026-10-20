import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/user_profile_model.dart';

class WearableSyncService {
  static const MethodChannel _channel = MethodChannel('id.wargabut/wearable_sync');

  /// Melakukan pairing Web ke Smartwatch via Firestore collection `wear_pairings`
  static Future<bool> pairWearDeviceWithCode({
    required String code,
    required UserProfileModel profile,
  }) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      if (cleanCode.isEmpty) return false;

      final role = profile.city.isNotEmpty
          ? 'Wargabut (${profile.city})'
          : (profile.customTags.isNotEmpty
              ? profile.customTags.first
              : 'Wargabut Member');

      await FirebaseFirestore.instance.collection('wear_pairings').doc(cleanCode).set({
        'code': cleanCode,
        'status': 'approved',
        'uid': profile.uid,
        'username': profile.username,
        'displayName': profile.displayName.isNotEmpty ? profile.displayName : profile.username,
        'role': role,
        'bio': profile.bio,
        'instagram': profile.instagram,
        'paired_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WearableSync] Error pairing wear device: $e');
      }
      return false;
    }
  }

  /// Mengirim data profil pengguna ke smartwatch Wear OS (Xiaomi Watch dsb)
  static Future<bool> syncProfile(UserProfileModel profile) async {
    if (kIsWeb) return false;

    try {
      final role = profile.customTags.isNotEmpty
          ? profile.customTags.join(', ')
          : (profile.bio.isNotEmpty ? profile.bio : 'Wargabut Member');

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('syncProfile', {
        'username': profile.username,
        'displayName': profile.displayName.isNotEmpty ? profile.displayName : profile.username,
        'role': role,
        'bio': profile.bio,
        'instagram': profile.instagram,
      });

      if (kDebugMode) {
        debugPrint('[WearableSync] Berhasil sinkron ke Wear OS: $result');
      }
      return true;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[WearableSync] Gagal sinkron ke Wear OS: ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WearableSync] Error tidak terduga: $e');
      }
      return false;
    }
  }

  /// Memeriksa apakah ada smartwatch Wear OS yang terhubung
  static Future<Map<String, dynamic>> checkWearConnected() async {
    if (kIsWeb) return {'connected': false, 'devices': []};

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkWearConnected');
      return {
        'connected': result?['connected'] == true,
        'devices': List<String>.from(result?['devices'] ?? []),
      };
    } catch (_) {
      return {'connected': false, 'devices': []};
    }
  }
}
