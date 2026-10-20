# Rekomendasi Otomatisasi Input Event Wargabut

Berdasarkan form input pada `create_event.dart`, data yang perlu diisi meliputi: **Nama Event, Tanggal, Area, Lokasi, HTM (Gratis/Berbayar & Harga), Deskripsi, Medpart, Poster, dan Rundown**. Mengisi ini secara manual dari Instagram atau web lain tentu memakan waktu.

Berikut adalah beberapa rekomendasi skenario (dari yang paling mudah hingga yang paling canggih) untuk melakukan otomatisasi/semi-otomatisasi:

## Skenario 1: Ekstraksi dari Gambar Poster (OCR + AI Vision) - *Paling Direkomendasikan*
Skenario ini memanfaatkan AI (seperti **Gemini Pro Vision** atau OpenAI GPT-4o) untuk membaca teks langsung dari poster event yang diunggah.

- **Alur Kerja (Workflow):**
  1. Admin mengunggah poster event di halaman `CreateEventPage`.
  2. Aplikasi (atau backend) mengirimkan gambar tersebut ke API AI (misal: Gemini API) dengan prompt: *"Ekstrak informasi berikut dari gambar ini dalam format JSON: nama_event, tanggal, area, lokasi, harga_tiket, deskripsi"*.
  3. AI mengembalikan data dalam bentuk JSON.
  4. Aplikasi otomatis mengisi (pre-fill) `TextField` yang ada. Admin tinggal mengecek, melengkapi data yang kurang (seperti rundown), dan klik "Save".
- **Kelebihan:** Sangat mudah bagi admin (hanya perlu upload gambar). Tidak perlu pusing dengan blokir scraping dari Instagram.
- **Kekurangan:** Membutuhkan biaya API (meski relatif murah), akurasi bergantung pada seberapa jelas tulisan di poster.
- **Teknologi:** Flutter + Firebase Cloud Functions (Node.js) + Gemini API.

## Skenario 2: Paste Link URL (Scraping + AI Text Extraction)
Skenario ini memungkinkan admin menempelkan (paste) link dari `ruangcosplay.com` atau Instagram, lalu sistem akan mengambil datanya.

- **Alur Kerja (Workflow):**
  1. Admin mem-paste link event ke sebuah `TextField` khusus di bagian atas halaman, lalu klik "Auto-Fill".
  2. Aplikasi mengirim link tersebut ke Backend Service.
  3. Backend melakukan scraping HTML/teks dari halaman tersebut (menggunakan Puppeteer/Playwright atau HTTP request biasa).
  4. Teks hasil scraping dikirim ke AI (LLM) untuk diubah menjadi struktur JSON yang rapi.
  5. JSON dikembalikan ke aplikasi Flutter untuk mengisi form.
- **Kelebihan:** Sangat cepat jika sumbernya adalah teks/website artikel.
- **Kekurangan:** Sulit untuk Instagram karena kebijakan anti-scraping IG yang sangat ketat (sering minta login/captcha).
- **Teknologi:** Backend Python (FastAPI + BeautifulSoup/Playwright) atau Node.js (Express + Puppeteer) + OpenAI/Gemini API.

## Skenario 3: Chrome Extension "Send to Wargabut" (Admin Tools)
Jika admin sering mencari event lewat browser di PC/Laptop, membuat ekstensi browser adalah solusi yang sangat efisien.

- **Alur Kerja (Workflow):**
  1. Admin membuka web seperti `ruangcosplay.com/event` atau post Instagram di Google Chrome.
  2. Admin mengeklik icon Wargabut Extension di pojok kanan atas browser.
  3. Ekstensi otomatis menyalin teks di halaman tersebut (atau admin memblok teks deskripsi lalu klik kanan -> Send to Wargabut).
  4. Ekstensi mengirim data ke Backend Wargabut, yang menyimpannya di Firestore dengan status `Draft`.
  5. Di aplikasi Flutter, ada halaman "Draft Events" di mana admin tinggal melakukan finalisasi dan Publish.
- **Kelebihan:** Alur kerja sangat mulus bagi admin yang bekerja di PC.
- **Kekurangan:** Perlu mengembangkan project terpisah (Chrome Extension berbasis HTML/JS).
- **Teknologi:** HTML/JS/CSS untuk Chrome Extension, Firebase Admin SDK.

## Skenario 4: Full Auto-Scraper (Cron Job)
Sistem berjalan otomatis di belakang layar tanpa perlu dipicu oleh admin.

- **Alur Kerja (Workflow):**
  1. Sebuah server berjalan setiap hari (misal jam 12 malam) untuk men-scrape daftar event dari sumber tertentu (seperti `ruangcosplay.com` atau eventbrite).
  2. Data disaring, dirapikan, dan langsung dimasukkan ke database Firestore.
  3. Admin hanya perlu memonitor event yang masuk atau menerima notifikasi jika ada event baru.
- **Kelebihan:** 100% otomatis, menghemat waktu admin hingga nol.
- **Kekurangan:** Jika struktur web sumber berubah, scraper akan rusak dan harus diperbaiki. Risiko memasukkan data yang salah/sampah jika tidak difilter dengan baik.
- **Teknologi:** Python (Scrapy/Selenium) dijalankan di VPS atau Google Cloud Run dengan Cloud Scheduler.

---

> [!IMPORTANT]
> **Keputusan yang Dibutuhkan (User Review Required)**
> 
> Silakan pilih skenario mana yang paling sesuai dengan alur kerja (workflow) Anda saat ini.
> 
> - Jika mayoritas sumber Anda berupa **Gambar Poster dari IG**, saya sangat merekomendasikan **Skenario 1 (AI Vision)** karena menghindari masalah pemblokiran web scraping IG.
> - Jika Anda lebih sering meng-copy link dari web browser/artikel, **Skenario 2** atau **Skenario 3** lebih cocok.
> 
> Setelah Anda memilih, saya akan membuatkan rancangan teknis detail (arsitektur, kode backend, dan modifikasi kode Flutter yang dibutuhkan).
