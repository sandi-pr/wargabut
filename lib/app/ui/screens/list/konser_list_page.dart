import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:provider/provider.dart';
import 'package:wargabut/app/ui/components/tile/konser_list_tile.dart';

// Providers & Models
import '../../../provider/auth_provider.dart';
import '../../../provider/konser_provider.dart';
import '../../../provider/location_provider.dart';
import '../../components/tile/event_list_tile.dart';

// Shared Components Baru
import '../../components/shared/list_page_config.dart';
import '../../components/shared/responsive_list_scaffold.dart';
import '../../components/shared/generic_filter_sheet.dart';
import '../../components/shared/shared_filter_segments.dart';
import '../../components/shared/shared_grid_result.dart';
import '../../components/shared/shared_welcome_view.dart';
import '../../components/shared/shared_admin_fab.dart';


class KonserListPage extends StatefulWidget {
  const KonserListPage({super.key});

  @override
  State<KonserListPage> createState() => _KonserListPageState();
}

class _KonserListPageState extends State<KonserListPage> {
  final FocusNode _searchFocusNode = FocusNode();

  // 1. TENTUKAN CONFIG DI SINI (Event)
  final config = ListPageConfig.konser;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Helper Logic
  void _loadMonths(List<DateTime> sourceDates) {
    List<String> temp = [];
    for (var date in sourceDates) {
      temp.add(DateFormat('MMMM', 'id_ID').format(date));
    }
    context.read<KonserProvider>().setSelectedMonths(temp);
  }

  void _handleFilterChange(Set<String> newSelection, BuildContext context) {
    final provider = context.read<KonserProvider>();
    final oldSelection = {
      if (provider.selectedAreas.isNotEmpty) 'Lokasi',
      if (provider.selectedMonths.isNotEmpty) 'Bulan',
    };

    // Hapus
    final removed = oldSelection.difference(newSelection);
    for (var f in removed) {
      if (f == 'Lokasi') provider.setSelectedAreas([]);
      if (f == 'Bulan') provider.setSelectedMonths([]);
    }

    // Tambah
    final added = newSelection.difference(oldSelection);
    if (added.isNotEmpty) {
      FocusScope.of(context).unfocus();
      final type = added.first;
      if (type == 'Lokasi') {
        _showFilterSheet(context, 'Lokasi');
      } else if (type == 'Bulan') {
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
        ).then((dates) { if (dates != null) _loadMonths(dates); });
      }
    }
  }

  void _showFilterSheet(BuildContext context, String type) {
    final provider = context.read<KonserProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // Siapkan kontennya
    final content = GenericFilterSheet(
      filterType: type,
      sourceList: provider.areas,
      currentSelection: provider.selectedAreas,
      onApply: (val) {
        provider.setSelectedAreas(val);
        if(val.contains("Terdekat")) provider.showAllNearest();
      },
      onNearestSelected: () async {
        final loc = context.read<LocationProvider>().userPosition;
        if(loc != null) await provider.fetchNearestEvents(loc);
      },
    );

    if (isDesktop) {
      // DESKTOP: Hapus properti 'title' dari AlertDialog karena sudah ada di dalam content
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
            // title: Text('Filter $type'), // <--- HAPUS INI agar tidak dobel
              content: SizedBox(
                  width: 400,
                  height: 400,
                  child: content // content sudah mengandung Padding & Judul
              )
          )
      );
    } else {
      // MOBILE: Langsung tampilkan content tanpa perlu Container/Column tambahan
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (_, __) => content // <--- Langsung panggil widgetnya, lebih bersih!
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<KonserProvider>();
    final authProvider = context.watch<AuthProvider>();

    final searchController = TextEditingController(text: eventProvider.searchTerm);
    searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchController.text.length));

    return ResponsiveListScaffold(
      title: config.title,
      searchHint: config.searchHint,
      drawerCurrentRoute: config.drawerRoute,
      searchController: searchController,
      searchFocusNode: _searchFocusNode,
      onSearchSubmitted: (val) => context.read<KonserProvider>().setSearchTerm(val),
      onClearSearch: () => context.read<KonserProvider>().clearFilters(),

      // MENGGUNAKAN SHARED COMPONENT FAB
      floatingActionButton: SharedAdminFab(
        isAdmin: authProvider.isAdmin,
        onRefresh: () => context.read<KonserProvider>().fetchData(forceRefresh: true),
        onAdd: () => context.push('/jeventku/baru'),
        onGeocode: () async {
          // Logic geocode pindah sini atau tetap di page, terserah Anda
          await context.read<KonserProvider>().geocodeAllEventsOnce();
        },
      ),

      bodyContent: Column(
        children: [
          // MENGGUNAKAN SHARED COMPONENT SEGMENTS
          SharedFilterSegments(
            isLocationSelected: eventProvider.selectedAreas.isNotEmpty,
            isMonthSelected: eventProvider.selectedMonths.isNotEmpty,
            onSelectionChanged: (val) => _handleFilterChange(val, context),
          ),
          const SizedBox(height: 8.0),

          Expanded(
            child: !eventProvider.isFilterActive
            // MENGGUNAKAN SHARED COMPONENT WELCOME
                ? SharedWelcomeView(
              config: config,
              upcomingEvents: eventProvider.nearestEvents,
              onSeeAllUpcoming: () => eventProvider.showFullList(),
              itemBuilder: (_, item) => KonserListTile(data: item),
            )
            // MENGGUNAKAN SHARED COMPONENT GRID RESULT
                : SharedGridResult(
              isLoading: eventProvider.isLoading,
              data: eventProvider.filteredEvents,
              config: config,
              onClearFilter: () => eventProvider.clearFilters(),
              itemBuilder: (_, item) => KonserListTile(data: item),
            ),
          ),
        ],
      ),
    );
  }
}