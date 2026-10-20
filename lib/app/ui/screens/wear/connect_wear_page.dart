import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/profile_provider.dart';
import '../../../services/wearable_sync_service.dart';

class ConnectWearPage extends StatefulWidget {
  const ConnectWearPage({super.key});

  @override
  State<ConnectWearPage> createState() => _ConnectWearPageState();
}

class _ConnectWearPageState extends State<ConnectWearPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handlePairing(UserProfileModel profile) async {
    final rawCode = _codeController.text.trim();
    if (rawCode.isEmpty) {
      setState(() {
        _statusMessage = 'Harap masukkan 6 digit kode dari layar smartwatch.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final success = await WearableSyncService.pairWearDeviceWithCode(
        code: rawCode,
        profile: profile,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = success;
          if (success) {
            _statusMessage =
                '✅ Berhasil terhubung! Smartwatch kamu (${rawCode.toUpperCase()}) sekarang sudah terotentikasi sebagai @${profile.username}.';
          } else {
            _statusMessage =
                '❌ Gagal menghubungkan. Pastikan kode benar dan smartwatch terhubung ke internet.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = false;
          _statusMessage = 'Terjadi kesalahan: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hubungkan Smartwatch (Wear OS)'),
        leading: IconButton(
          icon: Icon(context.canPop() ? Icons.arrow_back : Icons.home),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/welcome');
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.watch,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tautkan Xiaomi Watch 2 Pro / Wear OS',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nikmati akses cepat Kartu ID QR Wargabut, hitung mundur event cosplay terdekat, dan jadwal anime langsung dari pergelangan tanganmu.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    if (!authProvider.isLoggedIn || profile == null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade700, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Kamu perlu login terlebih dahulu untuk menghubungkan smartwatch ke akun Wargabut kamu.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.go('/login?from=/wear'),
                        icon: const Icon(Icons.login),
                        label: const Text('Login Sekarang'),
                      ),
                    ] else ...[
                      // Box Akun Pengguna
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: profile.avatarUrl.isNotEmpty
                                  ? NetworkImage(profile.avatarUrl)
                                  : null,
                              child: profile.avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.displayName.isNotEmpty
                                        ? profile.displayName
                                        : profile.username,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '@${profile.username}',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Aktif',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Input Kode Smartwatch
                      TextField(
                        controller: _codeController,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Kode Pairing Smartwatch',
                          hintText: 'WB-XXXX',
                          helperText: 'Masukkan 6 karakter kode yang muncul di jam tangan kamu',
                          prefixIcon: const Icon(Icons.pin),
                          suffixIcon: _codeController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _codeController.clear();
                                      _statusMessage = null;
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _handlePairing(profile),
                      ),
                      const SizedBox(height: 20),

                      if (_statusMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isSuccess
                                ? Colors.green.withOpacity(0.12)
                                : Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isSuccess ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isSuccess ? Icons.check_circle : Icons.error_outline,
                                color: _isSuccess ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _statusMessage!,
                                  style: TextStyle(
                                    color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : () => _handlePairing(profile),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.link),
                        label: Text(
                          _isSubmitting ? 'Menghubungkan...' : 'Hubungkan Smartwatch',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
