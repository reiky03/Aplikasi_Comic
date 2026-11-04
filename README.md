<p align="center">
  <img src="assets/branding/kizen_mark.png" width="110" alt="Kizen Logo" style="border-radius: 22px;" />
</p>

<h1 align="center">Kizen 📖</h1>

<p align="center">
  <b>Aplikasi baca manga, manhwa & manhua yang enteng, simpel, dan bebas iklan nyampah.</b><br>
  Dibikin pakai Flutter buat Android & iOS.
</p>

<p align="center">
  <a href="https://github.com/reiky03/Aplikasi_Comic/releases/download/v1.2.0/kizen-v1.2.0.apk">
    <img src="https://img.shields.io/badge/Download-APK%20Android%20(v1.2.0)-38bdf8?style=for-the-badge&logo=android&logoColor=white" alt="Download APK" />
  </a>
  <a href="https://github.com/reiky03/Aplikasi_Comic/releases/latest">
    <img src="https://img.shields.io/github/v/release/reiky03/Aplikasi_Comic?color=10b981&label=Rilis%20Terbaru&style=for-the-badge" alt="Rilis Terbaru" />
  </a>
  <img src="https://img.shields.io/badge/Flutter-v3.29+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
</p>

---

## ⚡ Kenapa Kizen?

Jujur aja, aplikasi ini awalnya dibuat karena capek tiap mau baca komik di browser selalu kena iklan pop-up yang gak abis-abis, situs yang suka ganti domain tiba-tiba, atau aplikasi baca yang terlalu berat dan penuh bloatware.

Kizen hadir buat bikin pengalaman maraton komik jadi tenang dan sat-set. Kamu tinggal cari komik, simpan ke library, dan baca dengan reader yang nyaman di mata.

---

## ✨ Fitur-Fitur Seru

- 🛡️ **Kizen VPN & Anti-Blokir (DoH)**: Buka web komik yang terblokir di Indonesia (Internet Positif / DNS hijacking) langsung di dalam aplikasi tanpa perlu install VPN luar atau izin root. Dilengkapi pilihan server Cloudflare 1.1.1.1, Google DNS, dan AdGuard Shield, pengukur ping live, dan tes status akses otomatis.
- 🚀 **In-App Direct Update & Install**: Cek pembaruan langsung di Pengaturan > Tentang, unduh APK rilis langsung di dalam aplikasi dengan progress bar real-time, dan pasang otomatis tanpa ribet bolak-balik browser.
- 🌐 **Universal Web Parser**: Tinggal tempel link homepage web komik favorit kamu di *"Sumber Saya"*, Kizen bakal coba deteksi dan parse daftarnya otomatis (support MangaThemesia, Madara CMS, dan berbagai web custom).
- 🧩 **Support Extension Repo (Tachiyomi / Mihon style)**: Punya link repository extension? Pasang di tab Repository dan langsung nikmati ribuan sumber komik dari berbagai bahasa.
- 🔄 **Sinkronisasi Otomatis & Anti-Nabrak**: Sering nemu web komik tiba-tiba ganti domain atau extension di-update dari app lain? Kizen otomatis menyelaraskan domain terbaru, menyimpan URL lama sebagai alias, dan meng-upgrade runtime extension tanpa bikin data library rusak atau tabrakan.
- 📜 **Reader Nyaman (Webtoon & Halaman)**:
  - Mode Webtoon vertikal yang smooth, gak patah-patah, dan seekbar presisi.
  - Mode Halaman (manga/buku) dengan rail zoom yang stabil tanpa bikin buram.
  - Bookmark per-halaman biar gak lupa panel favorit kamu.
- 📚 **Library Rapi & Floating Multi-Select**:
  - Filter langsung per koleksi bacaan tanpa tab menumpuk.
  - Mode pilih banyak dengan **tombol aksi melayang** (*floating action button*) di atas navbar untuk memindahkan komik antar koleksi, menandai tamat, atau menghapus massal dalam sekali tap.
  - Menu *"Kelola Berdasarkan Sumber"* buat ngecek ada berapa komik dari tiap situs, lengkap dengan opsi filter atau hapus per sumber.
- ☁️ **Login Google & Cloud Sync**: Data library dan riwayat baca tersimpan aman di cloud Firebase. Pindah HP? Tinggal login ulang dan semua komik kamu balik lagi.
- 🌓 **Tampilan Gelap Bersih**: Desain dark modern bernuansa obsidian yang adem di mata pas maraton malam-malam.

---

## 📲 Cara Download & Pasang (Android)

1. Klik tombol **[Download APK](https://github.com/reiky03/Aplikasi_Comic/releases/download/v1.2.0/kizen-v1.2.0.apk)** di atas, atau pilih versi lainnya di halaman **[Releases](https://github.com/reiky03/Aplikasi_Comic/releases)**.
2. Unduh file `kizen-v1.2.0.apk`.
3. Buka file APK yang sudah didownload di HP kamu.
4. Kalau ada peringatan *"Izinkan instalasi dari sumber tidak dikenal"*, centang izinkan/lanjutkan.
5. Buka **Kizen** dan langsung nikmati baca komik tanpa gangguan!

---

## 🛠️ Mau Coba Build Sendiri?

Buat kamu yang mau ngoprek kodenya atau compile sendiri:

```bash
# 1. Clone repository ini
git clone https://github.com/reiky03/Aplikasi_Comic.git
cd Aplikasi_Comic

# 2. Ambil semua dependency Flutter
flutter pub get

# 3. Jalankan di device/emulator kamu
flutter run
```

Buat jalanin unit test:
```bash
flutter test -j 1
```

---

## ☕ Catatan & Penafian

Kizen adalah proyek pribadi open source yang dibuat untuk tujuan belajar dan kenyamanan membaca pribadi. Kizen tidak meng-host atau menyimpan file gambar komik apa pun di server sendiri; semua konten diambil langsung dari website publik atau extension sumber yang kamu tambahkan. Dukung terus author dan penerbit resmi komiknya ya!

Kalau nemu bug atau punya saran fitur, jangan sungkan buat buka **[Issue](https://github.com/reiky03/Aplikasi_Comic/issues)**. Selamat membaca! 🚀
