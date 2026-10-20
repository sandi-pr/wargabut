import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/cosplay_project_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/cosplay_project_provider.dart';
import '../../../provider/event_provider.dart';
import '../../../provider/profile_provider.dart';

/// Draft internal untuk mengelola slot karakter dalam formulir
class _SlotDraft {
  final String id;
  final TextEditingController characterNameCtrl;
  final TextEditingController characterVersionCtrl;
  final TextEditingController categoryGroupCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController referenceUrlCtrl;
  XFile? imageFile;
  String existingImageUrl;
  String imageAlignment;
  bool isFilledByCreator;
  SlotFilledUser? existingFilledUser;
  String status;

  _SlotDraft({
    required this.id,
    String characterName = '',
    String characterVersion = '',
    String categoryGroup = 'Umum',
    String notes = '',
    String referenceUrl = '',
    this.existingImageUrl = '',
    this.imageAlignment = 'top',
    this.isFilledByCreator = false,
    this.existingFilledUser,
    this.status = 'open',
  })  : characterNameCtrl = TextEditingController(text: characterName),
        characterVersionCtrl = TextEditingController(text: characterVersion),
        categoryGroupCtrl = TextEditingController(text: categoryGroup),
        notesCtrl = TextEditingController(text: notes),
        referenceUrlCtrl = TextEditingController(text: referenceUrl);

  Alignment get parsedAlignment {
    switch (imageAlignment.toLowerCase()) {
      case 'bottom':
        return Alignment.bottomCenter;
      case 'center':
        return Alignment.center;
      case 'top':
      default:
        return Alignment.topCenter;
    }
  }

  void dispose() {
    characterNameCtrl.dispose();
    characterVersionCtrl.dispose();
    categoryGroupCtrl.dispose();
    notesCtrl.dispose();
    referenceUrlCtrl.dispose();
  }
}

class CreateCosplayProjectPage extends StatefulWidget {
  final CosplayProjectModel? projectToEdit;
  final String? projectId;

  const CreateCosplayProjectPage({
    super.key,
    this.projectToEdit,
    this.projectId,
  });

  @override
  State<CreateCosplayProjectPage> createState() => _CreateCosplayProjectPageState();
}

