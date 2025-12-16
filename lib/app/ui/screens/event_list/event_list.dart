import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wargabut/app/provider/event_provider.dart';
import 'package:wargabut/app/ui/components/event_list_tile.dart';
import 'package:wargabut/app/ui/components/drawer/app_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:wargabut/main.dart';

import '../../../provider/theme_provider.dart';

FirebaseFirestore firestore = FirebaseFirestore.instance;

class EventList extends StatefulWidget {
  const EventList({super.key});

  @override
  State<EventList> createState() => _EventListState();
}

class _EventListState extends State<EventList> {
  final storage = FirebaseStorage.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final _key = GlobalKey<ExpandableFabState>();
  final String _searchTerm = '';
  final Set<String> _selectedAreas = {};
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  List<EventListTile> _filteredEventCards = [];
  List<String> _areas = [];
  bool _isLoading = true;
  final double _minWidthForTextField = 800;
  bool _isLogin = false;
  List<Map<String, dynamic>> _eventCards = [];

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('EventList initState');
    }
    _checkLoginStatus();
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    eventProvider.fetchData();
    _searchController.addListener(() {
      if (kDebugMode) {
        print(
            'EventList _searchController.addListener: _searchController.text = ${_searchController.text}');
      }
      eventProvider.setSearchTerm(_searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      eventProvider.addListener(() {
        if (_searchController.text != eventProvider.searchTerm) {
          if (kDebugMode) {
            print(
                'EventList eventProvider.addListener: _searchController.text = ${_searchController.text}, eventProvider.searchTerm = ${eventProvider.searchTerm}');
          }
          _searchController.text = eventProvider.searchTerm;
        }
      });
    });
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
        if (kDebugMode) {
          print("User is logged in");
        }
        DocumentSnapshot? userDoc =
            await fireStore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          prefs.setBool('isAdmin', false);
          if (kDebugMode) {
            print("User is not admin");
          }
          return;
        } else {
          prefs.setBool('isAdmin', true);
          if (kDebugMode) {
            print("User is admin");
          }
        }
      } else {
        prefs.setBool('isLoggedIn', false);
        prefs.setBool('isAdmin', false);
        _isLogin = false;
        print("User is not logged in");
      }
    });
  }

  Future<void> _loadEventCards() async {
    // Get a reference to the Firestore collection
    CollectionReference eventsCollection = firestore.collection('events');

    // Get the documents from the collection
    QuerySnapshot querySnapshot = await eventsCollection.get();

    // Extract the data from the documents
    List<Map<String, dynamic>> events = querySnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // Update the state with the fetched events
    Provider.of<EventProvider>(context, listen: false).setAllEvents(events);
  }

  void _filterEvents() {
    setState(() {
      // Filter the events based on search term and selected areas
      _filteredEvents = _allEvents.where((event) {
        String eventName = event['event_name'] ?? '';
        String eventDate = event['date'] ?? '';
        String location = event['location'] ?? '';
        String area = event['area'] ?? '';
        bool matchesSearchTerm =
            eventName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
                eventDate.toLowerCase().contains(_searchTerm.toLowerCase()) ||
                location.toLowerCase().contains(_searchTerm.toLowerCase());
        bool matchesArea =
            _selectedAreas.isEmpty || _selectedAreas.contains(area);
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
        String area = event['area'] ?? '';
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
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('EventList build');
    }
    bool isWideScreen =
        MediaQuery.of(context).size.width > _minWidthForTextField;
    final themeProvider = context.watch<ThemeProvider>();
    final eventProvider = context.watch<EventProvider>();
    final areas = eventProvider.areas;
    final selectedAreas = eventProvider.selectedAreas;
    final filteredEvents = eventProvider.filteredEvents;
    final isLoading = eventProvider.isLoading;
    if (kDebugMode) {
      print(
          'EventList build: _searchController.text = ${_searchController.text}, eventProvider.searchTerm = ${eventProvider.searchTerm}');
    }
    // _searchController.text = eventProvider.searchTerm;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0.0,
        title: isWideScreen
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari event...',
                ),
                onSubmitted: (value) {
                  eventProvider.setSearchTerm(value);
                },
              )
            : Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  // hintText: 'Cari event...',
                  shadowColor: WidgetStateColor.resolveWith(
                      (states) => Colors.transparent),
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.only(right: 16.0, left: 12.0)),
                  onSubmitted: (value) {
                    eventProvider.setSearchTerm(value);
                  },
                  onTapOutside: (_) {
                    _searchFocusNode.unfocus();
                  },
                  leading: const Icon(Icons.search),
                  trailing: <Widget>[
                    _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              eventProvider.setSearchTerm('');
                            },
                          )
                        : Tooltip(
                            message: 'Ubah tema',
                            child: IconButton(
                              isSelected: themeProvider.isDark,
                              onPressed: themeProvider.toggleTheme,
                              icon: const Icon(Icons.wb_sunny_outlined),
                              selectedIcon:
                                  const Icon(Icons.brightness_2_outlined),
                            ),
                          )
                  ],
                ),
              ),
      ),
      floatingActionButton: _isLogin
          ? FloatingActionButton(
              onPressed: () {
                eventProvider.fetchData(forceRefresh: true);
              },
              child: const Icon(Icons.refresh),
            )
          : null,
      // floatingActionButtonLocation: ExpandableFab.location,
      // floatingActionButton: _isLogin ? ExpandableFab(
      //   key: _key,
      //   type: ExpandableFabType.up,
      //   childrenAnimation: ExpandableFabAnimation.none,
      //   distance: 70,
      //   overlayStyle: ExpandableFabOverlayStyle(
      //     color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
      //   ),
      //   openButtonBuilder: RotateFloatingActionButtonBuilder(
      //     child: const Icon(Icons.edit),
      //   ),
      //   children: const [
      //     Row(
      //       children: [
      //         Text('Refresh'),
      //         SizedBox(width: 16),
      //         FloatingActionButton.small(
      //           heroTag: null,
      //           onPressed: null,
      //           child: Icon(Icons.refresh),
      //         ),
      //       ],
      //     ),
      //     Row(
      //       children: [
      //         Text('Add Event'),
      //         SizedBox(width: 16),
      //         FloatingActionButton.small(
      //           heroTag: null,
      //           onPressed: null,
      //           child: Icon(Icons.add),
      //         ),
      //       ],
      //     ),
      //   ],
      // ) : null,
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
                      image: AssetImage('assets/images/Jventku_banner_clear.png'),
                      fit: BoxFit.cover,
                    )),
                child: SizedBox.shrink(),
              ),
            ),
            ListTile(
              title: const Text('Jventku'),
              subtitle: Text(
                'Media event Jejepangan',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              selected: _selectedIndex == 0,
              onTap: () {
                // Update the state of the app
                // _onItemTapped(0);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            // ListTile(
            //   title: const Text('Impactnation'),
            //   selected: _selectedIndex == 1,
            //   onTap: () {
            //     // Update the state of the app
            //     _onItemTapped(1);
            //     // Then close the drawer
            //     Navigator.pushNamed(context, '/impactnation');
            //   },
            // ),
            const Spacer(),
            _isLogin
                ? ListTile(
              title: const Text('Logout'),
              trailing: const Icon(Icons.logout),
              onTap: () {
                FirebaseAuth.instance.signOut();
                setState(() {
                  _isLogin = false;
                });
              },
            )
                : ListTile(
              title: const Text('Login Admin'),
              trailing: const Icon(Icons.login),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignInScreen(
                      showAuthActionSwitch: false,
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Row(
                      children: areas.map((area) {
                        return Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ChoiceChip(
                            label: Text(area),
                            selected: selectedAreas.contains(area),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  eventProvider.setSelectedAreas(
                                      [...selectedAreas, area]);
                                  print(eventProvider.selectedAreas);
                                } else {
                                  eventProvider.setSelectedAreas(selectedAreas
                                      .where((element) => element != area)
                                      .toList());
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                isWideScreen
                    ? Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 4 / 2,
                          ),
                          itemCount: filteredEvents.length,
                          shrinkWrap: true,
                          itemBuilder: (BuildContext context, int index) {
                            final event = filteredEvents[index];
                            return EventListTile(data: event);
                          },
                        ),
                      )
                    : Expanded(
                        child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredEvents.length,
                          itemBuilder: (BuildContext context, int index) {
                            final event = filteredEvents[index];
                            return EventListTile(data: event);
                          },
                        ),
                      )),
              ],
            ),
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
