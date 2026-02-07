import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/provider/konser_provider.dart';
import 'package:wargabut/app/services/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class CreateKonserPage extends StatefulWidget {
  const CreateKonserPage({super.key});

  @override
  State<CreateKonserPage> createState() => _CreateKonserPageState();
}

class _CreateKonserPageState extends State<CreateKonserPage> {
  final _eventNameController = TextEditingController();
  final _dateEventController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketPriceController = TextEditingController();

  String _htmType = 'free';

  final List<Map<String, dynamic>> _rundownList = [];

  List<Map<String, dynamic>> guestStars = [];
  String? selectedGuestStarId;

  bool _isMedpart = false;

  File? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  XFile? _imageFile;
  String? _downloadURL;

  @override
  void initState() {
    super.initState();
    getGuestStars();
    _addRundown(); // mulai dengan 1 rundown
  }

  void _addRundown() {
    setState(() {
      _rundownList.add({
        'time': null,
        'activity': '',
        'guestId': ''
      });
      selectedGuestStarId = null;
    });
  }

  void _removeRundown(int index) {
    setState(() {
      _rundownList.removeAt(index);
    });
  }

  Future<void> getGuestStars() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('guestStars')
        .get();

    setState(() {
      guestStars = snapshot.docs.map((doc) {
        return {
          'guestId': doc['guestId'],
          'name': doc['name'] ?? '',
        };
      }).toList();

      print('Guest Stars: $guestStars');
    });
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _dateController.text = DateFormat('dd MMM yyyy').format(picked);
    }
  }

  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _rundownList[index]['time'] = formatTimeOfDay(picked);
      });
    }
  }

  String formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  List<Map<String, dynamic>> newPosters = [];

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Uint8List imageBytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = imageBytes;
      });
    }
  }

  Future<void> _uploadImage(String eventName) async {
    if (_imageFile == null) return;
    String? url = await _storageService.uploadImage(_imageFile, 'dkonser', eventName);
    setState(() {
      _downloadURL = url;
    });
  }

  Future<void> _uploadImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? selectedImages = await picker.pickMultiImage();

    if (selectedImages != null && selectedImages.isNotEmpty) {
      List<Map<String, dynamic>> uploadedPosters =
          await _storageService.uploadImages(
        selectedImages,
        'dkonser',
        _eventNameController.text,
      );

      uploadedPosters[0]['is_main'] = true;

      print("poster: $uploadedPosters");

      setState(() {
        newPosters.addAll(uploadedPosters);
      });
    }
  }

  Future<void> _addPostersToFirestore(
      String eventId, List<Map<String, dynamic>> posters) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore.collection('dfestkonser').doc(eventId).update({
      'posters': posters,
      'is_postered': posters.isNotEmpty,
    });
  }

  String _createSlugFromName(String name) {
    // 1. Ubah ke huruf kecil
    String slug = name.toLowerCase();

    // 2. Hapus karakter spesial selain huruf, angka, dan spasi
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');

    // 3. Ganti spasi dengan tanda hubung (-)
    slug = slug.replaceAll(RegExp(r'\s+'), '-');

    // 4. Hapus tanda hubung berlebih di awal atau akhir
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');

    // 5. Batasi panjang slug jika perlu (opsional, tapi baik untuk performa)
    if (slug.length > 100) {
      slug = slug.substring(0, 100);
    }

    return slug;
  }

  Future<void> _saveEventToFirestore(BuildContext context) async {
    final eventProvider = Provider.of<KonserProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Pastikan nama event tidak kosong
    if (_eventNameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nama festival tidak boleh kosong!')),
      );
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      String eventName = _eventNameController.text;

      // 1. Buat 'slug' dari nama event menggunakan fungsi yang kita buat
      String eventIdSlug = _createSlugFromName(eventName);

      // 2. Tentukan DocumentReference dengan slug kustom
      DocumentReference eventRef = firestore.collection('dfestkonser').doc(eventIdSlug);

      // 3. (SANGAT PENTING) Cek apakah dokumen dengan ID ini sudah ada
      final docSnapshot = await eventRef.get();
      if (docSnapshot.exists) {
        // Jika sudah ada, beri peringatan dan batalkan penyimpanan
        messenger.showSnackBar(
          const SnackBar(content: Text('Gagal: Festival dengan nama yang mirip sudah ada! Coba ganti nama festival.')),
        );
        return; // Hentikan fungsi
      }

      // Jika belum ada, lanjutkan penyimpanan
      String? imageUrl;
      if (_imageFile != null) {
        await _uploadImage(eventName);
        imageUrl = _downloadURL;
      }

      // 4. Gunakan .set() untuk menyimpan data dengan ID kustom
      await eventRef.set({
        'event_name': eventName,
        'date': _dateEventController.text,
        'area': _areaController.text,
        'location': _locationController.text,
        'desc': _descriptionController.text,
        'ticket_price': _htmType == 'free' ? 'Gratis' : _ticketPriceController.text,
        'is_postered': imageUrl != null,
        'posters': [],
        'is_medpart': _isMedpart,
        'rundown': _rundownList,
      });

      // Jika ada poster yang diunggah, tambahkan ke Firestore
      if (newPosters.isNotEmpty) {
        await _addPostersToFirestore(eventRef.id, newPosters);
      }

      if (!mounted) return;

      await eventProvider.fetchData(forceRefresh: true);

      messenger.showSnackBar(
        const SnackBar(content: Text('Festival berhasil dibuat!')),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      print('Gagal menambahkan festival: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menambahkan festival: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Festival'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _saveEventToFirestore(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaQuery.of(context).size.width < 720
                ? Column(
                    children: [
                      Text("Detail Festival", style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8.0),
                      TextField(
                        controller: _eventNameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Nama Festival',
                          hintText: 'Masukkan nama festival',
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _dateEventController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Tanggal',
                          hintText: 'Masukkan tanggal festival',
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _areaController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Area',
                          hintText: 'Masukkan area festival',
                          helperText: 'Contoh: Jakarta, Surabaya, Bandung (wilayah umum)',
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Lokasi',
                          hintText: 'Masukkan lokasi festival',
                          helperText: 'Contoh: JIEXPO Kemayoran, ICE BSD (nama venue)',
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      DropdownButtonFormField<String>(
                        value: _htmType,
                        decoration: const InputDecoration(
                          labelText: 'HTM',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'free', child: Text('Gratis')),
                          DropdownMenuItem(value: 'paid', child: Text('Berbayar')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _htmType = value!;
                            if (_htmType == 'free') {
                              _ticketPriceController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Muncul hanya jika HTM "berbayar"
                      if (_htmType == 'paid')
                        TextField(
                          controller: _ticketPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Harga Tiket (Rp)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi',
                          hintText: 'Masukkan deskripsi festival',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                      ),

                      const SizedBox(height: 16.0),

                      const SizedBox(height: 16.0),
                      Row(
                        children: [
                          const Text('Medpart'),
                          Switch(
                            value: _isMedpart,
                            onChanged: (value) {
                              setState(() {
                                _isMedpart = value;
                              });
                            },
                          ),
                        ],
                      ),

                      // Tombol Pilih Gambar
                      ElevatedButton.icon(
                        onPressed: _uploadImages,
                        icon: const Icon(Icons.image),
                        label: const Text('Tambah Poster Baru'),
                      ),

                      const SizedBox(height: 16.0),

                      // Preview poster sebelum disimpan ke Firestore
                      if (newPosters.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: newPosters.length,
                          itemBuilder: (context, index) {
                            final poster = newPosters[index];

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      poster['url'],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          poster['path'].split('/').last,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 28),
                                    onPressed: () {
                                      setState(() {
                                        newPosters.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 24.0),
                      // Section Rundown Event
                      // Text("Rundown Event",
                      //     style: Theme.of(context).textTheme.headlineSmall),
                      // const SizedBox(height: 8.0),
                      // ..._rundownList.asMap().entries.map((entry) {
                      //   int index = entry.key;
                      //   Map<String, dynamic> rundown = entry.value;
                      //   return Card(
                      //     margin: const EdgeInsets.symmetric(vertical: 5),
                      //     child: Padding(
                      //       padding: const EdgeInsets.all(8.0),
                      //       child: Column(
                      //         children: [
                      //           Row(
                      //             children: [
                      //               Expanded(
                      //                 child: InkWell(
                      //                   onTap: () => _pickTime(index),
                      //                   child: InputDecorator(
                      //                     decoration: const InputDecoration(
                      //                       labelText: "Waktu",
                      //                       border: OutlineInputBorder(),
                      //                     ),
                      //                     child: Text(
                      //                       rundown['time'] != null && rundown['time'].toString().isNotEmpty
                      //                           ? rundown['time']
                      //                           : 'Pilih Waktu',
                      //                     ),
                      //                   ),
                      //                 ),
                      //               ),
                      //               const SizedBox(width: 8),
                      //               Expanded(
                      //                 flex: 2,
                      //                 child: TextFormField(
                      //                   decoration: const InputDecoration(
                      //                     labelText: 'Nama Aktivitas',
                      //                     border: OutlineInputBorder(),
                      //                   ),
                      //                   onChanged: (val) {
                      //                     _rundownList[index]['activity'] = val;
                      //                   },
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //           const SizedBox(height: 8),
                      //           Row(
                      //             children: [
                      //               Expanded(
                      //                 child: DropdownButtonFormField<String>(
                      //                   value: _rundownList[index]['guestId'] != '' &&
                      //                       guestStars.any((guest) => guest['guestId'] == _rundownList[index]['guestId'])
                      //                       ? _rundownList[index]['guestId']
                      //                       : null,
                      //                   decoration: const InputDecoration(
                      //                     labelText: 'Guest Star',
                      //                     border: OutlineInputBorder(),
                      //                   ),
                      //                   items: guestStars.map((guest) {
                      //                     return DropdownMenuItem<String>(
                      //                       value: guest['guestId'] as String,
                      //                       child: Text(guest['name'] as String),
                      //                     );
                      //                   }).toList(),
                      //                   onChanged: (value) {
                      //                     setState(() {
                      //                       selectedGuestStarId = value;
                      //                       _rundownList[index]['guestId'] = selectedGuestStarId; // simpan ID ke rundown
                      //                     });
                      //                   },
                      //                 ),
                      //               ),
                      //               IconButton(
                      //                 icon: const Icon(Icons.delete, color: Colors.red),
                      //                 onPressed: () => _removeRundown(index),
                      //               ),
                      //             ],
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   );
                      // }),
                      // TextButton.icon(
                      //   icon: const Icon(Icons.add),
                      //   label: const Text("Tambah Rundown"),
                      //   onPressed: _addRundown,
                      // ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kolom Kiri: Form Event
                      Expanded(
                        flex: 3, // Lebih lebar dibanding daftar poster
                        child: Column(
                          children: [
                            TextField(
                              controller: _eventNameController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Nama Festival',
                                hintText: 'Masukkan nama festival',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            TextField(
                              controller: _dateEventController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Tanggal',
                                hintText: 'Masukkan tanggal festival',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            TextField(
                              controller: _areaController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Area',
                                hintText: 'Masukkan area festival',
                                helperText: 'Contoh: Jakarta, Surabaya, Bandung (wilayah umum)',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Lokasi',
                                hintText: 'Masukkan lokasi festival',
                                helperText: 'Contoh: JIEXPO Kemayoran, ICE BSD (nama venue)',
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            DropdownButtonFormField<String>(
                              value: _htmType,
                              decoration: const InputDecoration(
                                labelText: 'HTM',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'free', child: Text('Gratis')),
                                DropdownMenuItem(value: 'paid', child: Text('Berbayar')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _htmType = value!;
                                  if (_htmType == 'free') {
                                    _ticketPriceController.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // 🔹 Muncul hanya jika HTM "berbayar"
                            if (_htmType == 'paid')
                              TextField(
                                controller: _ticketPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Harga Tiket (Rp)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Deskripsi',
                                hintText: 'Masukkan deskripsi festival',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                              keyboardType: TextInputType.multiline,
                            ),
                            const SizedBox(height: 16.0),
                            Row(
                              children: [
                                const Text('Medpart'),
                                Switch(
                                  value: _isMedpart,
                                  onChanged: (value) {
                                    setState(() {
                                      _isMedpart = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16.0),

                      // Kolom Kanan: Tombol Tambah Poster + List Poster
                      Expanded(
                        flex: 2, // Lebih kecil dari form
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tombol Pilih Gambar
                            ElevatedButton.icon(
                              onPressed: _uploadImages,
                              icon: const Icon(Icons.image),
                              label: const Text('Tambah Poster Baru'),
                            ),

                            const SizedBox(height: 16.0),

                            // Preview poster sebelum disimpan ke Firestore
                            if (newPosters.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: newPosters.length,
                                itemBuilder: (context, index) {
                                  final poster = newPosters[index];

                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            poster['url'],
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                poster['path'].split('/').last,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                newPosters[index]['is_main']
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: newPosters[index]
                                                        ['is_main']
                                                    ? Colors.amber
                                                    : Colors.grey,
                                                size: 32,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  for (var poster
                                                      in newPosters) {
                                                    poster['is_main'] = false;
                                                  }
                                                  newPosters[index]['is_main'] =
                                                      true;
                                                });
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red, size: 28),
                                              onPressed: () {
                                                setState(() {
                                                  newPosters.removeAt(index);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
          ],
        ),
      ),
    );
  }
}
