import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:localstorage/localstorage.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:wargabut/app/provider/konser_provider.dart';

import '../../../provider/auth_provider.dart';
import '../../../provider/event_provider.dart';
import '../../../provider/location_provider.dart';
import '../../../provider/theme_provider.dart';
import '../../components/drawer/app_drawer.dart';
import '../../components/event_list_tile.dart';
import '../../../config/app_menus.dart';

enum SponsorViewType { banner, logo }

// 1. UBAH MENJADI STATELESSWIDGET
// Semua state sekarang dikelola oleh Provider, jadi widget ini tidak perlu state lagi.
class KonserListPage extends StatefulWidget {
  const KonserListPage({super.key});

  @override
  State<KonserListPage> createState() => _KonserListPageState();
}

class _KonserListPageState extends State<KonserListPage> {
  // 1. Buat satu instance FocusNode di sini.
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> imgList = [
    'https://images.unsplash.com/photo-1520342868574-5fa3804e551c?auto=format&fit=crop&w=1951&q=80',
    'https://images.unsplash.com/photo-1522205408450-add114ad53fe?auto=format&fit=crop&w=1950&q=80',
    'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?auto=format&fit=crop&w=1950&q=80',
    'https://images.unsplash.com/photo-1523205771623-e0faa4d2813d?auto=format&fit=crop&w=1953&q=80',
    'https://images.unsplash.com/photo-1508704019882-f9cf40e475b4?auto=format&fit=crop&w=1352&q=80',
    'https://images.unsplash.com/photo-1519985176271-adb1088fa94c?auto=format&fit=crop&w=1355&q=80'
  ];

