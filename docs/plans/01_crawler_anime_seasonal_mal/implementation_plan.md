# Rencana Implementasi: Crawler Anime Seasonal (MyAnimeList) ke Ani News

Fitur ini menambahkan kemampuan crawling anime seasonal (seperti Fall 2026) dari MyAnimeList (`https://myanimelist.net/anime/season/2026/fall`) ke menu **Ani News** di Wargabut. Crawler mengekstrak seluruh data anime termasuk jumlah **members** (dengan ikon user, contoh: `👤 139K`), studio, genre, sinopsis, poster beresolusi tinggi, serta menyediakan sorting agar anime paling populer otomatis berada di paling atas.

---

## User Review Required

> [!IMPORTANT]
> **Metode Pengambilan Data:**
> Berdasarkan pengujian langsung, MyAnimeList menyediakan data lengkap (97 judul anime untuk Fall 2026) termasuk nilai eksak `js-members` (misal `138618`) dan teks format `139K` langsung di dalam HTML halaman seasonal. Kami akan menggunakan Cloud Function Proxy Wargabut yang sudah terbukti andal mengambil halaman MAL tanpa terkena blokir CORS di browser.

> [!TIP]
> **Penerjemahan Sinopsis (AI Gemini):**
> Halaman seasonal biasanya memuat 80–100 anime. Jika semua 100 anime diterjemahkan dengan Gemini secara beruntun dalam satu kali klik, proses import akan memakan waktu 2–3 menit dan berisiko terkena rate limit Gemini. Kami akan menyediakan:
> 1. Toggle opsi: *"Terjemahkan Sinopsis dengan Gemini"* saat import.
> 2. Tombol *"Terjemahkan"* manual di halaman Detail Berita/Anime jika pengguna ingin menerjemahkan sinopsis anime tertentu di kemudian hari.

---

## Open Questions

> [!NOTE]
> 1. **Default Pengurutan (Sorting) di Halaman Utama Ani News:**
>    - Apakah untuk tab **Jadwal Anime (Scheduled)** sebaiknya otomatis diurutkan berdasarkan **Members / Popularitas Terbanyak** (anime paling populer di atas) atau tetap ada pilihan tombol sortir (Populer vs Tanggal Terdekat)? *(Rekomendasi: Tambahkan opsi filter/sortir Populer vs Tanggal)*.

---

## Proposed Changes

### 1. Crawler Engine & UI ([crawl_scheduled_anime.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/create/crawl_scheduled_anime.dart))

#### [MODIFY] [crawl_scheduled_anime.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/create/crawl_scheduled_anime.dart)
- **Input URL & Season Selector:**
  - Tambahkan input URL fleksibel: pengguna bisa langsung paste link seperti `https://myanimelist.net/anime/season/2026/fall`.
  - Tambahkan selector cepat: Pilihan Musim (*Winter, Spring, Summer, Fall*) dan Tahun (*2024, 2025, 2026, 2027*).
- **Parser HTML MyAnimeList:**
  - Mengambil HTML melalui Cloud Function Proxy Wargabut.
  - Mem-parsing data per kartu anime:
    - `title`: Judul anime
    - `members`: Angka murni `int` (misal `138618`) dari `.js-members`
    - `members_formatted`: String format singkat (misal `"139K"`) dari `.scormem-item.member`
    - `score`: Skor MAL (misal `"8.45"` atau `"N/A"`)
    - `date`: Tanggal rilis yang diformat ke bahasa Indonesia (misal `"2 Okt 2026"`)
    - `genres` & `themes`: Kategori/genre anime
    - `studios`: Nama studio produksi (misal `OLM`, `Studio Pierrot`, `C2C`)
    - `source`: Sumber adaptasi (misal `Manga`, `Light novel`, `Original`)
    - `synopsis`: Ringkasan cerita anime
    - `img_url`: URL poster cover beresolusi tinggi
    - `season` & `premiered`: Tag musim (misal `"Fall 2026"`)
- **Fitur Sortir di Crawler:**
  - **Paling Populer (Members Terbanyak)** [Default]
  - **Tanggal Rilis**
  - **Judul (A-Z)**
- **UI & Interaksi:**
  - Tampilan grid card dengan badge jumlah members (`👤 139K`), studio, tanggal tayang, dan label *"SUDAH ADA DI DATABASE"*.
  - Tombol **Import Satuan** pada tiap anime dan tombol **Import Semua (Batch)** dengan progress bar.
  - Mengunggah poster ke Firebase Storage (`anichekku/<slug>`) dan menyimpan dokumen ke koleksi Firestore `anichekku`.

---

### 2. Provider State & Sorting ([aninews_provider.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/aninews_provider.dart))

#### [MODIFY] [aninews_provider.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/aninews_provider.dart)
- Tambahkan properti sortir jadwal: `sortScheduledBy` (`'popular'` vs `'date'`).
- Jika `sortScheduledBy == 'popular'`, urutkan `_allScheduled` berdasarkan `members` secara menurun (`(b['members'] ?? 0).compareTo(a['members'] ?? 0)`).
- Simpan dan load field `members`, `members_formatted`, dan `studios` pada serialisasi cache LocalStorage.

---

### 3. Tampilan Kartu List & Detail ([aninews_list_tile.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/tile/aninews_list_tile.dart) & [shared_detail_components.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/shared/detail/shared_detail_components.dart))

#### [MODIFY] [aninews_list_tile.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/tile/aninews_list_tile.dart)
- Tambahkan tampilan jumlah anggota anime dengan ikon user (`👤 139K`) di sebelah tanggal / badge musim jika field `members_formatted` atau `members` tersedia.
- Diterapkan pada layout Compact maupun Expanded.

#### [MODIFY] [shared_detail_components.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/shared/detail/shared_detail_components.dart)
- Di widget `NewsInfoCard`: tampilkan info Studio, Members (`139K Anggota`), dan Skor jika data tersebut ada pada dokumen.

---

## Verification Plan

### Automated / Syntax Tests
- Jalankan `flutter analyze lib/app/ui/screens/create/crawl_scheduled_anime.dart lib/app/provider/aninews_provider.dart lib/app/ui/components/tile/aninews_list_tile.dart lib/app/ui/components/shared/detail/shared_detail_components.dart` untuk memastikan tidak ada syntax / compilation error.

### Manual Verification
1. Buka menu **Ani News** > tekan tombol FAB Admin > pilih **Crawl Jadwal Anime**.
2. Masukkan link `https://myanimelist.net/anime/season/2026/fall` atau pilih musim *Fall 2026*.
3. Periksa daftar anime yang muncul:
   - Terurut dari yang paling populer (members terbanyak) di posisi paling atas (misal *Kusuriya no Hitorigoto 3rd Season* dengan *139K* members).
   - Terdapat ikon `👤` dan jumlah members pada setiap kartu.
4. Uji tombol import pada 1 anime untuk memvalidasi penyimpanan ke Firestore dan Storage.
5. Verifikasi tampilan anime yang sudah diimport di halaman list Ani News.
