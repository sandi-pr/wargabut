import 'package:flutter/material.dart';
import 'package:wargabut/app/ui/components/event_list_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

FirebaseFirestore firestore = FirebaseFirestore.instance;

class EventList extends StatefulWidget {
  const EventList({super.key});

  @override
  State<EventList> createState() => _EventListState();
}

class _EventListState extends State<EventList> {
  final Stream<QuerySnapshot> _eventsStream =
      FirebaseFirestore.instance.collection('jfestchart').snapshots();
  final storage = FirebaseStorage.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventsStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Convert and filter the documents based on search term
        List<DocumentSnapshot> filteredDocuments =
            snapshot.data!.docs.where((doc) {
          Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
          String eventName = data['event_name'] ?? '';
          String eventDate = data['date'] ?? '';
          String location = data['location'] ?? '';
          return eventName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              eventDate.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              location.toLowerCase().contains(_searchTerm.toLowerCase());
        }).toList();

        // Sort the filtered documents based on date
        filteredDocuments.sort((a, b) {
          DateTime dateA = _parseDate(a['date']);
          DateTime dateB = _parseDate(b['date']);
          return dateA.compareTo(dateB);
        });

        return Scaffold(
            // appBar: AppBar(
            //   title: const Text('J-EventKu'),
            // ),
            appBar: AppBar(
              title: SearchAnchor(
                  builder: (BuildContext context, SearchController controller) {
                return SearchBar(
                  shadowColor: MaterialStateColor.resolveWith(
                      (states) => Colors.transparent),
                  controller: controller,
                  padding: const MaterialStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 16.0)),
                  onTap: () {
                    // controller.openView();
                  },
                  onChanged: (value) {
                    setState(() {
                      _searchTerm = value;
                    });
                  },
                  leading: const Icon(Icons.search),
                  // trailing: <Widget>[
                  //   Tooltip(
                  //     message: 'Change brightness mode',
                  //     child: IconButton(
                  //       isSelected: isDark,
                  //       onPressed: () {
                  //         setState(() {
                  //           isDark = !isDark;
                  //         });
                  //       },
                  //       icon: const Icon(Icons.wb_sunny_outlined),
                  //       selectedIcon: const Icon(Icons.brightness_2_outlined),
                  //     ),
                  //   )
                  // ],
                );
              }, suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                return List<ListTile>.generate(5, (int index) {
                  final String item = 'item $index';
                  return ListTile(
                    title: Text(item),
                    onTap: () {
                      setState(() {
                        controller.closeView(item);
                        _searchTerm = item;
                      });
                    },
                  );
                });
              }),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (DocumentSnapshot document in filteredDocuments)
                      FutureBuilder(
                        future: _buildEventCard(document),
                        builder: (BuildContext context,
                            AsyncSnapshot<ListTileEvent> snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child:
                                    CircularProgressIndicator()); // Tambahkan indikator loading jika diperlukan
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          } else {
                            return snapshot.data!;
                          }
                        },
                      ),
                  ],
                ),
              ),
            ));
      },
    );
  }

  DateTime _parseDate(String date) {
    try {
      if (date.isEmpty) {
        return DateTime(9999, 12, 31); // Tanggal sangat jauh di masa depan
      }
      // print('Parsing date: $date'); // Log untuk memeriksa nilai tanggal
      final format = DateFormat('dd MMM yyyy', 'id_ID');
      return format.parse(date);
    } catch (e) {
      print('Error parsing date: $date, error: $e');
      return DateTime(
          9999, 12, 31); // Tanggal sangat jauh di masa depan jika ada error
    }
  }
}

Future<ListTileEvent> _buildEventCard(DocumentSnapshot document) async {
  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
  return ListTileEvent(
    eventName: data['event_name'],
    eventDate: data['date'],
    location: data['location'],
  );
}