class _CreateCosplayProjectPageState extends State<CreateCosplayProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  // Basic info controllers
  final _titleController = TextEditingController();
  final _seriesTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();

  // Target info controllers
  final _targetDateController = TextEditingController();
  final _targetVenueController = TextEditingController();

  // Contact & coordination controllers
  final _creatorWhatsAppController = TextEditingController();
  final _creatorInstagramController = TextEditingController();
  final _coordinationLinkController = TextEditingController();

  String _seriesCategory = 'anime';
  String _targetType = 'event'; // 'event', 'photoshoot', 'gathering', 'flexible'
  bool _isPrivate = false;

  // Selected event from JEventku
  String? _selectedEventId;
  String? _selectedEventName;
  String? _selectedEventPoster;

  // Banner image
  XFile? _bannerFile;
  String _existingBannerUrl = '';

  // Slot list
  final List<_SlotDraft> _slots = [];

  bool _isSubmitting = false;
  CosplayProjectModel? _existingProject;

  bool get isEditing => widget.projectToEdit != null || widget.projectId != null;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. Pastikan EventProvider telah mengambil data event untuk picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ep = context.read<EventProvider>();
      if (ep.allEvents.isEmpty) {
        ep.fetchData();
      }
    });

    // 2. Isi data default jika sedang mengedit
    if (widget.projectToEdit != null) {
      _existingProject = widget.projectToEdit;
      _populateFromProject(_existingProject!);
    } else if (widget.projectId != null) {
      final project = await context.read<CosplayProjectProvider>().streamProject(widget.projectId!).first;
      if (project != null && mounted) {
        setState(() {
          _existingProject = project;
          _populateFromProject(project);
        });
      }
    } else {
      // Mode Buat Baru: Inisialisasi slot pertama & kontak dari profil user
      _slots.add(_SlotDraft(id: _uuid.v4()));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final profile = context.read<ProfileProvider>().currentProfile;
        if (profile != null) {
          if (_creatorWhatsAppController.text.isEmpty && profile.whatsapp.isNotEmpty) {
            _creatorWhatsAppController.text = profile.whatsapp;
          }
          if (_creatorInstagramController.text.isEmpty && profile.instagram.isNotEmpty) {
            _creatorInstagramController.text = profile.instagram;
          }
        }
      });
    }
  }

  void _populateFromProject(CosplayProjectModel p) {
    _titleController.text = p.title;
    _seriesTitleController.text = p.seriesTitle;
    _seriesCategory = p.seriesCategory;
    _descriptionController.text = p.description;
    _rulesController.text = p.rules;

    _targetType = p.targetType;
    _selectedEventId = p.targetEventId;
    _selectedEventName = p.targetEventName;
    _selectedEventPoster = p.targetEventPoster;
    _targetDateController.text = p.targetDate;
    _targetVenueController.text = p.targetCityOrVenue;

    _creatorWhatsAppController.text = p.creatorWhatsApp;
    _creatorInstagramController.text = p.creatorInstagram;
    _coordinationLinkController.text = p.coordinationLink;
    _isPrivate = p.isPrivate;
    _existingBannerUrl = p.bannerUrl;

    _slots.clear();
    final currentUid = context.read<AuthProvider>().user?.uid;
    for (final s in p.slots) {
      final isSelf = s.filledUser != null && s.filledUser!.uid == currentUid;
      _slots.add(_SlotDraft(
        id: s.slotId,
        characterName: s.characterName,
        characterVersion: s.characterVersion,
        categoryGroup: s.categoryGroup,
        notes: s.notes,
        referenceUrl: s.referenceImageUrl,
        existingImageUrl: s.referenceImageUrl,
        imageAlignment: s.imageAlignment,
        isFilledByCreator: isSelf,
        existingFilledUser: isSelf ? null : s.filledUser,
        status: s.status,
      ));
    }

    if (_slots.isEmpty) {
      _slots.add(_SlotDraft(id: _uuid.v4()));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _seriesTitleController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    _targetDateController.dispose();
    _targetVenueController.dispose();
    _creatorWhatsAppController.dispose();
    _creatorInstagramController.dispose();
    _coordinationLinkController.dispose();
    for (final s in _slots) {
      s.dispose();
    }
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _pickBanner() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _bannerFile = picked);
    }
  }

  Future<void> _pickSlotImage(_SlotDraft slot) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        slot.imageFile = picked;
      });
    }
  }

  void _addSlot() {
    setState(() {
      // Ambil grup kategori slot terakhir sebagai default
      final lastGroup = _slots.isNotEmpty ? _slots.last.categoryGroupCtrl.text : 'Umum';
      _slots.add(_SlotDraft(
        id: _uuid.v4(),
        categoryGroup: lastGroup.isNotEmpty ? lastGroup : 'Umum',
      ));
    });
  }

  void _removeSlot(int index) {
    if (_slots.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projek minimal harus memiliki 1 slot karakter!')),
      );
      return;
    }
    setState(() {
      final removed = _slots.removeAt(index);
      removed.dispose();
    });
  }

  Set<String> _getExistingCategoryGroups() {
    final groups = <String>{};
    for (final s in _slots) {
      final text = s.categoryGroupCtrl.text.trim();
      if (text.isNotEmpty) groups.add(text);
    }
    return groups;
  }

  Future<void> _showEventPicker() async {
    final ep = context.read<EventProvider>();
    final events = ep.allEvents;

    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memuat data event... Mohon tunggu sebentar.')),
      );
      return;
    }

    final searchCtrl = TextEditingController();
    Map<String, dynamic>? selected;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final query = searchCtrl.text.toLowerCase().trim();
            final filtered = events.where((ev) {
              if (query.isEmpty) return true;
              final name = (ev['event_name'] ?? ev['name'] ?? ev['title'] ?? '').toString().toLowerCase();
              final loc = (ev['location'] ?? ev['area'] ?? '').toString().toLowerCase();
              return name.contains(query) || loc.contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Pilih Event dari JEventku'),
              content: SizedBox(
                width: 480,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Cari nama event atau lokasi...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Tidak ada event yang cocok'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (c, idx) {
                                final ev = filtered[idx];
                                final name = (ev['event_name'] ?? ev['name'] ?? ev['title'] ?? 'Event').toString();
                                final date = (ev['date'] ?? ev['date_event'] ?? '').toString();
                                final loc = (ev['location'] ?? ev['area'] ?? '').toString();
                                final poster = EventProvider.extractPosterUrl(ev);
                                final isSelected = selected == ev;

                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: poster.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: poster,
                                            width: 36,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => const Icon(Icons.event, size: 28),
                                          )
                                        : const Icon(Icons.event, size: 28),
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text('$date • $loc', style: const TextStyle(fontSize: 11)),
                                  selected: isSelected,
                                  onTap: () {
                                    setDialogState(() => selected = ev);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          final ev = selected!;
                          final eventId = (ev['id'] ?? ev['event_id'] ?? '').toString();
                          final eventName = (ev['event_name'] ?? ev['name'] ?? ev['title'] ?? '').toString();
                          final date = (ev['date'] ?? ev['date_event'] ?? '').toString();
                          final loc = (ev['location'] ?? ev['area'] ?? '').toString();
                          final poster = EventProvider.extractPosterUrl(ev);

                          setState(() {
                            _selectedEventId = eventId;
                            _selectedEventName = eventName;
                            _selectedEventPoster = poster;
                            if (_targetDateController.text.trim().isEmpty) {
                              _targetDateController.text = date;
                            }
                            if (_targetVenueController.text.trim().isEmpty) {
                              _targetVenueController.text = loc;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                  child: const Text('Pilih Event'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua bidang yang wajib diisi!')),
      );
      return;
    }

    // Validasi minimal 1 karakter dengan nama
    final hasValidSlot = _slots.any((s) => s.characterNameCtrl.text.trim().isNotEmpty);
    if (!hasValidSlot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projek harus memiliki minimal 1 karakter slot yang terisi nama!')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login terlebih dahulu!')),
      );
      return;
    }

    final profile = context.read<ProfileProvider>().currentProfile;
    final projectProvider = context.read<CosplayProjectProvider>();

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload Banner Projek jika ada foto baru
      String finalBannerUrl = _existingBannerUrl;
      if (_bannerFile != null) {
        final uploaded = await projectProvider.uploadImage(
          _bannerFile,
          folder: 'cosplay_projects',
          namePrefix: 'banner_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (uploaded != null) finalBannerUrl = uploaded;
      }

      // 2. Upload gambar referensi slot & susun slot list
      final List<CosplayProjectSlot> finalSlots = [];

      for (final draft in _slots) {
        final charName = draft.characterNameCtrl.text.trim();
        if (charName.isEmpty) continue; // Skip slot kosong

        String refUrl = draft.existingImageUrl;
        if (draft.imageFile != null) {
          final uploadedRef = await projectProvider.uploadImage(
            draft.imageFile,
            folder: 'cosplay_project_slots',
            namePrefix: 'slot_${draft.id}',
          );
          if (uploadedRef != null) refUrl = uploadedRef;
        } else if (draft.referenceUrlCtrl.text.trim().isNotEmpty) {
          refUrl = draft.referenceUrlCtrl.text.trim();
        }

        SlotFilledUser? filledUser;
        String slotStatus = 'open';

        if (draft.isFilledByCreator) {
          // Penyelenggara mengisi karakter ini sendiri
          filledUser = SlotFilledUser(
            uid: auth.user!.uid,
            username: profile?.username ?? (auth.user!.email?.split('@').first ?? 'warga'),
            displayName: profile?.displayName ?? (auth.user!.displayName ?? 'Warga'),
            avatarUrl: profile?.avatarUrl ?? (auth.user!.photoURL ?? ''),
            instagram: profile?.instagram ?? _creatorInstagramController.text.trim(),
            assignedAt: DateTime.now(),
            isExternal: false,
          );
          slotStatus = 'filled';
        } else if (draft.existingFilledUser != null) {
          // Pertahankan user yang sudah diterima sebelumnya saat edit mode
          filledUser = draft.existingFilledUser;
          slotStatus = draft.status.isNotEmpty ? draft.status : 'filled';
        }

        finalSlots.add(CosplayProjectSlot(
          slotId: draft.id,
          characterName: charName,
          characterVersion: draft.characterVersionCtrl.text.trim(),
          categoryGroup: draft.categoryGroupCtrl.text.trim().isEmpty ? 'Umum' : draft.categoryGroupCtrl.text.trim(),
          referenceImageUrl: refUrl,
          imageAlignment: draft.imageAlignment,
          notes: draft.notesCtrl.text.trim(),
          status: slotStatus,
          filledUser: filledUser,
        ));
      }

      // 3. Tentukan status projek
      final totalSlots = finalSlots.length;
      final openSlots = finalSlots.where((s) => s.isOpen).length;
      String projectStatus = 'open';
      if (totalSlots > 0 && openSlots == 0) {
        projectStatus = 'full';
      }

      final creatorName = profile?.displayName ?? (auth.user!.displayName ?? 'Warga');
      final creatorUsername = profile?.username ?? (auth.user!.email?.split('@').first ?? 'warga');
      final creatorAvatar = profile?.avatarUrl ?? (auth.user!.photoURL ?? '');

      if (isEditing && _existingProject != null) {
        // UPDATE PROJEK
        final updatedProject = _existingProject!.copyWith(
          title: _titleController.text.trim(),
          seriesTitle: _seriesTitleController.text.trim(),
          seriesCategory: _seriesCategory,
          bannerUrl: finalBannerUrl,
          description: _descriptionController.text.trim(),
          rules: _rulesController.text.trim(),
          targetType: _targetType,
          targetEventId: _selectedEventId,
          targetEventName: _selectedEventName,
          targetEventPoster: _selectedEventPoster,
          targetDate: _targetDateController.text.trim(),
          targetCityOrVenue: _targetVenueController.text.trim(),
          creatorWhatsApp: _creatorWhatsAppController.text.trim(),
          creatorInstagram: _creatorInstagramController.text.trim(),
          coordinationLink: _coordinationLinkController.text.trim(),
          isPrivate: _isPrivate,
          status: (_existingProject!.status == 'cancelled' || _existingProject!.status == 'completed')
              ? _existingProject!.status
              : projectStatus,
          slots: finalSlots,
        );

        await projectProvider.updateProject(updatedProject);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projek cosplay berhasil diperbarui!'), backgroundColor: Colors.green),
        );
        context.go('/dcosplay/${_existingProject!.id}');
      } else {
        // BUAT PROJEK BARU
        final newProject = CosplayProjectModel(
          id: '',
          title: _titleController.text.trim(),
          seriesTitle: _seriesTitleController.text.trim(),
          seriesCategory: _seriesCategory,
          bannerUrl: finalBannerUrl,
          description: _descriptionController.text.trim(),
          rules: _rulesController.text.trim(),
          targetType: _targetType,
          targetEventId: _selectedEventId,
          targetEventName: _selectedEventName,
          targetEventPoster: _selectedEventPoster,
          targetDate: _targetDateController.text.trim(),
          targetCityOrVenue: _targetVenueController.text.trim(),
          creatorUid: auth.user!.uid,
          creatorName: creatorName,
          creatorUsername: creatorUsername,
          creatorAvatar: creatorAvatar,
          creatorWhatsApp: _creatorWhatsAppController.text.trim(),
          creatorInstagram: _creatorInstagramController.text.trim(),
          status: projectStatus,
          isPrivate: _isPrivate,
          coordinationLink: _coordinationLinkController.text.trim(),
          slots: finalSlots,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final newId = await projectProvider.createProject(newProject);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projek cosplay berhasil dibuat! 🎉'), backgroundColor: Colors.green),
        );
        context.go('/dcosplay/$newId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan projek: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dcosplay');
            }
          },
        ),
        title: Text(isEditing ? 'Edit Projek Cosplay' : 'Buat Projek Cosplay'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: Text(isEditing ? 'Simpan' : 'Terbitkan'),
            ),
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menyimpan projek cosplay & mengunggah gambar...'),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      _buildBannerSection(theme, colorScheme),
                      const SizedBox(height: 20),
                      _buildBasicInfoSection(theme, colorScheme),
                      const SizedBox(height: 20),
                      _buildTargetSection(theme, colorScheme),
                      const SizedBox(height: 20),
                      _buildSlotsSection(theme, colorScheme),
                      const SizedBox(height: 20),
                      _buildCoordinationSection(theme, colorScheme),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.rocket_launch),
                        label: Text(
                          isEditing ? 'Simpan Perubahan Projek' : 'Terbitkan Projekan Sekarang',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- SECTIONS ---

  Widget _buildBannerSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _pickBanner,
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_bannerFile != null)
                kIsWeb
                    ? Image.network(_bannerFile!.path, fit: BoxFit.cover)
                    : Image.file(File(_bannerFile!.path), fit: BoxFit.cover)
              else if (_existingBannerUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: _existingBannerUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        'Unggah Foto Banner Projek (Opsional)',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rekomendasi rasio 16:9 atau banner horizontal',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              if (_bannerFile != null || _existingBannerUrl.isNotEmpty)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Ganti Banner', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text('Informasi Projek & Seri', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Judul Projek
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Projekan *',
                hintText: 'Misal: Projek Archon Squad Comifuro 19',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul projekan wajib diisi' : null,
            ),
            const SizedBox(height: 14),

            // Judul Seri & Kategori
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                final seriesTitleField = TextFormField(
                  controller: _seriesTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Seri / Anime / Game *',
                    hintText: 'Misal: Genshin Impact, Frieren, Solo Leveling',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul seri wajib diisi' : null,
                );

                final categoryDropdown = DropdownButtonFormField<String>(
                  initialValue: _seriesCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Seri',
                    border: OutlineInputBorder(),
                  ),
                  items: CosplayProjectProvider.categoryOptions
                      .where((c) => c['id'] != 'semua')
                      .map((c) => DropdownMenuItem(
                            value: c['id']!,
                            child: Text(c['label']!, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _seriesCategory = val);
                  },
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      seriesTitleField,
                      const SizedBox(height: 12),
                      categoryDropdown,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: seriesTitleField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: categoryDropdown),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Deskripsi Projek
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Projekan',
                hintText: 'Ceritakan vibe, rencana, atau gambaran projekan cosplay ini...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),

            // Syarat & Ketentuan / Rules
            TextFormField(
              controller: _rulesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Syarat & Ketentuan (Rules)',
                hintText: 'Misal: Dresscode rapi, komitmen hadir tepat waktu, patungan fotografer...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text('Target & Lokasi Pelaksanaan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),

            // Tipe Target (Pilihan Praktis)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('🎪 Event Jejepangan'),
                  selected: _targetType == 'event',
                  onSelected: (val) => setState(() => _targetType = 'event'),
                ),
                ChoiceChip(
                  label: const Text('📸 Photoshoot'),
                  selected: _targetType == 'photoshoot',
                  onSelected: (val) => setState(() => _targetType = 'photoshoot'),
                ),
                ChoiceChip(
                  label: const Text('☕ Gathering / Nobar'),
                  selected: _targetType == 'gathering',
                  onSelected: (val) => setState(() => _targetType = 'gathering'),
                ),
                ChoiceChip(
                  label: const Text('🤝 Fleksibel / Diskusi'),
                  selected: _targetType == 'flexible',
                  onSelected: (val) => setState(() => _targetType = 'flexible'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Jika tipe Target adalah EVENT, tampilkan selector JEventku
            if (_targetType == 'event') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.celebration, color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Target Event Jejepangan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _showEventPicker,
                          icon: const Icon(Icons.search, size: 16),
                          label: Text(_selectedEventId != null ? 'Ganti Event' : 'Pilih dari JEventku'),
                        ),
                      ],
                    ),
                    if (_selectedEventName != null && _selectedEventName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _selectedEventPoster != null && _selectedEventPoster!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _selectedEventPoster!,
                                  width: 44,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.event, size: 36),
                                )
                              : const Icon(Icons.event, size: 36),
                        ),
                        title: Text(
                          _selectedEventName!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${_targetDateController.text} • ${_targetVenueController.text}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Hapus Event Terpilih',
                          onPressed: () {
                            setState(() {
                              _selectedEventId = null;
                              _selectedEventName = null;
                              _selectedEventPoster = null;
                            });
                          },
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pilih event dari database JEventku untuk otomatis mengisi jadwal & tempat.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Input Tanggal & Venue Manual
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                final dateField = TextFormField(
                  controller: _targetDateController,
                  decoration: InputDecoration(
                    labelText: _targetType == 'event' ? 'Tanggal Event' : 'Target Tanggal / Bulan',
                    hintText: 'Misal: 15-16 Nov 2026 atau Akhir Tahun',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_month),
                  ),
                );

                final venueField = TextFormField(
                  controller: _targetVenueController,
                  decoration: InputDecoration(
                    labelText: _targetType == 'photoshoot' ? 'Studio / Lokasi Foto' : 'Kota / Venue',
                    hintText: 'Misal: ICE BSD Tangerang atau Studio Zen Jakbar',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.pin_drop_outlined),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      dateField,
                      const SizedBox(height: 12),
                      venueField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: dateField),
                    const SizedBox(width: 12),
                    Expanded(child: venueField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotsSection(ThemeData theme, ColorScheme colorScheme) {
    final existingGroups = _getExistingCategoryGroups();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.diversity_3, color: colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Daftar Karakter Slot (${_slots.length})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Karakter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tentukan karakter apa saja yang dicari. Anda juga bisa mengklaim karakter yang Anda isi sendiri.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: 16),

            // Daftar Slot Items
            ..._slots.asMap().entries.map((entry) {
              final index = entry.key;
              final slot = entry.value;
              return _buildSlotCard(index, slot, theme, colorScheme, existingGroups);
            }),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addSlot,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Karakter Lainnya'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotCard(
    int index,
    _SlotDraft slot,
    ThemeData theme,
    ColorScheme colorScheme,
    Set<String> existingGroups,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: slot.isFilledByCreator
              ? Colors.green.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: slot.isFilledByCreator ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Slot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Karakter #${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (slot.isFilledByCreator) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Diisi oleh Anda',
                        style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else if (slot.existingFilledUser != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Terisi (@${slot.existingFilledUser!.username})',
                        style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                tooltip: 'Hapus Slot',
                onPressed: () => _removeSlot(index),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nama Karakter & Versi Kostum (Responsif)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              final nameField = TextFormField(
                controller: slot.characterNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Karakter *',
                  hintText: 'Misal: Raiden Shogun, Fern, Gojo',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama karakter wajib' : null,
              );

              final versionField = TextFormField(
                controller: slot.characterVersionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Versi Kostum (Opsional)',
                  hintText: 'Misal: Default, Maid, Kimono',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 10),
                    versionField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: nameField),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: versionField),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Kategori / Grup Karakter
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: slot.categoryGroupCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Grup / Faksi Karakter',
                    hintText: 'Misal: Archons, Fatui, Party Frieren, Umum',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          // Chip Rekomendasi Grup yang sudah pernah diketik
          if (existingGroups.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: existingGroups.map((group) {
                final isCurrent = slot.categoryGroupCtrl.text.trim() == group;
                return ActionChip(
                  label: Text(group, style: const TextStyle(fontSize: 11)),
                  avatar: isCurrent ? const Icon(Icons.check, size: 14) : null,
                  onPressed: () {
                    setState(() {
                      slot.categoryGroupCtrl.text = group;
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),

          // Foto Referensi Kostum / Karakter
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail preview dengan click full image
              Tooltip(
                message: slot.imageFile != null || slot.existingImageUrl.isNotEmpty
                    ? 'Klik untuk melihat gambar penuh'
                    : 'Pilih foto referensi',
                child: InkWell(
                  onTap: () {
                    if (slot.imageFile != null || slot.existingImageUrl.isNotEmpty) {
                      _showFullImageDialog(
                        context,
                        file: slot.imageFile,
                        url: slot.existingImageUrl,
                        charName: slot.characterNameCtrl.text.isNotEmpty
                            ? slot.characterNameCtrl.text
                            : 'Karakter #${index + 1}',
                      );
                    } else {
                      _pickSlotImage(slot);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        slot.imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? Image.network(slot.imageFile!.path, fit: BoxFit.cover, alignment: slot.parsedAlignment)
                                    : Image.file(File(slot.imageFile!.path), fit: BoxFit.cover, alignment: slot.parsedAlignment),
                              )
                            : slot.existingImageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: slot.existingImageUrl,
                                      fit: BoxFit.cover,
                                      alignment: slot.parsedAlignment,
                                      errorWidget: (_, __, ___) => const Icon(Icons.image, size: 24),
                                    ),
                                  )
                                : const Center(child: Icon(Icons.add_a_photo, size: 22)),
                        if (slot.imageFile != null || slot.existingImageUrl.isNotEmpty)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.fullscreen, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickSlotImage(slot),
                          icon: const Icon(Icons.photo_library, size: 15),
                          label: Text(
                            slot.imageFile != null || slot.existingImageUrl.isNotEmpty
                                ? 'Ganti Foto'
                                : 'Pilih Foto Referensi',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                        if (slot.imageFile != null || slot.existingImageUrl.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            tooltip: 'Hapus Foto',
                            onPressed: () {
                              setState(() {
                                slot.imageFile = null;
                                slot.existingImageUrl = '';
                                slot.referenceUrlCtrl.clear();
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unggah foto art/kostum. Klik kotak untuk melihat full.',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Pilihan Fokus Alignment jika ada foto
          if (slot.imageFile != null || slot.existingImageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Fokus Preview:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        ChoiceChip(
                          label: const Text('⬆️ Atas (Wajah)', style: TextStyle(fontSize: 10)),
                          selected: slot.imageAlignment == 'top',
                          visualDensity: VisualDensity.compact,
                          onSelected: (val) {
                            if (val) setState(() => slot.imageAlignment = 'top');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('⏺️ Tengah', style: TextStyle(fontSize: 10)),
                          selected: slot.imageAlignment == 'center',
                          visualDensity: VisualDensity.compact,
                          onSelected: (val) {
                            if (val) setState(() => slot.imageAlignment = 'center');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('⬇️ Bawah', style: TextStyle(fontSize: 10)),
                          selected: slot.imageAlignment == 'bottom',
                          visualDensity: VisualDensity.compact,
                          onSelected: (val) {
                            if (val) setState(() => slot.imageAlignment = 'bottom');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Catatan Slot
          TextFormField(
            controller: slot.notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan Khusus Slot (Opsional)',
              hintText: 'Misal: Diutamakan punya prop senjata, proporsi tinggi menyesuaikan',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),

          // Checkbox: Saya yang mengisi karakter ini
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Saya sendiri yang cosplay karakter ini',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Slot akan langsung ditandai terisi dengan biodata profil Wargabut Anda.',
              style: TextStyle(fontSize: 11),
            ),
            value: slot.isFilledByCreator,
            onChanged: (val) {
              setState(() {
                slot.isFilledByCreator = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinationSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text('Akses & Koordinasi Projek', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),

            // Link Grup Koordinasi
            TextFormField(
              controller: _coordinationLinkController,
              decoration: const InputDecoration(
                labelText: 'Tautan Grup Koordinasi (WhatsApp / Discord / LINE)',
                hintText: 'https://chat.whatsapp.com/... atau https://discord.gg/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🔒 Terlindungi: Tautan koordinasi HANYA akan tampil bagi cosplayer yang sudah diterima di dalam projekan.',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kontak Penyelenggara (Responsif)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                final waField = TextFormField(
                  controller: _creatorWhatsAppController,
                  decoration: const InputDecoration(
                    labelText: 'No. WhatsApp Penyelenggara',
                    hintText: '081234567890',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                );

                final igField = TextFormField(
                  controller: _creatorInstagramController,
                  decoration: const InputDecoration(
                    labelText: 'Instagram Penyelenggara',
                    hintText: '@username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.camera_alt_outlined),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      waField,
                      const SizedBox(height: 12),
                      igField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: waField),
                    const SizedBox(width: 12),
                    Expanded(child: igField),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Private toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Projekan Bersifat Privat', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Hanya orang yang memiliki link langsung yang dapat melihat projekan ini.'),
              value: _isPrivate,
              onChanged: (val) => setState(() => _isPrivate = val),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImageDialog(
    BuildContext context, {
    XFile? file,
    String? url,
    required String charName,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: file != null
                    ? (kIsWeb
                        ? Image.network(file.path, fit: BoxFit.contain)
                        : Image.file(File(file.path), fit: BoxFit.contain))
                    : (url != null && url.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                            ),
                          )
                        : const SizedBox()),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  charName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
