import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:wargabut/app/ui/components/impacnation/poster_card.dart';

FirebaseFirestore firestore = FirebaseFirestore.instance;

class PosterList extends StatefulWidget {
  const PosterList({super.key});

  @override
  State<PosterList> createState() => _PosterListState();
}

class _PosterListState extends State<PosterList> {
  final storage = FirebaseStorage.instance;
  List<DocumentSnapshot> _allPosters = [];
  bool _isLoading = true;
  final double _minWidthForTextField = 800;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      QuerySnapshot eventSnapshot =
          await FirebaseFirestore.instance.collection('impacnation').orderBy('index').get();
      List<DocumentSnapshot> events = eventSnapshot.docs;

      setState(() {
        _allPosters = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _selectedIndex = 1;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width > _minWidthForTextField;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Impactnation Japan Festival 2024'),
        ),
        drawer: Drawer(
          // Add a ListView to the drawer. This ensures the user can scroll
          // through the options in the drawer if there isn't enough vertical
          // space to fit everything.
          child: ListView(
            // Important: Remove any padding from the ListView.
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(
                height: 140,
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
                  _onItemTapped(0);
                  // Then close the drawer
                  Navigator.pushNamed(context, '/event_list');
                },
              ),
              ListTile(
                title: const Text('Impactnation'),
                selected: _selectedIndex == 1,
                onTap: () {
                  // Update the state of the app
                  // _onItemTapped(1);
                  // Then close the drawer
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  isWideScreen
                      ? GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 4 / 2,
                          ),
                          itemCount: _allPosters.length,
                          shrinkWrap: true,
                          itemBuilder: (BuildContext context, int index) {
                            DocumentSnapshot document = _allPosters[index];
                            return FutureBuilder(
                              future: _buildEventCard(document),
                              builder: (BuildContext context, AsyncSnapshot<PosterCard> snapshot) {
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
                            itemCount: _allPosters.length,
                            itemBuilder: (BuildContext context, int index) {
                              DocumentSnapshot document = _allPosters[index];
                              return FutureBuilder(
                                future: _buildEventCard(document),
                                builder:
                                    (BuildContext context, AsyncSnapshot<PosterCard> snapshot) {
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
                          ),
                        )),
                ],
              ));
  }

  Future<PosterCard> _buildEventCard(DocumentSnapshot document) async {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
    // Ambil nilai pertama dari array event_poster
    List<dynamic> eventPosterArray = data['images'] ?? [];
    String baseUrl = 'https://is3.cloudhost.id/jeventku/impacnation';
    List<String> posterUrls = eventPosterArray.map((poster) => '$baseUrl/$poster').toList();

    // List<String> posterUrls = [];
    // for (var poster in eventPosterArray) {
    //   String posterUrl = await FirebaseStorage.instance
    //       .refFromURL('gs://wargabut-11.appspot.com/impactnation/$poster')
    //       .getDownloadURL();
    //   posterUrls.add(posterUrl);
    // }

    String urlAvatar = '';
    urlAvatar = await FirebaseStorage.instance
        .refFromURL('gs://wargabut-11.appspot.com/impactnation/logo-barcode_organizer.jpg')
        .getDownloadURL();

    return PosterCard(
      data: data,
      posterUrls: posterUrls,
      urlAvatar: urlAvatar,
    );
  }
}
