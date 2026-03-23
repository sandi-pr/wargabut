import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_sponsors.dart'; // Sesuaikan path

enum SponsorDisplayType { banner, logo }

class SharedSponsorSection extends StatelessWidget {
  final SponsorDisplayType displayType;
  final double logoSize;

  const SharedSponsorSection({
    super.key,
    this.displayType = SponsorDisplayType.banner, // Defaultnya banner
    this.logoSize = 84,
  });

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (activeSponsors.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Sponsor',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14, // Ukuran font sedikit dikecilkan agar elegan
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12.0),

        // Pengecekan tipe layout
        if (displayType == SponsorDisplayType.banner)
          _buildBannerLayout()
        else
          _buildLogoLayout(),
      ],
    );
  }

  // --- LAYOUT BANNER (Untuk Welcome View) ---
  Widget _buildBannerLayout() {
    return Column(
      children: activeSponsors.map((sponsor) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => _launchUrl(sponsor.linkUrl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image(
                  fit: BoxFit.cover,
                  image: AssetImage(sponsor.bannerUrl), // Menggunakan bannerUrl
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- LAYOUT LOGO BULAT (Untuk Sidebar / Drawer) ---
  Widget _buildLogoLayout() {
    // Wrap akan menyusun item ke samping, lalu otomatis turun ke baris baru jika penuh
    return Wrap(
      spacing: 16.0, // Jarak horizontal antar logo (kiri-kanan)
      runSpacing: 12.0, // Jarak vertikal antar baris (atas-bawah)
      alignment: WrapAlignment.center, // Logo berada di tengah
      children: activeSponsors.map((sponsor) {
        return InkWell(
          onTap: () => _launchUrl(sponsor.linkUrl),
          borderRadius: BorderRadius.circular(50), // Efek ripple bulat saat di-tap
          child: Container(
            width: logoSize, // Ukuran logo (lebar)
            height: logoSize, // Ukuran logo (tinggi)
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1), // Garis pinggir tipis
              image: DecorationImage(
                image: AssetImage(sponsor.logoUrl), // Menggunakan logoUrl
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}