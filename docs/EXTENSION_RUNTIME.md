# Extension Runtime

Kizen saat ini bisa membaca index repository Tachiyomi/Mihon-style sebagai
metadata sumber. Parser komik masih memakai parser Dart native atau fallback
`universal-html`.

Dokumen ini mencatat jalur menuju kompatibilitas extension yang lebih mirip
Tachiyomi/Tachimanga.

## Status Sekarang

- Flutter punya wrapper `ExtensionRuntimeBridge`.
- Android punya `MethodChannel` `kizen/extension_runtime`.
- Method tersedia:
  - `runtimeInfo`
  - `listInstalledExtensions`
  - `inspectExtension`
  - `fetchPopularFromExtension`
  - `fetchLatestFromExtension`
  - `fetchSearchFromExtension`
  - `fetchMangaDetailsFromExtension`
  - `fetchChapterListFromExtension`
  - `fetchPageListFromExtension`
- Native runtime sudah bisa menjalankan parser popular/latest/search/details/
  chapter/page dari APK extension yang kompatibel dengan stub saat ini.
- `ExtensionRuntimeSource` membungkus bridge native sebagai `MangaSource`, jadi
  source dari Repository yang punya `pkg` Tachiyomi bisa dipakai di UI browse,
  detail, chapter list, dan reader.
- Android manifest memakai `QUERY_ALL_PACKAGES` agar runtime bisa melihat APK
  extension Tachiyomi/Mihon yang sudah terpasang di device. Kalau nanti Kizen
  masuk Play Store, permission ini perlu direview lagi karena policy Google
  cukup ketat.
- Android sekarang punya compatibility stub minimal untuk API Tachiyomi:
  `HttpSource`, `Source`, `SourceFactory`, `SManga`, `SChapter`, `Page`,
  `MangasPage`, `FilterList`, `Filter`, dan `NetworkHelper`.
- Runtime memakai `DexClassLoader` untuk load class dari metadata
  `tachiyomi.extension.class`, menjalankan request/parse method `HttpSource`,
  lalu memetakan model Kotlin (`SManga`, `SChapter`, `Page`) ke model Dart.
- Komiku sudah diverifikasi di Pixel 7 Pro: repository/source detail memuat
  daftar populer, detail One Piece, chapter list 1207 item, dan reader gambar
  asli setelah header gambar (`Referer`, `Accept`, `Sec-Fetch-*`) dikirim.
- Repository row sekarang bisa membentuk URL APK dari metadata repo
  (`index.min.json` -> `apk/<file>.apk`) dan membuka installer sistem Android
  untuk package extension yang belum terpasang.
- Sumber Saya memakai domain matcher repository: URL manual yang host-nya cocok
  dengan `baseUrl` repo akan diarahkan ke `extension-runtime:<pkg>` juga, bukan
  hanya parser universal/WebView.

## Yang Masih Belum Setara Tachiyomi

Index seperti `keiyoushi/extensions` dan `yuzono/manga-repo` berisi metadata APK
extension. Logika parser sebenarnya ada di kelas Kotlin dalam APK/source
extension, biasanya implementasi `SourceFactory`, `HttpSource`, atau
`ParsedHttpSource`.

Untuk setara Tachiyomi di Android, Kizen perlu:

1. Memperluas compatibility layer untuk semua API/dependency yang dipakai
   extension populer.
2. Menjembatani model Kotlin ke model Dart:
   - popular/latest/search
   - manga details
   - chapter list
   - page list
3. Menangani network/cookie/WebView challenge dan dependency yang dipakai
   extension.

Untuk iOS, APK Android tidak bisa dijalankan langsung. Pendekatan Tachimanga
berarti harus punya compatibility layer sendiri atau source extension yang
dipaketkan ulang agar bisa berjalan di runtime iOS.

## Kontrak Data Flutter

File Dart utama: `lib/data/extension_runtime.dart`.

Runtime info:

- `platform`
- `apiVersion`
- `available`
- `message`
- `capabilities`

Installed extension package:

- `packageName`
- `name`
- `versionName`
- `versionCode`
- `installed`

## Tahap Berikutnya

1. Tambah flow update APK extension kalau versi repo lebih baru dari yang
   terpasang di device.
2. Validasi extension lain dari Keiyoushi/Yuzono; tambahkan stub API/dependency
   Tachiyomi yang muncul dari error runtime.
3. Perluas dukungan `SourceFactory` multi-source APK.
4. Untuk iOS, cari jalur runtime/port terpisah karena APK Android tidak bisa
   dijalankan langsung.
