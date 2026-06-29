import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../provider/auth_provider.dart';
import '../../../provider/aninews_provider.dart';
import '../../../provider/theme_provider.dart';
import '../../components/tile/aninews_list_tile.dart';

// SHARED COMPONENTS
import '../../components/shared/list_page_config.dart';
import '../../components/shared/responsive_list_scaffold.dart';
import '../../components/shared/generic_filter_sheet.dart';
import '../../components/shared/shared_filter_segments.dart';
import '../../components/shared/shared_grid_result.dart';
import '../../components/shared/shared_admin_fab.dart';
import '../create/crawl_ani_news.dart';
import '../create/crawl_scheduled_anime.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class AniNewsListPage extends StatefulWidget {
  const AniNewsListPage({super.key});

  @override
  State<AniNewsListPage> createState() => _AniNewsListPageState();
}

class _AniNewsListPageState extends State<AniNewsListPage> {
  final FocusNode _searchFocusNode = FocusNode();

  // Asumsi Anda punya ListPageConfig.aniNews, jika belum, buat di list_page_config.dart
  // title: 'AniChekku', searchHint: 'Cari berita...', drawerRoute: '/anichekku'
  final config = ListPageConfig.aniNews;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleFilterChange(Set<String> newSelection, BuildContext context) {
    final provider = context.read<AniNewsProvider>();
    final oldSelection = {
      if (provider.selectedTags.isNotEmpty) 'Tag',
      if (provider.selectedGenres.isNotEmpty) 'Genre',
    };

    // Hapus
    final removed = oldSelection.difference(newSelection);
    for (var f in removed) {
      if (f == 'Tag') provider.setSelectedTags([]);
      if (f == 'Genre') provider.setSelectedGenres([]);
    }

    // Tambah
    final added = newSelection.difference(oldSelection);
    if (added.isNotEmpty) {
      FocusScope.of(context).unfocus();
      final type = added.first;
      _showFilterSheet(context, type);
    }
  }

