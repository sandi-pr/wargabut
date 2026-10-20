import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../provider/auth_provider.dart';
import '../../../provider/cosplay_project_provider.dart';
import '../../components/shared/responsive_list_scaffold.dart';
import '../../components/tile/cosplay_project_card.dart';

class CosplayProjectListPage extends StatefulWidget {
  const CosplayProjectListPage({super.key});

  @override
  State<CosplayProjectListPage> createState() => _CosplayProjectListPageState();
}

class _CosplayProjectListPageState extends State<CosplayProjectListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    context.read<CosplayProjectProvider>().setSearchQuery(query);
  }

  void _onClearSearch() {
    _searchController.clear();
    context.read<CosplayProjectProvider>().setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CosplayProjectProvider>();
    final auth = context.watch<AuthProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return ResponsiveListScaffold(
      title: 'Cosplay Project',
      searchHint: 'Cari projek anime, karakter, atau event...',
      drawerCurrentRoute: '/dcosplay',
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      onSearchSubmitted: _onSearchSubmitted,
      onClearSearch: _onClearSearch,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!auth.isLoggedIn) {
            context.push('/login?from=/dcosplay/baru');
          } else {
            context.push('/dcosplay/baru');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Buat Projek'),
      ),
      bodyContent: Column(
        children: [
          // 1. FILTER BAR (CATEGORY & ONLY OPEN SLOTS)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Chips Scrollable
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Toggle "Hanya Slot Tersedia"
                      FilterChip(
                        avatar: Icon(
                          provider.onlyOpenSlots ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: provider.onlyOpenSlots ? theme.colorScheme.primary : Colors.grey,
                        ),
                        label: const Text('Hanya Slot Buka'),
                        selected: provider.onlyOpenSlots,
                        onSelected: (val) {
                          provider.setOnlyOpenSlots(val);
                        },
                      ),
                      const SizedBox(width: 8),
                      const VerticalDivider(width: 1, thickness: 1),
                      const SizedBox(width: 8),

                      // Category options
                      ...CosplayProjectProvider.categoryOptions.map((cat) {
                        final isSelected = provider.selectedCategory == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                provider.setSelectedCategory(cat['id']!);
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Counter info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menampilkan ${provider.filteredProjects.length} projekan cosplay',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    if (provider.selectedCategory != 'semua' || provider.onlyOpenSlots || provider.searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          provider.clearFilters();
                        },
                        child: Text(
                          'Reset Filter',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. PROJECT LIST / GRID
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.filteredProjects.isEmpty
                    ? _buildEmptyView(theme, provider)
                    : RefreshIndicator(
                        onRefresh: () async {
                          provider.listenToProjects();
                        },
                        child: isDesktop
                            ? GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 460,
                                  mainAxisExtent: 285,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: provider.filteredProjects.length,
                                itemBuilder: (context, index) {
                                  final project = provider.filteredProjects[index];
                                  return CosplayProjectCard(project: project);
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: provider.filteredProjects.length,
                                itemBuilder: (context, index) {
                                  final project = provider.filteredProjects[index];
                                  return CosplayProjectCard(project: project);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme, CosplayProjectProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_3_outlined,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Projekan Cosplay',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.searchQuery.isNotEmpty || provider.selectedCategory != 'semua'
                  ? 'Tidak ada projekan yang cocok dengan filter pencarian.'
                  : 'Ayo buat projekan pertamamu untuk merekrut teman cosplay satu judul!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            if (provider.searchQuery.isNotEmpty || provider.selectedCategory != 'semua' || provider.onlyOpenSlots)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Semua Filter'),
              )
            else
              FilledButton.icon(
                onPressed: () {
                  context.push('/dcosplay/baru');
                },
                icon: const Icon(Icons.add),
                label: const Text('Mulai Buat Projekan'),
              ),
          ],
        ),
      ),
    );
  }
}