  @override
  void dispose() {
    // 2. Penting! Buang FocusNode saat widget tidak lagi digunakan untuk mencegah memory leak.
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _confirmLocationPermission() async {
    final locationProvider = context.read<LocationProvider>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Izinkan Akses Lokasi?"),
        content: const Text(
          "Fitur ini memerlukan akses lokasi Anda untuk mencari festival terdekat dari posisi Anda saat ini. Data lokasi tidak disimpan.",
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text("Lanjutkan"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (result == true) {
      localStorage.setItem('locationPermissionAsked', 'true');
      await locationProvider.fetchUserLocationWeb();
      final userPos = locationProvider.userPosition;
      if (userPos != null && mounted) {
        await context
            .read<KonserProvider>()
            .fetchNearestEvents(userPos);
      }
    } else {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Akses lokasi dibatalkan."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil semua provider yang dibutuhkan di sini.
    final eventProvider = context.watch<KonserProvider>();
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    // Cek ukuran layar untuk layout responsif
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    // --- LAYOUT DESKTOP ---
    if (isDesktop) {
      return Scaffold(
        // 1. Tidak ada appBar atau drawer di level Scaffold utama untuk desktop
        floatingActionButton: _buildFloatingActionButton(context, authProvider),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. Drawer permanen di kiri, akan otomatis mengisi tinggi layar
            SizedBox(
              width: 250, // Lebar drawer tetap
              child: _buildDrawer(context, authProvider, true),
            ),

            // 3. Kolom konten utama di tengah
            Expanded(
              flex: 5, // Beri ruang lebih besar untuk konten utama
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 4. AppBar sekarang menjadi widget pertama di dalam kolom ini,
                  //    bukan properti Scaffold.
                  _buildAppBar(context, themeProvider, eventProvider),

                  // 5. Sisa konten (filter dan list) harus di dalam Expanded
                  //    agar bisa di-scroll dengan benar.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildFilterControls(context, eventProvider),
                        const SizedBox(height: 8.0),
                        Expanded(
                          child: !eventProvider.isFilterActive
                              ? _buildWelcomeView(context, isDesktop)
                              : _buildFilteredResults(context, eventProvider, isDesktop),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 6. Panel sponsor di kanan
            // Container(
            //   width: 200, // Lebar kolom sponsor
            //   padding: const EdgeInsets.only(top: 20, right: 20),
            //   child: _buildSponsorView(type: SponsorViewType.logo),
            // ),
          ],
        ),
      );
    }

    // --- LAYOUT MOBILE ---
    // Layout untuk mobile tetap sama seperti sebelumnya, karena sudah benar.
    return Scaffold(
      appBar: _buildAppBar(context, themeProvider, eventProvider),
      drawer: _buildDrawer(context, authProvider, false),
      floatingActionButton: _buildFloatingActionButton(context, authProvider),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterControls(context, eventProvider),
          const SizedBox(height: 8.0),
          Expanded(
            child: eventProvider.isFilterActive
                ? _buildFilteredResults(context, eventProvider, isDesktop)
                : _buildWelcomeView(context, isDesktop),
          ),
        ],
      ),
    );
  }

  // --- BAGIAN-BAGIAN UI DIPISAH MENJADI METHOD/WIDGET KECIL ---
  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeProvider themeProvider, KonserProvider eventProvider) {
    return AppBar(
      titleSpacing: 0.0,
      surfaceTintColor: Colors.transparent,
      title: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 700, // <-- ANDA BISA SESUAIKAN LEBAR MAKSIMUM INI
          ),
          child: SearchBar(
            key: Key(eventProvider.searchTerm), // Key untuk mereset text saat provider berubah
            controller: TextEditingController(text: eventProvider.searchTerm),
            // 3. Hubungkan FocusNode yang sudah kita buat ke SearchBar
            focusNode: _searchFocusNode,
            hintText: 'Cari konser...',
            shadowColor: WidgetStateColor.resolveWith((s) => Colors.transparent),
            padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
            onSubmitted: (value) => context.read<KonserProvider>().setSearchTerm(value),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            leading: const Icon(Icons.search),
            trailing: <Widget>[
              if (eventProvider.searchTerm.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => context.read<KonserProvider>().clearFilters(),
                )
              else
                Tooltip(
                  message: 'Ubah tema',
                  child: IconButton(
                    isSelected: themeProvider.isDark,
                    onPressed: themeProvider.toggleTheme,
                    icon: const Icon(Icons.wb_sunny_outlined),
                    selectedIcon: const Icon(Icons.brightness_2_outlined),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider authProvider, bool isDesktop) {
    // Widget Drawer yang sesungguhnya kita simpan dalam satu variabel
    final drawerContent = AppDrawer(
      isDesktop: isDesktop,
      currentRoute: "/dkonser",
      menuItems: appMenus,
      isLoggedIn: authProvider.isLoggedIn,
      onLogout: authProvider.isLoggedIn ? authProvider.signOut : null,
      onLogin: !authProvider.isLoggedIn ? () => context.push('/login') : null,
    );

    // Jika ini adalah tampilan desktop, bungkus dengan Container yang memiliki border
    if (isDesktop) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
        ),
        child: drawerContent,
      );
    }

    // Jika mobile, kembalikan Drawer seperti biasa
    return drawerContent;
  }

  Widget _buildFloatingActionButton(BuildContext context, AuthProvider authProvider) {
    if (!authProvider.isAdmin) return const SizedBox.shrink();

    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.refresh),
          label: 'Refresh Festival',
          onTap: () => context.read<KonserProvider>().fetchData(forceRefresh: true),
        ),
        SpeedDialChild(
          child: const Icon(Icons.location_on),
          label: 'Geocode Festival (Once)',
          onTap: () async {
            final provider = context.read<KonserProvider>();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏳ Memulai geocoding festival...'),
              ),
            );

            await provider.geocodeAllEventsOnce();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Geocoding selesai'),
              ),
            );
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.add),
          label: 'Add Festival',
          onTap: () => context.push('/dkonser/baru'),
        ),
      ],
    );
  }

  Widget _buildFilterControls(BuildContext context, KonserProvider eventProvider) {
    // Kita tidak perlu lagi watch di sini, karena onSelectionChanged akan menggunakan read.
    // Widget induk sudah watch, jadi rebuild akan tetap terjadi.

    List<String> tempSelectedItems = [];

    void loadMonths(List<DateTime> sourceDates) {
      tempSelectedItems.clear();

      // ambil nama bulan dari _sourceDates
      for (var date in sourceDates) {
        final monthName = DateFormat('MMMM', 'id_ID').format(date); // contoh: September
        tempSelectedItems.add(monthName);
      }

      final eventProvider = context.read<KonserProvider>();
      eventProvider.setSelectedMonths(tempSelectedItems);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SegmentedButton<String>(
        emptySelectionAllowed: true,
        multiSelectionEnabled: true,
        selected: <String>{
          if (context.read<KonserProvider>().selectedAreas.isNotEmpty) 'Lokasi',
          if (eventProvider.selectedMonths.isNotEmpty) 'Bulan',
        },

        // =============================================================
        // LOGIKA BARU YANG LEBIH PINTAR
        // =============================================================
        onSelectionChanged: (Set<String> newSelection) {
          // Dapatkan provider sekali saja dengan 'read'
          final provider = context.read<KonserProvider>();

          // Tentukan state seleksi SEBELUM ada perubahan
          final Set<String> currentSelection = {
            if (provider.selectedAreas.isNotEmpty) 'Lokasi',
            if (provider.selectedMonths.isNotEmpty) 'Bulan',
          };

          // Cari tahu filter mana yang BARU SAJA DITAMBAHKAN
          final Set<String> addedFilters = newSelection.difference(currentSelection);

          // Cari tahu filter mana yang BARU SAJA DIHAPUS
          final Set<String> removedFilters = currentSelection.difference(newSelection);

          // --- Proses Aksi ---

          // 1. Jika ada filter yang dihapus (tombol di-uncheck)
          for (final filter in removedFilters) {
            if (filter == 'Lokasi') {
              provider.setSelectedAreas([]);
            } else if (filter == 'Bulan') {
              provider.setSelectedMonths([]);
            }
          }

          // 2. Jika ada filter yang ditambahkan (tombol di-check)
          //    Kita hanya proses yang pertama untuk menghindari dua sheet muncul bersamaan
          if (addedFilters.isNotEmpty) {
            FocusScope.of(context).unfocus();
            final filterToShow = addedFilters.first;
            if (filterToShow == 'Lokasi') {
              _showSideSheet(context, filterToShow);
            } else if (filterToShow == 'Bulan') {
              showMonthRangePicker(
                context: context,
                initialRangeDate: DateTime.now(),
                rangeList: true,
                monthPickerDialogSettings: const MonthPickerDialogSettings(
                    dialogSettings: PickerDialogSettings(
                      locale: Locale('id'),
                      dialogRoundedCornersRadius: 20,
                    ),
                    actionBarSettings: PickerActionBarSettings(
                      actionBarPadding: EdgeInsets.only(bottom: 20, left: 20, right: 20),
                    )
                ),
              ).then((List<DateTime>? dates) {
                if (dates != null) {
                  loadMonths(dates);
                }
              });
            }
          }
        },
        segments: const <ButtonSegment<String>>[
          ButtonSegment<String>(value: 'Lokasi', label: Text('Lokasi'), icon: Icon(Icons.location_on)),
          ButtonSegment<String>(value: 'Bulan', label: Text('Bulan'), icon: Icon(Icons.calendar_month)),
        ],
      ),
    );
  }

  Widget _buildFilteredResults(BuildContext context, KonserProvider eventProvider, bool isDesktop) {
    if (eventProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (eventProvider.filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const Text('Konser Tidak Ditemukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Coba ubah kata kunci atau filter Anda.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<KonserProvider>().clearFilters(),
              child: const Text('Hapus Semua Filter'),
            )
          ],
        ),
      );
    }

    // Gunakan MasonryGridView untuk desktop, ListView untuk mobile
    if (isDesktop) {
      return MasonryGridView.count(
        crossAxisCount: MediaQuery.of(context).size.width < 1200 ? 1 : 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0),
        itemCount: eventProvider.filteredEvents.length,
        itemBuilder: (context, index) {
          final event = eventProvider.filteredEvents[index];
          return EventListTile(data: event); // Widget card Anda
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0),
        itemCount: eventProvider.filteredEvents.length,
        itemBuilder: (context, index) {
          final event = eventProvider.filteredEvents[index];
          return EventListTile(data: event);
        },
      );
    }
  }

  // Di dalam kelas _EventListPageState

  Widget _buildWelcomeView(BuildContext context, bool isDesktop) {
    final locationProvider = context.watch<LocationProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 80.0),
      child: Column(
        children: [
          // Bagian Card "Temukan Event Menarik!" Anda (tidak berubah)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 470,
              ),
              child: const Stack(
                children: [
                  // if (!isDesktop)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Image(
                          width: 150,
                          image: AssetImage('assets/images/wargabut_mascot_chibi.png')),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(height: 130),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text('Temukan Musisi Favoritmu!',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text(
                                  'Cari festival konser musik di sekitarmu!',
                                  textAlign: TextAlign.center),
                              // const SizedBox(height: 16),
                              // ElevatedButton.icon(
                              //   onPressed: () => _searchFocusNode.requestFocus(),
                              //   icon: const Icon(Icons.search),
                              //   label: const Text('Mulai Cari Event'),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ==========================================================
          // PANGGIL SECTION BARU "EVENT TERDEKAT" DI SINI
          // ==========================================================
          // _buildNearestEventsSection(context, isDesktop),

          // _buildNearestLocationEventsSection(context, isDesktop),

          // _buildPopularLocationSection(context, isDesktop),

          // Bagian Sponsor Anda (tidak berubah)
          // if (!isDesktop)
          //   Padding(
          //     padding: const EdgeInsets.only(top: 24.0),
          //     child: _buildSponsorView(type: SponsorViewType.banner),
          //   ),
        ],
      ),
    );
  }

  Widget _buildNearestEventsSection(BuildContext context, bool isDesktop) {
    // Gunakan 'read' karena kita hanya perlu data saat ini, tidak perlu rebuild jika berubah di sini
    final eventProvider = context.read<KonserProvider>();

    final nearestEvents = eventProvider.nearestEvents;

    if (nearestEvents.isEmpty) {
      return const SizedBox.shrink(); // Jangan tampilkan apa-apa jika tidak ada event sama sekali
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Festival Mendatang",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Gunakan ListView yang tidak bisa di-scroll di dalam SingleChildScrollView

          isDesktop ?
          MasonryGridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width < 1200 ? 1 : 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: nearestEvents.length,
            itemBuilder: (context, index) {
              final event = nearestEvents[index];
              return EventListTile(data: event); // Widget card Anda
            },
          ) :
          ListView.builder(
            itemCount: nearestEvents.length,
            shrinkWrap: true, // Penting agar ListView tidak mengambil tinggi tak terbatas
            physics: const NeverScrollableScrollPhysics(), // Matikan scroll untuk ListView ini
            itemBuilder: (context, index) {
              final event = nearestEvents[index];
              // Gunakan widget list tile Anda yang sudah ada
              return EventListTile(data: event);
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Panggil method baru di provider, tidak lagi menggunakan setState
                context.read<KonserProvider>().showFullList();
              },
              child: const Text("Lihat Semua Festival"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearestLocationEventsSection(
      BuildContext context,
      bool isDesktop,
      ) {
    final eventProvider = context.watch<KonserProvider>();
    final locationProvider = context.watch<LocationProvider>();

    final nearestEvents = eventProvider.nearestLocEvents;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Festival Terdekat",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          /// 1️⃣ BELUM ADA LOKASI USER
          if (!eventProvider.hasUserLocation)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.my_location),
                label: const Text("Cari Festival Terdekat"),
                onPressed: locationProvider.isFetching
                    ? null
                    : () async {
                  final asked = localStorage.getItem('locationPermissionAsked') == 'true';

                  if (locationProvider.userPosition == null && !asked) {
                    await _confirmLocationPermission(); // tampilkan dialog
                  }else if (locationProvider.userPosition == null && asked) {
                    await locationProvider.fetchUserLocationWeb();
                    eventProvider.fetchNearestEvents(locationProvider.userPosition!);
                  } else {
                    final pos = locationProvider.userPosition;
                    if (pos != null) {
                      await context
                          .read<KonserProvider>()
                          .fetchNearestEvents(pos);
                    }
                  }
                },
              ),
            )

          /// 2️⃣ SUDAH ADA LOKASI TAPI BELUM ADA EVENT
          else if (nearestEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text("Tidak ada festival dalam radius terdekat."),
            )

          /// 3️⃣ TAMPILKAN EVENT
          else ...[
              isDesktop
                  ? MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount:
                MediaQuery.of(context).size.width < 1200 ? 1 : 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: nearestEvents.length,
                itemBuilder: (_, i) =>
                    EventListTile(data: nearestEvents[i]),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nearestEvents.length,
                itemBuilder: (_, i) =>
                    EventListTile(data: nearestEvents[i]),
              ),
              const SizedBox(height: 16),
              /// 4️⃣ TOMBOL LIHAT SEMUA
              Center(
                child: ElevatedButton(
                  onPressed: () =>
                      context.read<KonserProvider>().showAllNearest(),
                  child: const Text("Lihat Semua"),
                ),
              ),
            ],
          if (locationProvider.error != null)
            Center(child: Text(locationProvider.error!, style: const TextStyle(color: Colors.red)))
        ],
      ),
    );
  }

  Widget _buildPopularLocationSection(BuildContext context, bool isDesktop) {
    final List<Widget> imageSliders = imgList
        .map((item) => Container(
      margin: const EdgeInsets.all(5.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        child: Stack(
          children: <Widget>[
            Image.network(item, fit: BoxFit.cover, width: 1000.0),
            Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(200, 0, 0, 0),
                      Color.fromARGB(0, 0, 0, 0)
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 20.0),
                child: Text(
                  'No. ${imgList.indexOf(item) + 1} image',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ))
        .toList();

    return CarouselSlider(
      options: CarouselOptions(
        aspectRatio: 16 / 9,
        enlargeCenterPage: true,
        enableInfiniteScroll: false,
        initialPage: 0,
        autoPlay: true,
      ),
      items: imageSliders,
    );
  }

  Widget _buildSponsorView({ SponsorViewType type = SponsorViewType.banner }) { // Default ke banner
    // Tentukan path gambar dan batasan ukuran berdasarkan tipenya
    final String imageAsset;
    final double maxWidth;

    if (type == SponsorViewType.logo) {
      imageAsset = 'assets/images/logo-squid_rentcos.png'; // Ganti dengan nama file logo Anda
      maxWidth = 150; // Logo biasanya lebih kecil
    } else { // type == SponsorViewType.banner
      imageAsset = 'assets/images/banner-squid_rentcos.jpg';
      maxWidth = 350; // Banner lebih lebar
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Sponsor', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8.0),
        InkWell(
          onTap: _launchUrl,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Image(
              image: AssetImage(imageAsset), // Gunakan path gambar yang dinamis
              filterQuality: FilterQuality.high, // Gunakan kualitas tinggi untuk logo
            ),
          ),
        ),
      ],
    );
  }

  // Ganti seluruh fungsi _showSideSheet Anda dengan yang ini
  void _showSideSheet(BuildContext context, String filterType) {
    bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      // Tampilan Dialog untuk Desktop
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Filter $filterType'),
            content: SizedBox(
              width: 400,
              height: 400,
              // Cukup panggil widget FilterContent
              child: FilterContent(filterType: filterType),
            ),
            // Tombol aksi sekarang menjadi bagian dari FilterContent
          );
        },
      );
    } else {
      // Tampilan BottomSheet untuk Mobile
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, scrollController) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Filter $filterType', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16.0),
                    // Cukup panggil widget FilterContent
                    Expanded(child: FilterContent(filterType: filterType)),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  // Pindahkan _launchUrl ke sini juga
  Future<void> _launchUrl() async {
    final Uri url = Uri.parse('https://www.instagram.com/squid_rentcos');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}

