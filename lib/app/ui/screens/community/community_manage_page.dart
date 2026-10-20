import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/community_model.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/community_provider.dart';
import '../../../provider/profile_provider.dart';
import '../../components/community/member_card_dialog.dart';

class CommunityManagePage extends StatefulWidget {
  final String slug;

  const CommunityManagePage({super.key, required this.slug});

  @override
  State<CommunityManagePage> createState() => _CommunityManagePageState();
}

class _CommunityManagePageState extends State<CommunityManagePage> {
  CommunityModel? _community;
  List<CommunityMemberModel> _pendingRequests = [];
  List<CommunityMemberModel> _activeMembers = [];
  String _memberFilter = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final communityProvider = context.read<CommunityProvider>();
    final com = await communityProvider.getCommunityBySlug(widget.slug);

    if (com != null) {
      final requests = await communityProvider.fetchPendingRequests(com.id);
      final members = await communityProvider.fetchActiveMembers(com.id);
      if (mounted) {
        setState(() {
          _community = com;
          _pendingRequests = requests;
          _activeMembers = members;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approve(CommunityMemberModel req) async {
    final communityProvider = context.read<CommunityProvider>();
    final success = await communityProvider.approveJoinRequest(req.id, _community!.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${req.displayName} berhasil disetujui menjadi anggota!'), backgroundColor: Colors.green),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyetujui permintaan'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reject(CommunityMemberModel req) async {
    final communityProvider = context.read<CommunityProvider>();
    final success = await communityProvider.rejectJoinRequest(req.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permintaan ${req.displayName} ditolak.')),
      );
      _load();
    }
  }

  Future<void> _promoteToAdmin(CommunityMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Angkat Jadi Admin'),
        content: Text('Jadikan ${member.displayName.isNotEmpty ? member.displayName : member.username} (@${member.username}) sebagai Admin komunitas?\n\nAdmin memiliki wewenang untuk menyetujui member baru dan mengedit info komunitas.'),
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
        _load();
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
        _load();
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
        _load();
      }
    }
  }

  void _showAddAdminDialog(BuildContext context) {
    final usernameController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    final nonAdminMembers = _activeMembers.where((m) => m.role == 'Member' && m.uid != _community!.creatorUid).toList();

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
                            Navigator.pop(dialogCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Berhasil menambahkan @$text sebagai Admin!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _load();
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

  void _previewBiodata(CommunityMemberModel req) async {
    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();

    final profile = await profileProvider.getProfileByUsername(req.username);
    if (profile == null || !mounted) return;

    MemberCardDialog.show(
      context,
      profile: profile,
      communityName: _community?.name,
      isCommunityAdmin: true,
      isFellowMember: false,
      isSelf: false,
      isLoggedIn: authProvider.isLoggedIn,
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
        appBar: AppBar(title: const Text('Kelola Anggota')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_community == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelola Anggota')),
        body: const Center(child: Text('Komunitas tidak ditemukan')),
      );
    }

    final isPermitted = _community!.isAdmin(currentUid) || authProvider.isAdmin;
    if (!isPermitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: const Center(child: Text('Anda bukan admin/pengurus komunitas ini.')),
      );
    }

    final isViewerFounder = _community!.isFounder(currentUid);

    final sortedMembers = List<CommunityMemberModel>.from(_activeMembers);
    sortedMembers.sort((a, b) {
      if (a.role == 'Founder') return -1;
      if (b.role == 'Founder') return 1;
      if (a.role == 'Admin' && b.role != 'Admin') return -1;
      if (b.role == 'Admin' && a.role != 'Admin') return 1;
      return (a.displayName.isNotEmpty ? a.displayName : a.username)
          .toLowerCase()
          .compareTo((b.displayName.isNotEmpty ? b.displayName : b.username).toLowerCase());
    });

    final filteredMembers = _memberFilter.isEmpty
        ? sortedMembers
        : sortedMembers.where((m) {
            final q = _memberFilter.toLowerCase();
            return m.displayName.toLowerCase().contains(q) ||
                m.username.toLowerCase().contains(q) ||
                m.city.toLowerCase().contains(q);
          }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kelola Komunitas', style: TextStyle(fontSize: 16)),
              Text(_community!.name, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Permintaan Baru'),
                    if (_pendingRequests.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Badge.count(count: _pendingRequests.length),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pengurus & Anggota'),
                    const SizedBox(width: 6),
                    Text('(${_activeMembers.length})', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Permintaan Bergabung
            _pendingRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('Tidak Ada Permintaan Bergabung', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Saat ini tidak ada calon anggota baru yang menunggu persetujuan.',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final req = _pendingRequests[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: req.avatarUrl.isNotEmpty ? NetworkImage(req.avatarUrl) : null,
                                    child: req.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req.displayName.isNotEmpty ? req.displayName : req.username,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          '@${req.username}${req.city.isNotEmpty ? " • ${req.city}" : ""}',
                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _previewBiodata(req),
                                    child: const Text('Lihat Biodata'),
                                  ),
                                ],
                              ),
                              if (req.customTags.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  children: req.customTags.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(tag, style: const TextStyle(fontSize: 11)),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 14),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _reject(req),
                                    icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                    label: const Text('Tolak', style: TextStyle(color: Colors.red)),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => _approve(req),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Setujui Member'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // TAB 2: Daftar Pengurus & Anggota
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Action Header
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
                              const Text('Admin & Pengurus Komunitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Tambahkan rekan untuk membantu mengelola komunitas.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
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

                // Search Box
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari anggota berdasarkan nama / username / kota...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _memberFilter = val.trim()),
                ),

                const SizedBox(height: 16),

                if (filteredMembers.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Tidak ada anggota yang cocok dengan pencarian.'),
                    ),
                  )
                else
                  ...List.generate(filteredMembers.length, (index) {
                    final member = filteredMembers[index];
                    final isMemberFounder = member.role == 'Founder' || member.uid == _community!.creatorUid;
                    final isMemberAdmin = member.role == 'Admin';

                    return Column(
                      children: [
                        ListTile(
                          onTap: () => _previewBiodata(member),
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
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) {
                              if (val == 'view') {
                                _previewBiodata(member);
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
                                        SizedBox(width: 8),
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
                          ),
                        ),
                        if (index < filteredMembers.length - 1) const Divider(height: 1),
                      ],
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
