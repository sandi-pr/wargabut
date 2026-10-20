import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../models/event_companion_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/companion_provider.dart';
import '../../../provider/profile_provider.dart';

class CreateCompanionDialog extends StatefulWidget {
  final String eventId;
  final String eventName;
  final EventCompanionModel? companionToEdit;

  const CreateCompanionDialog({
    super.key,
    required this.eventId,
    required this.eventName,
    this.companionToEdit,
  });

  bool get isEdit => companionToEdit != null;

  static Future<bool?> show(
    BuildContext context, {
    required String eventId,
    required String eventName,
    EventCompanionModel? companionToEdit,
  }) {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn || authProvider.user == null) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Login Diperlukan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            companionToEdit != null
                ? 'Untuk mengedit ajakan barengan, kamu perlu masuk (login) ke akun Wargabut terlebih dahulu.'
                : 'Untuk membuat ajakan barengan ke event, kamu perlu masuk (login) ke akun Wargabut terlebih dahulu.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nanti Saja'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx, false);
                context.push('/login');
              },
              icon: const Icon(Icons.login, size: 16),
              label: const Text('Login Sekarang'),
            ),
          ],
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (_) => CreateCompanionDialog(
        eventId: eventId,
        eventName: eventName,
        companionToEdit: companionToEdit,
      ),
    );
  }

  @override
  State<CreateCompanionDialog> createState() => _CreateCompanionDialogState();
}

class _CreateCompanionDialogState extends State<CreateCompanionDialog> {
  final _formKey = GlobalKey<FormState>();

  String _type = 'transit'; // 'transit' | 'venue'
  final _titleController = TextEditingController();
  final _meetingPointController = TextEditingController();
  final _meetingTimeController = TextEditingController();
  final _notesController = TextEditingController();
  final _telegramController = TextEditingController();
  final _instagramController = TextEditingController();

  int _maxMembers = 4;
  String _selectedActivityTag = 'Santai / Ngobrol';
  bool _isSubmitting = false;

  final List<String> _popularStations = [
    'Stasiun Bogor',
    'Stasiun Depok',
    'Stasiun Manggarai',
    'Stasiun Tanah Abang',
    'Stasiun Juanda',
    'Stasiun Jakarta Kota',
    'Stasiun Bekasi',
    'Stasiun Cikarang',
    'Stasiun Serpong',
    'Stasiun Jurang Mangu',
    'Stasiun Cisauk',
    'Stasiun Sudirman',
    'Stasiun Palmerah',
    'MRT Lebak Bulus',
    'MRT Bundaran HI',
  ];

