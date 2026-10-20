import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/community_model.dart';

class CommunityCard extends StatelessWidget {
  final CommunityModel community;

  const CommunityCard({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/komunitas/${community.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner & Logo Stack
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    image: community.bannerUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(community.bannerUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: community.bannerUrl.isEmpty
                      ? Center(
                          child: Icon(
                            Icons.groups,
                            size: 40,
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                          ),
                        )
                      : null,
                ),
                // Logo di kiri bawah banner
                Positioned(
                  left: 16,
                  bottom: -22,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      backgroundImage: community.logoUrl.isNotEmpty
                          ? NetworkImage(community.logoUrl)
                          : null,
                      child: community.logoUrl.isEmpty
                          ? Icon(Icons.people, color: colorScheme.primary, size: 26)
                          : null,
                    ),
                  ),
                ),
                // Badge Kota di kanan atas banner
                if (community.cityOrArea.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            community.cityOrArea,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 26),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Komunitas & Verified Icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          community.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (community.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 18, color: colorScheme.primary),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Tagline / Short Desc
                  if (community.shortDesc.isNotEmpty)
                    Text(
                      community.shortDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 10),

                  // Categories
                  if (community.categories.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: community.categories.take(3).map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 12),

                  // Footer: Member Count & Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            '${community.memberCount} Anggota',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Lihat Profil →',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
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
}
