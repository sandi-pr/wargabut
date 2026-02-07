import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:provider/provider.dart';
import '../../../provider/location_provider.dart';

// Callback function type definitions
typedef OnApplyFilter = void Function(List<String> selectedItems);
typedef OnFetchLocation = Future<void> Function();

class GenericFilterSheet extends StatefulWidget {
  final String filterType;
  final List<String> sourceList;
  final List<String> currentSelection;
  final OnApplyFilter onApply;
  final OnFetchLocation? onNearestSelected;

  const GenericFilterSheet({
    super.key,
    required this.filterType,
    required this.sourceList,
    required this.currentSelection,
    required this.onApply,
    this.onNearestSelected,
  });

  @override
  State<GenericFilterSheet> createState() => _GenericFilterSheetState();
}

class _GenericFilterSheetState extends State<GenericFilterSheet> {
  late List<String> _tempSelectedItems;

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = List.from(widget.currentSelection);
  }

  Future<void> _confirmLocationPermission() async {
    final locationProvider = context.read<LocationProvider>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Izinkan Akses Lokasi?"),
        content: const Text(
          "Fitur ini memerlukan akses lokasi Anda. Data lokasi tidak disimpan.",
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
      if (widget.onNearestSelected != null && locationProvider.userPosition != null) {
        await widget.onNearestSelected!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllSelected = widget.sourceList.isNotEmpty &&
        _tempSelectedItems.length == widget.sourceList.length;
    final bool isNearestSelected = _tempSelectedItems.contains('Terdekat');

    // --- PERUBAHAN ADA DI SINI ---
    // Membungkus seluruh konten dengan Padding agar rapi
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Menambahkan Judul dan Spasi
          Center( // Opsional: Center agar judul di tengah (mobile style), atau hapus Center jika ingin rata kiri
            child: Text(
              'Filter ${widget.filterType}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16.0),

          // 2. Konten Filter (Checkbox dll)
          if (widget.filterType == 'Lokasi')
            CheckboxListTile(
              title: const Text("Terdekat", style: TextStyle(fontWeight: FontWeight.bold)),
              value: isNearestSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _tempSelectedItems.clear();
                    _tempSelectedItems.add("Terdekat");
                  } else {
                    _tempSelectedItems.clear();
                  }
                });
              },
            ),

          CheckboxListTile(
            title: Text("Pilih Semua ${widget.filterType}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            value: isAllSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _tempSelectedItems.clear();
                  _tempSelectedItems.addAll(widget.sourceList);
                } else {
                  _tempSelectedItems.clear();
                }
              });
            },
          ),
          const Divider(),

          Expanded(
            child: ListView.builder(
              itemCount: widget.sourceList.length,
              itemBuilder: (context, index) {
                final item = widget.sourceList[index];
                return CheckboxListTile(
                  title: Text(item),
                  value: _tempSelectedItems.contains(item),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        if (_tempSelectedItems.contains("Terdekat")) _tempSelectedItems.clear();
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
                    if (_tempSelectedItems.contains("Terdekat") && widget.filterType == 'Lokasi') {
                      final locProvider = context.read<LocationProvider>();
                      if (locProvider.userPosition != null) {
                        if (widget.onNearestSelected != null) await widget.onNearestSelected!();
                      } else {
                        await _confirmLocationPermission();
                      }
                      widget.onApply(["Terdekat"]);
                      if (context.mounted) Navigator.pop(context);
                      return;
                    }
                    widget.onApply(_tempSelectedItems);
                    Navigator.pop(context);
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}