import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:wargabut/app/provider/aninews_provider.dart';

import '../../../provider/auth_provider.dart';
import '../../../provider/event_provider.dart';
import '../../../provider/location_provider.dart';
import '../../../provider/theme_provider.dart';
import '../../components/drawer/app_drawer.dart';
import '../../components/tile/aninews_list_tile.dart';
import '../../components/tile/event_list_tile.dart';
import '../../../config/app_menus.dart';

// 1. UBAH MENJADI STATELESSWIDGET
// Semua state sekarang dikelola oleh Provider, jadi widget ini tidak perlu state lagi.
class AniNewsListPage extends StatefulWidget {
  const AniNewsListPage({super.key});

  @override
  State<AniNewsListPage> createState() => _AniNewsListPageState();
}

class _AniNewsListPageState extends State<AniNewsListPage> {
  // 1. Buat satu instance FocusNode di sini.
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    // 2. Penting! Buang FocusNode saat widget tidak lagi digunakan untuk mencegah memory leak.
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambil semua provider yang dibutuhkan di sini.
    final newsProvider = context.watch<AniNewsProvider>();
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
                  _buildAppBar(context, themeProvider, newsProvider),

                  // 5. Sisa konten (filter dan list) harus di dalam Expanded
                  //    agar bisa di-scroll dengan benar.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: !newsProvider.isFilterActive
                              ? _buildWelcomeView(context, isDesktop)
                              : _buildFilteredResults(context, newsProvider, isDesktop),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // --- LAYOUT MOBILE ---
    // Layout untuk mobile tetap sama seperti sebelumnya, karena sudah benar.
    return Scaffold(
      appBar: _buildAppBar(context, themeProvider, newsProvider),
      drawer: _buildDrawer(context, authProvider, false),
      floatingActionButton: _buildFloatingActionButton(context, authProvider),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8.0),
          Expanded(
            child: newsProvider.isFilterActive
                ? _buildFilteredResults(context, newsProvider, isDesktop)
                : _buildWelcomeView(context, isDesktop),
          ),
        ],
      ),
    );
  }

  // --- BAGIAN-BAGIAN UI DIPISAH MENJADI METHOD/WIDGET KECIL ---
  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeProvider themeProvider, AniNewsProvider newsProvider) {
    return AppBar(
      titleSpacing: 0.0,
      surfaceTintColor: Colors.transparent,
      title: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 700, // <-- ANDA BISA SESUAIKAN LEBAR MAKSIMUM INI
          ),
          child: SearchBar(
            key: Key(newsProvider.searchTerm), // Key untuk mereset text saat provider berubah
            controller: TextEditingController(text: newsProvider.searchTerm),
            // 3. Hubungkan FocusNode yang sudah kita buat ke SearchBar
            focusNode: _searchFocusNode,
            hintText: 'Cari berita...',
            shadowColor: WidgetStateColor.resolveWith((s) => Colors.transparent),
            padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
            onSubmitted: (value) => context.read<AniNewsProvider>().setSearchTerm(value),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            leading: const Icon(Icons.search),
            trailing: <Widget>[
              if (newsProvider.searchTerm.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => context.read<AniNewsProvider>().clearFilters(),
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
      currentRoute: "/anichekku",
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
          label: 'Refresh News',
          onTap: () => context.read<AniNewsProvider>().fetchData(forceRefresh: true),
        ),
        SpeedDialChild(
          child: const Icon(Icons.add),
          label: 'Add News',
          onTap: () => context.push('/anichekku/baru'),
        ),
      ],
    );
  }

  Widget _buildFilteredResults(BuildContext context, AniNewsProvider newsProvider, bool isDesktop) {
    if (newsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (newsProvider.filteredNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const Text('Berita Tidak Ditemukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Coba ubah kata kunci Anda.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<AniNewsProvider>().clearFilters(),
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
        itemCount: newsProvider.filteredNews.length,
        itemBuilder: (context, index) {
          final event = newsProvider.filteredNews[index];
          return AniNewsListTile(data: event); // Widget card Anda
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0),
        itemCount: newsProvider.filteredNews.length,
        itemBuilder: (context, index) {
          final event = newsProvider.filteredNews[index];
          return AniNewsListTile(data: event);
        },
      );
    }
  }

  Widget _buildWelcomeView(BuildContext context, bool isDesktop) {
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
                              Text(
                                'Temukan Berita Anime Terbaru!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Update anime, movie, dan serial yang akan tayang — semuanya di AniChekku.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildNearestEventsSection(context, isDesktop),
        ],
      ),
    );
  }

  Widget _buildNearestEventsSection(BuildContext context, bool isDesktop) {
    // Gunakan 'read' karena kita hanya perlu data saat ini, tidak perlu rebuild jika berubah di sini
    final newsProvider = context.read<AniNewsProvider>();

    final nearestEvents = newsProvider.nearestEvents;

    if (nearestEvents.isEmpty) {
      return const SizedBox.shrink(); // Jangan tampilkan apa-apa jika tidak ada event sama sekali
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Berita Terbaru",
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
              return AniNewsListTile(data: event); // Widget card Anda
            },
          ) :
          ListView.builder(
            itemCount: nearestEvents.length,
            shrinkWrap: true, // Penting agar ListView tidak mengambil tinggi tak terbatas
            physics: const NeverScrollableScrollPhysics(), // Matikan scroll untuk ListView ini
            itemBuilder: (context, index) {
              final event = nearestEvents[index];
              // Gunakan widget list tile Anda yang sudah ada
              return AniNewsListTile(data: event);
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Panggil method baru di provider, tidak lagi menggunakan setState
                context.read<AniNewsProvider>().showFullList();
              },
              child: const Text("Lihat Semua Berita"),
            ),
          ),
        ],
      ),
    );
  }

}