# Rencana Implementasi: Info Komunitas & Event yang Akan Dihadiri pada Member Card

Fitur ini melengkapi **Wargabut Member ID Card** (baik pada modal dialog `MemberCardDialog` maupun halaman profil publik `MemberProfilePage`) dengan informasi:
1. **Komunitas yang Diikuti**: Menampilkan daftar komunitas yang telah diikuti oleh member (lengkap dengan logo, nama komunitas, status verifikasi, dan role jika Founder/Admin).
2. **Event yang Akan Dihadiri Selanjutnya**: Setiap member (terlepas dari apakah mereka tergabung dalam komunitas atau tidak) dapat memilih event-event dari katalog JEventku yang akan mereka hadiri selanjutnya.
3. **Pengelolaan Event Pribadi**:
   - Di halaman **Edit Biodata** (`/profil/edit`), member dapat mencari, menambah, memberi catatan, dan menghapus event yang akan dihadiri.
   - Di halaman **Detail Event** (`/jeventku/:eventId`), member yang sedang login dapat langsung menekan tombol **"Saya Akan Hadir"** untuk langsung menyimpannya ke kartu profil member mereka.

---

## User Review Required

> [!IMPORTANT]
> - **Independensi Event Pribadi vs Komunitas**: Sesuai instruksi, pemilihan event ini bersifat personal untuk setiap member. Member yang tidak bergabung dengan komunitas manapun tetap bebas memilih event mana saja yang akan mereka hadiri.
> - **Visibilitas Member Card**: Info komunitas yang diikuti dan event yang akan dihadiri akan langsung terlihat di kartu ID digital (`MemberCardDialog` saat nama member diklik di list, dan di halaman web publik `/@username`).
> - **Akses Navigasi**: Kartu komunitas di dalam member card dapat diklik untuk membuka `/komunitas/:slug`, dan kartu event dapat diklik untuk membuka detail event JEventku `/jeventku/:eventId`.

---

## Proposed Changes

### 1. Data Model & Firestore Schema

#### [MODIFY] [user_profile_model.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/models/user_profile_model.dart)
- Membuat kelas `UserAttendingEvent`:
  - `eventId`: ID event JEventku
  - `eventName`: Nama event
  - `eventDate`: Tanggal pelaksanaan event
  - `eventLocation`: Lokasi / venue event
  - `eventPoster`: URL gambar poster event
  - `notes`: Catatan personal kehadiran (misal: *"Cosplay Frieren hari Sabtu"*, *"Hunting merch"*)
- Menambahkan field `List<UserAttendingEvent> attendingEvents` ke dalam `UserProfileModel`.
- Memperbarui `fromMap()`, `toMap()`, dan `generateIntroText()` agar memuat daftar event dan komunitas yang diikuti.

---

### 2. State Management & Provider

#### [MODIFY] [profile_provider.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/profile_provider.dart)
- Memperbarui method `saveProfile()` agar menyertakan parameter `List<UserAttendingEvent> attendingEvents`.
- Menambahkan helper method:
  - `toggleEventAttendance(Map<String, dynamic> eventData, {String notes})`: Menambah atau membatalkan kehadiran pribadi pada suatu event secara instan dari halaman detail event.
  - `isAttendingEvent(String eventId)`: Mengecek apakah user yang sedang login sudah mendaftarkan event tersebut ke profilnya.

#### [MODIFY] [community_provider.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/community_provider.dart)
- Menambahkan method `fetchUserCommunities(String uid)`:
  - Mengambil daftar komunitas yang diikuti oleh member tertentu dengan status `active` dari koleksi `community_members`.
  - Mengembalikan list model komunitas untuk ditampilkan pada kartu profil member.

---

### 3. Komponen Kartu Member (Member Card)

#### [MODIFY] [member_card_dialog.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/community/member_card_dialog.dart)
- Mengubah `MemberCardDialog` menjadi `StatefulWidget` untuk memuat komunitas yang diikuti oleh user target.
- Menambahkan seksi **"Komunitas yang Diikuti"**:
  - Menampilkan chip/kartu komunitas (Avatar logo, nama komunitas, badge verified, role jika admin/founder).
  - Tapping kartu komunitas langsung mengarahkan ke `/komunitas/:slug`.
  - Jika belum bergabung komunitas: Menampilkan *"Belum bergabung komunitas"*.
- Menambahkan seksi **"Event Selanjutnya yang Akan Dihadiri"**:
  - Menampilkan daftar `profile.attendingEvents` (Poster thumbnail, nama event, tanggal & lokasi, serta badge catatan).
  - Tapping kartu event langsung mengarahkan ke detail event `/jeventku/:eventId`.
  - Jika belum ada event: Menampilkan *"Belum ada rencana event selanjutnya"*.

#### [MODIFY] [member_profile_page.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/profile/member_profile_page.dart)
- Menambahkan seksi yang sama dengan `member_card_dialog.dart` pada halaman profil publik (`/@username`):
  - Seksi **Komunitas yang Diikuti**
  - Seksi **Event yang Akan Dihadiri**
  - Kedua seksi interaktif dengan navigasi langsung ke halaman terkait.

---

### 4. Form Pemilihan Event Pribadi (Edit Biodata & Event Detail)

#### [MODIFY] [edit_profile_biodata_page.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/profile/edit_profile_biodata_page.dart)
- Menambahkan seksi baru di form: **"Event yang Akan Dihadiri Selanjutnya"**.
- Menampilkan daftar event yang telah dipilih member dengan tombol hapus.
- Tombol **"+ Tambah Event dari JEventku"**:
  - Membuka dialog pemilih event (searchable event picker dari katalog JEventku `EventProvider.allEvents`).
  - Menampilkan input catatan opsional (misal: cosplan target atau hari kedatangan).
  - Menambahkan event ke list `_attendingEvents`.
- Menyimpan perubahan ke Firestore saat form disubmit.

#### [MODIFY] [event_detail.dart](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/detail/event_detail.dart)
- Menambahkan tombol aksi personal kehadiran di samping info komunitas:
  - Tombol **"Saya Akan Hadir"** / **"✓ Anda Berencana Hadir"**.
  - Mengizinkan member mendaftarkan kehadiran pribadinya ke event tersebut dengan 1 kali klik langsung dari halaman event JEventku.

---

## Verification Plan

### Automated / Code Quality Verification
- Menjalankan `flutter analyze` pada semua file yang dimodifikasi.
- Menjalankan `flutter build web` untuk memastikan tidak ada masalah build.

### Manual Verification
1. **Di Edit Biodata (`/profil/edit`)**:
   - Buka halaman edit biodata.
   - Tambahkan 1 atau lebih event JEventku pada seksi "Event yang Akan Dihadiri", isi catatan (misal: "Cosplay Anya").
   - Simpan biodata.
2. **Di Member Card Dialog & Halaman Profil (`/@username`)**:
   - Buka kartu member ID (pop up dialog) atau halaman `/@username`.
   - Pastikan info komunitas yang diikuti tampil (nama komunitas, logo, dan badge).
   - Pastikan info event yang akan dihadiri tampil rapi beserta poster, tanggal, dan catatannya.
   - Klik kartu event -> diarahkan ke `/jeventku/:eventId`.
   - Klik kartu komunitas -> diarahkan ke `/komunitas/:slug`.
3. **Member Tanpa Komunitas**:
   - Akun yang belum bergabung komunitas tetap dapat memilih event dan tampil di kartu membernya tanpa error.
