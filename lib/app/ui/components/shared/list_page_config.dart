import 'package:flutter/material.dart';

/// Kelas ini menyimpan semua konfigurasi teks dan aset
/// agar widget UI bisa dipakai ulang untuk Event maupun Konser.
class ListPageConfig {
  final String title;
  final String searchHint;
  final String emptyTitle;
  final String emptySubtitle;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final String upcomingSectionTitle;
  final String nearestSectionTitle;
  final String mascotAsset;
  final String drawerRoute;
  final String bannerMenuPage;
  final String bannerMenuPageDark;

  // Constructor Constant
  const ListPageConfig({
    required this.title,
    required this.searchHint,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.welcomeTitle,
    required this.welcomeSubtitle,
    required this.upcomingSectionTitle,
    required this.nearestSectionTitle,
    required this.mascotAsset,
    required this.drawerRoute,
    required this.bannerMenuPage,
    required this.bannerMenuPageDark,
  });

  // --- PRESET UNTUK EVENT ---
  static const event = ListPageConfig(
    title: "Event",
    searchHint: "Cari event...",
    emptyTitle: "Event Tidak Ditemukan",
    emptySubtitle: "Coba ubah kata kunci atau filter Anda.",
    welcomeTitle: "Temukan Event Menarik!",
    welcomeSubtitle: "Cari event cosplay atau budaya Jejepangan di sekitarmu!",
    upcomingSectionTitle: "Event Mendatang",
    nearestSectionTitle: "Event Terdekat",
    mascotAsset: "assets/images/wargabut_mascot_chibi.png",
    drawerRoute: "/jeventku",
    bannerMenuPage: "assets/images/JEventku_banner_home.png",
    bannerMenuPageDark: "assets/images/JEventku_banner_home_dark.png",
  );

  // --- PRESET UNTUK KONSER ---
  static const konser = ListPageConfig(
    title: "Festival",
    searchHint: "Cari festival...",
    emptyTitle: "Festival Tidak Ditemukan",
    emptySubtitle: "Coba ubah kata kunci atau filter Anda.",
    welcomeTitle: "Temukan Musisi Favoritmu!",
    welcomeSubtitle: "Cari festival konser musik artis favorit di sekitarmu!",
    upcomingSectionTitle: "Festival Mendatang",
    nearestSectionTitle: "Festival Terdekat",
    mascotAsset: "assets/images/wargabut_mascot_chibi.png", // Bisa diganti jika ada mascot lain
    drawerRoute: "/dkonser",
    bannerMenuPage: "assets/images/dKonser_banner_home.png",
    bannerMenuPageDark: "assets/images/dKonser_banner_home_dark.png",
  );

  // --- PRESET UNTUK ANINEWS (AniChekku) ---
  static const aniNews = ListPageConfig(
    title: "AniChekku",
    searchHint: "Cari berita atau anime...",
    emptyTitle: "Berita Tidak Ditemukan",
    emptySubtitle: "Coba ubah kata kunci atau filter Anda.",
    welcomeTitle: "Temukan Berita Anime Terbaru!",
    welcomeSubtitle: "Update anime, movie, dan serial yang akan tayang — semuanya di AniChekku.",
    upcomingSectionTitle: "Anime yang akan tayang", // Untuk section Scheduled
    nearestSectionTitle: "Berita terbaru",          // Untuk section Latest News
    mascotAsset: "assets/images/wargabut_mascot_chibi.png",
    drawerRoute: "/anichekku",
    // Asumsi nama banner Anda:
    bannerMenuPage: "assets/images/anichekku_banner_home.png",
    bannerMenuPageDark: "assets/images/anichekku_banner_home_dark.png",
  );
}