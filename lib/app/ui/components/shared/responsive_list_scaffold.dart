import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/app_menus.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/theme_provider.dart';
import '../../components/drawer/app_drawer.dart';

class ResponsiveListScaffold extends StatelessWidget {
  final String title;
  final String searchHint;
  final String drawerCurrentRoute;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Widget bodyContent;
  final Widget? floatingActionButton;

  // Callback events
  final Function(String) onSearchSubmitted;
  final VoidCallback onClearSearch;

  const ResponsiveListScaffold({
    super.key,
    required this.title, // Bisa dipakai jika ingin menampilkan judul di AppBar mobile
    required this.searchHint,
    required this.drawerCurrentRoute,
    required this.searchController,
    required this.searchFocusNode,
    required this.bodyContent,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    // --- LOGIC DRAWER ---
    Widget buildDrawer(bool isDesktopMode) {
      final drawer = AppDrawer(
        isDesktop: isDesktopMode,
        currentRoute: drawerCurrentRoute,
        menuItems: appMenus,
        isLoggedIn: authProvider.isLoggedIn,
        onLogout: authProvider.isLoggedIn ? authProvider.signOut : null,
        onLogin: !authProvider.isLoggedIn ? () => context.push('/login') : null,
      );

      if (isDesktopMode) {
        return Container(
          width: 250,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1.0,
              ),
            ),
          ),
          child: drawer,
        );
      }
      return drawer;
    }

    // --- LOGIC APP BAR (SEARCH) ---
    PreferredSizeWidget buildAppBar() {
      return AppBar(
        titleSpacing: 0.0,
        surfaceTintColor: Colors.transparent,
        title: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SearchBar(
              // Key penting agar text ter-update saat tombol clear ditekan
              key: Key(searchController.text),
              controller: searchController,
              focusNode: searchFocusNode,
              hintText: searchHint,
              shadowColor: WidgetStateColor.resolveWith((s) => Colors.transparent),
              padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 16.0)),
              onSubmitted: onSearchSubmitted,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              leading: const Icon(Icons.search),
              trailing: <Widget>[
                if (searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClearSearch,
                  )
                else
                  Tooltip(
                    message: 'Ubah tema',
                    child: IconButton(
                      isSelected: themeProvider.isDark,
                      onPressed: themeProvider.toggleTheme,
                      icon: const Icon(Icons.wb_sunny_outlined),
                      selectedIcon: const Icon(Icons.brightness_2_outlined),
                    ),
                  )
              ],
            ),
          ),
        ),
      );
    }

    // --- LAYOUT DESKTOP ---
    if (isDesktop) {
      return Scaffold(
        floatingActionButton: floatingActionButton,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildDrawer(true), // Drawer Desktop
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  buildAppBar(), // AppBar ada di dalam Column konten
                  Expanded(
                    child: bodyContent, // Konten Utama
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // --- LAYOUT MOBILE ---
    return Scaffold(
      appBar: buildAppBar(),
      drawer: buildDrawer(false), // Drawer Mobile (Overlay)
      floatingActionButton: floatingActionButton,
      body: bodyContent,
    );
  }
}