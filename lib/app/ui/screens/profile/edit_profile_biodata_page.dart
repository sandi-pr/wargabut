import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/event_provider.dart';
import '../../../provider/profile_provider.dart';
import '../../../utils/event_date_utils.dart';
import '../../components/community/attending_event_poster.dart';

class EditProfileBiodataPage extends StatefulWidget {
  const EditProfileBiodataPage({super.key});

  @override
  State<EditProfileBiodataPage> createState() => _EditProfileBiodataPageState();
}

class _EditProfileBiodataPageState extends State<EditProfileBiodataPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _tagInputController = TextEditingController();

  String _profileVisibility = 'global';
  final List<String> _customTags = [];
  final List<String> _hobbies = [];
  final List<CosplanItem> _cosplans = [];
  final List<UserAttendingEvent> _attendingEvents = [];

  XFile? _newAvatarFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ep = context.read<EventProvider>();
      if (ep.allEvents.isEmpty) {
        ep.fetchData();
      }
    });
  }

  void _loadExistingProfile() {
    final profile = context.read<ProfileProvider>().currentProfile;
    if (profile != null) {
      _nameController.text = profile.displayName;
      _cityController.text = profile.city;
      _bioController.text = profile.bio;
      _instagramController.text = profile.instagram;
      _tiktokController.text = profile.tiktok;
      _profileVisibility = profile.profileVisibility;
      _customTags.addAll(profile.customTags);
      _hobbies.addAll(profile.hobbies);
      _cosplans.addAll(profile.cosplans);

      _attendingEvents.clear();
      final ep = context.read<EventProvider>();
      for (final ev in profile.upcomingAttendingEvents) {
        final latestPoster = ep.getLatestPosterUrl(ev.eventId, fallback: ev.eventPoster);
        _attendingEvents.add(ev.copyWith(
          eventPoster: latestPoster.isNotEmpty ? latestPoster : ev.eventPoster,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _newAvatarFile = picked);
    }
  }

  void _addTag() {
    String text = _tagInputController.text.trim();
    if (text.isEmpty) return;
    if (!text.startsWith('#')) text = '#$text';
    if (!_customTags.contains(text)) {
      setState(() {
        _customTags.add(text);
        _tagInputController.clear();
      });
    }
  }

  void _showAddCosplanDialog() {
    final charController = TextEditingController();
    final seriesController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Cosplan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: charController,
              decoration: const InputDecoration(
                labelText: 'Nama Karakter *',
                hintText: 'Misal: Frieren, Anya, Gojo',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: seriesController,
              decoration: const InputDecoration(
                labelText: 'Judul Anime / Game / Manga',
                hintText: 'Misal: Sousou no Frieren, Jujutsu Kaisen',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(
                labelText: 'Target Event / Wilayah (Opsional)',
                hintText: 'Misal: Impactnation 2026, Comifuro, Event Bogor',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (charController.text.trim().isNotEmpty) {
                setState(() {
                  _cosplans.add(CosplanItem(
                    character: charController.text.trim(),
                    series: seriesController.text.trim(),
                    targetEventOrCity: targetController.text.trim(),
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog() {
    final searchCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    Map<String, dynamic>? selectedEvent;
    String filterTerm = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final allEvents = context.watch<EventProvider>().allEvents;
          final filtered = allEvents.where((e) {
            final dateStr = (e['date'] ?? e['date_event'] ?? '').toString();
            // Jangan tampilkan event yang sudah terlewat
            if (EventDateUtils.isEventPast(dateStr)) return false;

            if (filterTerm.isEmpty) return true;
            final name = (e['event_name'] ?? e['name'] ?? e['title'] ?? '').toString().toLowerCase();
            final loc = (e['location'] ?? '').toString().toLowerCase();
            final area = (e['area'] ?? '').toString().toLowerCase();
            final q = filterTerm.toLowerCase();
            return name.contains(q) || loc.contains(q) || area.contains(q);
          }).toList();

          final sortedEvents = EventDateUtils.sortEventsByClosestDate(
            filtered,
            dateExtractor: (e) => (e['date'] ?? e['date_event'] ?? '').toString(),
            filterPast: true,
          );

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.event_available, color: Colors.blue),
                SizedBox(width: 8),
                Text('Pilih Event JEventku'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari event atau lokasi...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: filterTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setDialogState(() => filterTerm = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setDialogState(() => filterTerm = val),
                  ),
                  const SizedBox(height: 12),
                  const Text('Pilih Event:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: sortedEvents.isEmpty
                        ? const Center(child: Text('Event tidak ditemukan.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: sortedEvents.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final ev = sortedEvents[idx];
                              final isSelected = selectedEvent?['id'] == ev['id'];
                              final name = (ev['event_name'] ?? ev['name'] ?? ev['title'] ?? 'Event').toString();
                              final date = (ev['date'] ?? ev['date_event'] ?? '').toString();
                              final loc = (ev['location'] ?? '').toString();

                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text('$date • $loc', style: const TextStyle(fontSize: 11)),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                                onTap: () {
                                  setDialogState(() => selectedEvent = ev);
                                },
                              );
                            },
                          ),
                  ),
                  if (selectedEvent != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Dipilih: ${selectedEvent!['event_name'] ?? selectedEvent!['name'] ?? selectedEvent!['title']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Kehadiran (Opsional)',
                        hintText: 'Misal: Cosplay Frieren hari Sabtu, Hunting merch',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(
                onPressed: selectedEvent == null
                    ? null
                    : () {
                        final ev = selectedEvent!;
                        final eventId = (ev['id'] ?? ev['event_id'] ?? '').toString();
                        if (eventId.isEmpty) return;

                        // Cek apakah sudah ada di list
                        if (_attendingEvents.any((e) => e.eventId == eventId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Event ini sudah ada dalam daftar rencana Anda.')),
                          );
                          Navigator.pop(ctx);
                          return;
                        }

                        // Ekstrak poster terbaru
                        String posterUrl = EventProvider.extractPosterUrl(ev);

                        setState(() {
                          _attendingEvents.add(UserAttendingEvent(
                            eventId: eventId,
                            eventName: (ev['event_name'] ?? ev['name'] ?? ev['title'] ?? 'Event').toString(),
                            eventDate: (ev['date'] ?? ev['date_event'] ?? '').toString(),
                            eventLocation: (ev['location'] ?? '').toString(),
                            eventPoster: posterUrl,
                            notes: notesCtrl.text.trim(),
                          ));
                          final sorted = EventDateUtils.sortEventsByClosestDate(
                            _attendingEvents,
                            dateExtractor: (e) => e.eventDate,
                            filterPast: true,
                          );
                          _attendingEvents.clear();
                          _attendingEvents.addAll(sorted);
                        });

                        Navigator.pop(ctx);
                      },
                child: const Text('Tambahkan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = context.read<ProfileProvider>();
    final ep = context.read<EventProvider>();

    // Bersihkan event lampau dan sinkronisasi poster terbaru
    final List<UserAttendingEvent> cleanUpcoming = [];
    for (final ev in _attendingEvents) {
      if (!ev.isPast) {
        final latestPoster = ep.getLatestPosterUrl(ev.eventId, fallback: ev.eventPoster);
        cleanUpcoming.add(ev.copyWith(
          eventPoster: latestPoster.isNotEmpty ? latestPoster : ev.eventPoster,
        ));
      }
    }

    final success = await profileProvider.saveProfile(
      displayName: _nameController.text,
      city: _cityController.text,
      bio: _bioController.text,
      instagram: _instagramController.text,
      tiktok: _tiktokController.text,
      profileVisibility: _profileVisibility,
      customTags: _customTags,
      hobbies: _hobbies,
      cosplans: _cosplans,
      attendingEvents: cleanUpcoming,
      avatarImageFile: _newAvatarFile,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biodata berhasil disimpan!'), backgroundColor: Colors.green),
      );
      final username = profileProvider.currentProfile?.username;
      if (username != null) {
        context.push('/@$username');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileProvider.errorMessage ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Wargabut?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar (Logout)'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Berhasil keluar akun (logout)',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/komunitas');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileProvider = context.watch<ProfileProvider>();
    final currentProfile = profileProvider.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kartu Biodata Saya'),
        actions: [
          if (currentProfile != null && currentProfile.username.isNotEmpty)
            TextButton.icon(
              onPressed: () => context.push('/@${currentProfile.username}'),
              icon: const Icon(Icons.remove_red_eye, size: 16),
              label: const Text('Lihat Kartu'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: _newAvatarFile != null
                              ? NetworkImage(_newAvatarFile!.path)
                              : (currentProfile?.avatarUrl.isNotEmpty == true
                                  ? NetworkImage(currentProfile!.avatarUrl)
                                  : null),
                          child: (_newAvatarFile == null && (currentProfile?.avatarUrl.isEmpty ?? true))
                              ? Icon(Icons.person, size: 54, color: colorScheme.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              onPressed: _pickAvatar,
                              tooltip: 'Ubah Foto Profil / Cosplay',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      '@${currentProfile?.username ?? "user"}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Informasi Utama
                  Text('Informasi Identitas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Panggilan (Nickname) *',
                      hintText: 'Contoh: Yuki, Sandi, Riko',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama panggilan wajib diisi' : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Asal Kota / Domisili *',
                      hintText: 'Contoh: Bogor, Jakarta Selatan, Bandung',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Asal kota wajib diisi' : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _bioController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Bio Singkat',
                      hintText: 'Contoh: Cosplayer pemula & penikmat anime slice of life.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Custom Tag / Persona
                  Text('Role & Custom Tags', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Tambahkan persona bebas, contoh: #Cosplayer, #Fotografer, #WibuSantai',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagInputController,
                          decoration: const InputDecoration(
                            hintText: 'Ketik tag baru...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _addTag,
                        child: const Text('Tambah'),
                      ),
                    ],
                  ),

                  if (_customTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _customTags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          onDeleted: () {
                            setState(() => _customTags.remove(tag));
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Cosplan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rencana Cosplay (Cosplan)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _showAddCosplanDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah Cosplan'),
                      ),
                    ],
                  ),
                  if (_cosplans.isEmpty)
                    Text('Belum ada cosplan yang ditambahkan.', style: TextStyle(color: colorScheme.outline, fontStyle: FontStyle.italic))
                  else
                    Column(
                      children: _cosplans.map((c) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(Icons.theater_comedy, color: colorScheme.primary),
                            title: Text(c.character, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${c.series}${c.targetEventOrCity.isNotEmpty ? " • ${c.targetEventOrCity}" : ""}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () {
                                setState(() => _cosplans.remove(c));
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // Event yang Akan Dihadiri Selanjutnya
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Event yang Akan Dihadiri', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _showAddEventDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah Event'),
                      ),
                    ],
                  ),
                  if (_attendingEvents.isEmpty)
                    Text('Belum ada agenda event yang ditambahkan.', style: TextStyle(color: colorScheme.outline, fontStyle: FontStyle.italic))
                  else
                    Column(
                      children: _attendingEvents.map((ev) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: AttendingEventPoster(
                              eventId: ev.eventId,
                              initialPosterUrl: ev.eventPoster,
                              width: 40,
                              height: 52,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            title: Text(ev.eventName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (ev.eventDate.isNotEmpty || ev.eventLocation.isNotEmpty)
                                  Text(
                                    '${ev.eventDate}${ev.eventDate.isNotEmpty && ev.eventLocation.isNotEmpty ? " • " : ""}${ev.eventLocation}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (ev.notes.isNotEmpty)
                                  Text(
                                    'Catatan: ${ev.notes}',
                                    style: TextStyle(fontSize: 11, color: colorScheme.primary, fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () {
                                setState(() => _attendingEvents.remove(ev));
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // Kontak & Media Sosial
                  Text('Kontak & Media Sosial', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _instagramController,
                    decoration: const InputDecoration(
                      labelText: 'Username Instagram',
                      hintText: 'Contoh: @yuki_cosplay',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.camera_alt),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _tiktokController,
                    decoration: const InputDecoration(
                      labelText: 'Username TikTok (Opsional)',
                      hintText: 'Contoh: @yuki_cosplay atau username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.music_note),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pengaturan Privasi Profil (Global, Komunitas, Privat)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.public, size: 20, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Pengaturan Privasi Profil Biodata',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pilih di mana profil biodata Anda dapat ditemukan oleh pengguna lain:',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _profileVisibility,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          selectedItemBuilder: (context) {
                            return [
                              const Text('🌐 Global (Direktori & Komunitas)', overflow: TextOverflow.ellipsis, maxLines: 1),
                              const Text('👥 Hanya Komunitas yang Diikuti', overflow: TextOverflow.ellipsis, maxLines: 1),
                              const Text('🔒 Privat (Hanya Lewat Tautan)', overflow: TextOverflow.ellipsis, maxLines: 1),
                            ];
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'global',
                              child: Text('🌐 Global (Tampil di Direktori & Komunitas)', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: 'community',
                              child: Text('👥 Hanya Komunitas (Grup yang diikuti)', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('🔒 Privat (Disembunyikan dari pencarian)', overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _profileVisibility = val);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: profileProvider.isLoading ? null : _save,
                      child: profileProvider.isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan Biodata Member', style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Hubungkan Smartwatch Wear OS
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/wear'),
                      icon: const Icon(Icons.watch, size: 20),
                      label: const Text('Hubungkan Smartwatch (Wear OS)'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tombol Logout
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      label: const Text('Keluar dari Akun (Logout)', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
