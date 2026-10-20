# Walkthrough: Integrasi Agenda Event Komunitas dengan JEventku

Fitur integrasi dua arah antara **WargaKomunitas** (`/komunitas/:slug`) dan **JEventku** (`/jeventku/:eventId`) telah selesai diimplementasikan dengan sukses. Fitur ini memungkinkan Founder dan Admin komunitas merencanakan dan mengumumkan event jejepangan mana yang akan dihadiri oleh komunitas mereka, serta memungkinkan pengunjung umum melihat agenda komunitas maupun daftar komunitas yang hadir di setiap event.

---

## Ringkasan Perubahan

### 1. Model Data Agenda Event ([community_event_model.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/models/community_event_model.dart))
- Dibuat model `CommunityEventAttendanceModel` dengan koleksi Firestore `community_events`.
- ID Dokumen: `${communityId}_${eventId}` untuk mencegah duplikasi kehadiran komunitas pada event yang sama.
- Data terdenormalisasi untuk query cepat dua arah:
  - **Data Komunitas**: `community_id`, `community_name`, `community_logo`, `community_city`, `is_community_verified`
  - **Data Event**: `event_id`, `event_name`, `event_date`, `event_location`, `event_area`, `event_poster`
  - **Catatan & Audit**: `notes` (misal nomor booth, jam meetup, squad cosplay), `added_by_uid`, `created_at`

---

### 2. Pengelolaan State & Izin di Provider ([community_provider.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/community_provider.dart))
- Menambahkan metode-metode baru:
  - `fetchCommunityEvents(String communityId)`: Mengambil daftar event yang akan dihadiri oleh suatu komunitas (diurutkan berdasarkan `created_at` descending).
  - `fetchEventAttendingCommunities(String eventId)`: Mengambil daftar komunitas yang akan hadir di suatu event.
  - `addEventToCommunity({community, currentUid, eventData, notes})`: Memvalidasi bahwa hanya Founder (`creatorUid == currentUid`) atau Admin (`adminUids.contains(currentUid)`) yang dapat menambahkan event.
  - `removeEventFromCommunity({communityId, eventId, currentUid})`: Menghapus relasi agenda event dari Firestore dengan verifikasi hak akses.
  - `getCommunitiesManagedByUser(String uid)`: Mengambil daftar semua komunitas di mana pengguna berstatus sebagai Founder atau Admin.

---

### 3. Dialog Tambah Agenda Universal ([add_community_event_dialog.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/community/add_community_event_dialog.dart))
- Dapat dipanggil dari dua titik masuk (entry point):
  1. **Dari Halaman Detail Komunitas**: Komunitas sudah terpilih otomatis, pengguna mencari dan memilih event dari katalog JEventku.
  2. **Dari Halaman Detail Event**: Event sudah terpilih otomatis, pengguna memilih komunitas yang mereka kelola dari dropdown komunitas.
- Fitur pencarian instan nama event, lokasi, dan wilayah.
- Input catatan opsional (misal: "Meetup jam 14:00 di stage utama", "Booth C-04", dsb).

---

### 4. Tab Agenda di Detail Komunitas ([community_detail_page.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/community/community_detail_page.dart))
- TabController diperluas menjadi 3 tab:
  - `Tentang`
  - `Anggota (${memberCount})`
  - `Agenda Event (${eventsCount})`
- **Akses Publik**: Pengunjung manapun (meskipun bukan anggota komunitas) dapat melihat daftar event yang akan dihadiri oleh komunitas tersebut.
- **Hak Khusus Admin/Founder**:
  - Tombol aksi `+ Tambah Agenda Event` muncul di header tab jika pengguna adalah Founder atau Admin komunitas.
  - Tombol hapus event dari agenda pada setiap kartu event.
- **Navigasi Interaktif**:
  - Mengetuk kartu event langsung menavigasi ke halaman detail event JEventku (`/jeventku/${item.eventId}`).

---

### 5. Seksi Komunitas Hadir di Detail Event ([event_detail.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/detail/event_detail.dart))
- Ditambahkan seksi **"Komunitas Hadir"** di antara `DetailInfoCard` dan `SharedTransitSection`.
- Menampilkan badge jumlah total komunitas yang berencana hadir.
- Kartu kehadiran komunitas menyajikan:
  - Avatar logo komunitas (dengan inisial fallback jika belum ada logo).
  - Nama komunitas dan badge verifikasi biru jika terverifikasi.
  - Asal kota / wilayah komunitas.
  - Catatan partisipasi / meetup jika diisi oleh pengurus.
  - Tombol pembatalan kehadiran cepat jika user yang sedang login adalah pengurus komunitas terkait.
- Jika pengguna adalah Founder/Admin salah satu komunitas, muncul tombol cepat `Daftarkan` untuk mendaftarkan komunitasnya hadir ke event ini.
- Mengetuk kartu komunitas langsung menavigasi ke halaman profil komunitas (`/komunitas/${item.communityId}`).

---

## Hasil Verifikasi

1. **Analisis Statis (`flutter analyze`)**:
   - Menjalankan analisis pada seluruh file:
     - `lib/app/models/community_event_model.dart`
     - `lib/app/provider/community_provider.dart`
     - `lib/app/ui/components/community/add_community_event_dialog.dart`
     - `lib/app/ui/screens/community/community_detail_page.dart`
     - `lib/app/ui/screens/detail/event_detail.dart`
   - **Hasil: 0 errors, 0 warnings, 0 info notices (No issues found!)**.

2. **Arsitektur & Keamanan Data**:
   - Aturan hak akses diproteksi pada tingkat provider & UI: hanya Founder dan Admin komunitas yang diizinkan memanipulasi agenda komunitas.
   - Idempotent document ID (`${communityId}_${eventId}`) mencegah entri duplikat.
