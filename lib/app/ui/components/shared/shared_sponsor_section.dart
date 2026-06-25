import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_sponsors.dart'; // Sesuaikan path

enum SponsorDisplayType { banner, logo, poster }

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
        Text(
          displayType == SponsorDisplayType.poster
              ? 'Pengumuman Khusus'
              : 'Sponsor',
          style: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14, // Ukuran font sedikit dikecilkan agar elegan
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12.0),

        if (displayType == SponsorDisplayType.banner)
          _buildBannerLayout()
        else if (displayType == SponsorDisplayType.poster)
          _buildPosterLayout()
        else
          _buildLogoLayout(),
      ],
    );
  }

  Widget _buildPosterLayout() {
    // Saring hanya sponsor yang memiliki posterUrl
    final posterSponsors = activeSponsors.where((s) => s.posterUrl != null).toList();

    if (posterSponsors.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Scroll ke samping
      physics: const BouncingScrollPhysics(), // Efek pantulan yang halus
      child: Row(
        children: posterSponsors.map((sponsor) {
          return Padding(
            // Jarak antar poster
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: InkWell(
              onTap: () => _launchUrl(sponsor.linkUrl),
              borderRadius: BorderRadius.circular(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image(
                  // Batasi tinggi poster agar tidak menutupi seluruh layar HP
                  height: 320,
                  fit: BoxFit.cover,
                  image: AssetImage(sponsor.posterUrl!),
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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