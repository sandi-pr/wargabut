import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/community_model.dart';
import '../../../provider/community_provider.dart';
import '../../../provider/profile_provider.dart';

class CreateCommunityPage extends StatefulWidget {
  final CommunityModel? communityToEdit;
  final String? communitySlug;

  const CreateCommunityPage({
    super.key,
    this.communityToEdit,
    this.communitySlug,
  });

  @override
  State<CreateCommunityPage> createState() => _CreateCommunityPageState();
}

class _CreateCommunityPageState extends State<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();

  final List<String> _selectedCategories = [];
  XFile? _logoImage;
  XFile? _bannerImage;
  final ImagePicker _picker = ImagePicker();

  CommunityModel? _community;
  bool _isInitLoading = false;

  bool get isEditing => widget.communityToEdit != null || widget.communitySlug != null;

  @override
  void initState() {
    super.initState();
    if (widget.communityToEdit != null) {
      _community = widget.communityToEdit;
      _populateFields(_community!);
    } else if (widget.communitySlug != null) {
      _loadCommunity(widget.communitySlug!);
    }
  }

  void _populateFields(CommunityModel c) {
    _nameController.text = c.name;
    _cityController.text = c.cityOrArea;
    _shortDescController.text = c.shortDesc;
    _descriptionController.text = c.description;
    _instagramController.text = c.instagram;
    _tiktokController.text = c.tiktok;
    _selectedCategories.clear();
    _selectedCategories.addAll(c.categories);
  }

  Future<void> _loadCommunity(String slug) async {
    setState(() => _isInitLoading = true);
    final provider = context.read<CommunityProvider>();
    final c = await provider.getCommunityBySlug(slug);
    if (mounted) {
      setState(() {
        _community = c;
        if (c != null) _populateFields(c);
        _isInitLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _shortDescController.dispose();
    _descriptionController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _logoImage = picked;
      });
    }
  }

  Future<void> _pickBanner() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _bannerImage = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 kategori komunitas!')),
      );
      return;
    }

    final communityProvider = context.read<CommunityProvider>();

    // Mode Edit Komunitas
    if (isEditing && _community != null) {
      final error = await communityProvider.updateCommunity(
        communityId: _community!.id,
        name: _nameController.text,
        cityOrArea: _cityController.text,
        shortDesc: _shortDescController.text,
        description: _descriptionController.text,
        instagram: _instagramController.text,
        tiktok: _tiktokController.text,
        categories: _selectedCategories,
        logoImage: _logoImage,
        bannerImage: _bannerImage,
        existingLogoUrl: _community!.logoUrl,
        existingBannerUrl: _community!.bannerUrl,
      );

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informasi komunitas berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/komunitas/${_community!.id}');
      }
      return;
    }

    // Mode Daftar Komunitas Baru
    final profileProvider = context.read<ProfileProvider>();
    final userProfile = profileProvider.currentProfile;
    if (userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus melengkapi profil terlebih dahulu.')),
      );
      return;
    }

    final error = await communityProvider.createCommunity(
      name: _nameController.text,
      cityOrArea: _cityController.text,
      shortDesc: _shortDescController.text,
      description: _descriptionController.text,
      instagram: _instagramController.text,
      tiktok: _tiktokController.text,
      categories: _selectedCategories,
      creatorProfile: userProfile,
      logoImage: _logoImage,
      bannerImage: _bannerImage,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Pendaftaran Berhasil!'),
            ],
          ),
          content: const Text(
            'Komunitas Anda telah berhasil didaftarkan. Status saat ini adalah "Menunggu Verifikasi" dan akan ditinjau oleh Admin Wargabut sebelum tampil di direktori publik.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/komunitas');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final communityProvider = context.watch<CommunityProvider>();

    if (_isInitLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Komunitas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Informasi Komunitas' : 'Daftarkan Komunitas Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isEditing ? Icons.edit_note : Icons.info_outline,
                          color: colorScheme.secondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEditing
                                ? 'Perbarui informasi profil, aset visual, deskripsi, dan tautan resmi komunitas Anda. Perubahan yang Anda simpan akan langsung diperbarui.'
                                : 'Daftarkan komunitas cosplay, anime, atau hobi jejepangan Anda ke Wargabut! Komunitas yang didaftarkan akan melalui proses verifikasi oleh Admin Wargabut untuk menjaga keaslian dan keamanan informasi.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Media Pickers (Logo & Banner)
                  Text('Aset Visual Komunitas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Logo Picker
                      InkWell(
                        onTap: _pickLogo,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: _logoImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_logoImage!.path, fit: BoxFit.cover),
                                )
                              : (_community != null && _community!.logoUrl.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(_community!.logoUrl, fit: BoxFit.cover),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate, color: colorScheme.primary, size: 28),
                                        const SizedBox(height: 4),
                                        const Text('Logo', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Banner Picker
                      Expanded(
                        child: InkWell(
                          onTap: _pickBanner,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: _bannerImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(_bannerImage!.path, fit: BoxFit.cover),
                                  )
                                : (_community != null && _community!.bannerUrl.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(_community!.bannerUrl, fit: BoxFit.cover),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image, color: colorScheme.primary, size: 28),
                                          const SizedBox(height: 4),
                                          const Text('Banner Komunitas (Opsional)', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Info Dasar
                  Text('Informasi Dasar', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Komunitas *',
                      hintText: 'Contoh: Bogor Cosplay Community',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Nama komunitas wajib diisi';
                      if (val.trim().length < 3) return 'Minimal 3 karakter';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Wilayah / Asal Kota *',
                      hintText: 'Contoh: Bogor, Jakarta, Bandung, atau Seluruh Indonesia',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Wilayah/Kota wajib diisi' : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _shortDescController,
                    decoration: const InputDecoration(
                      labelText: 'Tagline Singkat *',
                      hintText: 'Contoh: Wadah silaturahmi & mabar cosplayer se-Bogor Raya',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.short_text),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Tagline singkat wajib diisi' : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Komunitas *',
                      hintText: 'Jelaskan visi, kegiatan rutin, sejarah, atau syarat bergabung komunitas...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Deskripsi wajib diisi' : null,
                  ),

                  const SizedBox(height: 24),

                  // Kategori
                  Text('Kategori Komunitas (Pilih minimal 1)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CommunityProvider.defaultCategories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat);
                      return FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories.add(cat);
                            } else {
                              _selectedCategories.remove(cat);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Tautan Sosial Media Resmi
                  Text('Tautan Komunitas Resmi',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _instagramController,
                    decoration: const InputDecoration(
                      labelText: 'Akun Instagram Resmi',
                      hintText: 'Contoh: @cosplay_bogor atau link profil',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.camera_alt),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _tiktokController,
                    decoration: const InputDecoration(
                      labelText: 'Akun TikTok Resmi (Opsional)',
                      hintText: 'Contoh: @cosplay_bogor atau username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.music_note),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: communityProvider.isLoading ? null : _submit,
                      child: communityProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEditing ? 'Simpan Perubahan Komunitas' : 'Kirim Pendaftaran Komunitas',
                              style: const TextStyle(fontSize: 16),
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
