# Rencana Implementasi: Integrasi Agenda Event Komunitas & Info Kehadiran Komunitas di JEventku

Fitur ini menghubungkan modul **WargaKomunitas** dengan modul **JEventku** secara dua arah:
1. **Di Halaman Komunitas**: Founder dan Admin Komunitas dapat memilih event dari JEventku yang akan dihadiri oleh komunitasnya (beserta catatan khusus seperti info booth, jam kumpul, atau dresscode cosplay). Semua pengunjung (meskipun bukan anggota) dapat melihat agenda event komunitas tersebut ("next ke event mana saja").
2. **Di Halaman Detail Event (`/jeventku/:eventId`)**: Menampilkan daftar komunitas yang telah mengonfirmasi akan hadir di event tersebut, lengkap dengan logo, nama, domisili, catatan kehadiran, dan navigasi langsung ke halaman profil komunitas.

---

## User Review Required

> [!IMPORTANT]
> - **Akses Penambahan Event**: Hanya **Founder** (`creator_uid`) dan **Admin Komunitas** (`admin_uids`) yang memiliki wewenang untuk menambah, mengedit, atau menghapus agenda event yang dihadiri oleh komunitas mereka.
> - **Visibilitas Publik**: Seluruh pengunjung (tamu/guest maupun anggota) dapat melihat agenda event yang akan dihadiri oleh komunitas di tab baru **"Agenda Event"** pada halaman detail komunitas.
> - **Shortcut Daftarkan Kehadiran dari Event**: Jika pengguna yang sedang melihat detail event adalah Founder atau Admin dari sebuah komunitas, mereka dapat langsung mendaftarkan komunitasnya ke event tersebut tanpa harus berpindah ke halaman komunitas terlebih dahulu.

---

## Proposed Changes

### 1. Data Model & Firestore Schema

#### [NEW] [community_event_model.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/models/community_event_model.dart)
Model data untuk menyimpan relasi kehadiran komunitas di event pada koleksi `community_events`:
- `id`: `${communityId}_${eventId}`
- `communityId`: Slug/ID komunitas
- `communityName`: Nama komunitas (denormalized untuk query cepat)
- `communityLogo`: URL logo komunitas
- `communityCity`: Kota/area komunitas
- `isCommunityVerified`: Status verifikasi komunitas
- `eventId`: ID dokumen event di `jfestchart`
- `eventName`: Nama event
- `eventDate`: Tanggal event
- `eventLocation`: Lokasi / venue event
- `eventPoster`: URL poster event
- `notes`: Catatan kehadiran dari admin komunitas (misal: *"Meetup cosplay bareng jam 14.00 di booth A2"*)
- `addedByUid`: UID admin/founder yang menambahkan
- `createdAt`: Timestamp penambahan

---

### 2. State Management (Provider)

#### [MODIFY] [community_provider.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/community_provider.dart)
Menambahkan method untuk mengelola relasi event komunitas:
- `fetchCommunityEvents(String communityId)`: Mengambil daftar agenda event yang akan dihadiri suatu komunitas (diurutkan berdasarkan tanggal).
- `fetchEventAttendingCommunities(String eventId)`: Mengambil daftar komunitas yang akan hadir pada event tertentu.
- `addEventToCommunity(...)`: Validasi wewenang (Founder/Admin komunitas), simpan ke koleksi `community_events`.
- `removeEventFromCommunity(...)`: Hapus event dari agenda komunitas.
- `getCommunitiesManagedByUser(String uid)`: Mengambil daftar komunitas di mana user adalah Founder atau Admin (untuk shortcut modal di detail event).

---

### 3. Komponen UI Pemilih Event (Event Selector Dialog)

#### [NEW] [add_community_event_dialog.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/community/add_community_event_dialog.dart)
Modal dialog/bottom sheet untuk Founder & Admin memilih event dari JEventku:
- Menampilkan pencarian event real-time dari daftar event yang ada di `EventProvider` / `jfestchart`.
- Menampilkan preview poster event, tanggal, dan lokasi.
- Input catatan opsional (misal: rencana kumpul atau titik kumpul).
- Tombol simpan dan feedback status.

