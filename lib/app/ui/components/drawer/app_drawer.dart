import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/menu_item_model.dart';
import '../../../provider/aninews_provider.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/event_provider.dart';
import '../../../provider/konser_provider.dart';

class AppDrawer extends StatefulWidget {
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
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? authProvider;
    try {
      authProvider = context.watch<AuthProvider>();
    } catch (_) {}
    final isAdmin = authProvider?.isAdmin ?? _isAdmin;

    final activeMenu = widget.menuItems.firstWhere(
          (m) => m.route == widget.currentRoute,
      orElse: () => widget.menuItems.first,
    );

    final displayedMenuItems = widget.menuItems.where((m) {
      if (m.route == '/tanya-maps' && !isAdmin) return false;
      return true;
    }).toList();

    final drawerContent = Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          _buildHeader(activeMenu.headerImage),
            Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...displayedMenuItems.map((m) => _buildMenuTile(context, m)),
                if (isAdmin) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildAdminTile(context),
                ],
              ],
            ),
          ),
          // const Padding(
          //   padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          //   child: SharedSponsorSection(
          //     displayType: SponsorDisplayType.logo, // <--- Panggil tipe Logo
          //   ),
          // ),
          const Divider(),
          _buildAuthSection(context),
        ],
      ),
    );

    if (widget.isDesktop) {
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

  // ---------------- ADMIN TILE ----------------
  Widget _buildAdminTile(BuildContext context) {
    final isSelected = widget.currentRoute == '/admin/storage';

    return ListTile(
      leading: const Icon(Icons.cleaning_services, color: Colors.orange),
      title: const Text('Cleanup'),
      subtitle: const Text('Storage, old events & images'),
      selected: isSelected,
      onTap: () {
        if (!isSelected) context.push('/admin/storage');
        if (!widget.isDesktop) Navigator.pop(context);
      },
    );
  }

  // ---------------- HEADER DINAMIS ----------------
  Widget _buildHeader(String imagePath) {
    return SizedBox(
      height: widget.isDesktop ? 120 : 140,
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
    final isSelected = menu.route == widget.currentRoute;

    void resetAllFilters(BuildContext context) {
      context.read<AniNewsProvider>().clearFilters();
      context.read<EventProvider>().clearFilters();
      context.read<KonserProvider>().clearFilters();
    }

    final isDevFeature = menu.route == '/tanya-maps';

    return ListTile(
      title: Row(
        children: [
          Text(menu.label),
          if (isDevFeature) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber, width: 0.8),
              ),
              child: const Text(
                'DEV',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(menu.subtitle),
      selected: isSelected,
      onTap: () {
        resetAllFilters(context);
        if (!isSelected) context.pushReplacement(menu.route);

        if (!widget.isDesktop) Navigator.pop(context);
      },
    );
  }

  // ---------------- LOGIN / LOGOUT ----------------
  Widget _buildAuthSection(BuildContext context) {
    if (widget.isLoggedIn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text("Biodata Saya"),
            subtitle: const Text("Kelola kartu ID & privasi"),
            onTap: () {
              context.push('/@me');
              if (!widget.isDesktop) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Logout"),
            onTap: () {
              final messenger = ScaffoldMessenger.of(context);
              if (!widget.isDesktop) Navigator.pop(context);
              widget.onLogout?.call();
              messenger.showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Berhasil keluar akun (logout)",
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      );
    }

    return ListTile(
      leading: const Icon(Icons.login),
      title: const Text("Masuk / Daftar"),
      subtitle: const Text("Kelola profil & komunitas"),
      onTap: () {
        widget.onLogin?.call();
        if (!widget.isDesktop) Navigator.pop(context);
      },
    );
  }
}
