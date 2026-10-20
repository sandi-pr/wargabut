# Walkthrough: Fitur WargaKomunitas, Direktori Member Global, & Sistem Privasi 3-Tingkat

Fitur **WargaKomunitas & Kartu Biodata Digital Member** telah selesai diperluas dengan penambahan **Direktori Member Wargabut Global** dan **Sistem Pengaturan Privasi 3-Tingkat (Global, Komunitas, Privat)**.

---

## 🌟 Pembaruan Terbaru yang Selesai Dikerjakan

### 1. 👥 Tab Direktori Seluruh Member Wargabut (`/komunitas`)
Halaman `/komunitas` kini memiliki dua tab utama melalui `SegmentedButton`:
- **Tab 1: Komunitas**: Menampilkan daftar komunitas pop culture & cosplay terverifikasi.
- **Tab 2: Member Wargabut**: Menampilkan daftar seluruh anggota wargabut yang mengatur profilnya ke visibilitas publik (*Global*).
  - Dilengkapi fitur **pencarian cerdas**: mencari berdasarkan nama panggilan, `@username`, kota domisili, tag persona, maupun rencana cosplan/anime.
  - Filter interaktif berdasarkan **Kota Domisili** dan **Tag Persona** (`#Cosplayer`, `#Fotografer`, dll.).
  - Card ringkas menampilkan avatar, nama, domisili, tags, cosplan, dan tombol *"Buka Kartu ID"* yang langsung memunculkan pop-up Digital Member ID Card interaktif.

---

### 2. 🛡️ Pengaturan Privasi 3-Tingkat (*Global, Komunitas, Privat*)
Pada halaman edit biodata ([`EditProfileBiodataPage`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/profile/edit_profile_biodata_page.dart) / `/@me`), pengguna kini memiliki kontrol privasi yang sangat jelas dan mudah:

#### A. Privasi Profil Biodata:
1. 🌐 **Global**: Profil biodata tampil di Direktori Member Wargabut global & di seluruh komunitas yang diikuti.
2. 👥 **Hanya Komunitas**: Profil hanya tampil di daftar anggota komunitas-komunitas yang diikutinya (tidak muncul di pencarian publik).
3. 🔒 **Privat**: Profil disembunyikan dari seluruh pencarian & hanya dapat diakses jika pengguna membagikan link langsungnya.

#### B. Privasi Kontak WhatsApp:
1. 👥 **Hanya Sesama Anggota Komunitas** (*Rekomendasi Default*): Tombol chat WhatsApp hanya aktif dan dapat diakses oleh sesama anggota komunitas yang terdaftar.
2. 🌐 **Global / Publik**: Tombol WhatsApp dapat dilihat dan dihubungi oleh semua pengunjung Wargabut.
3. 🔒 **Privat**: Nomor WhatsApp disembunyikan total (hanya menampilkan link Instagram).

---

### 3. 👑 Manajemen Admin Komunitas & Notifikasi Logout
- **Halaman Detail Komunitas (`/@:slug`):**
  - Tampilan hero banner & logo komunitas.
  - Role badge: 👑 **Founder**, 🛡️ **Admin**, Anggota.
  - Tombol aksi: Gabung / Status Membership, Instagram, WhatsApp Group, **Edit Komunitas**, dan **Kelola Anggota & Permintaan**.
  - **Manajemen Admin Komunitas:** Tombol "+ Tambah Admin", dialog pencarian username `@username` Wargabut atau pemilihan dari anggota aktif, serta menu titik tiga untuk mengangkat Admin, mencabut wewenang Admin, dan mengeluarkan anggota.
  - Tab Tentang Komunitas dan Tab Daftar Anggota terurut (Founder, Admin, Anggota).

- **Halaman Kelola Komunitas (`/komunitas/:slug/kelola`):**
  - Tab 1: **Permintaan Baru** (badge jumlah permintaan pending, tombol Setujui dan Tolak).
  - Tab 2: **Pengurus & Anggota** (pencarian nama/username/kota, tombol "+ Tambah Admin", badge role, dan opsi kelola role).

- **Penggantian Field WhatsApp dengan TikTok (Anti-Spam / Privasi):**
  - Menghapus seluruh input nomor WhatsApp dan opsi privasi nomor telepon dari profil member (`/@me`) untuk melindungi data pribadi dan menghindari spam.
  - Menggantinya dengan input **Username TikTok (Opsional)** pada profil member (`UserProfileModel`) dan akun TikTok resmi pada komunitas (`CommunityModel`).
  - Menampilkan tombol **TikTok** di kartu biodata digital (`MemberCardDialog`), halaman profil publik (`MemberProfilePage`), dan halaman detail komunitas (`CommunityDetailPage`).
  - Tombol **Salin Format Intro** telah dihapus dari kartu member dan halaman profil agar tampilan kartu tetap bersih dan ringkas.

- **Notifikasi Logout (Toast / SnackBar):**
  - SnackBar melayang (floating) dengan ikon centang muncul otomatis saat logout dari Drawer samping maupun tombol Logout di halaman Biodata Saya (`/@me`).
  - Dialog konfirmasi sebelum logout dari halaman biodata untuk mencegah logout tidak disengaja.

---

## 🔍 Hasil Verifikasi Kode
- Analisis sintaksis menggunakan `flutter analyze` berhasil dijalankan dan kode terverifikasi **100% bersih tanpa ada error**.
