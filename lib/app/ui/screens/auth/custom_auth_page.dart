import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/profile_provider.dart';

class CustomAuthPage extends StatefulWidget {
  const CustomAuthPage({super.key});

  @override
  State<CustomAuthPage> createState() => _CustomAuthPageState();
}

class _CustomAuthPageState extends State<CustomAuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login controllers
  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;

  // Register controllers
  final _regUsernameController = TextEditingController();
  final _regDisplayNameController = TextEditingController();
  final _regCityController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  bool _regObscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        _navigateAfterLogin();
      }
    });
  }

  void _navigateAfterLogin() {
    if (!mounted) return;
    final profileProvider = context.read<ProfileProvider>();
    final profile = profileProvider.currentProfile;
    final hasBiodata = profile != null && profile.hasFilledBiodata;

    if (hasBiodata) {
      // Jika member sudah pernah mengisi biodata: kembali ke halaman terakhir
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      if (from != null && from.isNotEmpty && !from.startsWith('/login')) {
        context.go(from);
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/jeventku');
      }
    } else {
      // Jika belum pernah mengisi biodata: arahkan untuk mengisi biodata
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan lengkapi kartu biodata Anda terlebih dahulu.'),
          backgroundColor: Colors.blueAccent,
        ),
      );
      context.go('/@me');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regUsernameController.dispose();
    _regDisplayNameController.dispose();
    _regCityController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _loginIdentifierController.text.trim();
    final password = _loginPasswordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan username/email dan password.')),
      );
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.loginWithUsernameOrEmail(
      usernameOrEmail: identifier,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil masuk!'), backgroundColor: Colors.green),
      );
      _navigateAfterLogin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileProvider.errorMessage ?? 'Gagal masuk.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    final username = _regUsernameController.text.trim();
    final displayName = _regDisplayNameController.text.trim();
    final city = _regCityController.text.trim();
    final password = _regPasswordController.text;
    final confirm = _regConfirmPasswordController.text;

    if (username.isEmpty || displayName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username, nama panggilan, dan password wajib diisi.')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi password tidak cocok.')),
      );
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    final success = await profileProvider.registerWithUsername(
      username: username,
      password: password,
      displayName: displayName,
      city: city,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun berhasil dibuat! Silakan lengkapi biodata Anda.'), backgroundColor: Colors.green),
      );
      context.go('/@me');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileProvider.errorMessage ?? 'Gagal mendaftar.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun Wargabut'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Masuk (Login)', icon: Icon(Icons.login)),
            Tab(text: 'Daftar Akun Baru', icon: Icon(Icons.person_add)),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  height: 520,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: LOGIN
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selamat Datang di Wargabut', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            'Masuk menggunakan username atau email Anda untuk mengelola komunitas dan biodata.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _loginIdentifierController,
                            decoration: const InputDecoration(
                              labelText: 'Username atau Email',
                              hintText: 'Contoh: sandi atau email@domain.com',
                              prefixIcon: Icon(Icons.account_circle),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _loginPasswordController,
                            obscureText: _loginObscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_loginObscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
                              ),
                            ),
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: profileProvider.isLoading ? null : _handleLogin,
                              child: profileProvider.isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Masuk Sekarang', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: TextButton(
                              onPressed: () => _tabController.animateTo(1),
                              child: const Text('Belum punya akun? Daftar gratis di sini'),
                            ),
                          ),
                        ],
                      ),

                      // TAB 2: REGISTER
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Daftar Akun Baru', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 18, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Privasi aman: Anda bisa mendaftar hanya dengan username tanpa wajib membagikan email pribadi!',
                                      style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _regUsernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username (Unik) *',
                                hintText: 'Contoh: sandi, yuki_cos',
                                prefixIcon: Icon(Icons.alternate_email),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _regDisplayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Panggilan / Nickname *',
                                hintText: 'Contoh: Yuki, Sandi',
                                prefixIcon: Icon(Icons.badge),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _regCityController,
                              decoration: const InputDecoration(
                                labelText: 'Asal Kota / Domisili',
                                hintText: 'Contoh: Bogor, Jakarta',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _regPasswordController,
                              obscureText: _regObscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password (Minimal 6 karakter) *',
                                prefixIcon: const Icon(Icons.lock),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: Icon(_regObscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _regObscurePassword = !_regObscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _regConfirmPasswordController,
                              obscureText: _regObscurePassword,
                              decoration: const InputDecoration(
                                labelText: 'Konfirmasi Password *',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: profileProvider.isLoading ? null : _handleRegister,
                                child: profileProvider.isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Buat Akun & Kartu Biodata', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
