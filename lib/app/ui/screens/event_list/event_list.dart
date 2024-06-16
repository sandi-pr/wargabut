import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
  final storage = FirebaseStorage.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  Set<String> _selectedAreas = {};
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
  List<String> _areas = [];
  bool _isLoading = true;
  double _minWidthForTextField = 800;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      QuerySnapshot eventSnapshot = await FirebaseFirestore.instance.collection('jfestchart').get();
      QuerySnapshot areaSnapshot = await FirebaseFirestore.instance.collection('event_areas').get();

      List<DocumentSnapshot> events = eventSnapshot.docs;
      List<String> areas = areaSnapshot.docs.map((doc) => doc['area'] as String).toList();

      setState(() {
        _allEvents = events;
        _filteredEvents = events;
        _areas = areas;
        _isLoading = false;
      });
      _filterEvents();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching data: $e');
    }
  }

  void _filterEvents() {
    setState(() {
      // Filter the events based on search term and selected areas
      _filteredEvents = _allEvents.where((doc) {
        Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
        String eventName = data['event_name'] ?? '';
        String eventDate = data['date'] ?? '';
        String location = data['location'] ?? '';
        String area = data['area'] ?? '';
        bool matchesSearchTerm = eventName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
            eventDate.toLowerCase().contains(_searchTerm.toLowerCase()) ||
            location.toLowerCase().contains(_searchTerm.toLowerCase());
        bool matchesArea = _selectedAreas.isEmpty || _selectedAreas.contains(area);
        return matchesSearchTerm && matchesArea;
      }).toList();

      // Sort the filtered events based on date
      _filteredEvents.sort((a, b) {
        DateTime dateA = _parseDate(a['date']);
        DateTime dateB = _parseDate(b['date']);
        return dateA.compareTo(dateB);
      });

      // Count the number of events for each area
      Map<String, int> areaEventCount = {};
      for (var event in _allEvents) {
        String area = (event.data() as Map<String, dynamic>)['area'] ?? '';
        if (areaEventCount.containsKey(area)) {
          areaEventCount[area] = areaEventCount[area]! + 1;
        } else {
          areaEventCount[area] = 1;
        }
      }

      // Sort the areas
      _areas.sort((a, b) {
        bool isSelectedA = _selectedAreas.contains(a);
        bool isSelectedB = _selectedAreas.contains(b);
        bool isOnlineA = a.toLowerCase().contains('online');
        bool isOnlineB = b.toLowerCase().contains('online');

        // Selected areas come first
        if (isSelectedA && !isSelectedB) return -1;
        if (!isSelectedA && isSelectedB) return 1;

        // Online areas come last
        if (!isOnlineA && isOnlineB) return -1;
        if (isOnlineA && !isOnlineB) return 1;

        // Sort by number of events
        int countA = areaEventCount[a] ?? 0;
        int countB = areaEventCount[b] ?? 0;
        return countB.compareTo(countA);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width > _minWidthForTextField;

    return Scaffold(
        // appBar: AppBar(
        //   title: const Text('J-EventKu'),
        // ),
        appBar: AppBar(
          title: isWideScreen
              ? TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Cari event...',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchTerm = value;
                      _filterEvents();
                    });
                  },
                )
              : SearchAnchor(
                  builder: (BuildContext context, SearchController controller) {
                    return SearchBar(
                      // hintText: 'Cari event...',
                      shadowColor: MaterialStateColor.resolveWith((states) => Colors.transparent),
                      controller: controller,
                      padding: const MaterialStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(horizontal: 16.0)),
                      onTap: () {},
                      onChanged: (value) {
                        setState(() {
                          _searchTerm = value;
                          _filterEvents();
                        });
                      },
                      leading: const Icon(Icons.search),
                    );
                  },
                  suggestionsBuilder: (BuildContext context, SearchController controller) {
                    return List<ListTile>.generate(5, (int index) {
                      final String item = 'item $index';
                      return ListTile(
                        title: Text(item),
                        onTap: () {
                          setState(() {
                            controller.closeView(item);
                            _searchTerm = item;
                            _filterEvents();
                          });
                        },
                      );
                    });
                  },
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Row(
                        children: _areas.map((area) {
                          return Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ChoiceChip(
                              label: Text(area),
                              selected: _selectedAreas.contains(area),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedAreas.add(area);
                                  } else {
                                    _selectedAreas.remove(area);
                                  }
                                  _filterEvents();
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: isWideScreen
                            ? GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16.0,
                                  mainAxisSpacing: 16.0,
                                  childAspectRatio: 4 / 2,
                                ),
                                itemCount: _filteredEvents.length,
                                shrinkWrap: true,
                                itemBuilder: (BuildContext context, int index) {
                                  DocumentSnapshot document = _filteredEvents[index];
                                  return FutureBuilder(
                                    future: _buildEventCard(document),
                                    builder: (BuildContext context,
                                        AsyncSnapshot<ListTileEvent> snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(
                                            child:
                                                CircularProgressIndicator()); // Tambahkan indikator loading jika diperlukan
                                      } else if (snapshot.hasError) {
                                        return Text('Error: ${snapshot.error}');
                                      } else {
                                        return snapshot.data!;
                                      }
                                    },
                                  );
                                },
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (DocumentSnapshot document in _filteredEvents)
                                    FutureBuilder(
                                      future: _buildEventCard(document),
                                      builder: (BuildContext context,
                                          AsyncSnapshot<ListTileEvent> snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
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
                    ),
                  ),
                ],
              ));
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
      return DateTime(9999, 12, 31); // Tanggal sangat jauh di masa depan jika ada error
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
}
