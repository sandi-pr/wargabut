import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/community_model.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/community_provider.dart';
import 'attending_event_poster.dart';

class MemberCardDialog extends StatefulWidget {
  final UserProfileModel profile;
  final String? communityName;
  final bool isCommunityAdmin;
  final bool isFellowMember;
  final bool isSelf;
  final bool isLoggedIn;

  const MemberCardDialog({
    super.key,
    required this.profile,
    this.communityName,
    this.isCommunityAdmin = false,
    this.isFellowMember = false,
    this.isSelf = false,
    this.isLoggedIn = false,
  });

  static void show(
    BuildContext context, {
    required UserProfileModel profile,
    String? communityName,
    bool isCommunityAdmin = false,
    bool isFellowMember = false,
    bool isSelf = false,
    bool isLoggedIn = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => MemberCardDialog(
        profile: profile,
        communityName: communityName,
        isCommunityAdmin: isCommunityAdmin,
        isFellowMember: isFellowMember,
        isSelf: isSelf,
        isLoggedIn: isLoggedIn,
      ),
    );
  }

  @override
  State<MemberCardDialog> createState() => _MemberCardDialogState();
}

class _MemberCardDialogState extends State<MemberCardDialog> {
  List<CommunityModel> _userCommunities = [];
  bool _isLoadingCommunities = true;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    try {
      final list = await context
          .read<CommunityProvider>()
          .fetchUserCommunities(widget.profile.uid);
      if (mounted) {
        setState(() {
          _userCommunities = list;
          _isLoadingCommunities = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCommunities = false);
    }
  }

  void _launchUrl(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat membuka tautan: $urlString')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = widget.profile;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Card dengan aksen anime card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.badge, size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'WARGABUT MEMBER ID',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Avatar & Nama
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage: profile.avatarUrl.isNotEmpty
                            ? NetworkImage(profile.avatarUrl)
                            : null,
                        child: profile.avatarUrl.isEmpty
                            ? Icon(Icons.person, size: 48, color: colorScheme.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '@${profile.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (profile.city.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            profile.city,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Body Konten Biodata
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bio singkat jika ada
                    if (profile.bio.isNotEmpty) ...[
                      Text(
                        profile.bio,
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
                    if (profile.customTags.isNotEmpty) ...[
                      const Text(
                        'Tag & Persona',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: profile.customTags.map((tag) {
                          return Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Hobi
                    if (profile.hobbies.isNotEmpty) ...[
                      const Text(
                        'Hobi & Minat',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: profile.hobbies.map((hobby) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(hobby, style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Cosplan
                    if (profile.cosplans.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.theater_comedy, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          const Text(
                            'Cosplan Masa Depan',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Column(
                        children: profile.cosplans.map((cosplan) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                      Text(
                                        cosplan.character,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (cosplan.series.isNotEmpty)
                                        Text(
                                          cosplan.series,
                                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                        ),
                                    ],
                                  ),
                                ),
                                if (cosplan.targetEventOrCity.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cosplan.targetEventOrCity,
                                      style: TextStyle(
                                        fontSize: 10,
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

                    // Sosial Media (Instagram & TikTok)
                    if (profile.instagram.isNotEmpty || profile.tiktok.isNotEmpty) ...[
                      const Text(
                        'Media Sosial',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (profile.instagram.isNotEmpty)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final clean = profile.instagram.replaceAll('@', '').trim();
                                  _launchUrl(context, 'https://instagram.com/$clean');
                                },
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: Text(
                                  profile.instagram.startsWith('@') ? profile.instagram : '@${profile.instagram}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          if (profile.instagram.isNotEmpty && profile.tiktok.isNotEmpty) const SizedBox(width: 8),
                          if (profile.tiktok.isNotEmpty)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final clean = profile.tiktok.replaceAll('@', '').trim();
                                  _launchUrl(context, 'https://tiktok.com/@$clean');
                                },
                                icon: const Icon(Icons.music_note, size: 16),
                                label: Text(
                                  profile.tiktok.startsWith('@') ? profile.tiktok : '@${profile.tiktok}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            if (!_isLoadingCommunities && _userCommunities.isNotEmpty)
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
        if (_isLoadingCommunities)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_userCommunities.isEmpty)
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
                onTap: () {
                  Navigator.pop(context);
                  context.push('/komunitas/${com.id}');
                },
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
    final events = widget.profile.upcomingAttendingEvents;

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
                onTap: () {
                  Navigator.pop(context);
                  context.push('/jeventku/${ev.eventId}');
                },
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
