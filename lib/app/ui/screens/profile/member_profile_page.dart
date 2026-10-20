import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/community_model.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/community_provider.dart';
import '../../../provider/profile_provider.dart';
import '../../components/community/attending_event_poster.dart';

class MemberProfilePage extends StatefulWidget {
  final String username;

  const MemberProfilePage({super.key, required this.username});

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  UserProfileModel? _profile;
  List<CommunityModel> _userCommunities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    // Hapus '@' di awal jika terkirim di parameter
    String cleanUsername = widget.username;
    if (cleanUsername.startsWith('@')) {
      cleanUsername = cleanUsername.substring(1);
    }

    final profileProvider = context.read<ProfileProvider>();
    final communityProvider = context.read<CommunityProvider>();
    final prof = await profileProvider.getProfileByUsername(cleanUsername);

    List<CommunityModel> comms = [];
    if (prof != null) {
      try {
        comms = await communityProvider.fetchUserCommunities(prof.uid);
      } catch (e) {
        debugPrint('Error fetching user communities: $e');
      }
    }

    if (mounted) {
      setState(() {
        _profile = prof;
        _userCommunities = comms;
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

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Member')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Member "@${widget.username}" Tidak Ditemukan',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/komunitas'),
                child: const Text('Jelajahi WargaKomunitas'),
              ),
            ],
          ),
        ),
      );
    }

    final isSelf = currentUid == _profile!.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(context.canPop() ? Icons.arrow_back : Icons.home),
          tooltip: context.canPop() ? 'Kembali' : 'Web Utama Wargabut',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/welcome');
            }
          },
        ),
        title: Text('@${_profile!.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Web Utama Wargabut',
            onPressed: () => context.go('/welcome'),
          ),
          if (isSelf) ...[
            IconButton(
              icon: const Icon(Icons.watch),
              tooltip: 'Hubungkan Smartwatch (Wear OS)',
              onPressed: () => context.push('/wear'),
            ),
            TextButton.icon(
              onPressed: () => context.push('/@me'),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Biodata'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan Tautan Profil',
            onPressed: () {
              final link = 'https://wargabut.id/@${_profile!.username}';
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tautan profil disalin ke clipboard!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              children: [
                // Digital ID Card Container
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'WARGABUT DIGITAL MEMBER CARD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                backgroundImage: _profile!.avatarUrl.isNotEmpty
                                    ? NetworkImage(_profile!.avatarUrl)
                                    : null,
                                child: _profile!.avatarUrl.isEmpty
                                    ? Icon(Icons.person, size: 54, color: colorScheme.primary)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _profile!.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '@${_profile!.username}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_profile!.city.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_on, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text(_profile!.city, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Detail Content
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_profile!.bio.isNotEmpty) ...[
                              Text(
                                _profile!.bio,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                            ],

                            // Komunitas yang Diikuti
                            _buildCommunitiesSection(theme, colorScheme),

                            // Event yang Akan Dihadiri
                            _buildAttendingEventsSection(theme, colorScheme),

                            // Custom Tags
                            if (_profile!.customTags.isNotEmpty) ...[
                              const Text('Persona / Tags',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _profile!.customTags.map((tag) {
                                  return Chip(label: Text(tag));
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Cosplans
                            if (_profile!.cosplans.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(Icons.theater_comedy, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('Cosplan Masa Depan',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: _profile!.cosplans.map((c) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(c.character,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              if (c.series.isNotEmpty)
                                                Text(c.series,
                                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                                            ],
                                          ),
                                        ),
                                        if (c.targetEventOrCity.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: colorScheme.secondaryContainer,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c.targetEventOrCity,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSecondaryContainer,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Media Sosial (Instagram & TikTok)
                            if (_profile!.instagram.isNotEmpty || _profile!.tiktok.isNotEmpty) ...[
                              const Text('Media Sosial',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  if (_profile!.instagram.isNotEmpty)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          final clean = _profile!.instagram.replaceAll('@', '').trim();
                                          _launchUrl('https://instagram.com/$clean');
                                        },
                                        icon: const Icon(Icons.camera_alt, size: 16),
                                        label: Text(
                                          _profile!.instagram.startsWith('@')
                                              ? _profile!.instagram
                                              : '@${_profile!.instagram}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  if (_profile!.instagram.isNotEmpty && _profile!.tiktok.isNotEmpty) const SizedBox(width: 8),
                                  if (_profile!.tiktok.isNotEmpty)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          final clean = _profile!.tiktok.replaceAll('@', '').trim();
                                          _launchUrl('https://tiktok.com/@$clean');
                                        },
                                        icon: const Icon(Icons.music_note, size: 16),
                                        label: Text(
                                          _profile!.tiktok.startsWith('@')
                                              ? _profile!.tiktok
                                              : '@${_profile!.tiktok}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Navigasi ke Web Utama Wargabut & WargaKomunitas
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Wargabut - Media Rekomendasi Event & Komunitas',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/welcome'),
                              icon: const Icon(Icons.home, size: 16),
                              label: const Text('Web Utama'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => context.go('/komunitas'),
                              icon: const Icon(Icons.groups, size: 16),
                              label: const Text('Komunitas'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunitiesSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            const Text(
              'Komunitas yang Diikuti',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(width: 6),
            if (_userCommunities.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_userCommunities.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_userCommunities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Belum bergabung dengan komunitas manapun.',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _userCommunities.map((com) {
              return InkWell(
                onTap: () => context.push('/komunitas/${com.id}'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: com.logoUrl.isNotEmpty ? NetworkImage(com.logoUrl) : null,
                        child: com.logoUrl.isEmpty
                            ? Text(
                                com.name.isNotEmpty ? com.name[0].toUpperCase() : 'K',
                                style: TextStyle(fontSize: 10, color: colorScheme.onPrimaryContainer),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        com.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (com.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 12, color: Colors.blue),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAttendingEventsSection(ThemeData theme, ColorScheme colorScheme) {
    // Filter & sort: hanya event mendatang/aktif dengan tanggal paling dekat di paling atas
    final events = _profile?.upcomingAttendingEvents ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_available_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            const Text(
              'Event yang Akan Dihadiri',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(width: 6),
            if (events.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${events.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Belum ada agenda event selanjutnya.',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          )
        else
          Column(
            children: events.map((ev) {
              return InkWell(
                onTap: () => context.push('/jeventku/${ev.eventId}'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      // Poster thumbnail
                      AttendingEventPoster(
                        eventId: ev.eventId,
                        initialPosterUrl: ev.eventPoster,
                        width: 44,
                        height: 56,
                      ),
                      const SizedBox(width: 10),
                      // Event details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.eventName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (ev.eventDate.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 11, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      ev.eventDate,
                                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (ev.eventLocation.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 11, color: theme.hintColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      ev.eventLocation,
                                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (ev.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ev.notes,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
