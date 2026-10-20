import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/cosplay_project_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/cosplay_project_provider.dart';
import 'dialogs/apply_slot_dialog.dart';
import 'dialogs/manual_fill_slot_dialog.dart';
import 'dialogs/project_applicants_dialog.dart';

class CosplayProjectDetailPage extends StatefulWidget {
  final String projectId;

  const CosplayProjectDetailPage({
    super.key,
    required this.projectId,
  });

  @override
  State<CosplayProjectDetailPage> createState() => _CosplayProjectDetailPageState();
}

class _CosplayProjectDetailPageState extends State<CosplayProjectDetailPage> {
  String _selectedCategoryGroup = 'Semua';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<CosplayProjectProvider>();

    return Scaffold(
      body: StreamBuilder<CosplayProjectModel?>(
        stream: provider.streamProject(widget.projectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final project = snapshot.data;
          if (project == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Projek Tidak Ditemukan')),
              body: const Center(child: Text('Projek cosplay ini mungkin telah dihapus.')),
            );
          }

          final isCreator = auth.user != null && auth.user!.uid == project.creatorUid;
          final isMember = auth.user != null &&
              project.slots.any((s) => s.filledUser?.uid == auth.user!.uid);

          // Kategori yang ada di projek ini
          final categories = ['Semua', ...project.uniqueCategories];
          final displayedSlots = _selectedCategoryGroup == 'Semua'
              ? project.slots
              : project.slots.where((s) => s.categoryGroup == _selectedCategoryGroup).toList();

          return CustomScrollView(
            slivers: [
              // 1. SLIVER APP BAR DENGAN BANNER
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      tooltip: 'Kembali',
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/dcosplay');
                        }
                      },
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 1)),
                        Shadow(blurRadius: 16, color: Colors.black, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      project.bannerUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: project.bannerUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildFallbackBanner(theme),
                            )
                          : _buildFallbackBanner(theme),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.45, 1.0],
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (isCreator) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          icon: const Icon(Icons.people_outline, color: Colors.white, size: 20),
                          tooltip: 'Review Pelamar Slot',
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            ProjectApplicantsDialog.show(context, project: project);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          onSelected: (val) {
                            if (val == 'edit') {
                              context.push('/dcosplay/${project.id}/edit', extra: project);
                            } else if (val == 'delete') {
                              _confirmDelete(context, project);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit Projek'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text('Hapus Projek', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),

              // 2. KONTEN DETAIL
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul Utama Projek
                      // Text(
                      //   project.title,
                      //   style: theme.textTheme.titleLarge?.copyWith(
                      //     fontWeight: FontWeight.bold,
                      //     color: theme.colorScheme.onSurface,
                      //     fontSize: 22,
                      //   ),
                      // ),
                      // const SizedBox(height: 10),

                      // Status & Badge Seri
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              project.seriesCategory.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project.seriesTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildStatusBadge(project),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Target Event / Venue Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  project.targetType == 'event'
                                      ? Icons.festival_outlined
                                      : Icons.photo_camera_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.targetEventName?.isNotEmpty == true
                                            ? project.targetEventName!
                                            : (project.targetCityOrVenue.isNotEmpty
                                                ? project.targetCityOrVenue
                                                : 'Lokasi Fleksibel'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      if (project.targetDate.isNotEmpty)
                                        Text(
                                          'Tanggal: ${project.targetDate}',
                                          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                        ),
                                    ],
                                  ),
                                ),
                                if (project.targetEventId != null && project.targetEventId!.isNotEmpty)
                                  FilledButton.tonal(
                                    onPressed: () {
                                      context.push('/jeventku/${project.targetEventId}');
                                    },
                                    child: const Text('Buka Event'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Organizer Card
                      _buildOrganizerCard(context, project, theme),
                      const SizedBox(height: 14),

                      // Coordination Link (Jika creator atau member)
                      if ((isCreator || isMember) && project.coordinationLink.isNotEmpty) ...[
                        _buildCoordinationCard(context, project, theme),
                        const SizedBox(height: 14),
                      ],

                      // Description & Rules
                      if (project.description.isNotEmpty) ...[
                        Text(
                          'Tentang Projekan:',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          project.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (project.rules.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.rule, size: 16, color: Colors.amber),
                                  SizedBox(width: 6),
                                  Text(
                                    'Aturan & Kriteria Projek:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(project.rules, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. HEADER SLOT KARAKTER & KATEGORI
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Katalog Karakter (${project.filledSlotsCount}/${project.totalSlots} Terisi)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCreator)
                            TextButton.icon(
                              onPressed: () {
                                ProjectApplicantsDialog.show(context, project: project);
                              },
                              icon: const Icon(Icons.rate_review_outlined, size: 16),
                              label: const Text('Review Pelamar'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Filter chips untuk kategori karakter jika lebih dari 1 kategori
                      if (categories.length > 2) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories.map((cat) {
                              final isSelected = _selectedCategoryGroup == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  onSelected: (sel) {
                                    if (sel) setState(() => _selectedCategoryGroup = cat);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),

              // 4. GRID / LIST SLOT KARAKTER
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 260,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final slot = displayedSlots[index];
                      return _buildSlotCard(context, project, slot, isCreator, theme);
                    },
                    childCount: displayedSlots.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(CosplayProjectModel project) {
    Color bg = Colors.teal;
    String label = '${project.openSlotsCount} Slot Buka';

    if (project.isFull) {
      bg = Colors.redAccent;
      label = 'Penuh';
    } else if (project.status == 'almost_full') {
      bg = Colors.orange;
      label = 'Hampir Penuh';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bg),
      ),
    );
  }

  Widget _buildOrganizerCard(BuildContext context, CosplayProjectModel project, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (project.creatorUsername.isNotEmpty) {
                context.push('/@${project.creatorUsername}');
              }
            },
            child: CircleAvatar(
              radius: 20,
              backgroundImage: project.creatorAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(project.creatorAvatar)
                  : null,
              child: project.creatorAvatar.isEmpty ? const Icon(Icons.person) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Penyelenggara Projek:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                InkWell(
                  onTap: () {
                    if (project.creatorUsername.isNotEmpty) {
                      context.push('/@${project.creatorUsername}');
                    }
                  },
                  child: Text(
                    '${project.creatorName} (@${project.creatorUsername})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (project.creatorWhatsApp.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
              tooltip: 'Chat WhatsApp Penyelenggara',
              onPressed: () async {
                final wa = project.creatorWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
                final url = Uri.parse('https://wa.me/$wa');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinationCard(BuildContext context, CosplayProjectModel project, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grup Koordinasi Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  project.coordinationLink,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: project.coordinationLink));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tautan grup koordinasi disalin!')),
              );
            },
          ),
          FilledButton.tonal(
            onPressed: () async {
              final url = Uri.parse(project.coordinationLink);
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    CosplayProjectModel project,
    CosplayProjectSlot slot,
    bool isCreator,
    ThemeData theme,
  ) {
    final isFilled = slot.isFilled;
    final isApplied = slot.isApplied;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isFilled
              ? Colors.teal.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference Image
          Expanded(
            child: GestureDetector(
              onTap: slot.referenceImageUrl.isNotEmpty
                  ? () => _showFullImageDialog(
                        context,
                        imageUrl: slot.referenceImageUrl,
                        charName: '${slot.characterName}${slot.characterVersion.isNotEmpty ? " (${slot.characterVersion})" : ""}',
                      )
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  slot.referenceImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: slot.referenceImageUrl,
                          fit: BoxFit.cover,
                          alignment: slot.parsedAlignment,
                          errorWidget: (_, __, ___) => _buildFallbackCharImage(theme),
                        )
                      : _buildFallbackCharImage(theme),
                  // Version badge overlay
                  if (slot.characterVersion.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          slot.characterVersion,
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  // Status chip top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isFilled
                            ? Colors.teal
                            : isApplied
                                ? Colors.orange
                                : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isFilled
                            ? 'Terisi'
                            : isApplied
                                ? 'Direview'
                                : 'Buka',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  // Fullscreen hint bottom right
                  if (slot.referenceImageUrl.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Slot Details
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.characterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (slot.categoryGroup.isNotEmpty)
                  Text(
                    slot.categoryGroup,
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                  ),
                const SizedBox(height: 6),

                // Pengisi Slot / Tombol Ajukan
                if (isFilled && slot.filledUser != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: slot.filledUser!.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(slot.filledUser!.avatarUrl)
                            : null,
                        child: slot.filledUser!.avatarUrl.isEmpty ? const Icon(Icons.person, size: 10) : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (!slot.filledUser!.isExternal && slot.filledUser!.username.isNotEmpty) {
                              context.push('/@${slot.filledUser!.username}');
                            }
                          },
                          child: Text(
                            slot.filledUser!.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: !slot.filledUser!.isExternal ? theme.colorScheme.primary : null,
                            ),
                          ),
                        ),
                      ),
                      if (isCreator)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.more_vert, size: 16),
                          onPressed: () => _showSlotManageMenu(context, project, slot),
                        ),
                    ],
                  ),
                ] else ...[
                  // Slot Masih Buka / Diajukan
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                          onPressed: () {
                            final auth = context.read<AuthProvider>();
                            if (!auth.isLoggedIn) {
                              context.push('/login?from=/dcosplay/${project.id}');
                              return;
                            }
                            ApplySlotDialog.show(context, project: project, slot: slot);
                          },
                          child: const Text('Ajukan Slot', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      if (isCreator) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit_note, size: 20),
                          tooltip: 'Tandai Manual',
                          onPressed: () {
                            ManualFillSlotDialog.show(context, projectId: project.id, slot: slot);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSlotManageMenu(BuildContext context, CosplayProjectModel project, CosplayProjectSlot slot) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: Colors.orange),
              title: const Text('Kosongkan Slot Karakter Ini'),
              subtitle: const Text('Keluarkan pengisi dan buka kembali slot untuk pendaftar lain'),
              onTap: () async {
                Navigator.pop(ctx);
                await context.read<CosplayProjectProvider>().vacateSlot(
                      projectId: project.id,
                      slotId: slot.slotId,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CosplayProjectModel project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Projek Cosplay?'),
        content: Text('Apakah Anda yakin ingin menghapus "${project.title}"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<CosplayProjectProvider>().deleteProject(project.id);
              if (context.mounted) {
                context.go('/dcosplay');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Projek cosplay berhasil dihapus.')),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      child: const Center(child: Icon(Icons.masks_outlined, size: 48, color: Colors.grey)),
    );
  }

  Widget _buildFallbackCharImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.person_outline, size: 36, color: Colors.grey)),
    );
  }

  void _showFullImageDialog(
    BuildContext context, {
    required String imageUrl,
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
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                  ),
                ),
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
