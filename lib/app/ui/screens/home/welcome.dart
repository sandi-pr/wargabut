import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:localstorage/localstorage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wargabut/app/ui/components/shared/shared_sponsor_section.dart';

// --- DATA MODEL UNTUK MENU PORTAL ---
class PortalMenu {
  final String title;
  final String subtitle;
  final String imagePath;
  final String route;
  final Color accentColor;

  PortalMenu({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.route,
    required this.accentColor,
  });
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    _setVisitDate();
  }

  Future<void> _setVisitDate() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (kIsWeb) {
      await initLocalStorage();
      localStorage.setItem('lastVisit', today);
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastVisit', today);
    }
  }

  // --- DAFTAR MENU APLIKASI ---
  // Pastikan path gambarnya sesuai dengan yang Anda punya
  final List<PortalMenu> _menus = [
    PortalMenu(
      title: 'JEventku',
      subtitle: 'Cari event cosplay & budaya Jejepangan.',
      imagePath: 'assets/images/JEventku_banner_home.png',
      route: '/jeventku',
      accentColor: Colors.blue.shade300,
    ),
    PortalMenu(
      title: 'AniChekku',
      subtitle: 'Update berita anime & jadwal rilis.',
      imagePath: 'assets/images/anichekku_banner_home.png', // Sesuaikan nama file
      route: '/anichekku',
      accentColor: Colors.teal.shade300,
    ),
    PortalMenu(
      title: 'dKonser',
      subtitle: 'Temukan festival musik & musisi favorit.',
      imagePath: 'assets/images/dKonser_banner_home.png', // Sesuaikan nama file
      route: '/dkonser',
      accentColor: Colors.indigo.shade300,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // 1. HEADER (Maskot + Sapaan)
                  _buildHeader(context),

                  const SizedBox(height: 40),

                  // 2. PORTAL MENU (Pilihan Jelajah)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Wrap(
                      spacing: 24.0,
                      runSpacing: 24.0,
                      alignment: WrapAlignment.center,
                      // PANGGIL WIDGET BARU DI SINI
                      children: _menus.map((menu) => AnimatedPortalCard(
                          menu: menu,
                          isDesktop: isDesktop
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // 3. SPONSOR SECTION
                  const SharedSponsorSection(
                    displayType: SponsorDisplayType.banner,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
              Positioned(
                top: 24.0, // Jarak dari atas layar
                left: 32.0, // Jarak dari kiri layar (disamakan dengan padding dalam card banner)
                child: Image(
                  image: const AssetImage('assets/icon/wg_logo_web.png'),
                  height: isDesktop ? 90 : 64, // Responsif: sedikit lebih kecil di mobile
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HEADER (FIX DESKTOP CLIPPING & WIDTH) ---
  Widget _buildHeader(BuildContext context) {
    // Kita ubah titik batas Desktop menjadi 900 agar lebih akurat
    bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      // Gunakan Center agar saat di layar Ultra Wide, banner tetap di tengah
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [

            // 1. BACKGROUND CARD
            Container(
              width: double.infinity,
              // [DIUBAH] Lebarkan batas maksimalnya agar terasa lebih 'full'
              constraints: const BoxConstraints(maxWidth: 1200),

              // [DIUBAH] INI KUNCINYA: Berikan margin atas yang SANGAT BESAR
              // di desktop agar kepala Aoi-chan punya ruang dan tidak menabrak atap layar
              margin: EdgeInsets.only(top: isDesktop ? 220.0 : 80.0),

              padding: EdgeInsets.only(
                left: isDesktop ? 48.0 : 32.0,
                top: isDesktop ? 48.0 : 32.0,
                bottom: isDesktop ? 48.0 : 32.0,
                // Padding kanan pastikan cukup lebar
                right: isDesktop ? 380.0 : 190.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang di Wargabut!',
                    style: TextStyle(
                      // [DIUBAH] Font juga dibesarkan agar seimbang dengan kotak yang lebar
                      fontSize: isDesktop ? 32 : 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pusat media hiburanmu.\nMau jelajah ke mana hari ini?',
                    style: TextStyle(
                      fontSize: isDesktop ? 20 : 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 2. MASKOT
            Positioned(
              // Di desktop, geser sedikit menjauh dari tepi kanan agar lebih dinamis
              right: isDesktop ? 40 : 16,
              bottom: 0,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.85, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Image(
                  image: const AssetImage('assets/images/kimono_aoi.png'),
                  // [DIUBAH] Tinggi maskot untuk desktop dimaksimalkan!
                  height: isDesktop ? 440 : 260,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET PORTAL CARD DENGAN ANIMASI ---
class AnimatedPortalCard extends StatefulWidget {
  final PortalMenu menu;
  final bool isDesktop;

  const AnimatedPortalCard({
    super.key,
    required this.menu,
    required this.isDesktop
  });

  @override
  State<AnimatedPortalCard> createState() => _AnimatedPortalCardState();
}

class _AnimatedPortalCardState extends State<AnimatedPortalCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Logika Animasi:
    // Jika ditekan -> Mengecil sedikit (0.96)
    // Jika di-hover -> Membesar sedikit (1.03)
    // Normal -> Ukuran asli (1.0)
    final double scale = _isPressed ? 0.96 : (_isHovered ? 1.03 : 1.0);

    // Shadow / Elevasi juga ikut membesar saat di-hover
    final double elevation = _isHovered ? 8.0 : 3.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 150), // Kecepatan animasi
      curve: Curves.easeInOut,
      child: SizedBox(
        width: widget.isDesktop ? 350 : double.infinity,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: elevation, // Menggunakan elevasi dinamis
          shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => context.go(widget.menu.route),

            // --- DETEKSI HOVER DAN KLIK ---
            onHover: (isHovering) {
              setState(() {
                _isHovered = isHovering;
              });
            },
            onHighlightChanged: (isPressing) {
              setState(() {
                _isPressed = isPressing;
              });
            },

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar Banner Menu
                Container(
                  height: widget.isDesktop ? 120 : 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: widget.menu.accentColor.withOpacity(0.2),
                  ),
                  child: Image(
                    image: AssetImage(widget.menu.imagePath),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                  ),
                ),
                // Teks Deskripsi
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.menu.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.menu.subtitle,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          // Tombol di dalam kartu juga bisa ditekan, arahnya sama
                          onPressed: () => context.go(widget.menu.route),
                          child: const Text('Jelajahi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}