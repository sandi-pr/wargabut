import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/ui/components/event_list_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';

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
  final Set<String> _selectedAreas = {};
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
  List<ListTileEvent> _allEventCards = []; // Data asli
  List<ListTileEvent> _filteredEventCards = []; // Data yang difilter
  List<String> _areas = [];
  bool _isLoading = true;
  final double _minWidthForTextField = 800;
  bool _isAdmin = false;
  bool _isLogin = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    if (_isLogin) {
      return;
    }
    final FirebaseFirestore fireStore = FirebaseFirestore.instance;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // FirebaseAuth.instance.signOut();
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        prefs.setBool('isLoggedIn', true);
        _isLogin = true;
        print("User is logged in");
        DocumentSnapshot? userDoc = await fireStore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          prefs.setBool('isAdmin', false);
          _isAdmin = false;
          print("User is not admin");
          return;
        } else {
          prefs.setBool('isAdmin', true);
          _isAdmin = true;
          print("User is admin");
        }
      } else {
        prefs.setBool('isLoggedIn', false);
        _isLogin = false;
        print("User is not logged in");
      }
    });
  }

  Future<void> _fetchData() async {
    try {
      QuerySnapshot eventSnapshot = await FirebaseFirestore.instance.collection('jfestchart').get();
      QuerySnapshot areaSnapshot = await FirebaseFirestore.instance.collection('event_areas').get();

      List<DocumentSnapshot> events = eventSnapshot.docs;
      List<String> areas = areaSnapshot.docs.map((doc) => doc['area'] as String).toList();

      setState(() {
        _allEvents = events;
        // _filteredEvents = events;
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

  Future<void> _loadEventCards() async {
    try {
      List<ListTileEvent> loadedEventCards = [];
      for (DocumentSnapshot document in _filteredEvents) {
        Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
        loadedEventCards.add(
          ListTileEvent(
            eventName: data['event_name'],
            eventDate: data['date'],
            location: data['location'],
            desc: data['desc'],
          ),
        );
      }

      setState(() {
        _filteredEventCards = loadedEventCards; // Inisialisasi data filter dengan semua data
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
    
    _loadEventCards();
  }

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
          titleSpacing: 0.0,
          title: isWideScreen
              ? TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Cari event...',
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _searchTerm = value;
                      _filterEvents();
                    });
                  },
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: SearchBar(
                    // hintText: 'Cari event...',
                    shadowColor: WidgetStateColor.resolveWith((states) => Colors.transparent),
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.only(right: 16.0, left: 12.0)),
                    onSubmitted: (value) {
                      setState(() {
                        _searchTerm = value;
                        _filterEvents();
                      });
                    },
                    // leading: const Icon(Icons.search),
                    trailing: const <Widget>[
                      Icon(Icons.search),
                    ],
                  ),
                ),
        ),
        drawer: Drawer(
          // Add a ListView to the drawer. This ensures the user can scroll
          // through the options in the drawer if there isn't enough vertical
          // space to fit everything.
          child: Column(
            // Important: Remove any padding from the ListView.
            children: [
              const SizedBox(
                height: 140,
                width: double.infinity,
                child: DrawerHeader(
                  decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/J-EventKu_Banner.png'),
                        fit: BoxFit.cover,
                      )),
                  child: SizedBox.shrink(),
                ),
              ),
              ListTile(
                title: const Text('List Event'),
                selected: _selectedIndex == 0,
                onTap: () {
                  // Update the state of the app
                  // _onItemTapped(0);
                  // Then close the drawer
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Impactnation'),
                selected: _selectedIndex == 1,
                onTap: () {
                  // Update the state of the app
                  _onItemTapped(1);
                  // Then close the drawer
                  Navigator.pushNamed(context, '/impactnation');
                },
              ),
              const Spacer(),
              _isLogin ? ListTile(
                title: const Text('Logout'),
                trailing: const Icon(Icons.logout),
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  setState(() {
                    _isLogin = false;
                  });
                },
              ) :
              ListTile(
                title: const Text('Login'),
                trailing: const Icon(Icons.login),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SignInScreen(
                        // showAuthActionSwitch: false,
                        actions: [
                          AuthStateChangeAction<SignedIn>((context, state) {
                            setState(() {
                              _isLogin = true;
                            });
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          }),
                        ],
                        providers: [
                          EmailAuthProvider(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedIndex == 0
                ? Column(
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
                      isWideScreen
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
                          : Expanded(
                              child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredEventCards.length,
                                itemBuilder: (BuildContext context, int index) {
                                  return _filteredEventCards[index];
                                },
                              ),
                            )),
                    ],
                  )
                : const SizedBox());
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
      desc: data['desc'],
    );
  }
}
