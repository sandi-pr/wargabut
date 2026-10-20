import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/cosplay_project_model.dart';

class CosplayProjectCard extends StatelessWidget {
  final CosplayProjectModel project;

  const CosplayProjectCard({
    super.key,
    required this.project,
  });

  Color _getStatusColor(String status, BuildContext context) {
    switch (status) {
      case 'full':
        return Colors.redAccent;
      case 'almost_full':
        return Colors.orangeAccent;
      case 'completed':
        return Colors.blueGrey;
      case 'cancelled':
        return Colors.grey;
      case 'open':
      default:
        return Colors.teal;
    }
  }

  String _getStatusLabel(String status, int openSlots) {
    switch (status) {
      case 'full':
        return 'Penuh (Lengkap)';
      case 'almost_full':
        return 'Sisa $openSlots Slot';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'open':
      default:
        return '$openSlots Slot Buka';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(project.status, context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/dcosplay/${project.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER / KEY VISUAL
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: project.bannerUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: project.bannerUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) => _buildFallbackBanner(theme),
                        )
                      : _buildFallbackBanner(theme),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
                // Series Title & Category Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          project.seriesCategory.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          project.seriesTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge (Penuh / Sisa Slot)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _getStatusLabel(project.status, project.openSlotsCount),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Project Title in Banner
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. BODY CONTENT
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target Event / Venue & Date
                  Row(
                    children: [
                      Icon(
                        project.targetType == 'event' ? Icons.festival_outlined : Icons.photo_camera_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          project.targetEventName?.isNotEmpty == true
                              ? project.targetEventName!
                              : (project.targetCityOrVenue.isNotEmpty
                                  ? project.targetCityOrVenue
                                  : 'Lokasi Fleksibel'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (project.targetDate.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          project.targetDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // PROGRESS BAR SLOT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Keterisian Karakter:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          Text(
                            '${project.filledSlotsCount} / ${project.totalSlots} Karakter',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: project.isFull ? Colors.redAccent : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: project.progressPercentage,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            project.isFull ? Colors.teal : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // FOOTER: Organizer + Slot Previews
                  Row(
                    children: [
                      // Creator Avatar & Username
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: project.creatorAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(project.creatorAvatar)
                            : null,
                        child: project.creatorAvatar.isEmpty
                            ? Text(
                                project.creatorName.isNotEmpty ? project.creatorName[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          project.creatorUsername.isNotEmpty
                              ? '@${project.creatorUsername}'
                              : project.creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Character Slot Count Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${project.totalSlots} Slot',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBanner(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.8),
            theme.colorScheme.secondary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.masks_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
