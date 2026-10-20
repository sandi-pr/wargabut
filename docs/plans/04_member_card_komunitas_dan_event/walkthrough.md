# Walkthrough: Info Komunitas & Event yang Akan Dihadiri pada Member Card

Fitur integrasi informasi **Komunitas yang Diikuti** dan **Event yang Akan Dihadiri Selanjutnya** telah selesai diimplementasikan pada kartu member (ID Card), profil publik, halaman edit biodata, dan halaman detail event.

---

## Ringkasan Perubahan

### 1. Data Model & Firestore Schema
- **File**: [`lib/app/models/user_profile_model.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/models/user_profile_model.dart)
  - Membuat class `UserAttendingEvent` (`eventId`, `eventName`, `eventDate`, `eventLocation`, `eventPoster`, `notes`).
  - Menambahkan list `attendingEvents` ke `UserProfileModel`.
  - Memperbarui serialization `toMap()` dan `fromMap()`.
  - Memperbarui generator teks intro AI (`generateIntroText`) agar menyertakan konteks event yang akan dihadiri.

### 2. State Management & Provider
- **File**: [`lib/app/provider/profile_provider.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/profile_provider.dart)
  - Memperbarui `saveProfile()` agar menyimpan list `attendingEvents`.
  - Menambahkan method `isAttendingEvent(String eventId)` untuk mengecek status kehadiran user yang sedang login.
  - Menambahkan method `toggleEventAttendance(Map<String, dynamic> eventData, {String notes})` untuk toggle kehadiran langsung dengan 1 ketukan.
- **File**: [`lib/app/provider/community_provider.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/community_provider.dart)
  - Menambahkan method `fetchUserCommunities(String uid)` yang mengambil daftar komunitas aktif yang diikuti user dari koleksi `community_members`.

### 3. Komponen Member Card Dialog & Halaman Profil
- **File**: [`lib/app/ui/components/community/member_card_dialog.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/community/member_card_dialog.dart)
  - Diubah menjadi `StatefulWidget` agar memuat data komunitas yang diikuti member target secara asynchronous.
  - Ditambahkan seksi **"Komunitas yang Diikuti"**:
    - Logo komunitas, nama, badge terverifikasi, dan role founder/admin.
    - Dapat diklik untuk langsung menuju halaman komunitas (`/komunitas/:slug`).
  - Ditambahkan seksi **"Event Selanjutnya yang Akan Dihadiri"**:
    - Thumbnail poster event, nama event, tanggal & lokasi, serta badge catatan (misal: "Cosplay Frieren").
    - Dapat diklik untuk langsung menuju halaman detail event JEventku (`/jeventku/:eventId`).
- **File**: [`lib/app/ui/screens/profile/member_profile_page.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/profile/member_profile_page.dart)
  - Ditambahkan seksi Komunitas yang Diikuti dan Event Selanjutnya pada halaman profil digital card publik (`/@username`).

### 4. Manajemen Event Pribadi (Edit Profil & Detail Event)
- **File**: [`lib/app/ui/screens/profile/edit_profile_biodata_page.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/profile/edit_profile_biodata_page.dart)
  - Ditambahkan seksi form **"Event yang Akan Dihadiri Selanjutnya"**.
  - Tombol **"+ Tambah Event dari JEventku"** membuka dialog pemilih event real-time dari katalog JEventku dengan input catatan personal.
  - Setiap event dapat dihapus dari daftar sebelum disimpan.
  - Nilai tersimpan ke Firestore saat menekan tombol "Simpan Biodata".
- **File**: [`lib/app/ui/screens/detail/event_detail.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/detail/event_detail.dart)
  - Ditambahkan kartu interaktif kehadiran personal:
    - Status **"Saya Akan Hadir"** (tombol aksi hijau/aksen).
    - Status **"✓ Anda Berencana Hadir"** (tombol batal).
    - Otomatis tersinkronisasi dengan `ProfileProvider` dan langsung memperbarui kartu member user.

---

## Verifikasi & Pengujian

- **Independensi Member**: Member yang tidak bergabung dengan komunitas tetap dapat memilih dan menampilkan rencana event yang akan dihadiri.
- **Keterhubungan Data**:
  - Klik kartu komunitas pada member card -> mengarahkan ke `/komunitas/:slug`.
  - Klik kartu event pada member card -> mengarahkan ke `/jeventku/:eventId`.
- **Navigasi & Context**: Semua operasi async menggunakan caching context / navigator aman tanpa build context warning.
