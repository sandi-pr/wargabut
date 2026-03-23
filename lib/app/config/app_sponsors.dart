class SponsorConfig {
  final String bannerUrl; // Gambar panjang untuk Welcome View
  final String logoUrl;   // Gambar kotak/bulat untuk Sidebar
  final String linkUrl;

  const SponsorConfig({
    required this.bannerUrl,
    required this.logoUrl,
    required this.linkUrl,
  });
}

// DAFTAR SPONSOR ANDA
const List<SponsorConfig> activeSponsors = [
  SponsorConfig(
    bannerUrl: 'assets/images/banner-squid_rentcos.jpg',
    logoUrl: 'assets/images/logo-squid_rentcos.png', // Ganti dengan nama file logo Anda
    linkUrl: 'https://www.instagram.com/squid_rentcos',
  ),
  // Coba hilangkan komen di bawah ini untuk melihat efek 2 sponsor sejajar:
  // SponsorConfig(
  //   bannerUrl: 'assets/images/banner-sponsor2.jpg',
  //   logoUrl: 'assets/images/logo-sponsor2.png',
  //   linkUrl: 'https://www.instagram.com/sponsor2',
  // ),
];