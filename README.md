# Wargabut.id

> **Media Rekomendasi Hobi, Event Jejepangan, Festival Konser, dan Berita Anime.**

**Wargabut** berawal dari singkatan **"Warga Gabut"** — sebuah platform yang hadir sebagai solusi bagi siapa saja yang sedang "gabut" atau bingung mencari agenda kegiatan seru di akhir pekan. Wargabut menyajikan panduan lengkap mulai dari event budaya pop Jejepangan (cosplay, matsuri, anime fest), festival konser musik, update jadwal anime, hingga rekomendasi rute transportasi umum menuju lokasi acara.

---

## 🌟 Fitur Utama

### 1. 🎌 JEventku (Media Event Jejepangan)
Direktori terlengkap untuk mencari event cosplay, festival anime, dan kebudayaan Jepang:
- **Pencarian & Filter Fleksibel**: Filter event berdasarkan wilayah/kota (fokus area Jabodetabek dan kota lainnya) serta rentang bulan pelaksanaan.
- **Event Terdekat (GPS Proximity)**: Mendeteksi lokasi pengguna secara real-time untuk menampilkan event terdekat berdasarkan perhitungan radius kilometer.
- **Panduan Rute Transit (Google Routes API)**: Rekomendasi moda transportasi umum di Jabodetabek (KRL Commuter Line, MRT Jakarta, LRT, TransJakarta/Bus, hingga Angkot) lengkap dengan estimasi waktu, transit, dan stasiun pemberhentian.
- **Detail Event Lengkap**: Informasi harga tiket (Gratis / Berbayar), alamat lokasi & maps, deskripsi, jadwal rundown acara, daftar guest star, dan galeri poster interaktif.
- **Prioritas Media Partner**: Event dengan status Media Partner (`is_medpart`) dan poster resmi diprioritaskan di daftar teratas.

### 2. 📰 AniChekku (Berita Anime & Jadwal Rilis)
Pusat informasi bagi para penikmat anime:
- **Jadwal Tayang Anime (Scheduled Anime)**: Menampilkan hitung mundur dan jadwal serial/movie anime yang akan segera rilis.
- **Berita Anime Terkini**: Kurasi berita terbaru seputar industri anime dan pop culture Jepang.
- **Filter Genre & Tag**: Memudahkan penelusuran anime berdasarkan genre dan preferensi pengguna.

### 3. 🎸 dKonser (Media Festival Musik)
Direktori panggung hiburan dan festival musik:
- Menemukan jadwal festival musik, gigs lokal, konser musisi nasional maupun internasional.
- Filter lokasi dan rentang tanggal untuk memudahkan merencanakan jadwal nonton konser.

### 4. 🤖 WGuide (AI Assistant Guide - Powered by Google Gemini)
> [!NOTE]
> **Status:** Fitur ini masih dalam tahap pengembangan (*work in progress*) dan saat ini belum dilanjutkan kembali.

Asisten AI interaktif untuk memandu pengguna mencari hiburan:
- **Gemini 2.5 Flash**: Menjawab pertanyaan seputar jadwal event, rekomendasi acara, dan informasi hobi.
- **Function Calling / Tools Firestore**: AI terhubung langsung dengan koleksi database Firestore (`getEventList`, `getEventDetail`) sehingga data yang diberikan selalu akurat dan up-to-date.
- **Streaming Respons & Histori Lokal**: Dilengkapi animasi streaming teks yang responsif dan riwayat percakapan yang disimpan di database lokal menggunakan **Hive**.

### 5. ⚡ Otomasi Input & Admin Tools (Khusus Admin)
Sistem otomasi untuk mempercepat dan mempermudah pengisian konten:
- **Auto-Fill via Tautan / Post Instagram**: Cukup masukkan link postingan Instagram atau artikel web; sistem akan mengambil kontennya dan memanfaatkan Gemini AI untuk mengekstrak nama event, tanggal, area, lokasi, HTM, dan deskripsi secara instan ke form input.
- **Batch Event Crawler**: Crawler otomatis untuk mengumpulkan data dari situs direktori event (seperti `ruangcosplay.com`), dilengkapi deduplikasi otomatis ke Firestore serta auto-upload poster berkualitas tinggi.
- **Geocoding Massal**: Mengonversi nama tempat/lokasi event menjadi koordinat geografis (Latitude & Longitude).
- **Storage Cleanup Page**: Halaman audit Firebase Storage untuk menganalisis dan membersihkan file gambar yatim (*orphaned images*), poster duplikat, dan arsip event lama.