  final List<String> _activityTags = [
    'First-Timer Friendly',
    'Hunting Merch',
    'Cosplay Buddy',
    'Hunting Foto',
    'Santai / Ngobrol',
    'Cari Makan Siang',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      final comp = widget.companionToEdit!;
      _type = comp.type;
      _titleController.text = comp.title;
      _meetingPointController.text = comp.meetingPoint;
      _meetingTimeController.text = comp.meetingTime;
      _notesController.text = comp.notes;
      _telegramController.text = comp.telegramHandle;
      _instagramController.text = comp.instagramHandle;
      _maxMembers = comp.maxMembers;
      if (comp.activityTag.isNotEmpty) {
        _selectedActivityTag = comp.activityTag;
      }
    } else {
      _meetingTimeController.text = 'Sabtu, 08:30 WIB';
      _titleController.text = 'Berangkat KRL Bareng ke ${widget.eventName}';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final profile = context.read<ProfileProvider>().currentProfile;
        if (profile != null && profile.instagram.isNotEmpty && _instagramController.text.isEmpty) {
          setState(() {
            _instagramController.text = profile.instagram;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _meetingPointController.dispose();
    _meetingTimeController.dispose();
    _notesController.dispose();
    _telegramController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _type = newType;
      if (!widget.isEdit) {
        if (_type == 'transit') {
          _titleController.text = 'Berangkat KRL Bareng ke ${widget.eventName}';
          if (_meetingPointController.text.isEmpty) {
            _meetingPointController.text = 'Stasiun Manggarai';
          }
        } else {
          _titleController.text = 'Teman Muter & Hangout di ${widget.eventName}';
          _meetingPointController.text = 'Lobi Utama / Gate Masuk';
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn || authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Silakan login terlebih dahulu untuk mengedit ajakan barengan.'
                : 'Silakan login terlebih dahulu untuk membuat ajakan barengan.',
          ),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    if (widget.isEdit) {
      final companionProvider = context.read<CompanionProvider>();
      final comp = widget.companionToEdit!;
      final isNowFull = _maxMembers > 0 && comp.members.length >= _maxMembers;

      final updateData = {
        'title': _titleController.text.trim(),
        'type': _type,
        'meeting_point': _meetingPointController.text.trim(),
        'meeting_time': _meetingTimeController.text.trim(),
        'activity_tag': _selectedActivityTag,
        'notes': _notesController.text.trim(),
        'max_members': _maxMembers,
        'telegram_handle': _telegramController.text.trim(),
        'instagram_handle': _instagramController.text.trim(),
        'status': isNowFull ? 'full' : 'open',
      };

      final success = await companionProvider.updateCompanion(comp.id, updateData);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ajakan barengan berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui ajakan barengan. Silakan coba lagi.')),
          );
        }
      }
      return;
    }

    final user = authProvider.user!;
    final profileProvider = context.read<ProfileProvider>();
    final currentProfile = profileProvider.currentProfile;

    final creatorUsername = currentProfile?.username.isNotEmpty == true
        ? currentProfile!.username
        : (user.displayName ?? user.email?.split('@').first ?? 'member');
    final creatorDisplayName = currentProfile?.displayName.isNotEmpty == true
        ? currentProfile!.displayName
        : creatorUsername;
    final creatorAvatar = currentProfile?.avatarUrl.isNotEmpty == true
        ? currentProfile!.avatarUrl
        : (user.photoURL ?? '');

    final creatorMember = CompanionMember(
      uid: user.uid,
      username: creatorUsername,
      displayName: creatorDisplayName,
      avatarUrl: creatorAvatar,
      joinedAt: DateTime.now(),
    );

    final companion = EventCompanionModel(
      id: '',
      eventId: widget.eventId,
      eventName: widget.eventName,
      creatorUid: user.uid,
      creatorName: creatorDisplayName,
      creatorUsername: creatorUsername,
      creatorAvatar: creatorAvatar,
      title: _titleController.text.trim(),
      type: _type,
      meetingPoint: _meetingPointController.text.trim(),
      meetingTime: _meetingTimeController.text.trim(),
      activityTag: _selectedActivityTag,
      notes: _notesController.text.trim(),
      maxMembers: _maxMembers,
      members: [creatorMember],
      telegramHandle: _telegramController.text.trim(),
      instagramHandle: _instagramController.text.trim(),
      status: 'open',
      createdAt: DateTime.now(),
    );

    final companionProvider = context.read<CompanionProvider>();
    final newId = await companionProvider.createCompanion(companion);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (newId != null) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajakan barengan berhasil dibuat! Semoga dapat teman yang asik.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat ajakan barengan. Silakan coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Dialog
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isEdit ? 'Edit Ajakan Barengan' : 'Buat Ajakan Barengan',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  widget.eventName,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Isi Form
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Pilihan Tipe Barengan
                        const Text('Pilih Tipe Barengan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'transit',
                              label: Text('🚆 Naik KRL / Transit'),
                            ),
                            ButtonSegment(
                              value: 'venue',
                              label: Text('🎪 Di Lokasi Event'),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (val) => _onTypeChanged(val.first),
                        ),
                        const SizedBox(height: 16),

                        // 2. Judul Ajakan
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Judul Ajakan',
                            hintText: _type == 'transit'
                                ? 'Misal: KRL Bareng dari Stasiun Bogor'
                                : 'Misal: Cari Teman Muter Booth Day 1',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Judul wajib diisi' : null,
                        ),
                        const SizedBox(height: 14),

                        // 3. Titik Kumpul
                        if (_type == 'transit') ...[
                          const Text('Rekomendasi Stasiun KRL Titik Kumpul:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _popularStations.take(6).map((station) {
                              return ActionChip(
                                label: Text(station, style: const TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() => _meetingPointController.text = station);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],

                        TextFormField(
                          controller: _meetingPointController,
                          decoration: InputDecoration(
                            labelText: _type == 'transit' ? 'Titik Kumpul (Stasiun / Halte)' : 'Titik Kumpul di Venue',
                            hintText: _type == 'transit'
                                ? 'Misal: Stasiun Manggarai (Indomaret Pintu Barat)'
                                : 'Misal: Lobi Depan Hall 10 / Mushola',
                            prefixIcon: const Icon(Icons.place_outlined, size: 20),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Titik kumpul wajib diisi' : null,
                        ),
                        const SizedBox(height: 14),

                        // 4. Waktu Kumpul
                        TextFormField(
                          controller: _meetingTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Hari & Waktu Kumpul',
                            hintText: 'Misal: Sabtu, 08:30 WIB',
                            prefixIcon: Icon(Icons.schedule, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Waktu kumpul wajib diisi' : null,
                        ),
                        const SizedBox(height: 14),

                        // 5. Kuota Rombongan
                        Row(
                          children: [
                            const Text('Maksimal Anggota:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: _maxMembers,
                              items: const [
                                DropdownMenuItem(value: 2, child: Text('2 Orang (Berdua)')),
                                DropdownMenuItem(value: 3, child: Text('3 Orang')),
                                DropdownMenuItem(value: 4, child: Text('4 Orang')),
                                DropdownMenuItem(value: 5, child: Text('5 Orang')),
                                DropdownMenuItem(value: 6, child: Text('6 Orang')),
                                DropdownMenuItem(value: 0, child: Text('Bebas / Tanpa Batas')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _maxMembers = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 6. Tag Aktivitas
                        const Text('Fokus Aktivitas:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _activityTags.map((tag) {
                            final isSelected = _selectedActivityTag == tag;
                            return ChoiceChip(
                              label: Text(tag, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedActivityTag = tag),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // 7. Kontak Komunikasi (Telegram & Instagram)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('Kontak Koordinasi (Opsional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Aman & nyaman. Kontak Telegram/Instagram memudahkan teman menghubungi Anda.',
                                style: TextStyle(fontSize: 11, color: theme.hintColor),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _telegramController,
                                decoration: const InputDecoration(
                                  labelText: 'Telegram Username / Link Grup',
                                  hintText: 'Misal: @wibubogor atau t.me/...',
                                  prefixIcon: Icon(Icons.send_rounded, size: 18, color: Colors.lightBlue),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _instagramController,
                                decoration: const InputDecoration(
                                  labelText: 'Instagram Handle',
                                  hintText: 'Misal: @wibuberbudaya',
                                  prefixIcon: Icon(Icons.camera_alt_outlined, size: 18, color: Colors.purple),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 8. Catatan Tambahan
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Catatan Tambahan (Opsional)',
                            hintText: 'Misal: "Santai aja jalan bareng, saya baru pertama kali ke event ini"',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Tombol Aksi Bawah
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: Text(widget.isEdit ? 'Simpan Perubahan' : 'Terbitkan Ajakan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
