import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../models/cosplay_project_model.dart';
import '../../../../provider/cosplay_project_provider.dart';

class ProjectApplicantsDialog extends StatelessWidget {
  final CosplayProjectModel project;

  const ProjectApplicantsDialog({
    super.key,
    required this.project,
  });

  static void show(BuildContext context, {required CosplayProjectModel project}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ProjectApplicantsDialog(project: project),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CosplayProjectProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Pelamar Slot',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        project.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<List<ProjectApplicationModel>>(
                  stream: provider.streamApplicationsForProject(project.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final apps = snapshot.data ?? [];
                    if (apps.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            const Text('Belum ada pelamar untuk projek ini.'),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: apps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final isPending = app.status == 'pending';
                        final isApproved = app.status == 'approved';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isApproved
                                  ? Colors.teal.withValues(alpha: 0.5)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Avatar Pelamar
                                  GestureDetector(
                                    onTap: () {
                                      if (app.applicantUsername.isNotEmpty) {
                                        context.push('/@${app.applicantUsername}');
                                      }
                                    },
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: app.applicantAvatar.isNotEmpty
                                          ? CachedNetworkImageProvider(app.applicantAvatar)
                                          : null,
                                      child: app.applicantAvatar.isEmpty
                                          ? const Icon(Icons.person, size: 20)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              app.applicantName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () {
                                                if (app.applicantUsername.isNotEmpty) {
                                                  context.push('/@${app.applicantUsername}');
                                                }
                                              },
                                              child: Text(
                                                '@${app.applicantUsername}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme.colorScheme.primary,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Mengajukan Karakter: ${app.characterName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isApproved
                                          ? Colors.teal.withValues(alpha: 0.2)
                                          : isPending
                                              ? Colors.orange.withValues(alpha: 0.2)
                                              : Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isApproved
                                          ? 'Diterima'
                                          : isPending
                                              ? 'Menunggu'
                                              : 'Ditolak',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isApproved
                                            ? Colors.teal
                                            : isPending
                                                ? Colors.orange
                                                : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (app.message.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '"${app.message}"',
                                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],

                              if (isPending) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () {
                                        if (app.applicantUsername.isNotEmpty) {
                                          context.push('/@${app.applicantUsername}');
                                        }
                                      },
                                      child: const Text('Lihat Biodata'),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () async {
                                        await provider.rejectApplication(
                                          applicationId: app.id,
                                          projectId: project.id,
                                          slotId: app.slotId,
                                        );
                                      },
                                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                      child: const Text('Tolak'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () async {
                                        await provider.approveApplication(
                                          projectId: project.id,
                                          application: app,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${app.applicantName} berhasil diterima di slot ${app.characterName}!'),
                                              backgroundColor: Colors.teal,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Terima'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
