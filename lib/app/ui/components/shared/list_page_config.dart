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
  });

  // --- PRESET UNTUK EVENT ---
  static const event = ListPageConfig(
    title: "Event",
    searchHint: "Cari event...",
    emptyTitle: "Event Tidak Ditemukan",
    emptySubtitle: "Coba ubah kata kunci atau filter Anda.",
    welcomeTitle: "Temukan Event Menarik!",
    welcomeSubtitle: "Cari event anime, manga, atau budaya Jejepangan di sekitarmu!",
    upcomingSectionTitle: "Event Mendatang",
    nearestSectionTitle: "Event Terdekat",
    mascotAsset: "assets/images/wargabut_mascot_chibi.png",
    drawerRoute: "/jeventku",
  );

  // --- PRESET UNTUK KONSER ---
  static const konser = ListPageConfig(
    title: "Festival",
    searchHint: "Cari festival...",
    emptyTitle: "Festival Tidak Ditemukan",
    emptySubtitle: "Coba ubah kata kunci atau filter Anda.",
    welcomeTitle: "Temukan Musisi Favoritmu!",
    welcomeSubtitle: "Cari festival musik di sekitarmu!",
    upcomingSectionTitle: "Festival Mendatang",
    nearestSectionTitle: "Festival Terdekat",
    mascotAsset: "assets/images/wargabut_mascot_chibi.png", // Bisa diganti jika ada mascot lain
    drawerRoute: "/dkonser",
  );
}