---

## 🛠️ Tech Stack & Arsitektur

- **Framework**: [Flutter](https://flutter.dev/) (Multi-platform: Web, Android, iOS)
- **Design System**: Material Design 3 dengan custom theme palette (Light & Dark mode)
- **State Management**: [Provider](https://pub.dev/packages/provider) (`ChangeNotifier`)
- **Routing**: [GoRouter](https://pub.dev/packages/go_router) dengan Route Guard berbasis role Admin
- **Backend & Cloud Services**:
  - **Firebase Firestore**: Database penyimpanan data event, konser, berita, dan user role.
  - **Firebase Authentication & UI Auth**: Autentikasi pengguna dan hak akses admin.
  - **Firebase Storage**: Penyimpanan aset poster dan gambar.
  - **Firebase Cloud Functions (Node.js)**: Serverless CORS proxy untuk scraping dan fetching data eksternal.
  - **Firebase App Check**: Proteksi keamanan endpoint API aplikasi.
- **Generative AI & API Eksternal**:
  - **Google Generative AI (Gemini SDK)**: Pemrosesan bahasa alami, ekstraksi form JSON, dan chatbot WGuide.
  - **Google Routes API**: Kalkulasi rute transportasi umum (transit).
- **Local Storage & Cache**:
  - **Hive**: Penyimpanan lokal riwayat chat WGuide.
  - **LocalStorage & SharedPreferences**: Caching data event harian untuk efisiensi pembacaan Firestore.

---

## 📁 Struktur Direktori `lib/`

```text
lib/
├── main.dart                      # Inisialisasi aplikasi, routing GoRouter, & MultiProvider
├── theme.dart                     # Konfigurasi Material Theme 3 (Light & Dark)
├── firebase_options.dart          # Konfigurasi platform Firebase
└── app/
    ├── config/                    # Pengaturan menu navigasi, API key, & sponsor
    ├── controller/                # Hive chat controller untuk persistensi pesan AI
    ├── models/                    # Data models (MenuItemModel, dsb.)
    ├── provider/                  # Business logic & state management (Event, Konser, Auth, dll.)
    ├── services/                  # Integrasi Storage, Transit Google Maps, & Gemini Stream
    ├── utils/                     # Utility lokasi dan perhitungan jarak
    └── ui/
        ├── components/            # Reusable UI widgets (Drawer, Scaffold, Cards, Filter Sheets)
        └── screens/
            ├── home/              # Halaman Welcome / Portal switcher
            ├── list/              # Halaman daftar (JEventku, AniChekku, dKonser)
            ├── detail/            # Halaman detail event, konser, dan artikel berita
            ├── chat/              # Chatbot WGuide dengan Gemini AI
            ├── create/            # Form input manual & Crawler otomatis berbasis AI
            └── admin/             # Tool pemeliharaan storage & audit
```

---

## 🚀 Memulai (Getting Started)

### Prasyarat
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi `>=3.3.4 <4.0.0`)
- Akun dan project [Firebase](https://firebase.google.com/) yang sudah dikonfigurasi
- Google Maps / Routes API Key dan Gemini API Key

### Langkah Instalasi

1. **Clone repository ini**:
   ```bash
   git clone https://github.com/sandi-pr/wargabut.git
   cd wargabut
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Konfigurasi Firebase**:
   Pastikan file `lib/firebase_options.dart` sudah terhubung dengan project Firebase Anda.

4. **Jalankan aplikasi**:
   - Untuk Web:
     ```bash
     flutter run -d chrome
     ```
   - Untuk Android / iOS:
     ```bash
     flutter run
     ```

