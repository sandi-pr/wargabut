import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/community_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/community_provider.dart';
import '../../../provider/event_provider.dart';

class AddCommunityEventDialog extends StatefulWidget {
  /// Komunitas target (jika dibuka dari halaman Komunitas)
  final CommunityModel? community;

  /// Event target (jika dibuka langsung dari halaman Detail Event JEventku)
  final Map<String, dynamic>? preselectedEvent;

  const AddCommunityEventDialog({
    super.key,
    this.community,
    this.preselectedEvent,
  });

  static Future<bool?> show(
    BuildContext context, {
    CommunityModel? community,
    Map<String, dynamic>? preselectedEvent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AddCommunityEventDialog(
        community: community,
        preselectedEvent: preselectedEvent,
      ),
    );
  }

  @override
  State<AddCommunityEventDialog> createState() => _AddCommunityEventDialogState();
}

class _AddCommunityEventDialogState extends State<AddCommunityEventDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Map<String, dynamic>? _selectedEvent;
  CommunityModel? _selectedCommunity;

  List<CommunityModel> _managedCommunities = [];
  bool _isLoadingCommunities = false;
  bool _isSubmitting = false;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _selectedEvent = widget.preselectedEvent;
    _selectedCommunity = widget.community;

    // Pastikan event provider sudah memuat data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ep = context.read<EventProvider>();
      if (ep.allEvents.isEmpty) {
        ep.fetchData();
      }
      if (widget.community == null) {
        _loadManagedCommunities();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadManagedCommunities() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _isLoadingCommunities = true);
    final cp = context.read<CommunityProvider>();
    final list = await cp.getCommunitiesManagedByUser(auth.user!.uid);

    if (mounted) {
      setState(() {
        _managedCommunities = list;
        _isLoadingCommunities = false;
        if (list.isNotEmpty && _selectedCommunity == null) {
          _selectedCommunity = list.first;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    final targetCommunity = _selectedCommunity ?? widget.community;
    if (targetCommunity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih komunitas terlebih dahulu.')),
      );
      return;
    }

    if (_selectedEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih event yang akan dihadiri.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final cp = context.read<CommunityProvider>();
    final error = await cp.addEventToCommunity(
      community: targetCommunity,
      currentUid: auth.user!.uid,
      eventData: _selectedEvent!,
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event "${_selectedEvent!['event_name'] ?? 'Event'}" berhasil ditambahkan ke agenda ${targetCommunity.name}!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allEvents = context.watch<EventProvider>().allEvents;

    final filteredEvents = allEvents.where((e) {
      if (_searchTerm.isEmpty) return true;
      final name = (e['event_name'] ?? e['title'] ?? '').toString().toLowerCase();
      final loc = (e['location'] ?? '').toString().toLowerCase();
      final area = (e['area'] ?? '').toString().toLowerCase();
      final q = _searchTerm.toLowerCase();
      return name.contains(q) || loc.contains(q) || area.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          children: [
            // Header Dialog
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.event_available, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tambah Agenda Event Komunitas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Pilih Komunitas (Jika belum ditentukan atau dari halaman Event)
                    if (widget.community == null) ...[
                      Text(
                        'Pilih Komunitas Anda:',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingCommunities)
                        const LinearProgressIndicator()
                      else if (_managedCommunities.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: const Text(
                            'Anda belum terdaftar sebagai Founder atau Admin pada komunitas manapun.',
                            style: TextStyle(color: Colors.brown, fontSize: 13),
                          ),
                        )
                      else
                        DropdownButtonFormField<CommunityModel>(
                          initialValue: _selectedCommunity,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: Icon(Icons.groups),
                          ),
                          items: _managedCommunities.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c.name, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedCommunity = val);
                          },
                        ),
                      const SizedBox(height: 16),
                    ],

                    // 2. Pilih Event (Jika belum ditentukan)
                    Text(
                      'Event JEventku:',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (widget.preselectedEvent != null) ...[
                      // Sudah ditentukan dari halaman event
                      _buildSelectedEventCard(widget.preselectedEvent!),
                    ] else ...[
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari nama event atau kota...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchTerm = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() => _searchTerm = val),
                      ),
                      const SizedBox(height: 10),

                      // List Event
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: filteredEvents.isEmpty
                            ? const Center(
                                child: Text('Event tidak ditemukan.', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                itemCount: filteredEvents.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final ev = filteredEvents[idx];
                                  final isSelected = _selectedEvent?['id'] == ev['id'];
                                  final name = ev['event_name'] ?? ev['title'] ?? 'Event';
                                  final date = ev['date'] ?? ev['date_event'] ?? '';
                                  final loc = ev['location'] ?? '';

                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('$date • $loc', maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: isSelected
                                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                                        : const Icon(Icons.circle_outlined, size: 18),
                                    onTap: () {
                                      setState(() => _selectedEvent = ev);
                                    },
                                  );
                                },
                              ),
                      ),
                      if (_selectedEvent != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Dipilih: ${_selectedEvent!['event_name'] ?? _selectedEvent!['title']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),

                    // 3. Catatan Kehadiran (Opsional)
                    Text(
                      'Catatan Kehadiran Komunitas (Opsional):',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Misal: Buka booth di Hall B / Kumpul bareng member jam 13:00 / Cosplay squad',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSubmitting || (_selectedEvent == null) || (_selectedCommunity == null && widget.community == null)
                        ? null
                        : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_task),
                    label: const Text('Simpan ke Agenda'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedEventCard(Map<String, dynamic> ev) {
    final name = ev['event_name'] ?? ev['title'] ?? 'Event';
    final date = ev['date'] ?? ev['date_event'] ?? '-';
    final loc = ev['location'] ?? '-';

    String posterUrl = '';
    if (ev['posters'] is List && (ev['posters'] as List).isNotEmpty) {
      final posters = ev['posters'] as List;
      final mainP = posters.firstWhere((p) => p is Map && p['is_main'] == true, orElse: () => posters[0]);
      if (mainP is Map) posterUrl = mainP['url']?.toString() ?? '';
    }
    if (posterUrl.isEmpty) {
      posterUrl = ev['poster']?.toString() ?? ev['poster_url']?.toString() ?? '';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (posterUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  posterUrl,
                  width: 50,
                  height: 65,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40),
                ),
              )
            else
              Container(
                width: 50,
                height: 65,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.event, color: Colors.grey),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(date, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(loc, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
