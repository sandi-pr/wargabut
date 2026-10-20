import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localstorage/localstorage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wargabut/app/provider/event_provider.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String formatImageName(String eventName) {
    // print('Event name: $eventName');
    // Menghapus spasi dan karakter khusus
    String formattedName = eventName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    // Mengubah ke huruf kecil
    formattedName = formattedName.toLowerCase();
    // Menambahkan ekstensi .jpg
    formattedName = '$formattedName.jpg';
    return formattedName;
  }

  Future<String?> uploadImage(XFile? imageFile, String menu, String eventName) async {
    if (imageFile == null) return null;

    try {
      // Format nama gambar
      String imageName = formatImageName(eventName);
      print('Image name: $imageName');
      Reference ref = _storage.ref().child('$menu/$imageName');

      if (kIsWeb) {
        // Web
        Uint8List bytes = await imageFile.readAsBytes();
        await ref.putData(bytes);
      } else {
        // Android/iOS
        File file = File(imageFile.path);
        await ref.putFile(file);
      }

      String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> uploadImages(List<XFile> images, String menu, String eventName) async {
    List<Map<String, dynamic>> posterList = [];

    for (int i = 0; i < images.length; i++) {
      XFile imageFile = images[i];
      String originalFileName = kIsWeb
          ? imageFile.name
          : imageFile.path.split('/').last;

      // Format nama yang akan di-upload
      String imageName = originalFileName;
      print('Image name: $imageName');
      Reference ref = _storage.ref().child('$menu/$imageName');

      try {
        if (kIsWeb) {
          Uint8List bytes = await imageFile.readAsBytes();
          await ref.putData(bytes);
        } else {
          File file = File(imageFile.path);
          await ref.putFile(file);
        }

        String downloadURL = await ref.getDownloadURL();
        posterList.add({
          "url": downloadURL,
          "path": "$menu/$imageName",
          "is_main": false,
          "order": i + 1
        });

      } catch (e) {
        print('Error uploading image: $e');
      }
    }

    return posterList;
  }

  Future<String?> getImageUrl(String menu, String eventName) async {
    try {
      String imageName = formatImageName(eventName);
      Reference ref = _storage.ref().child('$menu/$imageName');
      String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Error getting image URL: $e');
      return null;
    }
  }

  Future<Uint8List?> getCachedImage(String eventName) async {
    String imageName = formatImageName(eventName);
    if (kIsWeb) {
      // Web
      await initLocalStorage();
      final cachedData = localStorage.getItem(imageName);
      if (cachedData != null) {
        return Uint8List.fromList(cachedData.codeUnits);
      }
    } else {
      // Android/iOS
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$imageName');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }
    return null;
  }

  Future<void> cacheImage(String eventName, Uint8List bytes) async {
    String imageName = formatImageName(eventName);
    if (kIsWeb) {
      // Web
      print('Cached image: $imageName');
      await initLocalStorage();
      print('Success init localStorage');
      localStorage.setItem(imageName, String.fromCharCodes(bytes));
      print('Success set localStorage');
      // html.window.localStorage[imageName] = String.fromCharCodes(bytes);
    } else {
      // Android/iOS
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$imageName');
      await file.writeAsBytes(bytes);
    }
  }

  Future<void> deletePoster(
    BuildContext context,
    int index,
    String menu,
    String eventId, {
    Map<String, dynamic>? targetPoster,
  }) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String documentId = eventId;
      DocumentSnapshot doc = await firestore.collection(menu).doc(documentId).get();

      if (doc.exists) {
        List<dynamic> posters = List.from(doc['posters'] ?? []);
        Map<String, dynamic>? removedPoster;

        // 1. Prioritaskan pencarian berdasarkan targetPoster (path atau url)
        if (targetPoster != null) {
          final targetPath = targetPoster['path']?.toString();
          final targetUrl = targetPoster['url']?.toString();
          final idx = posters.indexWhere((item) =>
              (targetPath != null && item['path'] == targetPath) ||
              (targetUrl != null && item['url'] == targetUrl));
          if (idx != -1) {
            removedPoster = Map<String, dynamic>.from(posters.removeAt(idx));
          }
        }

        // 2. Fallback menggunakan index jika valid
        if (removedPoster == null && index >= 0 && index < posters.length) {
          removedPoster = Map<String, dynamic>.from(posters.removeAt(index));
        }

        if (removedPoster == null) {
          print('Poster to delete not found in document (index: $index, target: $targetPoster)');
          return;
        }

        // Hapus file dari Firebase Storage jika ada path valid
        try {
          final path = removedPoster['path']?.toString();
          if (path != null && path.isNotEmpty && !path.startsWith('http')) {
            Reference ref = _storage.ref().child(path);
            await ref.delete();
          }
        } catch (e) {
          print('Storage file delete error (non-critical): $e');
        }

        // Jika poster yang dihapus adalah utama, set poster pertama yang tersisa sebagai utama
        if (removedPoster['is_main'] == true && posters.isNotEmpty) {
          posters.first['is_main'] = true;
        }

        // Re-normalize order setelah penghapusan
        for (int i = 0; i < posters.length; i++) {
          posters[i]['order'] = i;
        }

        await firestore.collection(menu).doc(documentId).update({
          'posters': posters,
          'is_postered': posters.isNotEmpty,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Poster berhasil dihapus')),
          );
        }
      }
    } catch (e) {
      print('Error deleting poster: $e');
    }
  }
}