  void _showFilterSheet(BuildContext context, String type) {
    final provider = context.read<AniNewsProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final isTag = type == 'Tag';
    final sourceList = isTag ? provider.tags : provider.genres;
    final currentSelection = isTag ? provider.selectedTags : provider.selectedGenres;

    final content = GenericFilterSheet(
      filterType: type,
      sourceList: sourceList,
      currentSelection: currentSelection,
      onApply: (val) {
        if (isTag) {
          provider.setSelectedTags(val);
        } else {
          provider.setSelectedGenres(val);
        }
      },
    );

    if (isDesktop) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
              content: SizedBox(width: 400, height: 400, child: content)
          )
      );
    } else {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => DraggableScrollableSheet(
              expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
              builder: (_, __) => content
          )
      );
    }
  }

  void _showDeleteBySeasonDialog(BuildContext context) {
    final newsProvider = context.read<AniNewsProvider>();
    final scheduledAnimes = newsProvider.allScheduled;

    // Kumpulkan semua musim unik dari tags
    final Set<String> uniqueSeasons = {};
    for (var anime in scheduledAnimes) {
      if (anime['tags'] is List) {
        uniqueSeasons.addAll((anime['tags'] as List).map((e) => e.toString()));
      }
    }

    final List<String> availableSeasons = uniqueSeasons.toList()..sort();

    if (availableSeasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada jadwal tayang anime atau musim ditemukan.')),
      );
      return;
    }

    String? selectedSeason = availableSeasons.first;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Hapus Anime Berdasarkan Musim'),
              content: isDeleting
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Sedang menghapus anime dan gambar dari server...'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pilih musim anime jadwal tayang yang ingin Anda hapus masal:'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedSeason,
                          isExpanded: true,
                          items: availableSeasons.map((season) {
                            return DropdownMenuItem(value: season, child: Text(season));
                          }).toList(),
                          onChanged: (val) {
                            setStateDialog(() {
                              selectedSeason = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'PERINGATAN: Aksi ini tidak dapat dibatalkan. Semua gambar dan dokumen anime pada musim ini akan dihapus permanen.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
              actions: isDeleting
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (selectedSeason == null) return;
                          
                          setStateDialog(() {
                            isDeleting = true;
                          });

                          try {
                            final animesToDelete = scheduledAnimes.where((anime) {
                              return anime['tags'] is List && (anime['tags'] as List).contains(selectedSeason);
                            }).toList();

                            for (var anime in animesToDelete) {
                              // 1. Hapus gambar dari Storage
                              final List<dynamic> posters = anime['posters'] ?? [];
                              for (var p in posters) {
                                if (p is Map && p['path'] != null) {
                                  try {
                                    await FirebaseStorage.instance.ref(p['path']).delete();
                                  } catch (e) {
                                    debugPrint('Gagal hapus gambar storage: $e');
                                  }
                                }
                              }
                              // 2. Hapus dokumen Firestore
                              await FirebaseFirestore.instance.collection('anichekku').doc(anime['id']).delete();
                            }

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext); // Tutup dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Berhasil menghapus ${animesToDelete.length} anime musim $selectedSeason!')),
                              );
                              // Refresh list
                              newsProvider.fetchData(forceRefresh: true);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Terjadi kesalahan: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Hapus Semua'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final newsProvider = context.watch<AniNewsProvider>();
    final authProvider = context.watch<AuthProvider>();

    final searchController = TextEditingController(text: newsProvider.searchTerm);
    searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchController.text.length));

    // Menentukan data aktif berdasarkan activeSection (Berita vs Jadwal)
    final bool isShowingScheduled = newsProvider.activeSection == 'scheduled';
    final activeData = isShowingScheduled ? newsProvider.allScheduled : newsProvider.filteredNews;

    return ResponsiveListScaffold(
      title: config.title,
      searchHint: config.searchHint,
      drawerCurrentRoute: config.drawerRoute,
      searchController: searchController,
      searchFocusNode: _searchFocusNode,
      onSearchSubmitted: (val) => context.read<AniNewsProvider>().setSearchTerm(val),
      onClearSearch: () => context.read<AniNewsProvider>().clearFilters(),

      floatingActionButton: SharedAdminFab(
        isAdmin: authProvider.isAdmin,
        onRefresh: () => context.read<AniNewsProvider>().fetchData(forceRefresh: true),
        onAdd: () => context.push('/anichekku/baru'),
        crawlLabel: 'Crawl Berita Anime',
        onCrawl: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CrawlAniNewsPage()),
          );
        },
        crawlScheduledLabel: 'Crawl Jadwal Anime',
        onCrawlScheduled: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CrawlScheduledAnimePage()),
          );
        },
        onDeleteBySeason: () => _showDeleteBySeasonDialog(context),
      ),

      bodyContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Segments (Disesuaikan agar menampilkan "Tag" dan "Genre")
          SharedFilterSegments(
            isFilter1Selected: newsProvider.selectedTags.isNotEmpty,
            isFilter2Selected: newsProvider.selectedGenres.isNotEmpty,

            // Timpa tulisan Lokasi & Bulan dengan Tag & Genre
            filter1Label: 'Tag',
            filter1Value: 'Tag',
            filter1Icon: Icons.local_offer_outlined, // Icon Tag

            filter2Label: 'Genre',
            filter2Value: 'Genre',
            filter2Icon: Icons.category_outlined,    // Icon Kategori/Genre

            onSelectionChanged: (val) => _handleFilterChange(val, context),
          ),
          const SizedBox(height: 8.0),

          Expanded(
            child: !newsProvider.isFilterActive
                ? _AniNewsWelcomeView(isDesktop: MediaQuery.of(context).size.width > 900, config: config)
                : SharedGridResult(
              isLoading: newsProvider.isLoading,
              data: activeData,
              config: config,
              onClearFilter: () => newsProvider.clearFilters(),
              itemBuilder: (_, item) => AniNewsListTile(data: item),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET LOKAL: WELCOME VIEW KHUSUS ANINEWS
// ==========================================
class _AniNewsWelcomeView extends StatelessWidget {
  final bool isDesktop;
  final ListPageConfig config; // 1. Tambahkan config ke constructor

  const _AniNewsWelcomeView({
    required this.isDesktop,
    required this.config, // Wajib diisi saat memanggil widget ini
  });

  @override
  Widget build(BuildContext context) {
    final newsProvider = context.watch<AniNewsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 80.0),
      child: Column(
        children: [
          _buildBanner(context), // 2. Kirim context agar bisa membaca ThemeProvider

          if (newsProvider.upcomingScheduled.isNotEmpty)
            _buildSection(
              context: context,
              title: config.upcomingSectionTitle, // Ambil dari config
              data: newsProvider.upcomingScheduled,
              onSeeAll: () => context.read<AniNewsProvider>().showFullList('scheduled'),
            ),

          if (newsProvider.latestNews.isNotEmpty)
            _buildSection(
              context: context,
              title: config.nearestSectionTitle, // Ambil dari config
              data: newsProvider.latestNews,
              onSeeAll: () => context.read<AniNewsProvider>().showFullList('news'),
            ),
        ],
      ),
    );
  }

  // --- FUNGSI BUILD BANNER ---
  Widget _buildBanner(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>(); // Untuk cek isDark

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Stack(
          children: [
            // 1. Gambar Background Banner Kiri
            Align(
              alignment: Alignment.topLeft,
              child: Image(
                image: AssetImage(
                    themeProvider.isDark ? config.bannerMenuPageDark : config.bannerMenuPage
                ),
              ),
            ),

            // 2. Mascot Kanan Atas
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Image(
                  width: 150,
                  image: AssetImage(config.mascotAsset),
                ),
              ),
            ),

            // 3. Info Card
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 130),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                              config.welcomeTitle,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          const SizedBox(height: 8),
                          Text(
                              config.welcomeSubtitle,
                              textAlign: TextAlign.center
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FUNGSI BUILD SECTION ---
  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> data,
    required VoidCallback onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          isDesktop
              ? MasonryGridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width < 1200 ? 1 : 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: data.length,
            itemBuilder: (_, index) => AniNewsListTile(data: data[index]),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            itemBuilder: (_, index) => AniNewsListTile(data: data[index]),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: onSeeAll,
              child: Text("Lihat Semua ${title.split(' ').first}"), // Cerdas: Mengambil kata pertama (misal: "Lihat Semua Anime" / "Lihat Semua Berita")
            ),
          ),
        ],
      ),
    );
  }
}