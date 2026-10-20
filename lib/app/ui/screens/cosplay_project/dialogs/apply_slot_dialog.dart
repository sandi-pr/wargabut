import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/cosplay_project_model.dart';
import '../../../../provider/auth_provider.dart';
import '../../../../provider/cosplay_project_provider.dart';
import '../../../../provider/profile_provider.dart';

class ApplySlotDialog extends StatefulWidget {
  final CosplayProjectModel project;
  final CosplayProjectSlot slot;

  const ApplySlotDialog({
    super.key,
    required this.project,
    required this.slot,
  });

  static Future<bool?> show(BuildContext context, {
    required CosplayProjectModel project,
    required CosplayProjectSlot slot,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ApplySlotDialog(project: project, slot: slot),
    );
  }

  @override
  State<ApplySlotDialog> createState() => _ApplySlotDialogState();
}

class _ApplySlotDialogState extends State<ApplySlotDialog> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final profileProv = context.watch<ProfileProvider>();
    final myProfile = profileProv.currentProfile;

    final displayName = myProfile?.displayName.isNotEmpty == true
        ? myProfile!.displayName
        : (auth.user?.displayName ?? 'Pengguna Wargabut');
    final username = myProfile?.username.isNotEmpty == true
        ? myProfile!.username
        : (auth.user?.email?.split('@').first ?? 'warga');
    final avatarUrl = myProfile?.avatarUrl.isNotEmpty == true
        ? myProfile!.avatarUrl
        : (auth.user?.photoURL ?? '');
    final city = myProfile?.city ?? '';
    final instagram = myProfile?.instagram ?? '';
    final whatsapp = myProfile?.whatsapp ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ajukan Slot Karakter',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Character Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Reference Image
                      GestureDetector(
                        onTap: widget.slot.referenceImageUrl.isNotEmpty
                            ? () => _showFullImageDialog(
                                  context,
                                  imageUrl: widget.slot.referenceImageUrl,
                                  charName:
                                      '${widget.slot.characterName}${widget.slot.characterVersion.isNotEmpty ? " (${widget.slot.characterVersion})" : ""}',
                                )
                            : null,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: widget.slot.referenceImageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: widget.slot.referenceImageUrl,
                                      width: 56,
                                      height: 56,
                                      alignment: widget.slot.parsedAlignment,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => _buildFallbackCharImage(theme),
                                    )
                                  : _buildFallbackCharImage(theme),
                            ),
                            if (widget.slot.referenceImageUrl.isNotEmpty)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.fullscreen, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.slot.characterName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.slot.characterVersion.isNotEmpty)
                              Text(
                                'Versi: ${widget.slot.characterVersion}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (widget.slot.categoryGroup.isNotEmpty)
                              Text(
                                'Kategori: ${widget.slot.categoryGroup}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Biodata Info (Terhubung Kartu Biodata Wargabut)
                Text(
                  'Kartu Biodata Anda yang Terlampir:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                        child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '@$username ${city.isNotEmpty ? '• 📍 $city' : ''}',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                            ),
                            if (instagram.isNotEmpty)
                              Text(
                                'IG: @$instagram',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Message Text Field
                Text(
                  'Pesan / Keterangan Kesiapan Kostum:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Misal: Kostum wig & props sudah ready, domisili Tangerang siap ikut briefing.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            final user = auth.user;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Silakan login terlebih dahulu.')),
                              );
                              return;
                            }

                            setState(() => _isSubmitting = true);
                            final nav = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final provider = context.read<CosplayProjectProvider>();

                            try {
                              await provider.submitApplication(
                                    projectId: widget.project.id,
                                    projectTitle: widget.project.title,
                                    slotId: widget.slot.slotId,
                                    characterName: widget.slot.characterName,
                                    applicantUid: user.uid,
                                    applicantUsername: username,
                                    applicantName: displayName,
                                    applicantAvatar: avatarUrl,
                                    applicantCity: city,
                                    applicantInstagram: instagram,
                                    applicantWhatsApp: whatsapp,
                                    message: _messageController.text.trim(),
                                  );

                              if (mounted) {
                                nav.pop(true);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Pengajuan slot berhasil dikirim! Menunggu konfirmasi organizer.'),
                                    backgroundColor: Colors.teal,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Gagal mengajukan slot: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isSubmitting = false);
                            }
                          },
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'Mengirim...' : 'Kirim Pengajuan Slot'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCharImage(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.person_pin, size: 28),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