// Widget baru yang Stateful untuk mengelola state filter sementara
class FilterContent extends StatefulWidget {
  final String filterType;

  const FilterContent({
    super.key,
    required this.filterType,
  });

  @override
  State<FilterContent> createState() => _FilterContentState();
}

class _FilterContentState extends State<FilterContent> {
  // State sementara untuk menampung pilihan pengguna
  late List<String> _tempSelectedItems;
  late List<String> _sourceList;

  @override
  void initState() {
    super.initState();
    // Inisialisasi state SEKALI SAJA saat widget dibuat
    final eventProvider = context.read<KonserProvider>();

    if (widget.filterType == 'Lokasi') {
      _sourceList = eventProvider.areas;
      _tempSelectedItems = List.from(eventProvider.selectedAreas);
    } else {
      _sourceList = const [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
        'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      _tempSelectedItems = List.from(eventProvider.selectedMonths);
    }
  }

  Future<void> _confirmLocationPermission() async {
    final locationProvider = context.read<LocationProvider>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Izinkan Akses Lokasi?"),
        content: const Text(
          "Fitur ini memerlukan akses lokasi Anda untuk mencari festival terdekat dari posisi Anda saat ini. Data lokasi tidak disimpan.",
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text("Lanjutkan"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (result == true) {
      localStorage.setItem('locationPermissionAsked', 'true');
      await locationProvider.fetchUserLocationWeb();
      final userPos = locationProvider.userPosition;
      if (userPos != null && mounted) {
        await context
            .read<KonserProvider>()
            .fetchNearestEvents(userPos);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Akses lokasi dibatalkan."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<KonserProvider>();
    final locationProvider = context.watch<LocationProvider>();

    // 1. Tentukan status "Pilih Semua" berdasarkan perbandingan panjang list
    final bool isAllSelected = _sourceList.isNotEmpty && _tempSelectedItems.length == _sourceList.length;
    final bool isNearestSelected = _tempSelectedItems.contains('Terdekat');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text(
            "Terdekat",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          value: isNearestSelected,
          onChanged: (bool? value) {
            // 3. Logika untuk memilih atau menghapus semua pilihan
            setState(() {
              if (value == true) {
                // Jika dicentang, salin semua item dari sumber ke daftar pilihan
                _tempSelectedItems.clear();
                _tempSelectedItems.add("Terdekat");
              } else {
                // Jika tidak dicentang, kosongkan daftar pilihan
                _tempSelectedItems.clear();
              }
            });
          },
        ),
        // 2. TAMBAHKAN WIDGET CHECKBOXLISTTILE UNTUK "PILIH SEMUA"
        CheckboxListTile(
          title: Text(
            "Pilih Semua ${widget.filterType}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          value: isAllSelected,
          onChanged: (bool? value) {
            // 3. Logika untuk memilih atau menghapus semua pilihan
            setState(() {
              if (value == true) {
                // Jika dicentang, salin semua item dari sumber ke daftar pilihan
                _tempSelectedItems.clear();
                _tempSelectedItems.addAll(_sourceList);
              } else {
                // Jika tidak dicentang, kosongkan daftar pilihan
                _tempSelectedItems.clear();
              }
            });
          },
        ),
        const Divider(), // Tambahkan pemisah visual

        // Daftar item filter (kode ini tidak berubah)
        Expanded(
          child: ListView.builder(
            itemCount: _sourceList.length,
            itemBuilder: (context, index) {
              final item = _sourceList[index];
              return CheckboxListTile(
                title: Text(item),
                value: _tempSelectedItems.contains(item),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _tempSelectedItems.add(item);
                    } else {
                      _tempSelectedItems.remove(item);
                    }
                  });
                },
              );
            },
          ),
        ),

        // Tombol Aksi (kode ini tidak berubah)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final eventProvider = context.read<KonserProvider>();
                  if (_tempSelectedItems.contains("Terdekat")) {
                    final locUser = locationProvider.userPosition;
                    final asked = localStorage.getItem('locationPermissionAsked') == 'true';
                    if (locUser != null) {
                      await eventProvider.fetchNearestEvents(locUser);
                      eventProvider.setSelectedAreas(["Terdekat"]);
                      eventProvider.showAllNearest();
                    } else if (locUser == null && asked) {
                      await locationProvider.fetchUserLocationWeb();
                      await eventProvider.fetchNearestEvents(locationProvider.userPosition!);
                      eventProvider.setSelectedAreas(["Terdekat"]);
                      eventProvider.showAllNearest();
                    } else if (locationProvider.userPosition == null) {
                      await _confirmLocationPermission(); // tampilkan dialog
                      eventProvider.setSelectedAreas(["Terdekat"]);
                      eventProvider.showAllNearest();
                    }
                    Navigator.pop(context);
                    return;
                  } else if (widget.filterType == 'Lokasi') {
                    _tempSelectedItems.remove('Terdekat');
                    eventProvider.setSelectedAreas(_tempSelectedItems);
                  } else {
                    eventProvider.setSelectedMonths(_tempSelectedItems);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Terapkan'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}