import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
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

  Future<String?> uploadImage(XFile? imageFile, String eventName) async {
    if (imageFile == null) return null;

    try {
      // Format nama gambar
      String imageName = formatImageName(eventName);
      print('Image name: $imageName');
      Reference ref = _storage.ref().child('jfestchart/$imageName');

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

  Future<List<Map<String, dynamic>>> uploadImages(List<XFile> images, String eventName) async {
    List<Map<String, dynamic>> posterList = [];

    for (int i = 0; i < images.length; i++) {
      XFile imageFile = images[i];
      String originalFileName = kIsWeb
          ? imageFile.name
          : imageFile.path.split('/').last;

      // Format nama yang akan di-upload
      String imageName = originalFileName;
      print('Image name: $imageName');
      Reference ref = _storage.ref().child('jfestchart/$imageName');

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
          "path": "jfestchart/$imageName",
          "is_main": false,
          "order": i + 1
        });

      } catch (e) {
        print('Error uploading image: $e');
      }
    }

    return posterList;
  }

  Future<String?> getImageUrl(String eventName) async {
    try {
      String imageName = formatImageName(eventName);
      Reference ref = _storage.ref().child('jfestchart/$imageName');
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

  Future<void> deletePoster(BuildContext context, int index, String eventId) async {
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String documentId = eventId;
      DocumentSnapshot doc = await firestore.collection('jfestchart').doc(documentId).get();

      if (doc.exists) {
        List<dynamic> posters = List.from(doc['posters']);
        Map<String, dynamic> removedPoster = posters.removeAt(index);

        // Hapus file dari Firebase Storage
        Reference ref = _storage.ref().child(removedPoster['path']);
        await ref.delete();

        // Jika poster yang dihapus adalah utama, set poster lain sebagai utama
        if (removedPoster['is_main'] && posters.isNotEmpty) {
          posters.first['is_main'] = true;
        }

        await firestore.collection('jfestchart').doc(documentId).update({
          'posters': posters,
          'is_postered': posters.isNotEmpty,
        });
      }
    } catch (e) {
      print('Error deleting poster: $e');
    }
  }
}