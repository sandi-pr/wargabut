import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/community_event_model.dart';
import '../../../models/community_model.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/community_provider.dart';
import '../../../provider/profile_provider.dart';
import '../../components/community/add_community_event_dialog.dart';
import '../../components/community/member_card_dialog.dart';

class CommunityDetailPage extends StatefulWidget {
  final String slug;

  const CommunityDetailPage({super.key, required this.slug});

  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CommunityModel? _community;
  List<CommunityMemberModel> _members = [];
  List<CommunityEventAttendanceModel> _communityEvents = [];
  CommunityMemberModel? _userMembership;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final communityProvider = context.read<CommunityProvider>();
    final authProvider = context.read<AuthProvider>();

    final com = await communityProvider.getCommunityBySlug(widget.slug);
    if (com == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Komunitas tidak ditemukan.';
        });
      }
      return;
    }

    final members = await communityProvider.fetchActiveMembers(com.id);
    final events = await communityProvider.fetchCommunityEvents(com.id);

    CommunityMemberModel? userMembership;
    if (authProvider.user != null) {
      userMembership = await communityProvider.getUserMembership(com.id, authProvider.user!.uid);
    }

    if (mounted) {
      setState(() {
        _community = com;
        _members = members;
        _communityEvents = events;
        _userMembership = userMembership;
        _isLoading = false;
      });
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleJoinRequest() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final communityProvider = context.read<CommunityProvider>();

    if (!authProvider.isLoggedIn) {
      context.push('/login');
      return;
    }

    final profile = profileProvider.currentProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan lengkapi biodata Anda terlebih dahulu di menu profil.')),
      );
      context.push('/@me');
      return;
    }

    final error = await communityProvider.requestToJoin(_community!.id, profile);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan bergabung telah dikirimkan! Menunggu persetujuan PIC Komunitas.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  void _openMemberCard(CommunityMemberModel member) async {
    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUid = authProvider.user?.uid;

    final targetProfile = await profileProvider.getProfileByUsername(member.username);
    if (targetProfile == null || !mounted) return;

    final isCommunityAdmin = _community?.isAdmin(currentUid) ?? false;
    final isFellowMember = _userMembership?.isActive ?? false;

    MemberCardDialog.show(
      context,
      profile: targetProfile,
      communityName: _community?.name,
      isCommunityAdmin: isCommunityAdmin,
      isFellowMember: isFellowMember,
      isSelf: currentUid == member.uid,
      isLoggedIn: authProvider.isLoggedIn,
    );
  }

  Future<void> _promoteToAdmin(CommunityMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Angkat Jadi Admin'),
        content: Text('Jadikan ${member.displayName.isNotEmpty ? member.displayName : member.username} (@${member.username}) sebagai Admin komunitas?\n\nAdmin memiliki wewenang untuk menyetujui member baru dan mengedit profil komunitas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Jadikan Admin'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final comProvider = context.read<CommunityProvider>();
      final ok = await comProvider.promoteMemberToAdmin(
        communityId: _community!.id,
        uid: member.uid,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${member.username} sekarang menjadi Admin komunitas.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    }
  }

  Future<void> _demoteAdmin(CommunityMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cabut Akses Admin'),
        content: Text('Cabut wewenang Admin dari ${member.displayName.isNotEmpty ? member.displayName : member.username} (@${member.username})? Pengguna akan kembali menjadi Member biasa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut Akses'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final comProvider = context.read<CommunityProvider>();
      final ok = await comProvider.demoteAdminToMember(
        communityId: _community!.id,
        uid: member.uid,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akses admin @${member.username} berhasil dicabut.'),
          ),
        );
        _loadData();
      }
    }
  }

  Future<void> _removeMember(CommunityMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluarkan Anggota'),
        content: Text('Apakah Anda yakin ingin mengeluarkan ${member.displayName.isNotEmpty ? member.displayName : member.username} (@${member.username}) dari komunitas ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluarkan'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final comProvider = context.read<CommunityProvider>();
      final ok = await comProvider.removeMember(
        communityId: _community!.id,
        uid: member.uid,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${member.username} telah dikeluarkan dari komunitas.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _loadData();
      }
    }
  }

  void _showAddAdminDialog(BuildContext context) {
    final usernameController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    final nonAdminMembers = _members.where((m) => m.role == 'Member' && m.uid != _community!.creatorUid).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text('Tambah Admin Komunitas', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin komunitas dapat menyetujui permohonan anggota baru dan mengedit informasi komunitas.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username Wargabut',
                          hintText: 'Contoh: sandi atau riko',
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: const OutlineInputBorder(),
                          errorText: errorText,
                          isDense: true,
                        ),
                        onChanged: (_) {
                          if (errorText != null) {
                            setDialogState(() => errorText = null);
                          }
                        },
                      ),
                      if (nonAdminMembers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Atau pilih dari anggota saat ini:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: nonAdminMembers.take(8).map((m) {
                            return ActionChip(
                              avatar: const Icon(Icons.person, size: 14),
                              label: Text('@${m.username}'),
                              onPressed: () {
                                usernameController.text = m.username;
                                setDialogState(() => errorText = null);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = usernameController.text.trim();
                          if (text.isEmpty) {
                            setDialogState(() => errorText = 'Ketik username terlebih dahulu');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          final comProvider = context.read<CommunityProvider>();
                          final err = await comProvider.addAdminByUsername(
                            communityId: _community!.id,
                            username: text,
                          );

                          if (err != null) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = err;
                            });
                          } else {
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Berhasil menambahkan @$text sebagai Admin!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadData();
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Angkat Jadi Admin'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final currentUid = authProvider.user?.uid;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _community == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Komunitas')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Komunitas tidak ditemukan', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/komunitas'),
                child: const Text('Kembali ke Direktori Komunitas'),
              ),
            ],
          ),
        ),
      );
    }

    final isCommunityAdmin = _community!.isAdmin(currentUid);

    return Scaffold(
      appBar: AppBar(
        title: Text(_community!.name),
        actions: [
          if (isCommunityAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profil Komunitas',
              onPressed: () => context.push('/komunitas/${_community!.id}/edit', extra: _community),
            ),
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              tooltip: 'Kelola Anggota Komunitas',
              onPressed: () => context.push('/komunitas/${_community!.id}/kelola'),
            ),
          ],
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Banner & Logo Stack
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          image: _community!.bannerUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_community!.bannerUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _community!.bannerUrl.isEmpty
                            ? Center(
                                child: Icon(Icons.groups, size: 64, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.3)),
                              )
                            : null,
                      ),
                      Positioned(
                        left: 20,
                        bottom: -36,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            backgroundImage: _community!.logoUrl.isNotEmpty
                                ? NetworkImage(_community!.logoUrl)
                                : null,
                            child: _community!.logoUrl.isEmpty
                                ? Icon(Icons.people, color: colorScheme.primary, size: 40)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 44),

                  // Info Komunitas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _community!.name,
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_community!.isVerified) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Komunitas Terverifikasi Wargabut',
                                child: Icon(Icons.verified, color: colorScheme.primary, size: 24),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _community!.cityOrArea,
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.groups, size: 16, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${_members.length} Anggota',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),

                        if (_community!.shortDesc.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _community!.shortDesc,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Tombol Aksi Tautan (Instagram, WhatsApp, Join)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            // Tombol Join / Status Membership
                            if (_userMembership == null)
                              FilledButton.icon(
                                onPressed: _handleJoinRequest,
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Minta Gabung Komunitas'),
                              )
                            else if (_userMembership!.isPending)
                              FilledButton.tonalIcon(
                                onPressed: null,
                                icon: const Icon(Icons.hourglass_top, size: 18),
                                label: const Text('Menunggu Persetujuan Admin'),
                              )
                            else if (_userMembership!.isActive)
                              FilledButton.tonalIcon(
                                onPressed: null,
                                icon: const Icon(Icons.check, size: 18),
                                label: Text('Anggota (${_userMembership!.role})'),
                              ),

                            // Instagram Tautan
                            if (_community!.instagram.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  final clean = _community!.instagram.replaceAll('@', '').trim();
                                  _launchUrl('https://instagram.com/$clean');
                                },
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Instagram'),
                              ),

                            // TikTok Tautan
                            if (_community!.tiktok.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  final clean = _community!.tiktok.replaceAll('@', '').trim();
                                  _launchUrl('https://tiktok.com/@$clean');
                                },
                                icon: const Icon(Icons.music_note, size: 18),
                                label: const Text('TikTok'),
                              ),

                            // Jika Admin / Founder Komunitas, tampilkan tombol Edit & Kelola
                            if (isCommunityAdmin) ...[
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  await context.push('/komunitas/${_community!.id}/edit', extra: _community);
                                  // Muat ulang data komunitas setelah kembali dari halaman edit
                                  _loadData();
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit Komunitas'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/komunitas/${_community!.id}/kelola'),
                                icon: const Icon(Icons.manage_accounts, size: 18),
                                label: const Text('Kelola Anggota & Permintaan'),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // TabBar
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        text: _communityEvents.isNotEmpty
                            ? 'Tentang & Agenda (${_communityEvents.length})'
                            : 'Tentang Komunitas',
                        icon: const Icon(Icons.info_outline),
                      ),
                      Tab(
                        text: 'Daftar Anggota (${_members.length})',
                        icon: const Icon(Icons.badge_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: Tentang Komunitas & Agenda Event
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deskripsi Komunitas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _community!.description.isNotEmpty
                        ? _community!.description
                        : 'Belum ada deskripsi lengkap.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  if (_community!.categories.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Fokus Kategori', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _community!.categories.map((cat) {
                        return Chip(label: Text(cat));
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Agenda Event Section
                  _buildEventsSection(theme, colorScheme, isCommunityAdmin),
                ],
              ),
            ),

            // TAB 2: Daftar Anggota
            Builder(
              builder: (context) {
                final sortedMembers = List<CommunityMemberModel>.from(_members);
                sortedMembers.sort((a, b) {
                  if (a.role == 'Founder') return -1;
                  if (b.role == 'Founder') return 1;
                  if (a.role == 'Admin' && b.role != 'Admin') return -1;
                  if (b.role == 'Admin' && a.role != 'Admin') return 1;
                  return (a.displayName.isNotEmpty ? a.displayName : a.username)
                      .toLowerCase()
                      .compareTo((b.displayName.isNotEmpty ? b.displayName : b.username).toLowerCase());
                });

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header khusus Admin/Founder untuk menambah Admin
                    if (isCommunityAdmin)
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: colorScheme.primary, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Pengurus Komunitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('Kelola admin & anggota yang berhak mengurus komunitas.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () => _showAddAdminDialog(context),
                                icon: const Icon(Icons.person_add_alt_1, size: 16),
                                label: const Text('Tambah Admin', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (sortedMembers.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('Belum ada anggota yang terdaftar di komunitas ini.'),
                        ),
                      )
                    else
                      ...List.generate(sortedMembers.length, (index) {
                        final member = sortedMembers[index];
                        final isMemberFounder = member.role == 'Founder' || member.uid == _community!.creatorUid;
                        final isMemberAdmin = member.role == 'Admin';
                        final isViewerFounder = _community!.isFounder(currentUid);

                        return Column(
                          children: [
                            ListTile(
                              onTap: () => _openMemberCard(member),
                              leading: CircleAvatar(
                                backgroundImage: member.avatarUrl.isNotEmpty ? NetworkImage(member.avatarUrl) : null,
                                child: member.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.displayName.isNotEmpty ? member.displayName : member.username,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (isMemberFounder)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('👑 ', style: TextStyle(fontSize: 10)),
                                          Text('Founder', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
                                        ],
                                      ),
                                    )
                                  else if (isMemberAdmin)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.shield, size: 10, color: colorScheme.onPrimaryContainer),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Admin',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('@${member.username}${member.city.isNotEmpty ? " • ${member.city}" : ""}'),
                                  if (member.customTags.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        member.customTags.join(' '),
                                        style: TextStyle(fontSize: 11, color: colorScheme.primary),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isCommunityAdmin
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (val) {
                                        if (val == 'view') {
                                          _openMemberCard(member);
                                        } else if (val == 'promote') {
                                          _promoteToAdmin(member);
                                        } else if (val == 'demote') {
                                          _demoteAdmin(member);
                                        } else if (val == 'remove') {
                                          _removeMember(member);
                                        }
                                      },
                                      itemBuilder: (context) {
                                        return [
                                          const PopupMenuItem(
                                            value: 'view',
                                            child: Row(
                                              children: [
                                                Icon(Icons.badge_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Lihat Biodata'),
                                              ],
                                            ),
                                          ),
                                          if (!isMemberFounder && !isMemberAdmin)
                                            PopupMenuItem(
                                              value: 'promote',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.shield_outlined, size: 18, color: colorScheme.primary),
                                                  const SizedBox(width: 8),
                                                  Text('Jadikan Admin', style: TextStyle(color: colorScheme.primary)),
                                                ],
                                              ),
                                            ),
                                          if (isViewerFounder && isMemberAdmin)
                                            const PopupMenuItem(
                                              value: 'demote',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.remove_moderator, size: 18, color: Colors.orange),
                                                  SizedBox(width: 8),
                                                  Text('Cabut Akses Admin', style: TextStyle(color: Colors.orange)),
                                                ],
                                              ),
                                            ),
                                          if (!isMemberFounder)
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.person_remove, size: 18, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Keluarkan Anggota', style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                        ];
                                      },
                                    )
                                  : const Icon(Icons.arrow_forward_ios, size: 14),
                            ),
                            if (index < sortedMembers.length - 1) const Divider(height: 1),
                          ],
                        );
                      }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection(ThemeData theme, ColorScheme colorScheme, bool isCommunityAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar Agenda Event
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_available_rounded, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Agenda Kehadiran Event',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_communityEvents.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_communityEvents.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daftar event JEventku yang direncanakan dihadiri oleh komunitas ini',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCommunityAdmin)
                FilledButton.icon(
                  onPressed: _openAddEventDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Event', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_communityEvents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada agenda event.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCommunityAdmin
                        ? 'Klik tombol "Tambah Event" untuk mencantumkan event JEventku yang akan dihadiri.'
                        : 'Komunitas ini belum mencantumkan jadwal event mendatang yang akan dihadiri.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (isCommunityAdmin) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openAddEventDialog,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Pilih Event dari JEventku'),
                    ),
                  ],
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _communityEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _communityEvents[index];
                return Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => context.push('/jeventku/${item.eventId}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Poster Event
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.eventPoster.isNotEmpty
                                ? Image.network(
                                    item.eventPoster,
                                    width: 70,
                                    height: 95,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 70,
                                      height: 95,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 30),
                                    ),
                                  )
                                : Container(
                                    width: 70,
                                    height: 95,
                                    color: colorScheme.primaryContainer,
                                    child: Icon(Icons.event, color: colorScheme.primary, size: 30),
                                  ),
                          ),
                          const SizedBox(width: 14),

                          // Detail Event & Notes
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.eventName,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                if (item.eventDate.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 12, color: Colors.blueAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.eventDate,
                                        style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                if (item.eventLocation.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 12, color: colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.eventLocation,
                                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Catatan Khusus Kehadiran Komunitas
                                if (item.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 12, color: Colors.amber.shade900),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            item.notes,
                                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Tombol Opsi Hapus (Khusus Founder / Admin)
                          if (isCommunityAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              tooltip: 'Hapus dari Agenda',
                              onPressed: () => _removeEventFromAgenda(item),
                            )
                          else
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
    );
  }

  void _openAddEventDialog() async {
    if (_community == null) return;
    final success = await AddCommunityEventDialog.show(
      context,
      community: _community,
    );
    if (success == true && mounted) {
      _loadData();
    }
  }

  Future<void> _removeEventFromAgenda(CommunityEventAttendanceModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Agenda Event'),
        content: Text('Apakah Anda yakin ingin menghapus "${item.eventName}" dari agenda kehadiran komunitas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final auth = context.read<AuthProvider>();
      final cp = context.read<CommunityProvider>();
      final ok = await cp.removeEventFromCommunity(
        communityId: item.communityId,
        eventId: item.eventId,
        currentUid: auth.user?.uid ?? '',
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event "${item.eventName}" dihapus dari agenda komunitas.')),
        );
        _loadData();
      }
    }
  }
}
