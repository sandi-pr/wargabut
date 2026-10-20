# 📚 Dokumentasi Arsitektur & Riwayat Pengembangan Wargabut

Direktori ini berisi seluruh arsip **Implementation Plan** (rencana teknis) dan **Walkthrough** (hasil implementasi & pengujian) yang dibuat selama sesi pair-programming bersama Antigravity AI assistant.

Dokumen-dokumen ini disimpan permanen di dalam repositori agar riwayat desain arsitektur dan keputusan teknis tetap dapat diakses kapan saja tanpa bergantung pada cache riwayat percakapan IDE.

---

## 🗂️ Daftar Rencana & Walkthrough

| No | Modul / Fitur | Tanggal | Dokumen Rencana | Dokumen Hasil & Pengujian | Sesi AI (ID) |
| :---: | :--- | :---: | :--- | :--- | :--- |
| **01** | **Crawler Anime Seasonal (MAL) ke Ani News**<br>• Scraping jadwal musiman MyAnimeList (Fall 2026)<br>• Sortir popularitas berdasarkan member (`👤 139K`)<br>• Crawl poster HD dari galeri `/pics`<br>• Terjemahan sinopsis multi-model AI Gemini | Sep 2026 | [Implementation Plan](file:///docs/plans/01_crawler_anime_seasonal_mal/implementation_plan.md) | [Walkthrough](file:///docs/plans/01_crawler_anime_seasonal_mal/walkthrough.md) | `42f4d317` |
| **02** | **Direktori WargaKomunitas & Sistem Privasi**<br>• Direktori komunitas & biodata member<br>• Sistem privasi profil 3-tingkat (Publik / Anggota / Privat)<br>• Integrasi Firestore & konfigurasi Firebase Hosting | Sep 2026 | [Implementation Plan](file:///docs/plans/02_wargakomunitas_direktori_dan_privasi/implementation_plan.md) | [Walkthrough](file:///docs/plans/02_wargakomunitas_direktori_dan_privasi/walkthrough.md) | `b0fa4bf7` / `837331df` |
| **00** | **Otomatisasi Input Event Wargabut**<br>• Rekomendasi otomatisasi OCR/scraping event<br>• Proxy CORS cloud functions & parser poster IG | Jul 2026 | [Implementation Plan](file:///docs/plans/00_otomatisasi_event/implementation_plan.md) | *—* | *Inisial* |

---

## 📌 Ringkasan Isi per Modul

### 1. [Crawler Anime Seasonal MAL (Ani News)](file:///docs/plans/01_crawler_anime_seasonal_mal/walkthrough.md)
- **Path File Terkait**: `lib/app/ui/screens/create/crawl_scheduled_anime.dart`, `lib/app/provider/aninews_provider.dart`, `lib/app/ui/screens/detail/ani_news_detail.dart`
- **Fitur Utama**:
  - Scraping HTML jadwal anime musiman via Cloud Function Proxy.
  - Sorting otomatis anime paling populer ke posisi teratas berdasarkan jumlah anggota (`members`).
  - Upgrade gambar poster ke versi HD (`...l.jpg`) dan crawl galeri resmi `/pics` untuk multi-poster carousel.
  - Multi-model fallback terjemahan sinopsis AI (`gemini-flash-lite-latest`, `gemini-flash-latest`, `gemini-2.0-flash-lite`, `gemini-2.5-flash`).
  - Tombol **Update** pada kartu anime yang sudah ada di database untuk memperbarui poster HD & terjemahan secara instan.

### 2. [Direktori WargaKomunitas & Sistem Privasi](file:///docs/plans/02_wargakomunitas_direktori_dan_privasi/walkthrough.md)
- **Path File Terkait**: `lib/app/ui/screens/community/`, `lib/app/provider/community_provider.dart`, `lib/app/models/community_model.dart`
- **Fitur Utama**:
  - Direktori komunitas dan anggota komunitas Wargabut.
  - Pengaturan privasi nomor kontak/identitas member dengan 3 level visibilitas.
  - Pengaturan visibilitas card di halaman `welcome.dart` serta panduan deploy hosting.
