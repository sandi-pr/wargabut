import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/menu_item_model.dart';

class AppDrawer extends StatelessWidget {
  final bool isDesktop;
  final String currentRoute;
  final List<MenuItemModel> menuItems;

  /// untuk login/logout
  final VoidCallback? onLogout;
  final VoidCallback? onLogin;
  final bool isLoggedIn;

  const AppDrawer({
    super.key,
    required this.isDesktop,
    required this.currentRoute,
    required this.menuItems,
    required this.isLoggedIn,
    this.onLogout,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final activeMenu = menuItems.firstWhere(
          (m) => m.route == currentRoute,
      orElse: () => menuItems.first,
    );

    final drawerContent = Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          _buildHeader(activeMenu.headerImage),
          ...menuItems.map((m) => _buildMenuTile(context, m)),
          const Spacer(),
          const Divider(),
          _buildAuthSection(context),
        ],
      ),
    );

    if (isDesktop) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
        ),
        child: drawerContent,
      );
    }

    return drawerContent;
  }

  // ---------------- HEADER DINAMIS ----------------
  Widget _buildHeader(String imagePath) {
    return SizedBox(
      height: isDesktop ? 120 : 140,
      width: double.infinity,
      child: DrawerHeader(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: const SizedBox.shrink(),
      ),
    );
  }

  // ---------------- MENU ITEM DINAMIS ----------------
  Widget _buildMenuTile(BuildContext context, MenuItemModel menu) {
    final isSelected = menu.route == currentRoute;

    return ListTile(
      title: Text(menu.label),
      subtitle: Text(menu.subtitle),
      selected: isSelected,
      onTap: () {
        if (!isSelected) context.pushReplacement(menu.route);

        if (!isDesktop) Navigator.pop(context);
      },
    );
  }

  // ---------------- LOGIN / LOGOUT ----------------
  Widget _buildAuthSection(BuildContext context) {
    return ListTile(
      title: Text(isLoggedIn ? "Logout" : "Login Admin"),
      leading: Icon(isLoggedIn ? Icons.logout : Icons.login),
      onTap: () {
        if (isLoggedIn) {
          onLogout?.call();
        } else {
          onLogin?.call();
        }

        if (!isDesktop) Navigator.pop(context);
      },
    );
  }
}
