# Walkthrough: Opsi Filter Lokasi Jabodetabek

Fitur filter cepat **Jabodetabek** telah ditambahkan ke dalam dialog Filter Lokasi untuk mempermudah pengguna memfilter seluruh event di wilayah Jakarta, Bogor, Depok, Tangerang (termasuk Tangerang Selatan), dan Bekasi secara otomatis.

---

## Ringkasan Perubahan

### 1. Location Utilities
- **Berkas**: [`lib/app/utils/location_utils.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/utils/location_utils.dart)
  - Menambahkan konstanta `jabodetabekAreas` (Jakarta, Jakarta Pusat, Jakarta Utara, Jakarta Barat, Jakarta Timur, Jakarta Selatan, Bogor, Depok, Tangerang, Tangerang Selatan, Bekasi).
  - Menambahkan fungsi `isJabodetabekArea(String? area)` yang mengecek apakah nama wilayah/lokasi mengandung kata kunci Jabodetabek (misal: `jakarta`, `kepulauan seribu`, `bogor`, `depok`, `tangerang`, `tangsel`, `bekasi`, `jabodetabek`).

### 2. Dialog Filter Lokasi (GenericFilterSheet)
- **Berkas**: [`lib/app/ui/components/shared/generic_filter_sheet.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/components/shared/generic_filter_sheet.dart)
  - Menambahkan opsi `CheckboxListTile` **Jabodetabek** dengan subtitle `"Jakarta, Bogor, Depok, Tangerang, Bekasi"`.
  - Mendukung state **Tristate**:
    - `true` (centang): Semua area Jabodetabek dalam daftar terpilih.
    - `null` (dash/strip): Sebagian area Jabodetabek terpilih.
    - `false` (kosong): Tidak ada area Jabodetabek yang terpilih.
  - Saat opsi Jabodetabek dicentang:
    - Otomatis mencentang seluruh kota Jabodetabek yang ada di daftar pilihan di bawahnya (Jakarta, Jakarta Pusat, Bogor, Depok, Tangerang, Tangerang Selatan, Bekasi, dll).
    - Otomatis menghapus filter "Terdekat" jika sebelumnya aktif.
  - Saat salah satu kota Jabodetabek di-uncheck dari daftar:
    - Opsi Jabodetabek otomatis berubah menjadi dash/indeterminate, kota-kota Jabodetabek lainnya tetap terpilih.
  - Saat opsi Jabodetabek di-uncheck:
    - Otomatis menghapus centang dari seluruh area Jabodetabek.

### 3. Logika Filter pada Provider (EventProvider & KonserProvider)
- **Berkas**:
  - [`lib/app/provider/event_provider.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/event_provider.dart)
  - [`lib/app/provider/konser_provider.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/provider/konser_provider.dart)
- Pada `_filterEvents()`:
  - Event otomatis cocok jika `_selectedAreas.contains('Jabodetabek')` dan `isJabodetabekArea(area)` bernilai benar.
  - Fallback: jika field `area` kosong pada event, pencarian mencakup teks `location` untuk menemukan keyword Jabodetabek.
  - Menambahkan pencocokan fleksibel untuk Tangerang (mencakup `Tangerang Selatan` / `Tangsel`).
- Pada `_areas.sort()`:
  - Menggunakan `jabodetabekAreas` terpusat dan memprioritaskan area yang termasuk dalam seleksi Jabodetabek.

### 4. Tampilan Dialog Desktop
- **Berkas**:
  - [`lib/app/ui/screens/list/event_list_page.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/list/event_list_page.dart)
  - [`lib/app/ui/screens/list/konser_list_page.dart`](file:///c:/Users/sandy/Documents/github/wargabut/lib/app/ui/screens/list/konser_list_page.dart)
- Menyesuaikan tinggi dialog desktop menjadi `480px` agar daftar kota tetap leluasa di-scroll setelah penambahan opsi Jabodetabek.

---

## Hasil Pengujian & Analisis
- `flutter analyze` berhasil dengan **0 issues found**.
- Opsi Jabodetabek berfungsi sinkron dua arah (mengubah opsi Jabodetabek mencentang/membatalkan kota individual, dan memilih kota individual secara manual memperbarui status checkbox Jabodetabek).
