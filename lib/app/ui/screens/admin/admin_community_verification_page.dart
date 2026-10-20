import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/community_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/community_provider.dart';

class AdminCommunityVerificationPage extends StatefulWidget {
  const AdminCommunityVerificationPage({super.key});

  @override
  State<AdminCommunityVerificationPage> createState() => _AdminCommunityVerificationPageState();
}

class _AdminCommunityVerificationPageState extends State<AdminCommunityVerificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().fetchPendingCommunities();
    });
  }

  Future<void> _verify(CommunityModel community) async {
    final provider = context.read<CommunityProvider>();
    final success = await provider.verifyCommunity(community.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Komunitas "${community.name}" berhasil diverifikasi dan kini tayang ke publik!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _reject(CommunityModel community) async {
    final provider = context.read<CommunityProvider>();
    final success = await provider.rejectCommunity(community.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Komunitas "${community.name}" telah ditolak.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final communityProvider = context.watch<CommunityProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: const Center(child: Text('Hanya Admin Wargabut yang dapat mengakses halaman ini.')),
      );
    }

    final pendingList = communityProvider.pendingVerificationCommunities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Komunitas Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => communityProvider.fetchPendingCommunities(),
          ),
        ],
      ),
      body: communityProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_outlined, size: 64, color: colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Semua Komunitas Sudah Terverifikasi', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text('Tidak ada pendaftaran komunitas yang menunggu verifikasi saat ini.',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final com = pendingList[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: com.logoUrl.isNotEmpty ? NetworkImage(com.logoUrl) : null,
                                  child: com.logoUrl.isEmpty ? const Icon(Icons.people) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(com.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      Text('Slug: /komunitas/${com.id}', style: TextStyle(color: colorScheme.primary, fontSize: 12)),
                                      Text('Wilayah: ${com.cityOrArea}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: const Text('Menunggu Review', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (com.shortDesc.isNotEmpty)
                              Text(com.shortDesc, style: const TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Text(com.description, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              children: com.categories.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                            ),
                            const SizedBox(height: 12),
                            if (com.instagram.isNotEmpty || com.whatsappGroupLink.isNotEmpty)
                              Text('Kontak: IG: ${com.instagram} | WA: ${com.whatsappGroupLink}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 16),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _reject(com),
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  label: const Text('Tolak', style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: () => _verify(com),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Verifikasi & Publikasikan'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
