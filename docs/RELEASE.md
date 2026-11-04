# Checklist Rilis Publik Kizen

Dokumen ini membedakan **build stabil buat testing** dari artifact yang benar-
benar siap diunggah ke store. Jangan menyebut app siap Play Store/App Store
kalau bagian signing dan kebijakan di bawah belum selesai.

## Status teknis terakhir (6 Agustus 2026)

- `flutter analyze`: bersih.
- `flutter test -j 1`: 118 lulus, 3 test WebView safe-mode diskip sengaja.
- `dart fix --dry-run`: tidak ada saran perbaikan.
- Build web FAKE_AUTH lulus; smoke-test Reader mode Halaman pada tiga viewport
  HP memverifikasi zoom/reset dan layout tanpa error console.
- Android Lint profile: 0 error; 7 warning tersisa cuma pemberitahuan versi
  tool/dependency native yang sengaja belum dinaikkan tanpa uji kompatibilitas
  extension.
- Android APK profile 6 Agustus berhasil dibangun (120,9 MB), tetapi tetap
  memakai debug certificate dan belum dites di perangkat fisik karena tidak
  ada device yang terdeteksi ADB saat QC.
- Android App Bundle release: berhasil compile ke
  `build/app/outputs/bundle/release/app-release.aab`.
- iOS minimum deployment target sudah 15.0 sesuai Firebase terbaru.
- Build iOS profile tanpa codesign berhasil menghasilkan `Runner.app` 60,8 MB; app
  deployable tetap butuh Apple Development identity, Development Team, dan
  provisioning profile.

## Batas fitur yang jangan disamarkan

- Tombol download chapter saat ini baru mengubah state visual selama sesi;
  file halaman belum disimpan dan reader offline belum ada. Jangan menjanjikan
  fitur unduh/offline di rilis publik sebelum backend download selesai.
- Tiga strategi snapshot WebView otomatis masih dimatikan dalam safe mode ANR.
  Parser biasa, extension runtime, dan fallback WebView tetap aktif, tetapi
  tiga test tersebut bukan coverage aktif.
- Extension APK hanya bisa dijalankan di Android. iOS tetap memakai parser
  Dart/WebView dan tidak dapat memuat APK Tachiyomi.
- Parser adaptif, alias/mirror domain, dan repository `index.pb` mengurangi
  kerusakan saat situs pindah domain, tetapi tidak menjamin semua website akan
  selalu terbaca. API privat, login, Cloudflare, atau perubahan struktur besar
  tetap membutuhkan update extension/parser; WebView adalah fallback terakhir.

## Wajib sebelum distribusi publik

1. Buat dan backup **Android upload keystore** produksi. Isi
   `android/key.properties`, ubah `android/app/build.gradle.kts` agar build
   release memakai key itu, lalu cek signature artifact. Saat ini release
   masih memakai debug signing untuk kebutuhan testing lokal.
2. Aktifkan Play App Signing dan naikkan `version`/build number dari
   `pubspec.yaml` pada setiap rilis.
3. Untuk App Store, login Apple Developer di Xcode, pilih Development Team,
   pastikan Bundle ID terdaftar, lalu buat provisioning/distribution profile.
4. Tentukan jalur distribusi Android:
   - GitHub/direct APK: tetap wajib production signing agar update berikutnya
     bisa dipasang di atas versi lama.
   - Google Play: audit dan deklarasikan `QUERY_ALL_PACKAGES` serta
     `REQUEST_INSTALL_PACKAGES`. Dua permission ini dipakai buat menemukan dan
     memasang APK extension, tetapi termasuk permission terbatas di Play.
5. Siapkan privacy policy dan disclosure yang menjelaskan login Google,
   Firestore, daftar aplikasi terpasang yang dibaca lokal, WebView/cookie lokal,
   serta konten pihak ketiga. Data inventory aplikasi jangan dikirim ke server.
6. Jalankan closed/internal testing di artifact **yang sudah production-signed**,
   termasuk login Google dengan SHA fingerprint key produksi.

## Verifikasi kandidat rilis

```sh
flutter analyze
flutter test -j 1
flutter build appbundle --release
flutter build ios --release
```

Sesudah signing siap, tes install/update di minimal dua Android dan satu iPhone,
lalu cek login, sinkronisasi, pemasangan extension, WebView, reader panjang,
Updates, History, keluar akun, dan install-over-existing-version.
