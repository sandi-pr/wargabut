import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/community_provider.dart';
import '../../../provider/profile_provider.dart';
import '../../components/community/member_card_dialog.dart';
import '../../components/shared/responsive_list_scaffold.dart';
import '../../components/tile/community_card.dart';

class CommunityListPage extends StatefulWidget {
  const CommunityListPage({super.key});

  @override
  State<CommunityListPage> createState() => _CommunityListPageState();
}

class _CommunityListPageState extends State<CommunityListPage> {
  final FocusNode _searchFocusNode = FocusNode();
  String _activeTab = 'komunitas'; // 'komunitas' | 'members'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchGlobalMembers();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showCityFilter(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Wilayah / Kota',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (provider.selectedCity != null)
                    TextButton(
                      onPressed: () {
                        provider.setSelectedCity(null);
                        Navigator.pop(context);
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.availableCities.map((city) {
                  final isSelected = provider.selectedCity == city;
                  return ChoiceChip(
                    label: Text(city),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setSelectedCity(selected ? city : null);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryFilter(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Kategori Komunitas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (provider.selectedCategory != null)
                    TextButton(
                      onPressed: () {
                        provider.setSelectedCategory(null);
                        Navigator.pop(context);
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CommunityProvider.defaultCategories.map((cat) {
                  final isSelected = provider.selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setSelectedCategory(selected ? cat : null);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberCityFilter(BuildContext context) {
    final provider = context.read<ProfileProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Domisili Member',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (provider.selectedMemberCity != null)
                    TextButton(
                      onPressed: () {
                        provider.setSelectedMemberCity(null);
                        Navigator.pop(context);
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.globalMemberCities.map((city) {
                  final isSelected = provider.selectedMemberCity == city;
                  return ChoiceChip(
                    label: Text(city),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setSelectedMemberCity(selected ? city : null);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberTagFilter(BuildContext context) {
    final provider = context.read<ProfileProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Tag Persona',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (provider.selectedMemberTag != null)
                    TextButton(
                      onPressed: () {
                        provider.setSelectedMemberTag(null);
                        Navigator.pop(context);
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.globalMemberTags.map((tag) {
                  final isSelected = provider.selectedMemberTag == tag;
                  return ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setSelectedMemberTag(selected ? tag : null);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final communityProvider = context.watch<CommunityProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    final isKomunitasTab = _activeTab == 'komunitas';

    final currentSearchText = isKomunitasTab
        ? communityProvider.searchTerm
        : profileProvider.memberSearchTerm;

    final searchController = TextEditingController(text: currentSearchText);
    searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: searchController.text.length));

    return ResponsiveListScaffold(
      title: 'WargaKomunitas',
      searchHint: isKomunitasTab ? 'Cari komunitas atau kota...' : 'Cari member, kota, cosplan, atau tag...',
      drawerCurrentRoute: '/komunitas',
      searchController: searchController,
      searchFocusNode: _searchFocusNode,
      onSearchSubmitted: (val) {
        if (isKomunitasTab) {
          communityProvider.setSearchTerm(val);
        } else {
          profileProvider.setMemberSearchTerm(val);
        }
      },
      onClearSearch: () {
        if (isKomunitasTab) {
          communityProvider.clearFilters();
        } else {
          profileProvider.clearMemberFilters();
        }
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!authProvider.isLoggedIn) {
            context.push('/login');
          } else {
            if (isKomunitasTab) {
              context.push('/komunitas/baru');
            } else {
              context.push('/@me');
            }
          }
        },
        icon: Icon(isKomunitasTab ? Icons.group_add : Icons.badge),
        label: Text(isKomunitasTab ? 'Daftarkan Komunitas' : 'Edit Biodata Saya'),
      ),
      bodyContent: RefreshIndicator(
        onRefresh: () async {
          if (isKomunitasTab) {
            await communityProvider.fetchCommunities(forceRefresh: true);
          } else {
            await profileProvider.fetchGlobalMembers(forceRefresh: true);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner Sambutan
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.diversity_3, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'WargaKomunitas & Member ID',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Temukan komunitas pop culture favoritmu dan berkenalan dengan sesama wibu & cosplayer dari seluruh Indonesia. Bagikan kartu biodata digitalmu dan temukan teman sefrekuensi!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            if (!authProvider.isLoggedIn) {
                              context.push('/login');
                            } else {
                              context.push('/@me');
                            }
                          },
                          icon: const Icon(Icons.badge, size: 18),
                          label: const Text('Kartu Biodata Saya'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (!authProvider.isLoggedIn) {
                              context.push('/login');
                            } else {
                              context.push('/komunitas/baru');
                            }
                          },
                          icon: const Icon(Icons.group_add, size: 18),
                          label: const Text('Daftarkan Komunitas Baru'),
                        ),
                        if (authProvider.isAdmin)
                          FilledButton.tonalIcon(
                            onPressed: () => context.push('/admin/komunitas'),
                            icon: const Icon(Icons.admin_panel_settings, size: 18),
                            label: const Text('Verifikasi Komunitas (Admin)'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Segmented Button: Tab Komunitas vs Tab Direktori Member
              Center(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'komunitas',
                      label: Text('Komunitas (${communityProvider.filteredCommunities.length})'),
                      icon: const Icon(Icons.groups),
                    ),
                    ButtonSegment<String>(
                      value: 'members',
                      label: Text('Member Wargabut (${profileProvider.filteredGlobalMembers.length})'),
                      icon: const Icon(Icons.badge),
                    ),
                  ],
                  selected: {_activeTab},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _activeTab = newSelection.first;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Filter Chips
              if (isKomunitasTab)
                // Filter Komunitas
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: communityProvider.selectedCity != null,
                        avatar: const Icon(Icons.location_on, size: 16),
                        label: Text(communityProvider.selectedCity ?? 'Semua Kota'),
                        onSelected: (_) => _showCityFilter(context),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: communityProvider.selectedCategory != null,
                        avatar: const Icon(Icons.category, size: 16),
                        label: Text(communityProvider.selectedCategory ?? 'Semua Kategori'),
                        onSelected: (_) => _showCategoryFilter(context),
                      ),
                      if (communityProvider.selectedCity != null ||
                          communityProvider.selectedCategory != null ||
                          communityProvider.searchTerm.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.close, size: 16),
                          label: const Text('Hapus Filter'),
                          onPressed: () => communityProvider.clearFilters(),
                        ),
                      ],
                    ],
                  ),
                )
              else
                // Filter Member
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: profileProvider.selectedMemberCity != null,
                        avatar: const Icon(Icons.location_on, size: 16),
                        label: Text(profileProvider.selectedMemberCity ?? 'Semua Domisili'),
                        onSelected: (_) => _showMemberCityFilter(context),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: profileProvider.selectedMemberTag != null,
                        avatar: const Icon(Icons.tag, size: 16),
                        label: Text(profileProvider.selectedMemberTag ?? 'Semua Tag Persona'),
                        onSelected: (_) => _showMemberTagFilter(context),
                      ),
                      if (profileProvider.selectedMemberCity != null ||
                          profileProvider.selectedMemberTag != null ||
                          profileProvider.memberSearchTerm.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.close, size: 16),
                          label: const Text('Hapus Filter'),
                          onPressed: () => profileProvider.clearMemberFilters(),
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // CONTENT VIEW
              if (isKomunitasTab)
                // KONTEN TAB 1: KOMUNITAS
                communityProvider.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : communityProvider.filteredCommunities.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum Ada Komunitas Ditemukan',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Coba ubah kata kunci atau filter pencarian Anda, atau daftarkan komunitas Anda sekarang!',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.tonal(
                                    onPressed: () => communityProvider.clearFilters(),
                                    child: const Text('Reset Pencarian'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : width <= 650
                            ? ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: communityProvider.filteredCommunities.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final community = communityProvider.filteredCommunities[index];
                                  return CommunityCard(community: community);
                                },
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: communityProvider.filteredCommunities.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: width > 1100 ? 3 : 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: width > 1100 ? 1.55 : 1.4,
                                ),
                                itemBuilder: (context, index) {
                                  final community = communityProvider.filteredCommunities[index];
                                  return CommunityCard(community: community);
                                },
                              )
              else
                // KONTEN TAB 2: DIREKTORI MEMBER WARGABUT
                profileProvider.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : profileProvider.filteredGlobalMembers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_search, size: 64, color: colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum Ada Member Ditemukan',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Coba ubah kata kunci, kota, atau tag persona Anda.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.tonal(
                                    onPressed: () => profileProvider.clearMemberFilters(),
                                    child: const Text('Reset Filter Member'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : width <= 650
                            ? ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: profileProvider.filteredGlobalMembers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final member = profileProvider.filteredGlobalMembers[index];
                                  return _buildMemberCard(context, member, colorScheme, authProvider);
                                },
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: profileProvider.filteredGlobalMembers.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: width > 1100 ? 3 : 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: width > 1100 ? 2.3 : 2.0,
                                ),
                                itemBuilder: (context, index) {
                                  final member = profileProvider.filteredGlobalMembers[index];
                                  return _buildMemberCard(context, member, colorScheme, authProvider);
                                },
                              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    UserProfileModel member,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          MemberCardDialog.show(
            context,
            profile: member,
            isSelf: authProvider.user?.uid == member.uid,
            isLoggedIn: authProvider.isLoggedIn,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: member.avatarUrl.isNotEmpty
                        ? NetworkImage(member.avatarUrl)
                        : null,
                    child: member.avatarUrl.isEmpty
                        ? Icon(Icons.person, color: colorScheme.primary, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName.isNotEmpty ? member.displayName : member.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${member.username}',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (member.city.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: colorScheme.outline),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    member.city,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.outline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (member.customTags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: member.customTags.take(4).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else if (member.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  member.bio,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (member.cosplans.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.theater_comedy, size: 13, color: colorScheme.tertiary),
                          const SizedBox(width: 4),
                          Text(
                            '${member.cosplans.length} Cosplan',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                  Text(
                    'Buka Kartu ID →',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
