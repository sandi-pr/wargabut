# Walkthrough: Crawler Anime Seasonal MyAnimeList (MAL) ke Ani News

Fitur crawler anime seasonal dari MyAnimeList (`https://myanimelist.net/anime/season/2026/fall`) ke menu **Ani News** telah selesai diimplementasikan. Crawler ini mengambil data anime musiman secara akurat, mengekstrak metrik popularitas `members` (angka asli dan format singkat seperti `👤 139K`), serta mengurutkan anime terpopuler di urutan paling atas.

---

## Ringkasan Perubahan

### 1. Mesin Crawler & UI Baru ([crawl_scheduled_anime.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/create/crawl_scheduled_anime.dart))
- **Input URL Fleksibel & Quick Selector:**
  - Pengguna dapat langsung menempelkan URL musim apa saja dari MAL (contoh: `https://myanimelist.net/anime/season/2026/fall`).
  - Disediakan tombol chip cepat untuk memilih **Musim** (*Winter, Spring, Summer, Fall*) dan **Tahun** (*2024, 2025, 2026, 2027*) yang otomatis menyinkronkan URL dan menjalankan crawling.
- **Parsing Data Lengkap dari DOM MyAnimeList:**
  - Menggunakan Cloud Function Proxy Wargabut (`https://us-central1-wargabut-11.cloudfunctions.net/proxy?url=...`) untuk menghindari pemblokiran CORS browser.
  - Mengekstrak data per anime:
    - **Judul**: `title`
    - **Members**: Jumlah anggota integer (`members`, contoh `138618`) dan teks terformat (`members_formatted`, contoh `139K`)
    - **Skor**: Skor MAL (`score`, contoh `8.45` atau `N/A`)
    - **Tanggal Rilis**: Diformat otomatis ke bahasa Indonesia (`date`, contoh `Oct 2, 2026` -> `2 Okt 2026`)
    - **Poster Cover**: Resolusi tinggi dari CDN MAL
- **Resolusi Tinggi Poster & Halaman /pics Resmi MAL:**
  - Thumbnail MyAnimeList pada seasonal list kini otomatis di-upgrade ke format resolusi tinggi asli MyAnimeList (`...l.jpg` berukuran ~1000px+).
  - Saat mengimport anime, crawler juga menelusuri halaman `/pics` resmi (contoh: `https://myanimelist.net/anime/61987/Kusuriya_no_Hitorigoto_3rd_Season/pics`) untuk mengambil hingga 4 key visual / poster resmi beresolusi tinggi.
  - Gambar diunduh via Cloud Function proxy agar tidak terkendala CORS di Flutter Web, lalu disimpan di Firebase Storage dan ditambahkan ke daftar `posters` dokumen Firestore sehingga carousel detail anime dapat menampilkan seluruh poster HD tersebut.
- **Terjemahan Sinopsis AI Andal (Fallback Multi-Model):**
  - Mengatasi error kuota 429 pada model `gemini-2.5-flash` dengan menyediakan perulangan fallback ke model-model stabil: `gemini-flash-lite-latest`, `gemini-flash-latest`, `gemini-2.0-flash-lite`, dan `gemini-2.5-flash`.
  - Tombol manual terjemahkan di [ani_news_detail.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/detail/ani_news_detail.dart) juga diperbarui menggunakan sistem fallback yang sama.
- **Fitur Update / Re-Import pada Card:**
  - Card anime yang sudah ada di database (`isExists`) kini menampilkan tombol **Update** (bukan hanya label pasif `Ada`), sehingga anime yang sudah diimport sebelumnya dapat diperbarui dengan poster HD dan terjemahan Bahasa Indonesia hanya dengan satu klik.
- **Tampilan Card & Layout Responsif:**
  - **Eliminasi Blank Space**:
    - Menghapus pembagian `flex: 5` dan `mainAxisAlignment: MainAxisAlignment.spaceBetween` yang sebelumnya membuat area teks kosong melompong.
    - Poster anime kini memakai `Expanded` dengan `alignment: Alignment.topCenter`, sehingga artwork poster tampil penuh dan wajah karakter tidak terpotong.
    - Bagian info bawah memakai `mainAxisSize: MainAxisSize.min` dengan padding pas (8px).
    - Genre chips dan tombol `+ Import` kini berada sejajar di satu baris bawah, menghilangkan ruang kosong sepenuhnya.
    - Rasio card diatur ke `0.68` agar proporsional dan tidak meregang di layar mobile maupun desktop.
  - **Responsif Mobile**:
    - Bar kontrol opsi sortir dan toggle filter dibungkus dalam `Column` dan `Wrap(spacing: 12, runSpacing: 8)` dengan `MaterialTapTargetSize.shrinkWrap` untuk mencegah overflow di layar sempit.
- **Opsi Sortir di Halaman Crawler:**
  - **👤 Populer (Members):** Default — anime paling populer (seperti *Kusuriya no Hitorigoto 3rd Season* dengan *139K members*) otomatis berada di paling atas.
  - **📅 Tanggal Rilis:** Berdasarkan tanggal tayang terdekat.
  - **🔤 Judul (A-Z):** Urutan alfabetis.
- **Interaksi Import Fleksibel:**
  - Tombol **Import Satuan** pada setiap kartu anime.
  - Tombol **Import Semua ($unimportedCount)** secara batch dengan progress bar.
  - Deteksi otomatis apakah anime sudah ada di database Firestore (`SUDAH DIIMPORT`).

---

### 2. Provider State & Sorting Popularitas ([aninews_provider.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/aninews_provider.dart))
- Menambahkan field `sortScheduledBy` dengan nilai default `'popular'`.
- Jadwal anime (`_allScheduled`) otomatis diurutkan berdasarkan jumlah `members` tertinggi secara menurun:
  ```dart
  (b['members'] ?? 0).compareTo(a['members'] ?? 0)
  ```
- Mendukung peralihan pengurutan antara `Paling Populer` dan `Tanggal Terdekat`.

---

### 3. Tampilan Kartu & Halaman List ([aninews_list_tile.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/tile/aninews_list_tile.dart) & [aninews_list_page.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/list/aninews_list_page.dart))
- **Ikon User & Jumlah Members pada Kartu:**
  - Menampilkan ikon `👤` dan teks format members (contoh: `👤 139K`) di sebelah tanggal rilis pada mode tampilan Compact maupun Expanded.
- **Chip Urutan di Halaman Utama:**
  - Saat melihat jadwal anime, terdapat action chip `Urutan: [👤 Paling Populer]` yang dapat diklik untuk berganti antara popularitas dan tanggal.

---

### 4. Detail Berita / Anime ([shared_detail_components.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/shared/detail/shared_detail_components.dart))
- Pada `NewsInfoCard`, ditampilkan metadata tambahan:
  - **Anggota:** `👤 139K Anggota`
  - **Studio:** `🏢 OLM`
  - **Skor:** `⭐ 8.45`

---

## Verifikasi
- Pengujian parser dengan data live `https://myanimelist.net/anime/season/2026/fall`:
  - Berhasil mengekstrak 97 anime musiman.
  - 5 teratas berdasarkan members:
    1. *Kusuriya no Hitorigoto 3rd Season* (139K members)
    2. *Cyberpunk: Edgerunners 2* (112K members)
    3. *Black Clover 2nd Season* (103K members)
    4. *Tensei shitara Ken deshita II* (92K members)
    5. *Ao no Hako Season 2* (69K members)
- Menjalankan `flutter analyze` pada seluruh berkas yang dimodifikasi: **0 compilation error**.
