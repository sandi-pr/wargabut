# Walkthrough: Fitur "Cari Teman Barengan" ke Event (Transit KRL & Di Venue)

Fitur **"Cari Teman Barengan" (Looking For Group / LFG)** telah selesai diimplementasikan sebagai solusi sosial terstruktur bagi para pengunjung event/festival wibu & pop-culture yang ingin berangkat ke event namun tidak memiliki teman (*solo event-goer*).

---

## Ringkasan Fitur yang Diimplementasikan

### 1. Data Model & Firestore Schema
- **[`lib/app/models/event_companion_model.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/models/event_companion_model.dart)**:
  - Menyimpan data rombongan di koleksi Firestore `event_companions`.
  - Field meliputi: tipe (`transit` atau `venue`), titik kumpul, waktu kumpul, tag aktivitas (*First-Timer Friendly*, *Hunting Merch*, *Cosplay Buddy*, dll.), kapasitas/kuota maksimal, daftar anggota yang bergabung, serta handle kontak **Telegram** dan **Instagram**.
- **[`lib/app/models/companion_message_model.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/models/companion_message_model.dart)**:
  - Menyimpan obrolan koordinasi/tanya jawab real-time di subkoleksi `event_companions/{companionId}/messages`.

### 2. State Management & Provider
- **[`lib/app/provider/companion_provider.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/companion_provider.dart)**:
  - `getCompanionsStream(eventId)`: Real-time stream daftar rombongan untuk suatu event.
  - `createCompanion(...)`: Menerbitkan ajakan baru (otomatis mendaftarkan pembuat sebagai anggota pertama).
  - `joinCompanion(...)`: Bergabung ke rombongan dengan pengecekan kuota otomatis.
  - `leaveCompanion(...)`: Membatalkan keikutsertaan.
  - `deleteCompanion(...)`: Menghapus ajakan (khusus pembuat / admin).
  - `getMessagesStream(...)` & `sendMessage(...)`: Obrolan koordinasi real-time antar anggota.
  - Terdaftar di `MultiProvider` pada [`lib/main.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/main.dart).

### 3. Komponen Antarmuka Pengguna (UI)

#### A. Seksi Mandiri di Halaman Event ([`EventCompanionSection`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/companion/event_companion_section.dart))
- Terletak mandiri di halaman detail event ([`EventDetailPage`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/detail/event_detail.dart)).
- Dilengkapi header berikon `Icons.groups_rounded`, badge jumlah rombongan, tombol `+ Buat Ajakan`, dan filter kategori:
  - **Semua**
  - **🚆 KRL / Transit**
  - **🎪 Di Venue**
- Setiap kartu rombongan menampilkan:
  - Profil pembuat (klik avatar/nama untuk membuka **Member ID Card**).
  - Badge tipe rombongan (Biru untuk KRL Transit, Oranye untuk Di Venue).
  - Badge status kuota (misal: *2/4 Orang*, atau *Penuh*).
  - Titik kumpul (berikon pin merah) dan waktu kumpul (berikon jam biru).
  - Tag aktivitas (*# First-Timer Friendly*, dll.) dan catatan tambahan.
  - Barisan avatar profil anggota yang telah bergabung.
  - **Tombol Aksi**:
    - `Gabung Rombongan` / `Keluar Rombongan`.
    - `Diskusi & Tanya Jawab`: Membuka modal chat koordinasi.
    - **Chip Kontak Telegram**: Membuka Telegram langsung ke username/link grup pembuat.
    - **Chip Kontak Instagram**: Membuka profil Instagram pembuat.

#### B. Dialog Buat Ajakan ([`CreateCompanionDialog`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/companion/create_companion_dialog.dart))
- Pilihan mode: **🚆 Naik KRL / Transit** atau **🎪 Di Lokasi Event**.
- Pilihan cepat stasiun KRL populer (Stasiun Bogor, Manggarai, Tanah Abang, Juanda, Bekasi, Cikarang, Serpong, Jurang Mangu, Cisauk, Sudirman, MRT, dll.) atau input stasiun bebas.
- Pilihan kuota anggota (2 orang / berdua, 3 orang, 4 orang, 5 orang, 6 orang, atau Bebas).
- Pilihan tag fokus aktivitas.
- Input kontak aman: Username Telegram dan Instagram.

#### C. Dialog Obrolan Koordinasi ([`CompanionChatDialog`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/companion/companion_chat_dialog.dart))
- Tampilan bubble chat real-time khusus rombongan terkait.
#### D. Proteksi Autentikasi (Login Wajib)
- **Pembuatan Ajakan**:
  - Tombol *Buat Ajakan* (baik di header maupun empty state) memeriksa status login terlebih dahulu. Jika belum login, sistem memunculkan dialog konfirmasi *Login Diperlukan* dengan tombol langsung ke halaman login (`/login`).
  - `CreateCompanionDialog.show` juga dilengkapi *guard* validasi login untuk mencegah pemanggilan ilegal saat belum masuk akun.
- **Bergabung ke Rombongan**:
  - Menekan *Gabung Rombongan* saat belum login otomatis menampilkan dialog *Login Diperlukan* (*"Untuk bergabung ke rombongan ini, kamu perlu masuk (login) ke akun Wargabut terlebih dahulu"*).
- **Ruang Obrolan & Koordinasi**:
  - Tamu / pengunjung yang belum login tetap dapat melihat riwayat pesan koordinasi untuk transparansi acara.
  - Namun pada bagian bawah input pesan, ditampilkan bar informatif *"Login untuk ikut berdiskusi dan berkoordinasi"* dengan tombol *"Login Sekarang"* (`/login`).
  - Pengiriman pesan dilindungi agar tidak dapat dilakukan tanpa akun aktif.

---

## Verifikasi
- Pengujian kode dilakukan dengan `flutter analyze` untuk memastikan seluruh berkas bebas error dan warning (`No issues found!`).