---

### 4. Halaman Detail Komunitas

#### [MODIFY] [community_detail_page.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/community/community_detail_page.dart)
- Mengubah `TabController` dari 2 tab menjadi **3 tab**:
  1. `Tentang Komunitas`
  2. **`Agenda Event (X)`** *(Baru)*
  3. `Daftar Anggota (Y)`
- Konten Tab Agenda Event:
  - Tampil untuk semua pengunjung (anggota maupun publik).
  - Menampilkan kartu event JEventku (Poster, Nama, Tanggal, Lokasi, Catatan Komunitas).
  - Mengklik kartu event langsung navigasi ke `/jeventku/:eventId`.
  - Jika user adalah Founder atau Admin komunitas, tampil tombol **"+ Tambah Agenda Event"** dan opsi hapus/edit catatan.

---

### 5. Halaman Detail Event (JEventku)

#### [MODIFY] [event_detail.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/detail/event_detail.dart)
- Menambahkan komponen **"Komunitas yang Akan Hadir"** di antara `DetailInfoCard` dan `SharedTransitSection`.
- Jika ada komunitas yang hadir:
  - Tampilkan list/carousel horizontal kartu komunitas (Logo bulat, Nama komunitas, Badge terverifikasi, Domisili kota, Catatan kehadiran).
  - Mengklik kartu komunitas membuka halaman komunitas terkait (`/komunitas/:slug`).
- Jika belum ada komunitas yang hadir:
  - Tampilkan kartu informatif: *"Belum ada komunitas yang mendaftarkan kehadiran di event ini."*
- Jika pengguna login adalah Founder/Admin dari suatu komunitas:
  - Tampilkan tombol aksi cepat: **"Daftarkan Komunitas Anda"** agar admin tidak perlu repot mencari menu komunitas secara terpisah.

---

## Verification Plan

### Automated / Code Quality Verification
- Menjalankan `flutter analyze` untuk memastikan tidak ada error kompilasi, peringatan lint, atau tipe data yang tidak sesuai pada:
  - `lib/app/models/community_event_model.dart`
  - `lib/app/provider/community_provider.dart`
  - `lib/app/ui/components/community/add_community_event_dialog.dart`
  - `lib/app/ui/screens/community/community_detail_page.dart`
  - `lib/app/ui/screens/detail/event_detail.dart`

### Manual Flow Verification
1. **Sebagai Founder / Admin Komunitas**:
   - Buka halaman komunitas yang Anda kelola (misal: `/komunitas/wargabut-cosplay`).
   - Buka tab **"Agenda Event"**.
   - Klik tombol **"+ Tambah Agenda Event"**.
   - Pilih event dari daftar JEventku dan masukkan catatan kehadiran (misal: *"Kumpul member jam 13:00"*).
   - Pastikan event muncul di tab Agenda Event komunitas.
2. **Sebagai Pengunjung Biasa (Bukan Anggota)**:
   - Buka halaman komunitas tersebut tanpa login atau menggunakan akun biasa.
   - Buka tab **"Agenda Event"** dan pastikan seluruh agenda event terlihat dengan jelas tanpa batasan akses, namun tanpa tombol edit/hapus.
   - Klik salah satu kartu event dan pastikan diarahkan ke detail event `/jeventku/:eventId`.
3. **Di Halaman Detail Event (`/jeventku/:eventId`)**:
   - Buka event yang tadi didaftarkan oleh komunitas.
   - Pastikan komunitas tersebut muncul di bagian **"Komunitas yang Akan Hadir"** lengkap dengan logo dan catatannya.
   - Klik kartu komunitas tersebut dan pastikan diarahkan kembali ke `/komunitas/:slug`.
