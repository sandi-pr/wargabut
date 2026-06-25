class SponsorConfig {
  final String bannerUrl;
  final String logoUrl;
  final String? posterUrl; // [BARU] Tambahkan properti opsional untuk poster tegak
  final String linkUrl;

  const SponsorConfig({
    required this.bannerUrl,
    required this.logoUrl,
    this.posterUrl, // Opsional (tidak pakai required)
    required this.linkUrl,
  });
}

// DAFTAR SPONSOR ANDA
const List<SponsorConfig> activeSponsors = [
  // SponsorConfig(
  //   bannerUrl: 'assets/images/banner-squid_rentcos.jpg',
  //   logoUrl: 'assets/images/logo-squid_rentcos.png', // Ganti dengan nama file logo Anda
  //   posterUrl: 'assets/images/kawan_cosplay-collab.jpg',
  //   linkUrl: 'https://www.instagram.com/p/DXtp9-qFGyZ',
  // ),
  // Coba hilangkan komen di bawah ini untuk melihat efek 2 sponsor sejajar:
  // SponsorConfig(
  //   bannerUrl: 'assets/images/banner-sponsor2.jpg',
  //   logoUrl: 'assets/images/logo-sponsor2.png',
  //   linkUrl: 'https://www.instagram.com/sponsor2',
  // ),
];