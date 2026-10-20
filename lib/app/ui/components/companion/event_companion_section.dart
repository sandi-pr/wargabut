import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/event_companion_model.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/companion_provider.dart';
import '../../../provider/profile_provider.dart';
import '../community/member_card_dialog.dart';
import 'create_companion_dialog.dart';
import 'companion_chat_dialog.dart';

class EventCompanionSection extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventCompanionSection({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventCompanionSection> createState() => _EventCompanionSectionState();
}

class _EventCompanionSectionState extends State<EventCompanionSection> {
  String _filterType = 'all'; // 'all' | 'transit' | 'venue'

  void _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openTelegram(String handle) {
    final clean = handle.trim().replaceAll('@', '');
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      _launchExternal(clean);
    } else {
      _launchExternal('https://t.me/$clean');
    }
  }

  void _openInstagram(String handle) {
    final clean = handle.trim().replaceAll('@', '');
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      _launchExternal(clean);
    } else {
      _launchExternal('https://instagram.com/$clean');
    }
  }

  String _resolveAvatar(String uid, String rawAvatarUrl, ProfileProvider profileProvider) {
    if (rawAvatarUrl.trim().isNotEmpty) return rawAvatarUrl.trim();
    if (profileProvider.currentProfile?.uid == uid &&
        profileProvider.currentProfile?.avatarUrl.isNotEmpty == true) {
      return profileProvider.currentProfile!.avatarUrl;
    }
    final cached = profileProvider.getCachedProfile(uid);
    if (cached != null && cached.avatarUrl.isNotEmpty) {
      return cached.avatarUrl;
    }
    return '';
  }

  Future<void> _openMemberCard(
    BuildContext context,
    String uid,
    String username,
    String displayName,
    String avatarUrl,
  ) async {
    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();

    UserProfileModel? targetProfile;

    // Jika profil sendiri dan sudah termuat di memory
    if (authProvider.user?.uid == uid && profileProvider.currentProfile != null) {
      targetProfile = profileProvider.currentProfile;
    } else {
      // Ambil profil lengkap dari Firestore (melalui UID atau Username)
      targetProfile = await profileProvider.getProfileByUid(uid);
      if (targetProfile == null && username.isNotEmpty) {
        targetProfile = await profileProvider.getProfileByUsername(username);
      }
    }

    targetProfile ??= UserProfileModel(
      uid: uid,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );

    if (context.mounted) {
      MemberCardDialog.show(
        context,
        profile: targetProfile,
        isSelf: authProvider.user?.uid == uid,
        isLoggedIn: authProvider.isLoggedIn,
      );
    }
  }

  Future<void> _showLoginRequiredDialog({required String actionText}) async {
    final doLogin = await showDialog<bool>(
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
          'Untuk $actionText, kamu perlu masuk (login) ke akun Wargabut terlebih dahulu.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti Saja'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Login Sekarang'),
          ),
        ],
      ),
    );

    if (doLogin == true && mounted) {
      context.push('/login');
    }
  }

  void _handleCreateCompanion() {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn || authProvider.user == null) {
      _showLoginRequiredDialog(actionText: 'membuat ajakan barengan ke event');
      return;
    }

    CreateCompanionDialog.show(
      context,
      eventId: widget.eventId,
      eventName: widget.eventName,
    );
  }

  void _handleEditCompanion(EventCompanionModel companion) {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn || authProvider.user == null) {
      _showLoginRequiredDialog(actionText: 'mengedit ajakan barengan');
      return;
    }

    CreateCompanionDialog.show(
      context,
      eventId: widget.eventId,
      eventName: widget.eventName,
      companionToEdit: companion,
    );
  }

  Future<void> _joinCompanion(EventCompanionModel companion) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn || authProvider.user == null) {
      _showLoginRequiredDialog(actionText: 'bergabung ke rombongan "${companion.title}"');
      return;
    }

    final user = authProvider.user!;
    final profileProvider = context.read<ProfileProvider>();
    final currentProfile = profileProvider.currentProfile;

    final memberUsername = currentProfile?.username.isNotEmpty == true
        ? currentProfile!.username
        : (user.displayName ?? user.email?.split('@').first ?? 'member');
    final memberDisplayName = currentProfile?.displayName.isNotEmpty == true
        ? currentProfile!.displayName
        : memberUsername;
    final memberAvatar = currentProfile?.avatarUrl.isNotEmpty == true
        ? currentProfile!.avatarUrl
        : (user.photoURL ?? '');

    final member = CompanionMember(
      uid: user.uid,
      username: memberUsername,
      displayName: memberDisplayName,
      avatarUrl: memberAvatar,
      joinedAt: DateTime.now(),
    );

    final messenger = ScaffoldMessenger.of(context);
    final companionProvider = context.read<CompanionProvider>();
    final success = await companionProvider.joinCompanion(companion.id, member);

    if (mounted) {
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Berhasil bergabung ke "${companion.title}"! Koordinasikan titik kumpul di tombol Diskusi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Gagal bergabung. Mungkin kuota rombongan sudah penuh.')),
        );
      }
    }
  }

  Future<void> _leaveCompanion(EventCompanionModel companion) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn || authProvider.user == null) return;

    final user = authProvider.user!;
    final messenger = ScaffoldMessenger.of(context);
    final companionProvider = context.read<CompanionProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Rombongan?'),
        content: Text('Apakah Anda yakin ingin keluar dari rombongan "${companion.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await companionProvider.leaveCompanion(companion.id, user.uid);

    if (mounted && success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Anda telah keluar dari rombongan.')),
      );
    }
  }

  Future<void> _deleteCompanion(EventCompanionModel companion) async {
    final messenger = ScaffoldMessenger.of(context);
    final companionProvider = context.read<CompanionProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Ajakan Barengan?'),
        content: Text('Apakah Anda yakin ingin menghapus ajakan "${companion.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await companionProvider.deleteCompanion(companion.id);

    if (mounted && success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ajakan barengan telah dihapus.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final currentUid = authProvider.user?.uid;
    final companionProvider = context.watch<CompanionProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    return StreamBuilder<List<EventCompanionModel>>(
      stream: companionProvider.getCompanionsStream(widget.eventId),
      builder: (context, snapshot) {
        final allCompanions = snapshot.data ?? [];
        final transitCompanions = allCompanions.where((c) => c.isTransit).toList();
        final venueCompanions = allCompanions.where((c) => c.isVenue).toList();

        if (allCompanions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (final c in allCompanions) {
              if (c.creatorUid.isNotEmpty && profileProvider.getCachedProfile(c.creatorUid) == null) {
                profileProvider.getProfileByUid(c.creatorUid);
              }
              for (final m in c.members) {
                if (m.uid.isNotEmpty && profileProvider.getCachedProfile(m.uid) == null) {
                  profileProvider.getProfileByUid(m.uid);
                }
              }
            }
          });
        }

        List<EventCompanionModel> filteredList;
        if (_filterType == 'transit') {
          filteredList = transitCompanions;
        } else if (_filterType == 'venue') {
          filteredList = venueCompanions;
        } else {
          filteredList = allCompanions;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Seksi
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.groups_rounded, color: colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Cari Teman Barengan',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (allCompanions.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${allCompanions.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sendirian ke event? Temukan rombongan naik KRL bareng atau teman jalan di venue.',
                          style: TextStyle(fontSize: 12, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _handleCreateCompanion,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Buat Ajakan', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Tabs
              if (allCompanions.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Semua (${allCompanions.length})'),
                        selected: _filterType == 'all',
                        onSelected: (_) => setState(() => _filterType = 'all'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: const Icon(Icons.directions_railway_rounded, size: 16),
                        label: Text('🚆 KRL / Transit (${transitCompanions.length})'),
                        selected: _filterType == 'transit',
                        onSelected: (_) => setState(() => _filterType = 'transit'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: const Icon(Icons.place_rounded, size: 16),
                        label: Text('🎪 Di Venue (${venueCompanions.length})'),
                        selected: _filterType == 'venue',
                        onSelected: (_) => setState(() => _filterType = 'venue'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Konten Daftar Rombongan / Empty State
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.directions_subway_rounded, size: 40, color: theme.hintColor.withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Text(
                        allCompanions.isEmpty
                            ? 'Belum ada ajakan rombongan barengan'
                            : 'Belum ada ajakan barengan di kategori ini.',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jadilah yang pertama membuat rombongan! Ajak teman naik KRL bareng atau janjian di lokasi event.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _handleCreateCompanion,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Buat Ajakan Barengan Pertama'),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    final isMember = item.isMember(currentUid);
                    final isCreator = item.creatorUid == currentUid;
                    final isAdmin = authProvider.isAdmin;
                    final canEdit = isCreator || isAdmin;
                    final canDelete = isCreator || isAdmin;

                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isMember
                              ? colorScheme.primary.withValues(alpha: 0.4)
                              : colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Kartu: Pembuat & Badge
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => _openMemberCard(
                                    context,
                                    item.creatorUid,
                                    item.creatorUsername,
                                    item.creatorName,
                                    _resolveAvatar(item.creatorUid, item.creatorAvatar, profileProvider),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage: _resolveAvatar(item.creatorUid, item.creatorAvatar, profileProvider).isNotEmpty
                                            ? NetworkImage(_resolveAvatar(item.creatorUid, item.creatorAvatar, profileProvider))
                                            : null,
                                        child: _resolveAvatar(item.creatorUid, item.creatorAvatar, profileProvider).isEmpty
                                            ? const Icon(Icons.person, size: 16)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.creatorName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            '@${item.creatorUsername}',
                                            style: TextStyle(fontSize: 11, color: theme.hintColor),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),

                                // Badge Tipe
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: item.isTransit ? Colors.blue.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: item.isTransit ? Colors.blue.shade200 : Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.isTransit ? Icons.directions_railway : Icons.place,
                                        size: 12,
                                        color: item.isTransit ? Colors.blue.shade800 : Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.isTransit ? 'KRL / Transit' : 'Di Venue',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: item.isTransit ? Colors.blue.shade800 : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Badge Kuota
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: item.isFull
                                        ? Colors.red.shade50
                                        : colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.isFull
                                        ? 'Penuh'
                                        : (item.maxMembers > 0
                                            ? '${item.members.length}/${item.maxMembers} Orang'
                                            : '${item.members.length} Orang'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.isFull
                                          ? Colors.red.shade800
                                          : colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),

                                if (canEdit)
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, size: 18, color: colorScheme.primary),
                                    tooltip: 'Edit Ajakan',
                                    onPressed: () => _handleEditCompanion(item),
                                  ),

                                if (canDelete)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    tooltip: 'Hapus Ajakan',
                                    onPressed: () => _deleteCompanion(item),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Judul Rombongan
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 6),

                            // Info Titik Kumpul & Waktu
                            Row(
                              children: [
                                const Icon(Icons.place, size: 14, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.meetingPoint,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.blueAccent),
                                const SizedBox(width: 4),
                                Text(
                                  item.meetingTime,
                                  style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),

                            // Tag Aktivitas
                            if (item.activityTag.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '# ${item.activityTag}',
                                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                                ),
                              ),
                            ],

                            // Catatan Rombongan
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Text(
                                  item.notes,
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Avatar Anggota Rombongan
                            Row(
                              children: [
                                const Text('Anggota: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ...item.members.map((m) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Tooltip(
                                      message: '${m.displayName} (@${m.username})',
                                      child: InkWell(
                                        onTap: () => _openMemberCard(
                                          context,
                                          m.uid,
                                          m.username,
                                          m.displayName,
                                          _resolveAvatar(m.uid, m.avatarUrl, profileProvider),
                                        ),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundImage: _resolveAvatar(m.uid, m.avatarUrl, profileProvider).isNotEmpty
                                              ? NetworkImage(_resolveAvatar(m.uid, m.avatarUrl, profileProvider))
                                              : null,
                                          child: _resolveAvatar(m.uid, m.avatarUrl, profileProvider).isEmpty
                                              ? const Icon(Icons.person, size: 12)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (item.maxMembers > 0 && item.members.length < item.maxMembers)
                                  Text(
                                    '+${item.maxMembers - item.members.length} slot',
                                    style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Baris Tombol Aksi Bawah
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Tombol Gabung / Keluar
                                if (isMember && !isCreator)
                                  OutlinedButton.icon(
                                    onPressed: () => _leaveCompanion(item),
                                    icon: const Icon(Icons.logout, size: 14, color: Colors.red),
                                    label: const Text('Keluar Rombongan', style: TextStyle(fontSize: 11, color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  )
                                else if (!isMember)
                                  FilledButton.icon(
                                    onPressed: item.isFull ? null : () => _joinCompanion(item),
                                    icon: const Icon(Icons.person_add_alt_1, size: 14),
                                    label: Text(
                                      item.isFull ? 'Rombongan Penuh' : 'Gabung Rombongan',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: const Text(
                                      '✓ Anda Pembuat Rombongan',
                                      style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),

                                // Tombol Edit Ajakan (jika pembuat/admin)
                                if (canEdit)
                                  OutlinedButton.icon(
                                    onPressed: () => _handleEditCompanion(item),
                                    icon: const Icon(Icons.edit_outlined, size: 13),
                                    label: const Text('Edit Ajakan', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),

                                // Tombol Diskusi & Koordinasi
                                OutlinedButton.icon(
                                  onPressed: () => CompanionChatDialog.show(context, companion: item),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                                  label: const Text('Diskusi & Tanya Jawab', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),

                                // Tombol Kontak Telegram (jika ada)
                                if (item.telegramHandle.isNotEmpty)
                                  ActionChip(
                                    avatar: const Icon(Icons.send_rounded, size: 14, color: Colors.lightBlue),
                                    label: Text(
                                      item.telegramHandle.startsWith('@') ? item.telegramHandle : 'Telegram',
                                      style: const TextStyle(fontSize: 11, color: Colors.lightBlue, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: Colors.lightBlue.shade50,
                                    side: BorderSide(color: Colors.lightBlue.shade200),
                                    onPressed: () => _openTelegram(item.telegramHandle),
                                  ),

                                // Tombol Kontak Instagram (jika ada)
                                if (item.instagramHandle.isNotEmpty)
                                  ActionChip(
                                    avatar: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.purple),
                                    label: Text(
                                      item.instagramHandle.startsWith('@') ? item.instagramHandle : 'Instagram',
                                      style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: Colors.purple.shade50,
                                    side: BorderSide(color: Colors.purple.shade200),
                                    onPressed: () => _openInstagram(item.instagramHandle),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
