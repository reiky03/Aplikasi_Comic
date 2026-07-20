# Progress Tracking — My Comic (Flutter)

Rekreasi desain dari `design_handoff_my_comic/` (prototipe `My Comic.dc.html`).
Urutan build mengikuti `00_START_HERE.md`. Tiap item selesai → review & approve dulu sebelum lanjut.

## Status

| # | File spek | Scope | Status | Catatan |
|---|---|---|---|---|
| 1 | `01_design_system.md` | Design tokens (warna, tipografi, spacing, radii, ikon, motion) | ✅ Approved | `lib/core/theme/` |
| 2 | `15_shared_components.md` | Bottom nav, FAB, bottom sheet shell, toast, context menu, collection picker, empty state | ✅ Approved | `lib/core/widgets/` |
| 3 | `03_onboarding.md` | Splash → Login (Google) → Sync | ✅ Approved | `lib/features/onboarding/`, `lib/features/auth/`, `lib/features/sync/` |
| 4 | `04_library.md` | Tab Library (kategori, search, sort, grid, empty state) | ✅ Approved | `lib/features/library/`, `lib/features/home/`, `lib/data/` |
| 5 | `05_updates.md` | Tab Updates (feed per tanggal + refresh) | ✅ Approved | `lib/features/updates/`, `lib/data/updates_state.dart` |
| 6 | `06_history.md` | Tab History (lanjut baca, hapus riwayat) | 👀 Menunggu review | `lib/features/history/`, `lib/data/history_state.dart` |
| 7 | `07_browse_sumber_saya.md` | Tab Jelajahi — sub-tab "Sumber Saya" | 👀 Menunggu review | `lib/features/browse/browse_screen.dart`, `lib/data/sources_state.dart` |
| 8 | `09_add_source.md` | Layar Add Source URL (form, test/validate, simpan) | 👀 Menunggu review | `lib/features/browse/add_source_screen.dart` |
| 9 | `10_source_detail_webview.md` | Source Detail + WebView Session Mode | 👀 Menunggu review | `lib/features/browse/source_detail_screen.dart`, `web_view_screen.dart` |
| 10 | `08_browse_repository.md` | Tab Jelajahi — sub-tab "Repository" | 👀 Menunggu review | `lib/features/browse/repo_browse_tab.dart`, `lib/data/repository_state.dart` |
| 11 | `11_repository_management.md` | Repository List, Add/Edit Repository, language picker | 👀 Menunggu review | `lib/features/browse/repository_screens.dart` |
| 12 | `12_comic_detail.md` | Comic Detail (daftar chapter, download, koleksi) | 👀 Menunggu review | `lib/features/detail/`, `lib/data/downloads_state.dart` |
| 13 | `13_reader.md` | Reader (webtoon + manga paged, settings sheet, nav chapter) | 👀 Menunggu review | `lib/features/reader/`, `lib/data/reader_settings.dart` |
| 14 | `14_settings.md` | Settings (akun, tema, reader default, sync, sign out) | 👀 Menunggu review | `lib/features/settings/`, `lib/data/demo_state.dart` |
| 15 | `02_flow_overview.md` | Final pass: navigation graph lengkap + back-stack | 👀 Menunggu review | test alur end-to-end di `test/widget_test.dart` |

Legenda: ⬜ Belum · 🔨 Dikerjakan · 👀 Menunggu review · ✅ Approved

## Log

### 2026-07-18 — Extension Soul Scans yang hanya mengirim 4 item ikut diperluas

Tab Terbaru masih 4 item karena source yang tersimpan ternyata bisa resolve ke
extension repository Soul Scans. `ExtensionRuntimeSource` menganggap 4 hasil
extension sebagai hasil final, sehingga parser HTML/SvelteKit tidak pernah
dipakai walau katalog website lebih lengkap.

Fix:
- `extension_runtime_source.dart` khusus pada `fetchLatest` sekarang, bila
  extension mengembalikan kurang dari 20 item, mencoba fallback HTML dan parser
  alternatif. Hasil fallback dipakai hanya jika jumlahnya lebih besar, jadi
  extension normal yang sudah lengkap tetap tidak disentuh.
- Test baru mensimulasikan extension 4 item + fallback 5 item dan memastikan
  hasil 5 item yang dipakai.

Diverifikasi:
- `flutter analyze lib test` bersih.
- Test extension runtime lulus 6/6.
- APK profile berhasil dibuild dan dipasang ulang ke device.

### 2026-07-18 — Tab Terbaru Soulscans ikut memakai katalog penuh

Tab Terbaru masih menampilkan 4 komik karena parser mencoba route `/latest`
yang ternyata 404, lalu jatuh ke `/comic` sebagai homepage. Homepage hanya
punya 4 item, sementara katalog `/allcomic` live berisi daftar penuh.

Fix:
- `sveltekit_comic_source.dart` mengubah urutan `fetchLatest` menjadi
  `/allcomic` → `/comic` → `/`, sama seperti popular. Parameter halaman tetap
  dikirim untuk scroll/pagination.
- Test baru memastikan `fetchLatest(1)` request pertama ke `/allcomic`.

Diverifikasi:
- Route live `/latest` 404, `/comic` 4 item, `/allcomic` 50 item.
- `flutter analyze lib test` bersih.
- Test SvelteKit lulus 5/5.
- APK profile berhasil dibuild dan dipasang ulang ke device.

### 2026-07-18 — Universal parser tidak berhenti di 4 item homepage SvelteKit

Walau parser SvelteKit sudah mendahulukan `/allcomic`, source Soulscans lama
masih bisa memakai `UniversalHtmlSource`. Universal menganggap 4 item dari
homepage sebagai hasil valid dan selesai sebelum fallback SvelteKit terpanggil.

Fix:
- `universal_html_source.dart` sekarang mengenali marker
  `data-sveltekit-fetched`/`__sveltekit_`. Kalau hasilnya kurang dari 20 item,
  parser mengecek katalog SvelteKit penuh sebelum mengembalikan hasil kecil.
- Hasil katalog yang lebih banyak dipakai sebagai hasil final, sementara
  source non-SvelteKit tetap memakai jalur universal lama tanpa request
  tambahan ini.
- Test Universal + SvelteKit tetap lulus setelah perubahan.

Diverifikasi:
- `flutter analyze lib test` bersih.
- Test targeted parser lulus 19 test dengan 3 skip WebView safe mode.
- APK profile berhasil dibuild dan dipasang ulang ke device.

### 2026-07-18 — Soulscans memakai katalog penuh, bukan homepage 4 komik

User menemukan Soulscans hanya menampilkan 4 komik walaupun katalog website
jauh lebih banyak. Root cause-nya parser berhenti di homepage: payload
homepage hanya berisi section `hot_weekly` dengan 4 item.

Fix:
- `sveltekit_comic_source.dart` sekarang mencoba `/allcomic` lebih dulu untuk
  popular, lalu `/comic`, baru homepage sebagai fallback. Parameter `page`
  tetap dikirim supaya infinite scroll di Source Detail bisa mengambil katalog
  berikutnya.
- Test baru memastikan request pertama popular selalu ke `/allcomic`, jadi
  homepage ringkas tidak boleh lagi memotong daftar menjadi 4 item.

Diverifikasi:
- `flutter analyze lib test` bersih.
- Test SvelteKit lulus 4/4.
- APK profile berhasil dibuild dan dipasang ulang ke device.

### 2026-07-18 — Sumber custom tanpa parserKind tidak lagi langsung dilempar ke WebView

User sudah memasukkan Soulscans, tetapi app tetap membuka WebView. Root cause:
sumber yang dibuat sebelum parser SvelteKit ditambahkan kemungkinan tersimpan
tanpa `parserKind`; `SourceDetailScreen` dan `source_resolver.dart` sebelumnya
memang menganggap kondisi itu tidak punya parser native.

Fix:
- `adaptive_source.dart` menambah rantai otomatis untuk sumber custom tanpa
  parserKind: SvelteKit → Universal HTML → MangaThemesia → NatsuId. Setiap
  metode harus menghasilkan data non-kosong; kalau semua gagal, exception
  WebView membawa URL halaman yang relevan.
- `source_catalog.dart` menambah factory `buildAutomatic`.
- `source_resolver.dart` sekarang memakai parser otomatis untuk source manual
  dan source repository yang belum punya parserKind, jadi komik lama tetap
  bisa dicoba tanpa hapus/tambah ulang sumber.
- `source_detail_screen.dart` memakai parser otomatis saat metadata source
  belum menyimpan parserKind.

Diverifikasi:
- `flutter analyze lib test` bersih.
- Test parser SvelteKit dan resolver lulus.
- APK profile sudah dibuild dan dipasang ulang ke device; startup setelah
  install tidak menunjukkan crash/ANR.

### 2026-07-18 — Parser pola SvelteKit untuk Soulscans dan URL gambar HTTPS

User minta Soulscans dibuatkan parser yang bisa menjadi pola reusable untuk
situs lain. Dari halaman live `v1.soulscans.asia` terlihat daftar/detail/chapter
dirender lewat payload SvelteKit `application/json`/`data-sveltekit-fetched`,
sedangkan gambar reader dikirim dari `sscdn.dbm.my.id` memakai URL `http://`.
URL HTTP itu rawan gagal di Android karena cleartext/network security.

Fix:
- `sveltekit_comic_source.dart` menambah parser generik pola SvelteKit untuk
  daftar manga, detail, chapter, payload `pages`, dan gambar DOM. Parser tidak
  dikunci ke satu domain supaya bisa dipakai situs SvelteKit lain yang memakai
  struktur route/payload serupa.
- URL gambar host `sscdn.dbm.my.id` dan subdomain Soulscans dinormalisasi ke
  HTTPS sebelum masuk ke Reader.
- `source_catalog.dart` menambah kind `sveltekit-comic` di auto-detect sebelum
  parser tema lain.
- `universal_html_source.dart` tetap menjadi metode utama untuk sumber lama,
  tetapi sekarang punya fallback SvelteKit setelah parser universal gagal dan
  ikut menormalisasi URL gambar Soulscans. Jadi source yang sudah terlanjur
  tersimpan sebagai `universal-html` tetap mendapat perbaikan tanpa wajib
  dihapus/tambah ulang.
- `sveltekit_comic_source_test.dart` menguji listing, detail/chapter, payload
  pages, dan konversi HTTP gambar menjadi HTTPS.

Diverifikasi:
- Halaman live Soulscans merespons HTTP 200; route comic/chapter dan URL gambar
  HTTPS terkonfirmasi dari response saat pengecekan.
- `flutter analyze lib test` bersih.
- Test parser SvelteKit + Universal lulus; 3 test WebView lama tetap di-skip
  sengaja karena safe mode ANR.

### 2026-07-18 — Parser alternatif berantai + tombol WebView saat semua metode gagal

User minta setiap sumber dicoba dengan beberapa metode secara berurutan: parser
yang sudah jalan tetap dicoba dulu, parser tambahan baru dipakai kalau hasilnya
kosong/gagal, lalu user tetap diberi jalan keluar lewat WebView. Sebelumnya
`ExtensionRuntimeSource` berhenti setelah bridge dan satu fallback HTML gagal,
sedangkan reader cuma menampilkan pesan error.

Fix additive:
- `alternative_source_methods.dart` menambah rantai parser tema
  MangaThemesia dan NatsuId. Rantai ini hanya dipanggil setelah bridge APK dan
  parser universal lama tidak menghasilkan data, jadi jalur source yang sudah
  stabil tidak diambil alih parser baru.
- `extension_runtime_source.dart` sekarang mencoba bridge → fallback lama →
  parser alternatif untuk popular/latest/search/detail/chapter/page. Kalau
  semuanya gagal, dilempar `MangaSourceWebViewException` dengan URL halaman
  yang bisa langsung dibuka.
- `manga_source.dart` menambah exception khusus WebView tanpa mengubah kontrak
  `MangaSource` yang lama.
- `reader_screen.dart` menampilkan tombol `Buka WebView` pada error daftar
  chapter maupun gambar halaman dan mengirim URL chapter/detail yang gagal.
- `source_detail_screen.dart` juga menampilkan tombol WebView saat daftar
  Jelajahi gagal; `web_view_screen.dart` menerima `initialUrl` baru, sementara
  pemakaian WebView lama tetap memakai URL sumber seperti sebelumnya.
- Test extension runtime menutup dua jalur baru: fallback alternatif dipakai
  setelah parser utama kosong, dan kegagalan total menghasilkan URL absolut
  untuk WebView.

Diverifikasi:
- `flutter analyze lib test` bersih.
- `flutter test -j 1` selesai tanpa failure; 3 test WebView otomatis tetap
  di-skip sengaja karena safe mode ANR.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke device `2A311FDH300122` dan startup setelah
  install tidak menunjukkan `FATAL EXCEPTION` atau ANR di logcat.

### 2026-07-18 — Rollback compatibility batch karena regresi Doujindesu

Setelah batch compatibility API lama dipasang ke APK profile, Doujindesu
kembali membalas HTTP 404 walaupun blok request Doujindesu tidak diedit.
Karena baseline sebelum batch terbukti jalan di device, semua tambahan batch
terakhir di-rollback dari build yang akan dites:
- status/constructor tambahan di `Page.kt`;
- perubahan constructor `Filter.Separator`;
- API fetch Rx tambahan di `HttpSource.kt`;
- implementasi Observable tambahan di `rx/Observable.kt`.

Baseline runtime extension dan fallback Doujindesu tetap dipertahankan. Ini
menegaskan compatibility API baru harus diuji terpisah dulu dan tidak boleh
masuk ke build utama sebelum ada bukti source stabil.

### 2026-07-18 — Tambah compatibility API Tachiyomi lama tanpa ubah jalur stabil

User minta dukungan source repository diperluas dengan aturan ketat: metode yang
sudah jalan, terutama reader Doujindesu, tidak boleh dirombak. Dari APK
extension Sektedoujin yang terpasang ditemukan signature Tachiyomi lama yang
belum ada di compatibility layer Kizen:
- constructor `Page(index, url, imageUrl, uri, status)`;
- `Filter.Separator(name)`;
- API Rx `Observable.just/error/map`;
- API fetch lama `HttpSource.fetchPopularManga`, `fetchLatestUpdates`,
  `fetchSearchManga`, `fetchMangaDetails`, `fetchChapterList`, dan
  `fetchPageList`.

Fix additive:
- `Page.kt` hanya menambah status + konstanta status, tanpa mengubah field lama.
- `Filter.kt` hanya membuat nama Separator bisa diisi, sementara constructor
  kosong tetap tersedia.
- `rx/Observable.kt` menambah constructor kosong kompatibel dan operasi dasar
  Observable yang dipakai extension lama.
- `HttpSource.kt` menambah API fetch lama yang menjalankan request/parse bawaan;
  method request/parse existing dan bridge modern tidak diubah.

Diverifikasi:
- APK extension Doujindesu dan Sektedoujin dibaca dari device untuk mencocokkan
  signature constructor/API yang benar.
- Build dan test penuh dijalankan setelah compile selesai.

### 2026-07-18 — Balikin URL asli extension supaya Doujindesu gak 404 lagi

User melaporkan reader Doujindesu berubah dari error gambar/no-host menjadi
`Doujindesu mengembalikan status 404`. Root cause regresinya ketemu di working
tree: jalur bridge APK sebelumnya mengirim URL manga/chapter asli ke method
`mangaDetailsRequest`, `chapterListRequest`, dan `pageListRequest`, tetapi
perubahan metode tambahan sempat menormalisasi URL menjadi path baru sebelum
diberikan ke extension. Sebagian extension Doujindesu membangun request sendiri
dari URL itu, sehingga endpoint akhirnya berubah dan dibalas 404.

Fix:
- `ExtensionRuntimeBridge.kt` kembali mengirim `mangaUrl` dan `chapterUrl`
  persis seperti yang diberikan extension/runtime, mengikuti perilaku commit
  yang sebelumnya sudah berjalan.
- Helper normalisasi URL yang tidak lagi dipakai di jalur extension dibuang.
- Resolusi URL relatif tetap dipertahankan hanya di parser fallback universal
  dan fallback native ketika memang perlu membuat URL absolut; jalur extension
  lama tidak ikut disentuh.

Diverifikasi:
- Kotlin source dicek ulang terhadap commit `d038302` yang sebelumnya stabil.
- Berikutnya wajib build APK profile dan uji reader Doujindesu di device.

### 2026-07-17 — Hardening source/repository + Updates dan Settings final
- Runtime extension Android sekarang punya compatibility stub yang lebih luas,
  cache hasil request, resolver source stabil berdasarkan package/source ID,
  dan bridge penuh untuk popular/latest/search/detail/chapter/page. Source dari
  repo yang APK-nya terpasang bisa dipakai sebagai `MangaSource` sungguhan.
- Universal parser diperluas untuk HTML, JSON/REST, WordPress, script-embedded
  image, header/cookie sesi WebView, dan berbagai pola reader/chapter. Parser
  khusus Asura juga ditambah; gambar reader mempertahankan rasio/header asli.
- Repository otomatis refresh index saat tab dibuka atau lewat tombol refresh,
  mengikuti perubahan domain/base URL dan membandingkan versionCode/versionName
  extension. Source terpasang naik ke atas, tersedia install/update/uninstall,
  pencarian tetap fixed di atas, dan bookmark repo lama diganti konsep install.
- Progress parsial Reader sekarang disimpan per chapter memakai identitas URL,
  jadi posisi seperti 3/16 dan 4/16 dari dua chapter tidak saling overwrite.
  Reader juga memakai lazy image, cacheWidth, precache terkontrol, dan rasio
  source supaya scroll profile lebih ringan tanpa memotong gambar.
- Feed Updates sekarang membuat satu snapshot chapter terbaru untuk setiap komik
  Library yang berhasil diperiksa, menyimpan `chapterUrl` stabil, cover, dan
  label asli. Refresh tanpa perubahan tidak menulis ulang timestamp/unread;
  entri komik yang sudah keluar dari Library tidak ditampilkan.
- Sumber Saya, source repo, repository list, dan preview memakai favicon situs
  dengan fallback berlapis. Label bahasa ID/EN dibuat lebih terang.
- Tentang disederhanakan menjadi `@reiky03`, pemeriksaan pembaruan, dan lisensi
  open source. Tombol Keluar kini meminta konfirmasi; logout memutus Firebase
  dan mereset seluruh provider data akun, lalu provider di-reset lagi sebelum
  sync login berikutnya agar data antarakun tidak bercampur.
- Verifikasi: `flutter analyze lib test` bersih, seluruh 48 test lolos, APK
  profile berhasil dibuild dan dipasang ke Pixel 7 Pro serta iQOO I2508.

### 2026-07-17 — Repository runtime Tachiyomi + fix gambar reader Komiku
- Android extension runtime diperluas dari POC popular menjadi bridge penuh:
  popular/latest/search, manga details, chapter list, dan page list dari APK
  extension Tachiyomi/Mihon yang terpasang di device.
- `ExtensionRuntimeSource` ditambahkan sebagai implementasi `MangaSource`; source
  Repository yang punya `pkg` sekarang diarahkan ke `extension-runtime:<pkg>`.
  Ini membuat source repo seperti Komiku bisa muncul di Source Detail, membuka
  detail manga, mengambil daftar chapter, dan masuk Reader tanpa parser Dart
  manual khusus per-web.
- Repository tab punya pencarian source; index Keiyoushi/Yuzono tetap dibaca dari
  metadata repo, dengan fallback parser universal/WebView untuk source yang belum
  punya APK runtime terpasang.
- Validasi Pixel 7 Pro: APK profile terinstall, Komiku repository/source detail
  memuat daftar populer, detail One Piece, chapter list 1207 item, dan reader
  berhasil membuka gambar asli.
- Fix tambahan untuk `KomikuSource` manual: image reader sekarang membawa header
  browser-like (`Referer`, `Accept`, `Accept-Language`, `Sec-Fetch-*`) sehingga
  `img.komiku.org` tidak lagi 403/placeholder. Sebelum fix log menunjukkan
  `HTTP request failed, statusCode: 403` dengan `headers={}`.
- Verifikasi: `flutter analyze lib test` bersih, `flutter test` lolos 29/29,
  `flutter build apk --profile` sukses, dan APK profile sudah di-install ke
  Pixel.

### 2026-07-17 — Installer extension repo + domain matcher Sumber Saya
- Repository row sekarang membaca package extension terpasang via
  `ExtensionRuntimeBridge.listInstalledExtensions()`; row menampilkan tombol
  status kecil: centang kalau APK sudah terpasang, download kalau belum.
- Android runtime menambah `installExtensionApk`: download APK dari URL repo ke
  cache app, lalu buka Android Package Installer lewat `FileProvider`.
  Manifest ditambah `REQUEST_INSTALL_PACKAGES` dan provider cache
  `@xml/file_paths`; dependency AndroidX Core ditambahkan untuk `FileProvider`.
- URL APK dibentuk dari metadata repository: contoh
  `.../repo/index.min.json` + `tachiyomi-id.komiku-v1.4.21.apk` menjadi
  `.../repo/apk/tachiyomi-id.komiku-v1.4.21.apk`.
- Add Source / Sumber Saya sekarang mencocokkan domain URL manual ke source
  repository (`baseUrl`). Kalau cocok dan source punya `pkg`, parser yang
  disimpan menjadi `extension-runtime:<pkg>`, sehingga URL manual bisa pakai
  runtime extension juga.
- Resolver global (Comic Detail, Reader, Updates) ikut membaca repository, jadi
  sumber lama di Sumber Saya yang domainnya cocok repo bisa naik ke runtime
  extension tanpa perlu ditambah ulang.
- Verifikasi: `flutter analyze lib test` bersih, `flutter test` lolos 31/31,
  `:app:compileProfileKotlin` sukses.

### 2026-07-16 — Firebase tersambung (Android/iOS/Web)
- User berhasil `flutterfire configure --project=kizen-da39f` (Android, iOS, Web) —
  `lib/firebase_options.dart`, `android/app/google-services.json`,
  `ios/Runner/GoogleService-Info.plist`, `firebase.json`, plugin Gradle
  `com.google.gms.google-services` di `android/settings.gradle.kts` &
  `android/app/build.gradle.kts` semua sudah ada & di-merge.
- `main.dart`: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
  dipanggil sebelum `runApp()` — dilewati saat `--dart-define=FAKE_AUTH=true` (mode
  dev/preview tetap tidak butuh Firebase asli).
- `authRepositoryProvider` sekarang default ke `FirebaseAuthRepository` (Google
  Sign-In → `signInWithCredential`) — `GoogleAuthRepository` (versi device-only
  tanpa Firebase) dihapus karena sudah tidak dipakai/tidak relevan.
- Test widget diperbaiki: test pertama sekarang juga override
  `authRepositoryProvider` dengan `FakeAuthRepository` (widget test pump `KizenApp`
  langsung tanpa lewat `main()`, jadi Firebase memang belum ter-init di situ —
  itu bukan bug, dan test seharusnya tidak bergantung pada Firebase App nyata).
- **Belum jalan** (butuh langkah manual di device/Android Studio, akan dipandu
  saat user siap test login Google beneran di HP): tambah SHA-1/SHA-256
  fingerprint debug ke Firebase Console (syarat wajib `google_sign_in` v7 di
  Android), dan `serverClientId` (Web Client ID) untuk `idToken` yang valid.
- Data layer Firestore (`docs/DATABASE.md`) belum diimplementasi — masih pakai
  data demo lokal di semua Notifier `lib/data/`. Langkah berikutnya setelah
  login Google beneran diverifikasi jalan.

### 2026-07-16 — Rebrand ke Kizen + palet navy-biru + persiapan Firebase
- **Rebrand nama**: "My Comic" → "Kizen" di semua teks UI (splash, login, footer versi,
  copy no-bypass WebView/Source Detail), judul app, class `MyComicApp` → `KizenApp`,
  Android `android:label`, iOS `CFBundleDisplayName`/`CFBundleName`, web manifest
  `name`/`short_name`/`theme_color`, `<title>` web. Package Dart (`aplikasi_komik`)
  & applicationId/bundle ID Android/iOS **sengaja tidak diubah** (internal identifier,
  rename akan memaksa ubah import di ~30 file tanpa nilai tambah user-visible).
- **Palet warna baru** (`lib/core/theme/app_colors.dart`) sesuai brand Kizen:
  `bg #05070A`, `surface #101B2D`, `accent #1E88C8` (tombol utama), `accentText #7EC8E3`
  (highlight aktif), `danger`/`badge #D6422B` (destruktif & badge new/update — dipisah
  jadi 2 token karena beda konteks meski nilainya sama), `textPrimary #F8F6F0`.
  Semua turunan alpha (segment aktif, border faint, shadow FAB, dll) dihitung ulang
  dari accent/danger baru. `accentGradient` jadi biru-ke-navy ("ombak"). Badge unread
  di grid Library diubah dari accent→badge (merah) sesuai spek pemisahan "tombol
  utama" vs "badge/new/update". Palet light-mode dicatat sebagai konstanta
  (`lightBg`, dll) untuk referensi nanti — belum diaktifkan (spek awal: dark-first,
  toggle Tema masih dekoratif).
- **Logo**: BELUM terpasang — file gambar yang di-paste di chat tidak tersimpan
  sebagai file yang bisa diakses (beda dari upload file biasa). Menunggu user
  mengirim file logo via upload supaya bisa ditaruh di `assets/branding/` dan
  dipasang di Splash/Login menggantikan `AppMark` (glyph vektor buatan sendiri).
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore` ditambahkan ke
  pubspec. `lib/features/auth/auth_repository.dart` — kelas baru
  `FirebaseAuthRepository` (Google Sign-In → `signInWithCredential`) sudah ditulis
  lengkap tapi **belum jadi default** (butuh `lib/firebase_options.dart` dari
  `flutterfire configure`, yang perlu login interaktif di mesin user — tidak bisa
  dijalankan dari sandbox ini). `main.dart` belum memanggil `Firebase.initializeApp()`
  supaya app tetap bisa dibuild tanpa config. Skema data siap dipakai:
  `docs/DATABASE.md`.

### 2026-07-16 — 06 s/d 14 + 02 (final pass)
- **06 History** — row lanjut baca (thumbnail 48×64, progress bar 4px, waktu + tombol play bulat → Reader langsung), tombol Bersihkan + toast, empty state jam.
- **07 Sumber Saya** — header Jelajahi (globe berbadge + glyph repo custom), 2 sub-tab, daftar sumber dengan 6 status berwarna + pill bahasa, search live, context menu ter-wire, FAB hanya di sub-tab ini.
- **09 Add Source** — form lengkap, Test Sumber 1.3s (gagal bila URL mengandung error/fail/xxx), pesan inline sukses/gagal, simpan dedup URL, status normal/webview sesuai hasil test.
- **10 Source Detail + WebView** — state parsable (banner session + Reset, search, tab underline, grid discover 9 judul) & state error per status; WebView dengan challenge "Saya bukan robot" 1.4s → session tersimpan, banner hijau, Simpan ke Library; tanpa bypass otomatis (hard requirement). Body webview masih mock demo — TODO webview_flutter saat sumber asli dipakai.
- **08 Repository sub-tab** — grup per bahasa aktif, bookmark independen + section DITANDAI, sheet Bahasa aktif (5 bahasa, live), 3 state konten; row membuka Source Detail via sumber sintetis.
- **11 Repository management** — Repository Saya (edit/hapus per row, + di header), Add/Edit satu layar dua mode, Periksa Repository + pratinjau isi, bahasa round-robin placeholder.
- **12 Comic Detail** — hero 230px + cover overlap, genre pills, sinopsis, bookmark → collection picker kontekstual, Mulai/Lanjut Baca, chapter list + toggle unduh (downloadsProvider).
- **13 Reader** — webtoon (slider ↔ scroll dua arah — bug prototipe diperbaiki, footer chapter berikutnya) & manga paged (tap zone 32%, RTL flip), chrome toggle, nav chapter + toast batas, Pengaturan Reader (arah, 4 swatch latar, jarak, kecerahan dengan overlay dim nyata, wakelock via wakelock_plus) persisten via SharedPreferences.
- **14 Setelan** — account card dari user login asli, Tema (dekoratif dark-first), Pengaturan Reader, Sinkronisasi manual, 5 toggle demo/QA yang benar-benar memaksa empty state, Keluar (sign out asli → Login), footer versi.
- **02 Final pass** — back-stack diverifikasi (detail kembali ke pemanggil; reader "Lihat detail" pop bila dari detail / replace bila dari History-play; add/edit repo → Repository List; webview → Source Detail), toast sort Library ditambahkan (perilaku prototipe), test widget end-to-end login→sync→Library.
- Catatan produksi: section Demo/QA disarankan di-gate flag debug sebelum rilis; OAuth Google & backend sync/parse masih TODO yang disengaja.

### 2026-07-15 — 05_updates.md
- `lib/data/updates_state.dart` — model `UpdateEntry` (grup tanggal, chapter, waktu relatif) + `UpdatesNotifier` seeded data prototipe; `refresh()` stub 1.2s (TODO backend).
- `lib/features/updates/updates_screen.dart` — header + tombol refresh (ikon ↻ berubah spinner 17px selama refresh, lalu toast "Updates diperbarui — memeriksa chapter baru"), feed grup per tanggal (eyebrow uppercase HARI INI/KEMARIN), row: thumbnail 44×58 + judul + "Chapter N" accentText + sumber + waktu kanan; empty state "Belum ada update terbaru" tanpa CTA.
- Tab Updates di-wire ke `HomeShell`. Tap row → Comic Detail masih placeholder (spek 12).

### 2026-07-15 — 04_library.md
- `lib/data/models.dart` — model `Comic` + `ComicCollection` + `comicCover(hue)` (gradient placeholder 155°, formula prototipe).
- `lib/data/library_state.dart` — `LibraryNotifier` & `CollectionsNotifier` (Riverpod) seeded data demo prototipe; mutasi: pindah koleksi, tandai selesai, hapus, buat/hapus koleksi (hapus koleksi → komik lepas ke "Semua").
- `lib/features/home/home_shell.dart` — shell 5 tab (IndexedStack + bottom nav persisten) + `activeTabProvider`; tab lain masih placeholder judul.
- `lib/features/library/library_screen.dart` — header + tombol search/filter, search inline (border accent, filter judul live), chips koleksi (aktif accent, badge count, "+" dashed → Kelola koleksi), grid 3 kolom (`ComicGridCard` reusable: cover 2:3 r13, inisial 52px 14%, badge unread, scrim bawah, judul 2 baris + "Ch. N"), sort sheet 3 opsi, context menu long-press ter-wire penuh, empty state library + pesan ringan untuk koleksi kosong/hasil pencarian kosong.
- Splash/Sync sekarang mendarat di `HomeShell`; harness dev `lib/dev/` dihapus.
- Tap kartu → Comic Detail masih toast placeholder (menunggu spek 12).

### 2026-07-15 — 03_onboarding.md
- `lib/features/auth/auth_repository.dart` — integrasi Google Sign-In asli (google_sign_in v7: `initialize` → `attemptLightweightAuthentication` untuk restore sesi di Splash, `authenticate` untuk login interaktif) di balik interface `AuthRepository`; `FakeAuthRepository` untuk dev/preview via `--dart-define=FAKE_AUTH=true` (sesi tersimpan di SharedPreferences). `AuthController` (Riverpod Notifier) pegang user aktif.
- `lib/features/sync/sync_service.dart` — stub sync awal (timing prototipe 1.5s) + `syncDebugFailProvider` (dipakai debug toggle Settings/14 nanti). TODO(backend).
- `lib/features/onboarding/splash_screen.dart` — brand moment 1.7s paralel dengan cek sesi; sesi valid → skip login+sync.
- `lib/features/onboarding/login_screen.dart` — tombol Google putih 56/r16 + logo G SVG, legal line; gagal → toast, batal → diam.
- `lib/features/onboarding/sync_screen.dart` — spinner 64 + glyph panah sinkron custom; state error produksi: "Gagal sync, coba lagi" + tombol Coba Lagi + Lanjutkan offline (sesuai instruksi spek, bukan auto-lanjut prototipe).
- `lib/core/widgets/app_mark.dart` (logo 4 panel) + `app_spinner.dart` (ring + track, reusable).
- Setup platform Google Sign-In (OAuth client ID Android/iOS) masih perlu diisi saat mau rilis — dicatat di komentar `GoogleAuthRepository`.

### 2026-07-15 — 15_shared_components.md
- `lib/core/widgets/app_bottom_nav.dart` — `AppTab` enum + nav pill mengambang (margin 8/10/22, radius 20, shadow ke atas, aktif `accentText` / inaktif `textFaint`) + backdrop gradasi; margin bawah adaptif safe-area.
- `lib/core/widgets/library_glyph.dart` — ikon Library dua-bar custom painter (tidak ada padanan Lucide).
- `lib/core/widgets/app_fab.dart` — FAB 58×58 r19 gradient + shadow ungu.
- `lib/core/widgets/app_sheet.dart` — `showAppSheet` (scrim .55, slide-up 280ms cubic(.2,.8,.2,1)), `AppSheetShell` (drag handle, padding 14/20/34 atau 14/14/34 menu-style), `AppSheetTitle`, `AppSheetOptionRow` (checkmark accent), `AppSheetMenuRow` (ikon 19 + label, varian destruktif).
- `lib/core/widgets/app_context_menu.dart` — context menu komik/sumber (dengan preview row 42×42) + reader more menu, copy persis prototipe.
- `lib/core/widgets/app_toast.dart` — toast overlay bottom:120, bg #26262f, ikon centang hijau, auto-dismiss 2.4s, toast baru menggantikan yang lama.
- `lib/core/widgets/app_empty_state.dart` — pola empty state 96×96 r26 + judul + deskripsi (InlineSpan, bisa highlight) + CTA opsional.
- `lib/core/widgets/app_toggles.dart` — `AppPillSwitch` (track #2a2a35/accent) + `AppSegmentedControl` (aktif: tint accent 16% + border 50%).
- `lib/core/widgets/collection_sheets.dart` — collection picker (judul kontekstual, "Buat koleksi baru" dashed → expand input) + kelola koleksi (hapus per-row, input+Buat persisten, disabled state).
- `lib/dev/components_preview.dart` — harness dev SEMENTARA untuk review komponen; dihapus saat 03_onboarding dibangun.
- Fix: toast dibungkus `Material` transparan (hilangkan underline kuning teks di Overlay).

### 2026-07-15 — 01_design_system.md
- Setup dependency: `flutter_riverpod` (state management), `google_fonts` (Plus Jakarta Sans + JetBrains Mono), `lucide_icons_flutter` (ikon outline Feather/Lucide-style).
- `lib/core/theme/app_colors.dart` — semua token warna + `accentGradient` (150deg) + radial wash splash/login.
- `lib/core/theme/app_typography.dart` — preset text style sesuai tabel tipografi; helper `mono()` untuk URL.
- `lib/core/theme/app_dimens.dart` — padding layar, radii, tombol, FAB (58px, bottom 104), nav pill, sheet, grid 3 kolom gap 14, cover 2:3.
- `lib/core/theme/app_motion.dart` — durasi/curve (screen 280ms, sheet cubic-bezier(0.2,0.8,0.2,1), spinner 750ms, toast 2.4s) + `FadeSlideUpPageTransitionsBuilder`.
- `lib/core/theme/app_icons.dart` — mapping ikon Lucide sesuai daftar Iconography.
- `lib/core/theme/app_theme.dart` — `ThemeData` dark (satu-satunya tema; toggle tema terang di Settings = TODO dekoratif sesuai handoff).
- `lib/main.dart` — `ProviderScope` + `MaterialApp` pakai tema; home placeholder sementara.

### 2026-07-16 — Google Sign-In: Web Client ID (serverClientId) terpasang
- Provider Google diaktifkan di Firebase Authentication → Sign-in method → memicu Firebase auto-create Web OAuth Client (`client_type: 3`) di `google-services.json`/`GoogleService-Info.plist`.
- `flutterfire configure --project=kizen-da39f` dijalankan ulang untuk refresh config (android/ios/web), lalu di-push.
- `lib/features/auth/auth_repository.dart` — `FirebaseAuthRepository._webClientId` diisi dengan Web Client ID hasil auto-create tsb, dipakai sebagai `serverClientId` pada `GoogleSignIn.instance.initialize(...)` — ini yang bikin Android/iOS dapat `idToken` valid untuk ditukar ke `GoogleAuthProvider.credential` → `signInWithCredential`.
- `flutter analyze` bersih, `flutter test` lolos (2/2).
- `ios/Runner/Info.plist` — tambah `CFBundleURLTypes` dengan `REVERSED_CLIENT_ID` (dari `GoogleService-Info.plist`) sebagai URL scheme, wajib untuk redirect Google Sign-In di iOS.
- Sisa: belum dicoba build/run asli Android/iOS (masih tahap kode+konfigurasi, belum diverifikasi end-to-end dengan device/emulator sungguhan).

### 2026-07-16 — Logo Kizen asli terpasang
- User kirim file logo asli (upload, bukan paste inline) — lingkaran ombak navy brush-stroke + kanji 善 + aksen matahari merah + katakana きぜん.
- Di-crop jadi mark lingkaran (tanpa wordmark "KIZEN"/tagline di bawahnya, karena teks "Kizen" sudah dirender terpisah di Splash/Login) → `assets/branding/kizen_mark.png` (512×512, sudut luar lingkaran transparan).
- `pubspec.yaml` — tambah `assets/branding/` ke daftar assets.
- `lib/core/widgets/app_mark.dart` — disederhanakan total: `AppMark` sekarang `DecorationImage` bulat dari asset di atas (dengan shadow yang sama seperti sebelumnya), menggantikan gradient+`CustomPaint` 4-panel komik placeholder. Parameter `radius` dibiarkan ada di API (dipakai pemanggil) tapi diabaikan karena mark aslinya bundar.
- Diverifikasi visual: build web (`--no-web-resources-cdn` supaya CanvasKit dari lokal, bukan CDN gstatic yang diblok sandbox) + screenshot headless Chromium — logo tampil bersih & kontras di Splash & Login (background gelap).
- Tagline Splash dikonfirmasi user: tetap pakai yang sudah ada ("Baca komik dari sumber pilihanmu dan sinkronkan koleksi antar-device"), bukan opsi Inggris yang ditawarkan.

### 2026-07-16 — Animasi gelombang di Splash
- `lib/core/widgets/wave_background.dart` (baru) — 3 lapis gelombang sinus tipis (opacity 8–13%, warna `accent`/`accentText`) di-loop 8s pakai `AnimationController` + `CustomPainter`, tiap lapis beda fase/amplitudo/kecepatan biar terasa organik (bukan looping obviously berulang).
- Dipasang di `splash_screen.dart`, `Align(bottomCenter)` di belakang logo & spinner — motif ombak yang senada sama logo Kizen (ombak navy).
- Diverifikasi visual (build web + screenshot 2 frame beda waktu) — gerakannya halus, tidak mengganggu keterbacaan teks/logo.

### 2026-07-16 — Fix overlap spinner + animasi "ombak jadi logo"
- Fix: `WaveBackground` di Splash diperkecil (240→120px) + posisi `AppSpinner` dinaikkan (bottom 60→88), supaya puncak gelombang tidak lagi ketimpa/menabrak spinner loading (laporan user).
- `lib/core/widgets/logo_reveal.dart` (baru) — animasi sekali-main (~1.1s) di ikon Splash: 2 cincin riak bertepi bergelombang (motif ombak, bukan lingkaran polos) mengecil & memudar dari luar, bertumpang-tindih dengan logo asli yang fade+scale-in di tengahnya → efek "ombak menjadi ikon Kizen", bukan logo yang muncul instan.
- `splash_screen.dart` — `AppMark` langsung diganti `LogoReveal` (bungkus `AppMark` di dalamnya, shadow tetap sama).
- Diverifikasi visual dengan durasi animasi diperpanjang sementara (18s) khusus untuk screenshot bertahap (build web + Playwright headless), lalu dikembalikan ke nilai produksi (1100ms reveal / 1700ms total brand moment) sebelum commit.

### 2026-07-16 — Perpanjang animasi reveal logo (kurang kelihatan)
- User merasa animasi ombak→logo kurang lama/kurang kelihatan. `LogoReveal.duration` default 1100ms → 1900ms; total brand moment Splash 1700ms → 2600ms (reveal selesai + jeda tahan ~700ms sebelum pindah layar).
- `test/widget_test.dart` — pump durasi splash disesuaikan (1800→2700ms) di kedua test; sempat ada bug replace yang cuma kena test pertama (baris test kedua ada komentar inline `// splash` jadi tidak match), diperbaiki manual — `flutter test` sekarang lolos lagi (2/2).

### 2026-07-16 — Splash jadi 3.5 detik
- Reveal logo 1.9s → 2.4s, total brand moment 2.6s → 3.5s (permintaan user).
- `test/widget_test.dart` pump durasi splash disesuaikan (2700→3600ms).

### 2026-07-16 — Backend Firestore terpasang (data layer nyata)
Implementasi penuh skema `docs/DATABASE.md` — seluruh Notifier di `lib/data/`
sekarang dual-mode: Firestore real-time (login asli) atau data demo in-memory
(FAKE_AUTH/widget test/belum login), tanpa mengubah tampilan/API yang dipakai
layar sama sekali.

- `lib/data/firestore_scope.dart` (baru) — `FirestoreScope.uid`/`userDoc`/
  `collection(name)`, semua getter aman dipanggil walau Firebase belum
  di-init (cek `Firebase.apps.isEmpty` dulu sebelum sentuh `FirebaseAuth`/
  `FirebaseFirestore.instance`) — inilah seam dual-mode-nya, bukan flag
  `kUseFakeAuth` (supaya widget test yang tidak lewat `main()` tetap aman).
- `Comic`, `ComicCollection`, `ComicSource`, `ComicRepository`+`RepoSource`,
  `ReaderSettings` — ditambah `toMap()`/`fromMap()` sesuai kolom di docs.
- `LibraryNotifier`/`CollectionsNotifier` (`library_state.dart`) — stream
  `users/{uid}/library` & `collections`; mutasi (`add`/`remove`/
  `moveToCollection`/`markFinished`/`unassignCollection`) jadi Firestore
  write saat login asli (listener yang update `state`), tetap local-mutate
  langsung saat fallback. Tambah `updateProgress()` baru untuk Reader.
- `SourcesNotifier` (`sources_state.dart`), `RepositoriesNotifier` +
  `ActiveLangsNotifier`/`RepoBookmarksNotifier` (`repository_state.dart`,
  2 provider terakhir stream dokumen `settings/app` yang sama) — pola sama.
- `HistoryNotifier` (`history_state.dart`) — `HistoryEntry` ditambah field
  `comicId` (doc id Firestore = comicId, sebelumnya tidak ada id sama
  sekali, match by title di UI). Field `time` string statis diganti
  `readAt` (Timestamp) + label relatif dihitung saat render (`_relativeLabel`,
  bukan disimpan) sesuai docs. `upsert()` baru dipanggil dari Reader.
  `history_screen.dart` disesuaikan pakai `comicId` bukan title-matching.
- `ReaderSettingsNotifier` (`reader_settings.dart`) — SharedPreferences
  (lokal) jadi Firestore `settings/reader` doc saat login asli; dua-duanya
  tetap optimistic-update (`state` langsung, baru persist/write).
- `reader_screen.dart` — progres baca (chapter/halaman) sekarang ditulis ke
  `history` + `library.read/unread` dengan debounce 2 detik (`Timer`),
  flush sekali lagi di `dispose()` kalau ada perubahan pending — sebelumnya
  Reader tidak menyimpan progres sama sekali (mock murni).
- `sync_service.dart` — `SyncService` sekarang benar-benar mengisi/
  memperbarui dokumen profil `users/{uid}` (`name`/`email`/`photoUrl`/
  `lastSyncAt`, `createdAt` sekali saja) saat login asli, dijalankan
  paralel dengan timing UI 1.5s brand moment (tidak berubah).
- `firestore.rules` + `firestore.indexes.json` (baru) + `firebase.json`
  didaftarkan (`"firestore"` key) — rules persis docs (`users/{uid}` hanya
  bisa diakses oleh pemiliknya).
- Diverifikasi: `flutter analyze` bersih, `flutter test` lolos (2/2, tidak
  ada perubahan karena keduanya pakai `FakeAuthRepository` — Firestore
  path tidak pernah tersentuh di test), smoke-test manual (build web
  FAKE_AUTH + Playwright headless: Login → Sync → Library → History,
  semua render benar, tidak ada Dart exception).
- **Sengaja TETAP lokal/di luar scope** (sesuai docs): unduhan chapter
  (`downloads_state.dart`), cookie/sesi WebView asli, dan feed Updates
  (`updates_state.dart` — cek chapter baru butuh backend scraping sumber
  yang berbeda sama sekali, bukan penyimpanan user; masih mock/TODO).
  `themeModeLabelProvider` (`demo_state.dart`) juga belum disambungkan ke
  `settings/app.themeMode` — masih dekoratif sesuai catatan docs, prioritas
  rendah karena toggle tema terang belum aktif juga.
- **Langkah manual yang masih perlu user** (belum bisa dari sandbox ini):
  1. Buat database Firestore di Firebase Console (Build → Firestore
     Database → Create database) — project `kizen-da39f` kemungkinan
     belum punya Firestore aktif sama sekali.
  2. Deploy `firestore.rules` — via `firebase deploy --only firestore`
     dari terminal, atau paste manual ke tab Rules di Console.

### 2026-07-16 — Fondasi "ambil komik asli" (4 parser native + katalog)
User minta lanjut ke fitur ambil komik asli, kasih 4 situs (Shinigami,
Ikiru, Komiku, Komikindo) + 2 link "repository" Tachiyomi/Mihon
(`keiyoushi/extensions`, `yuzono/manga-repo`).

- **Klarifikasi penting**: 2 link repository itu **bukan** config data
  biasa — itu indeks APK Android untuk aplikasi Tachiyomi/Mihon (logika
  scraping tiap situs ada di dalam APK Kotlin terkompilasi). Tidak bisa
  dipakai langsung dari Flutter (beda bahasa/arsitektur total, dan
  APK-loading cuma bisa di Android, tidak iOS). **Yang tetap dipakai**:
  karena extension-nya open-source, source code Kotlin-nya (di
  `keiyoushi/extensions-source`, bukan repo `extensions` yang isinya APK
  terkompilasi) dibaca langsung untuk tahu persis endpoint/struktur HTML
  tiap situs, lalu diporting jadi Dart native — bukan nebak dari nol.
- `lib/sources/manga_source.dart` (baru) — kontrak `MangaSource`
  (`fetchPopular/Latest/Search`, `fetchMangaDetails`, `fetchChapterList`,
  `fetchPageList`) + model (`SourceManga`, `SourceMangaDetails`,
  `SourceChapter`, `SourcePage`, `MangaSourceException`) — mirip konsep
  "extension" Tachiyomi tapi native Dart, jalan di Android & iOS.
- `lib/sources/shinigami_source.dart` — API JSON murni (`api.shngm.io`),
  diporting 1:1 dari `Shinigami.kt`+`ShinigamiDto.kt`.
- `lib/sources/komiku_source.dart` — HTML scraping (`api.komiku.org`),
  diporting dari `Komiku.kt`. Selector jsoup yang pakai `:contains()`/
  `:has()` (tidak didukung `package:html` Dart) ditulis ulang jadi
  traversal manual (logika tetap sama).
- `lib/sources/mangathemesia_source.dart` — parser generik utk tema
  WordPress "MangaThemesia" (dipakai Komikindo & ratusan situs sejenis),
  diporting dari `lib-multisrc/mangathemesia`. Reusable: tinggal beda
  `baseUrl`/`name` utk situs MangaThemesia lain nanti.
- `lib/sources/natsuid_source.dart` — parser tema WordPress "NatsuId"
  (dipakai Ikiru), diporting dari `lib-multisrc/natsuid`. Detail
  komik/daftar chapter/daftar halaman (bagian inti baca komik) 1:1 sesuai
  referensi; listing populer/terbaru disederhanakan pakai WP REST API
  standar (bukan endpoint AJAX+nonce situs asli yang nilai field
  order/orderby persisnya tak bisa dipastikan tanpa akses situs langsung)
  — urutan "populer" mungkin belum 100% akurat, item lanjutan kalau perlu.
- `lib/sources/source_catalog.dart` — `SourceCatalog.matchByUrl()`
  mencocokkan URL yang diketik user ke salah satu dari 4 parser di atas
  (by host base URL); situs lain tetap bisa ditambahkan seperti biasa,
  fallback ke WebView Session Mode (spek 10), bukan error.
- `add_source_screen.dart` — "Test Sumber" sekarang benar-benar
  memanggil `fetchPopular(1)` via parser yang cocok kalau URL dikenali;
  situs di luar 4 itu tetap pakai simulasi prototipe (regex
  error/fail/xxx) seperti sebelumnya.
- **Testing**: sandbox ini tidak bisa akses situs manapun (network policy
  blokir semua domain non-allowlist, termasuk API-nya) — jadi tiap parser
  divalidasi pakai **unit test dengan fixture** (data JSON/HTML persis
  bentuk asli, lihat `test/sources/*_test.dart`, total 16 test + 2 test
  lama = 18, semua lolos) alih-alih tes langsung ke internet. User perlu
  tes final di HP (koneksi asli) untuk verifikasi endpoint/selector masih
  akurat saat ini (situs bisa berubah struktur sewaktu-waktu).
- Dependencies baru: `http` (HTTP client), `html` (parser HTML/DOM).
- **Belum dikerjakan** (langkah lanjutan): wiring ke Source Detail
  (grid discover pakai data asli, bukan dummy) dan Reader (render
  gambar chapter asli, ganti placeholder gradient "PAGE N"); comic
  detail & search juga belum pakai parser ini. `flutter analyze` bersih,
  seluruh test lolos.

### 2026-07-16 — Wiring komik asli: Source Detail, Comic Detail, Reader
Lanjutan dari parser native — sekarang beneran dipakai di UI (bukan cuma
kode parser doang), sesuai keluhan user "berasa kurang isian list grid".

- `lib/core/widgets/comic_cover_content.dart` (baru) — `comicCoverContent()`
  render gambar cover asli (`Image.network`, fallback ke gradient+inisial
  kalau null/gagal dimuat) — dipakai konsisten di grid Library & Source
  Detail; Comic Detail hero juga pakai cover asli (banner + poster).
- `lib/data/models.dart` — `Comic` ditambah `coverUrl` (URL cover asli) &
  `sourceMangaUrl` (identifier manga di parser sumber; null = komik demo/
  lokal). `toMap`/`fromMap` disesuaikan (Firestore ikut simpan field ini).
- `source_detail_screen.dart` — kalau URL sumber cocok salah satu dari 4
  parser (`SourceCatalog.matchByUrl`), tab Populer/Terbaru/Hasil Cari
  benar-benar fetch dari situs asli (loading spinner, error state +
  Coba Lagi, search di-debounce 500ms) — menggantikan 9 judul dummy statis.
  Sumber di luar 4 itu (termasuk sumber sintetis dari Repository) tidak
  berubah sama sekali.
- `comic_detail_screen.dart` — diubah dari `ConsumerWidget` ke
  `ConsumerStatefulWidget`. Kalau `comic.sourceMangaUrl != null`: fetch
  `fetchMangaDetails`+`fetchChapterList` paralel saat dibuka (loading
  state, error + Coba Lagi), lalu render deskripsi/genre/author/status
  ASLI dan daftar chapter ASLI (nomor sintetis tetap dihitung turun dari
  total→1 biar kompatibel dengan logika "dibaca" yang sudah ada). Simpan
  ke koleksi otomatis isi `ch` sungguhan (sebelumnya 0 sampai chapter
  ter-fetch).
- `reader_screen.dart` — constructor baru `sourceChapters`/
  `initialChapterUrl` (null = komik demo, perilaku lama 100% tidak
  berubah). Kalau ada: fetch `fetchPageList` sungguhan per pindah chapter
  (loading spinner, error + Coba Lagi), render `Image.network` per
  halaman (fallback ke placeholder gradient saat masih loading/gagal),
  navigasi Prev/Next chapter jalan di atas index list asli (bukan
  aritmetika int seperti komik demo, karena penomoran chapter asli bisa
  tidak berurutan/desimal).
- Diverifikasi: `flutter analyze` bersih, semua test lolos (18/18), plus
  smoke-test manual jalur komik DEMO end-to-end (Library → Comic Detail →
  Reader, build web + Playwright headless) — tampilan & interaksi persis
  sama seperti sebelum perubahan ini, tidak ada regresi.
- Ditemukan (bukan regresi): `wakelock_plus` di web build sempat
  melempar unhandled error karena JS pendukungnya (`no_sleep.js`) gagal
  dimuat di sandbox — murni keterbatasan web/sandbox, tidak berlaku di
  Android/iOS asli (pakai platform channel native, bukan JS).
- **Belum ketes ke internet asli** — user perlu coba "Test Sumber" +
  buka salah satu dari 4 situs di HP buat verifikasi endpoint/selector
  masih akurat (situs bisa berubah struktur sewaktu-waktu).
- **Belum dikerjakan**: comic dari discover yang di-`_openComic` tidak
  otomatis ke-cache identitasnya kalau title sama dari sumber beda (id
  sintetis `src_{sourceId}_{urlEncoded}` per sumber, jadi aman); search
  global lintas-sumber (Browse) masih belum menyentuh parser ini.

### 2026-07-16 — Fix: login gagal "No credential available" setelah Sign Out
User laporan: sign out lalu coba login Google lagi → gagal, pesan
"no credential available". Ketemu akar masalahnya di source Kotlin
plugin `google_sign_in_android` — `signOut()` kita memanggil
`GoogleSignIn.instance.signOut()`, yang di Android meng-clear
Credential Manager (`clearCredentialState()`). Di sejumlah versi
Android, ini bikin `authenticate()` berikutnya gagal dengan
`GetCredentialFailureType.noCredential` ("No credential available: ...")
walau akun Google-nya masih ada di device.
- `lib/features/auth/auth_repository.dart` — `FirebaseAuthRepository.
  signOut()` sekarang hanya `FirebaseAuth.instance.signOut()`, tidak lagi
  memanggil `GoogleSignIn.signOut()`. Tombol "Continue with Google" tetap
  selalu minta pilih akun tiap login (bukan auto-login diam-diam via akun
  tersimpan), jadi tidak ada perubahan UX — cuma menghindari bug
  Credential Manager di atas.

### 2026-07-16 — Fix Reader: gambar kepotong + patah-patah
User tes Shinigami beneran di HP: scroll patah-patah + gambar chapter
kepotong. Dua akar masalah di `reader_screen.dart`:
1. Gambar asli dipaksa masuk kotak rasio 2:3 tetap + `BoxFit.cover`
   (logika itu buat placeholder demo, bukan gambar asli yang rasionya
   macam-macam) → kepotong.
2. `ListView` (bukan `.builder`) bikin SEMUA halaman ke-build & mulai
   fetch/decode sekaligus di awal, bukan lazy sesuai viewport → berat,
   patah-patah, apalagi gambar manga scan biasanya beresolusi besar dan
   didekode di resolusi asli (tidak di-downsize).

Perbaikan:
- Webtoon: `ListView` → `ListView.builder` (lazy, cuma bangun item
  dekat viewport). Halaman lebar penuh, tinggi menyesuaikan rasio ASLI
  gambar (`BoxFit.fitWidth`, tanpa tinggi dipaksa) — gambar utuh, tidak
  kepotong lagi, mirip Tachiyomi.
- Manga (paged): full-screen `BoxFit.contain` (letterbox kalau rasio
  beda) untuk gambar asli, bukan `AspectRatio` tetap+cover.
- `cacheWidth` di tiap `Image.network` (gambar asli) — Flutter decode
  sesuai lebar layar device, bukan resolusi asli file (bisa jauh lebih
  besar) — jauh lebih ringan untuk CPU/memori, mengurangi jank.
- `_pageExtent()` (estimasi scroll→halaman untuk slider) disesuaikan:
  placeholder demo tetap rasio 2:3, komik asli pakai perkiraan rasio umum
  webtoon (0.7) — karena tinggi asli per halaman kini bervariasi, slider
  untuk komik asli jadi perkiraan (bukan presisi piksel sempurna, sama
  seperti reader app lain pada umumnya untuk mode scroll kontinu).
- Diverifikasi: `flutter analyze` bersih, semua test lolos (18/18),
  smoke-test jalur demo (build web + Playwright) — render identik
  seperti sebelum perubahan, tidak ada regresi.

### 2026-07-16 — Fix: pilih chapter lag untuk komik dengan banyak chapter
User laporan: baca chapter udah mulus, tapi buka daftar chapter di
Comic Detail lag banget kalau chapternya banyak. Penyebabnya:
`comic_detail_screen.dart` render seluruh daftar chapter pakai `Column`
biasa di dalam `ListView` — artinya SEMUA `_ChapterRow` langsung
di-build sekaligus begitu layar dibuka, bukan cuma yang kelihatan di
layar (untuk komik ratusan chapter, ini ratusan widget + ratusan
`ref.watch` sekaligus).

- `comic_detail_screen.dart` — diubah dari `ListView` ke
  `CustomScrollView` + sliver: bagian atas (cover, judul, sinopsis,
  tombol) di `SliverToBoxAdapter`, daftar chapter di `SliverList` dengan
  `SliverChildBuilderDelegate` (lazy, cuma bangun chapter dekat
  viewport) — persis prinsip yang sama dengan fix Reader sebelumnya.
- Diverifikasi: `flutter analyze` bersih, semua test lolos (18/18),
  smoke-test visual (build web + Playwright) — tampilan identik seperti
  sebelumnya, tidak ada regresi.

### 2026-07-16 — Reader lebih halus lagi + progres baca per-chapter + tanda "sudah di Library"
- **Performa Reader**: tiap halaman webtoon/manga dibungkus `RepaintBoundary`
  (scroll di satu halaman tidak memicu repaint halaman lain) +
  `filterQuality: FilterQuality.low` (raster GPU lebih ringan, penting di
  layar refresh rate tinggi) + `gaplessPlayback: true` (tidak flicker saat
  ganti chapter). `ListView.builder` webtoon pakai `scrollCacheExtent:
  ScrollCacheExtent.viewport(2.0)` — halaman 2 layar ke depan mulai
  di-load sebelum kelihatan, bukan mepet muncul.
- **Progres baca per-chapter** (`comic_detail_screen.dart`) — chapter list
  sekarang bedain 3 status, bukan cuma "Dibaca"/belum: chapter sebelum
  posisi terakhir = "Dibaca" (tuntas), chapter yang SEDANG dibaca
  (cocok dengan entri `history`) tampilkan progres asli "Hal X/Y" (bukan
  langsung dianggap tuntas begitu dibuka), chapter setelahnya = polos
  (belum disentuh). Otomatis tersinkron lewat Firestore (`history` +
  `library.read`) karena semua akun pakai login Google — beda dari
  Tachiyomi yang riwayatnya lokal per-device.
- **Tanda "sudah di Library"** (`source_detail_screen.dart`) — kartu
  discover di Source Detail sekarang kasih badge centang biru di pojok
  cover kalau komik itu sudah tersimpan di Library user (dicek via id
  sintetis `src_{sourceId}_{urlEncoded}`, konsisten dari saat komik
  pertama ditemukan sampai disimpan).
- Diverifikasi: `flutter analyze` bersih, semua test lolos (18/18),
  smoke-test visual (build web + Playwright) — progres "Hal 8/38"
  muncul benar untuk chapter yang sedang dibaca (data demo), counter
  "X dibaca" ikut ter-update akurat.

### 2026-07-16 — Fix: progres baca tidak ke-track
User laporan: buka komik dari Library, baca, tapi nggak ada yang
"ketrack" (riwayat/progres nggak update). Dua bug:
1. `reader_screen.dart` — progres cuma dijadwalkan simpan kalau scroll
   melewati batas halaman (`_onScroll`) atau ganti chapter/halaman
   manual. Baca chapter pendek/cepat tanpa scroll jauh → sinyal simpan
   nggak pernah kepicu sampai keluar layar. Fix: `initState()` sekarang
   langsung jadwalkan simpan progres begitu chapter dibuka (tetap
   debounce 2 detik), jadi minimal posisi awal selalu tersimpan.
2. `library_state.dart` — `updateProgress()` (dipanggil tiap progres
   baca) langsung `.update()` dokumen Firestore `library/{comicId}`
   tanpa cek keberadaannya dulu. Kalau komik itu belum pernah disimpan
   ke Library (baca langsung dari hasil pencarian tanpa nge-bookmark
   dulu), dokumennya belum ada → Firestore lempar error "not-found",
   dan karena panggilannya fire-and-forget tanpa try-catch, errornya
   gagal diam-diam (tidak kelihatan sama sekali). Fix: cek dulu apakah
   comicId ada di `state` (list Library yang lagi aktif) sebelum
   nyoba update Firestore — kalau belum tersimpan, dilewati (riwayat
   `history` tetap selalu tercatat terpisah, cuma field `library.read`
   yang di-skip). `reader_screen.dart` juga sekarang `catchError` di
   kedua panggilan (history & library) supaya kalau ada kegagalan lain
   di masa depan, minimal muncul di log debug — tidak sepenuhnya bisu.
- Diverifikasi: `flutter analyze` bersih, semua test lolos (18/18),
  smoke-test (build web + Playwright) — buka chapter baru, TANPA
  scroll sama sekali, tunggu >2 detik, balik ke Comic Detail →
  progres "Hal 1/8" muncul otomatis di chapter yang baru dibuka.

### 2026-07-16 — Diagnostik: progres masih belum ke-track setelah fix sebelumnya
User sudah pull+rebuild fix sebelumnya, tapi History & Comic Detail
masih tetap kosong sama sekali — berarti kemungkinan bukan (cuma) soal
timing debounce/dokumen belum ada, ada sesuatu yang gagal total di
jalur Firestore write yang belum kelihatan errornya (sebelumnya cuma
`debugPrint`, tidak pernah kelihatan user karena bukan developer yang
mantengin terminal/logcat).
- `reader_screen.dart` — kegagalan simpan history/library sekarang juga
  muncul sebagai **toast di layar** (`AppToast.show`), bukan cuma log
  — supaya kalau ada error Firestore (rules, koneksi, dll), user bisa
  langsung lihat & laporkan pesannya. Sifatnya sementara buat
  diagnosa, akan dibalikin ke silent-log setelah dipastikan beres.
- User lapor lagi: masih tetap kosong total, toast juga tidak pernah
  muncul (berarti bukan write yang gagal) — ditambah laporan baru:
  counter halaman di bawah Reader ("1/8") kadang tidak sesuai jumlah
  halaman asli & tidak reset rapi tiap ganti chapter.

### 2026-07-16 — Root cause ditemukan: `orderBy` + `serverTimestamp()` bikin entri history hilang dari listener
Toast tidak pernah muncul (berarti tulisan ke Firestore **berhasil**,
bukan gagal) tapi History tetap kosong — artinya masalahnya di sisi
baca/listener, bukan tulis. Ditemukan lewat baca ulang
`history_state.dart`: query listener-nya pakai
`col.orderBy('readAt', descending: true).snapshots()`, sedangkan
`readAt` ditulis pakai `FieldValue.serverTimestamp()`. Selama
tulisannya masih *pending* (server belum ack), nilai field itu `null`
di cache lokal — dan Firestore **mengecualikan dokumen dari hasil
`orderBy`** kalau field yang diurutkan belum ke-resolve. Efeknya:
entri riwayat yang baru ditulis sempat (atau bahkan terus, kalau ack
server lambat/gagal) tidak pernah muncul di listener sama sekali.
Ini persis best-case penjelasan kenapa: tulisan sukses (toast tidak
pernah muncul), tapi baca selalu kosong.
- `history_state.dart` — buang `orderBy('readAt')` dari query, urutkan
  hasilnya manual di Dart (`list..sort(...)`) setelah snapshot masuk.
  Tidak butuh field itu ter-resolve dulu buat muncul di hasil. Juga
  tambah `onError` di listener (`debugPrint`) sebagai jaring pengaman
  diagnostik kalau ada masalah baca lain di masa depan.
- `reader_screen.dart` — perbaiki laporan counter halaman: sebelumnya
  selama `fetchPageList` masih loading untuk chapter sumber asli,
  `_totalPages` jatuh ke nilai mock (8) karena `_realPages` belum ada,
  padahal toolbar bawah (counter "X/Y" + slider) tetap tampil terus
  (tidak ikut disembunyikan bareng spinner loading gambar) — jadi
  angkanya kelihatan salah/ngasal tiap baru ganti chapter, baru benar
  setelah selesai fetch. Ditambah getter `_pageCountKnown`; selama
  belum diketahui, counter tampil "–" dan slider dinonaktifkan (bukan
  nampilin "1/8" yang salah).
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web (FAKE_AUTH) — baca komik demo, tunggu >2 detik, balik
  ke History → entri "Baru saja" muncul di posisi teratas dengan
  progres terbaru (mengonfirmasi jalur simpan→tampil bekerja begitu
  listenernya tidak lagi salah mengecualikan dokumen).

### 2026-07-16 — Fix tambahan: race condition fetch halaman & tanda "sudah dibaca" yang salah
User lapor dua hal lagi setelah fix di atas: (1) counter/slider halaman
di Reader kadang tidak sesuai chapter yang lagi dibuka & tidak "reset"
rapi tiap ganti chapter, (2) lebih parah — komik yang belum pernah
dibaca sama sekali kadang chapter-chapter lamanya langsung kelihatan
"sudah dibaca" (redup/dicoret) padahal belum pernah dibuka.
- **Race condition di `_loadRealPages`** (`reader_screen.dart`):
  kalau pindah chapter sebelum fetch chapter sebelumnya kelar, dan
  fetch lama itu (jaringan lambat) baru resolve BELAKANGAN, hasilnya
  bisa menimpa `_realPages` chapter yang SEDANG dibuka — jadi
  counter/slider kelihatan tidak sesuai/tidak reset. Ditambah
  `_pagesRequestId` (naik tiap panggilan baru); hasil fetch cuma
  dipakai kalau id-nya masih yang terbaru saat request itu selesai.
- **Tanda "Dibaca" per-chapter yang salah** (bug lebih serius):
  `comic_detail_screen.dart` sebelumnya nandain chapter "sudah dibaca"
  pakai `num < comic.read`, dengan `comic.read` = nomor chapter
  TERJAUH yang pernah dibuka (di-set tiap kali chapter dibuka, lihat
  `updateProgress`). Asumsinya user selalu baca urut dari chapter 1 —
  begitu user buka SATU chapter dengan nomor besar (mis. chapter
  terbaru, wajar krn daftar chapter selalu terbaru di atas), SEMUA
  chapter dengan nomor lebih kecil otomatis ketandain "sudah dibaca"
  walau belum pernah dibuka sama sekali.
  - Tambah field baru `Comic.readChapters` (`Set<int>`, persisten ke
    Firestore) — daftar chapter yang BENAR-BENAR sudah tercapai
    halaman terakhirnya, per-chapter, bukan diturunkan dari
    perbandingan angka.
  - `library_state.dart` — method baru `markChapterRead(comicId,
    chapterNum)`, idempotent, dipanggil dari `reader_screen.dart`
    tiap `_saveProgress()` kalau posisi baca sudah di halaman
    terakhir chapter itu (terpisah dari `updateProgress`, yang tetap
    jalan seperti sebelumnya buat label "Ch. N" & badge unread).
  - `comic_detail_screen.dart` — `_buildChapter` sekarang cek
    `comic.readChapters.contains(num)`, bukan `num < comic.read`.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — baca chapter demo (baru sampai halaman 1 dari 8,
  BELUM tamat) → chapter lain (termasuk yang nomornya lebih kecil)
  tetap tidak ketandain "Dibaca", header total "0 dibaca" (sebelumnya,
  dengan bug lama, seed data yang sudah under partial "read" akan
  memicu tanda salah begitu progres tersimpan).

### 2026-07-16 — Slider webtoon pakai posisi render nyata, paginasi discover grid, tombol WebView di header
Tiga laporan lagi dari user:
1. Slider/counter halaman di Reader "mentok penuh" padahal chapter
   belum tamat, dan progres "Hal X/Y" (belum tamat) di Comic Detail
   masih belum pernah muncul.
2. Grid discover di Source Detail isinya cuma segitu-segitu terus,
   ditekan refresh juga sama saja — padahal situs sumbernya harusnya
   punya banyak judul.
3. Minta ikon browser/WebView di sebelah ikon refresh Source Detail,
   biar gampang buka situs asli langsung kalau parser situsnya lagi
   bermasalah.

Root cause #1: `_onScroll` (reader_screen.dart) menghitung posisi
baca dari **estimasi** tinggi tiap halaman (`_pageExtent` — rasio
manga standar, lebar/0.7), bukan tinggi RENDER sungguhan. Untuk
webtoon strip (umum di situs-situs ini) yang jauh lebih tinggi dari
estimasi itu, sedikit scroll saja sudah dihitung sebagai "sudah lewat
banyak halaman" — slider mentok duluan. Ini juga yang bikin progres
"Hal X/Y" tidak pernah muncul: `_page` yang salah tinggi bikin
`progress.page >= progress.pages` keburu true (dianggap "sudah
tamat"), padahal belum.
- Ganti jadi baca posisi RENDER NYATA tiap halaman lewat `GlobalKey`
  per item (`_pageKeys`) + `RenderBox.localToGlobal`, bukan estimasi
  tinggi rata-rata. Akurat untuk rasio gambar apa pun (manga standar
  maupun webtoon strip panjang).

Root cause #2: `_loadDiscover` di `source_detail_screen.dart`
memang HANYA PERNAH memanggil halaman 1 (`fetchPopular/Latest/Search`
selalu dengan `page` default) — tidak ada mekanisme infinite-scroll
maupun tombol "muat lagi" sama sekali, walau tiap parser sumber
(`shinigami_source.dart` dkk) sebenarnya SUDAH menghitung
`hasNextPage` dengan benar, cuma nilainya tidak pernah dipakai UI-nya.
- Tambah infinite-scroll: `ScrollController` di grid, deteksi dekat
  dasar (<600px tersisa) → auto-fetch halaman berikutnya
  (`_loadMore()`), append ke hasil yang sudah ada. Spinner kecil di
  dasar grid selama memuat halaman tambahan.

#3: `AppHeaderIconButton` baru (ikon `globe`) di sebelah ikon refresh
header Source Detail, buka `WebViewScreen` langsung — sebelumnya opsi
WebView cuma ada di state error total, sekarang bisa diakses kapan
saja tanpa nunggu source ditandai gagal dulu.

- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web (mode demo, karena situs sumber asli tidak bisa
  diakses dari sandbox) — scroll manual sebagian chapter, counter
  "3/8" & posisi slider sesuai konten yang benar-benar terlihat di
  layar ("PAGE 4"), tidak mentok/salah. Paginasi & tombol WebView
  tidak bisa dites live dari sandbox (jaringan ke situs sumber
  diblok) — perlu konfirmasi dari user di HP asli.

### 2026-07-16 — WebView asli, throttle scroll Reader, sort chapter, bersihin Add Source
Empat item dari user setelah tes round sebelumnya:
1. Sidebar Reader & progres masih "kurang mulus".
2. Grid discover sudah bagus (positif, tidak ada aksi).
3. Minta ikon sort (kecil↔besar) di sebelah label "X dibaca" pada
   daftar chapter Comic Detail.
4. WebView Source Detail "masih template belum actual" — dan karena
   sumber sudah terisi, hapus "Pilih Cepat" di Tambah Sumber.

- **`reader_screen.dart`** — `_onScroll` (geometri render nyata dari
  fix sebelumnya) bisa terpicu lebih dari sekali per frame selama
  fling, dan perhitungannya (walk RenderBox + `localToGlobal` per
  halaman) dilakukan inline di listener scroll. Sekarang dikumpulkan
  jadi maksimal SEKALI per frame lewat `addPostFrameCallback`
  (`_scrollComputeScheduled` guard), plus `_pageKeys` di-prune dari
  entry yang sudah ter-unmount tiap hitung (jaga peta tetap kecil di
  chapter yang panjang) — ini akar "kurang mulus"-nya.
- **`comic_detail_screen.dart`** — tombol ikon urutan (panah naik/
  turun) di sebelah "X dibaca"; state `_sortDescending` (default:
  chapter terbaru di atas, seperti sebelumnya), daftar chapter
  di-`reversed` saat toggle tanpa mengubah logika progres/tanda baca.
- **`web_view_screen.dart`** — ditulis ulang total. Sebelumnya 100%
  mock (halaman "KOMIK·STATION" palsu, simulasi CAPTCHA fake, tombol
  simpan hardcode "Void Chronicles"). Sekarang pakai package
  `webview_flutter` sungguhan: navigasi ke URL source asli, tombol
  back/forward/reload asli via `WebViewController`, progress bar
  loading asli. "Simpan ke Library" (yang fake & tidak masuk akal
  tanpa parser per-situs) diganti "Tandai Session Aktif" — sesuai
  spek awal (verifikasi manual, TANPA bypass/deteksi otomatis), user
  sendiri yang menandai kalau sudah login/lolos verifikasi di situs
  aslinya.
  - Ditambah dependency `webview_flutter: ^4.13.0`.
  - **Fix bonus**: `android/app/src/main/AndroidManifest.xml` ternyata
    tidak punya `<uses-permission INTERNET>` — selama ini jalan karena
    `flutter run` (debug) otomatis dapat izin itu dari manifest
    debug-only, tapi build **release** nanti bakal gagal total akses
    jaringan (http/Firestore/WebView) tanpa ini. Ditambahkan ke
    manifest utama sebelum kejadian pas rilis.
- **`add_source_screen.dart`** — bagian "Pilih Cepat" (chip 4 sumber
  native) & `_QuickPickChip` dihapus, form langsung ke "Nama Sumber".
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — toggle sort chapter kebukti kebalik urutannya
  (Chapter 42→1 jadi 1→42) & ikon berubah arah, "Pilih Cepat" sudah
  tidak ada di Tambah Sumber. WebView pakai plugin native
  Android/iOS (bukan web) jadi tidak bisa dites langsung dari sandbox
  — perlu konfirmasi user di HP asli, termasuk cek build **release**
  tidak kena masalah izin internet di masa depan.

### 2026-07-16 — Fitur baru: Bookmark per-halaman di Reader
Permintaan user: bisa nandain "momen epic" saat baca di halaman
tertentu suatu chapter, biar gampang ditemukan lagi lain kali — beda
dari progres baca biasa (yang cuma nyimpen posisi TERAKHIR, ketimpa
terus tiap baca).

- `lib/data/bookmarks_state.dart` (baru) — `BookmarkEntry` +
  `BookmarksNotifier` (pola sama seperti `history_state.dart`: sync
  Firestore `users/{uid}/bookmarks`, fallback in-memory kalau belum
  login). Doc id deterministik `{comicId}_ch{chNum}_p{page}` supaya
  toggle on/off = set/delete dokumen yang sama (tidak ada duplikat).
  Listener SENGAJA tanpa `orderBy` (sort manual di client) — pelajaran
  langsung dari bug history sebelumnya (`orderBy` +
  `FieldValue.serverTimestamp()` bisa bikin dokumen hilang dari hasil
  selama tulisan pending).
- `lib/core/widgets/app_context_menu.dart` — tambah item "Lihat
  bookmark" di menu "more" Reader, dan `showBookmarkListSheet()` baru:
  daftar bookmark satu komik (label chapter + halaman), tap = lompat
  ke situ, ikon hapus di tiap baris.
- `lib/features/reader/reader_screen.dart` — ikon bookmark di toolbar
  atas (di sebelah ikon "more"), terisi/kosong sesuai status halaman
  yang lagi dibuka; tap = toggle + toast konfirmasi. `_jumpToBookmark`
  pindah chapter+halaman (pakai ulang mekanisme `_changeSourceChapter`
  buat sumber asli, plus `_seekToPage` buat lompat scroll — perkiraan
  posisi awal, self-correct begitu `_computeCurrentPage` jalan lagi).
- `docs/DATABASE.md` — dokumentasi skema `bookmarks/{bookmarkId}` baru,
  sekalian benerin dua bagian yang sudah basi: catatan `history` masih
  bilang query pakai `orderBy` (sudah tidak, sejak fix bug hilang
  total), dan field `readChapters` di `library/{comicId}` yang belum
  pernah didokumentasikan dari fix "tanda sudah dibaca" sebelumnya.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — toggle bookmark → ikon terisi + toast "Bookmark
  disimpan", buka "Lihat bookmark" dari menu more → sheet menampilkan
  "Chapter 41 · Hal 1/8" dengan benar.

### 2026-07-16 — Ikon bookmark di daftar chapter, sheet keyboard fix, konfirmasi hapus, ikon app & splash asli
Lima item dari screenshot + laporan user:
1. Sheet "Kelola koleksi" — input nama koleksi baru ketutup keyboard
   pas diketik, sama sekali tidak kelihatan.
2. Hapus koleksi/sumber/repository langsung eksekusi tanpa konfirmasi.
3. Ikon & splash screen native masih default Flutter, bukan logo Kizen
   ("gelombang air" yang sudah dibuat sendiri di splash Flutter-nya).
4. Bookmark sudah jalan, tapi tidak kelihatan di daftar chapter Comic
   Detail — harus buka satu-satu buat tau chapter mana yang ada
   bookmark-nya.

- **`lib/core/widgets/app_sheet.dart`** — `AppSheetShell` sekarang
  nambah `MediaQuery.viewInsetsOf(context).bottom` ke padding bawah,
  jadi sheet otomatis naik ngikutin tinggi keyboard (sebelumnya sheet
  diam di posisi tetap, keyboard nutupin input di bawahnya). Juga
  ditambah `showConfirmSheet()` baru — sheet konfirmasi generik
  (judul+pesan+tombol Batal/Hapus) dipakai di 3 tempat:
  - `collection_sheets.dart` — hapus koleksi (di dalam sheet "Kelola
    koleksi" yang masih terbuka, konfirmasi numpuk di atasnya).
  - `browse_screen.dart` — hapus sumber.
  - `repository_screens.dart` — hapus repository.
- **Ikon bookmark di chapter row** (`comic_detail_screen.dart`) —
  `_Chapter` dapat field `hasBookmark`, dihitung dari
  `bookmarksProvider` sekali per render daftar chapter (bukan per-baris)
  lalu di-cocokkan ke tiap nomor chapter; `_ChapterRow` nampilin ikon
  bookmark kecil di sebelah judul chapter kalau `hasBookmark` true.
- **Ikon app & splash native** — logo `assets/branding/kizen_mark.png`
  dipakai lewat package `flutter_launcher_icons` (ikon launcher
  Android+iOS, adaptive icon Android pakai versi yang di-padding lebih
  banyak — `kizen_mark_adaptive.png`, logo aslinya full-bleed sampai
  tepi kanvas jadi kalau dipakai langsung bakal kepotong sama mask
  bulat/rounded adaptive icon) dan `flutter_native_splash` (splash
  native sebelum Flutter engine siap, background `#05070A` — sama
  persis dengan `AppColors.bg` yang dipakai splash Flutter sendiri,
  biar transisinya mulus bukan lompat warna). Kedua tool di-run sekali
  buat generate semua asset (mipmap, drawable, Info.plist iOS, dst) —
  hasilnya di-commit, tidak di-generate ulang saat build.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — sheet konfirmasi hapus koleksi muncul & numpuk
  dengan benar di atas sheet "Kelola koleksi". Fix keyboard TIDAK bisa
  divalidasi dari sandbox (browser desktop tidak mensimulasikan
  keyboard virtual/viewInsets seperti HP asli) — perlu dicoba langsung.
  Ikon app & splash juga cuma bisa dicek visual dari file PNG yang
  di-generate (bukan build native) — perlu dikonfirmasi tampilannya
  di HP asli setelah install ulang (uninstall dulu / clear cache
  launcher kalau ikon lama masih ke-cache).

### 2026-07-16 — Splash native jadi warna solid saja, durasi splash Flutter 3,5s → 5 detik + mulai sinkron lebih awal
Ikon app disetujui, tapi user minta splash native (logo statis di atas
warna solid, dari fix sebelumnya) dibuang — dua momen splash berurutan
(logo statis → logo animasi "gelombang air" muncul lagi) berasa
redundan. Sebagai gantinya, durasi splash Flutter (`splash_screen.dart`,
animasi gelombang air asli) diperpanjang jadi 5 detik, DAN dipakai
produktif buat mulai sinkron data dari akun (bukan cuma animasi kosong).

- `dart run flutter_native_splash:remove` lalu re-`create` dengan config
  baru: **cuma warna** (`color: "#05070A"`, sama seperti `AppColors.bg`),
  TANPA `image` sama sekali. Splash native jadi transisi warna solid
  polos ke splash Flutter (bukan putih/logo Flutter default, tapi juga
  bukan logo Kizen dobel) — satu-satunya momen "logo muncul" ya splash
  Flutter animasi itu sendiri.
- `splash_screen.dart` — delay `3500ms` → `5000ms`. `restoreSession()`
  (murah/sinkron) dijalankan duluan sebelum delay diawait, dan kalau
  user masih login, provider `libraryProvider`/`historyProvider`/
  `collectionsProvider`/`bookmarksProvider` langsung dibaca saat itu
  juga (bukan nunggu splash kelar) — listener Firestore-nya nempel
  lebih awal, jadi sisa waktu splash (~5 detik) beneran kepakai buat
  narik data dari cloud sebelum user sampai di Library/History,
  bukan sekadar delay kosong.
- `test/widget_test.dart` — durasi `pump()` splash disesuaikan ke
  5100ms (dari 3600ms) biar konsisten dengan delay baru.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos
  (termasuk timing baru), smoke-test web end-to-end tanpa error. Warna
  background native Android (`drawable/background.png`) & iOS
  (`LaunchBackground.imageset/background.png`) dicek manual sama-sama
  `#05070A` — konsisten dua platform. Efek "provider dibaca lebih awal
  bikin data lebih siap" tidak bisa diukur/dites dari sandbox (perlu
  koneksi Firestore asli + device asli buat rasain bedanya).

### 2026-07-16 — Keyboard gak nutup sehabis buat koleksi + animasi sheet kurang mulus
Dua hal dari fix keyboard-avoidance sebelumnya: (1) sehabis tekan
"Buat" di sheet "Kelola koleksi", keyboard tetap terbuka (fokus masih
di text field walau isinya sudah di-clear); (2) padding sheet yang
menyesuaikan tinggi keyboard lompat langsung ke nilai akhir tiap
frame (bukan di-easing), kerasa jitter/patah pas keyboard buka-tutup.

- `collection_sheets.dart` — `FocusScope.of(context).unfocus()`
  dipanggil di `onCreate` sebelum nge-clear controller, keyboard
  otomatis nutup begitu koleksi baru dibuat.
- `app_sheet.dart` — `AppSheetShell` sekarang bungkus padding bawah
  (mengikuti `MediaQuery.viewInsetsOf(context).bottom`) pakai
  `AnimatedPadding` (180ms, `Curves.easeOut`) alih-alih nilai statis
  langsung — transisinya di-interpolasi mulus, bukan lompat sekali
  jadi.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos.
  Baik unfocus maupun kemulusan animasi tidak bisa divalidasi visual
  dari sandbox (perlu keyboard virtual sungguhan di HP) — perlu
  dicoba langsung.

### 2026-07-16 — Fix regresi sheet ketutup, lazy-load Updates, catatan soal refresh rate
User lapor fix keyboard kemarin bikin efek samping: sheet "Kelola
koleksi" ikut ketutup total sehabis "Buat" ditekan (bukan cuma
keyboard-nya). Juga minta smoothness dilanjut ke Updates & History,
dan nanya soal ngikutin refresh rate HP (60/120Hz).

- **Root cause regresi**: `FocusScope.of(context).unfocus()` di dalam
  bottom sheet adalah gotcha Flutter yang cukup dikenal — panggilan
  itu bisa "bubble up" ke `FocusScopeNode` punya route/sheet-nya
  sendiri, dan itu bisa kebaca sebagai "sheet-nya kehilangan fokus,
  tutup aja", padahal niatnya cuma mau nutup keyboard.
  `collection_sheets.dart` diganti pakai
  `FocusManager.instance.primaryFocus?.unfocus()` — cuma lepas fokus
  dari TextField yang aktif sekarang, tanpa efek bubbling ke scope.
- **Updates feed** (`updates_screen.dart`) — `_buildFeed` sebelumnya
  pakai `ListView(children: [...])` (bangun SEMUA baris sekaligus,
  termasuk header grup tanggal) — pola sama persis yang bikin daftar
  chapter Comic Detail lag dulu. Diganti `ListView.builder` (lazy),
  header grup tanggal diselipkan sebagai baris tersendiri di daftar
  campuran header+entri.
- **History** — sudah pakai `ListView.builder` dari awal, tidak ada
  yang perlu diubah.
- **Soal refresh rate 60/120Hz**: dicek `MainActivity.kt` — masih
  stock/default (`class MainActivity : FlutterActivity()`, tanpa kode
  custom apa pun) dan manifest sudah `hardwareAccelerated="true"`.
  Flutter modern di Android SUDAH otomatis mengikuti refresh rate
  aktif dari pengaturan sistem HP (termasuk 120Hz Pixel 7 Pro kamu)
  tanpa perlu kode tambahan — tidak ada "saklar 60 vs 120Hz" yang
  perlu (atau aman) untuk di-hardcode; App tidak pernah membatasi ke
  60Hz secara eksplisit. Kalau masih kerasa kurang mulus, penyebabnya
  faktor lain (kerja per-frame yang berat — persis jenis masalah yang
  sudah dan terus dibenahi), bukan soal refresh rate.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — Updates feed tampil benar (header tanggal + baris
  update), alur buat koleksi (isi nama → tekan Buat) sheet tetap
  terbuka & toast konfirmasi muncul. Regresi fokus/keyboard spesifik
  ke perilaku keyboard virtual Android — perlu dicoba langsung di HP.

### 2026-07-16 — Fix "sudah dibaca" kadang gak ke-set walau chapter sudah tamat
User lapor: baca 1 chapter penuh, kadang statusnya berubah "Dibaca",
kadang enggak — random, bukan konsisten gagal/berhasil terus.

Root cause: `_computeCurrentPage()` nentuin `_page` dari widget
halaman mana yang lagi ter-mount di `_pageKeys` (lihat fix "slider
mentok" sebelumnya). Begitu user scroll sampai lewat halaman
terakhir (mentok ke footer "Akhir chapter") dan diam beberapa saat,
halaman TERAKHIR itu sendiri bisa ter-unmount (keluar dari cache
extent ListView) dan ke-prune dari `_pageKeys` SEBELUM debounce 2
detik buat simpan progres sempat jalan. Begitu itu kejadian, `_page`
jatuh ke halaman termounted tertinggi (lebih rendah dari yang
sebenarnya), jadi `_page + 1 >= _totalPages` gak pernah kebaca true
— chapter gak ketandain tamat, padahal user sudah scroll sampai habis.
Ini soal RACE antara timing debounce vs kapan widget di-dispose, jadi
kadang lolos kadang enggak — persis gejala yang dilaporkan.

- `reader_screen.dart` — `_computeCurrentPage()` sekarang cek dulu
  posisi scroll relatif ke `maxScrollExtent`: kalau sudah di ujung
  bawah (atau nyaris), langsung set `_page = _totalPages - 1` tanpa
  bergantung sama sekali ke geometri per-halaman/`_pageKeys` — posisi
  scroll itu stabil & akurat terlepas dari widget mana yang lagi
  ter-mount atau tidak.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — scroll chapter demo sampai benar-benar mentok
  ("Akhir chapter" footer kelihatan, slider "8/8"), balik ke Comic
  Detail → "Chapter 41" ketandai "Dibaca", header "1 dibaca" muncul
  benar.

### 2026-07-16 — Updates jadi nyata: pengecekan chapter baru sungguhan
Dikonfirmasi via pilihan user (bukan cuma performa) — feed Updates
selama ini 100% data contoh statis, gak pernah beneran ngecek chapter
baru. Sekarang benar-benar mengecek lewat parser sumber asli.

- `lib/data/updates_state.dart` — ditulis ulang total. `UpdateEntry`
  sekarang nyimpen `comicId` + `detectedAt` (bukan string
  `dateGroup`/`time` statis) — label grup tanggal & waktu relatif
  dihitung saat render (getter), sama seperti pola `HistoryEntry`.
  `UpdatesNotifier.refresh()`: iterasi semua komik Library yang punya
  `sourceMangaUrl` (dari sumber asli, lib/sources/), cocokkan
  `MangaSource`-nya lewat `SourceCatalog`, panggil `fetchChapterList`
  SUNGGUHAN. Kalau jumlah chapter di situs > `totalChapters` yang
  tercatat, catat sebagai entri Updates baru + panggil
  `LibraryNotifier.applyNewChapters()` biar `totalChapters`/badge
  unread di Library ikut ke-update. Sekuensial (bukan paralel) —
  sengaja, biar tidak membanjiri situs sumber dengan banyak request
  sekaligus. Komik dari sumber tanpa parser native (WebView-only)
  dilewati (gak bisa dicek otomatis, konsisten prinsip "tanpa bypass
  otomatis"). Kegagalan per-komik (situs down/parser meleset)
  dilewati, tidak menggagalkan keseluruhan pengecekan — balikin
  `UpdateCheckResult` (checked/updated/failed) buat toast yang jujur,
  bukan generik "diperbarui" doang.
- `lib/data/library_state.dart` — method baru `applyNewChapters()`.
- `lib/data/models.dart` — `Comic.copyWith()` sekarang bisa ubah `ch`
  juga (sebelumnya cuma unread/read/col/readChapters).
- `lib/features/updates/updates_screen.dart` — `_refresh()` sekarang
  nampilin toast sesuai hasil sungguhan (jumlah chapter baru/gagal
  diperiksa, bukan pesan generik). Tap row sekarang resolve ke komik
  ASLI dari Library (`_resolveComic`, pola sama seperti History) —
  sebelumnya `UpdateEntry.toComic()` bikin komik palsu dengan id `'u'`
  yang gak ada hubungannya sama data Library sungguhan.
- `docs/DATABASE.md` — dokumentasi skema `updates/{comicId}` baru.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — label tanggal/waktu dinamis kebukti benar (cocok
  dengan seed lama), refresh dengan komik demo (tanpa `sourceMangaUrl`)
  kasih toast jujur "belum ada komik dari sumber asli buat dicek", tap
  entri resolve ke komik ASLI dari Library (bukan stub palsu). Cek
  chapter baru sungguhan lewat parser tidak bisa dites live dari
  sandbox (jaringan ke situs sumber diblok) — perlu dicoba di HP asli
  dengan komik dari salah satu 4 sumber native.

### 2026-07-16 — Beres-beres TODO(backend) yang tersisa: Sync Now nyata, cabut toast diagnostik
User bilang "gas" (lanjut) tanpa target spesifik — disisir TODO(backend)
yang masih nyantol di kode, dua yang masuk akal buat diberesin sekarang:

- **`settings_screen.dart`** — tombol "Sinkronisasi & Cadangan" tadinya
  cuma toast palsu (delay 1.4 detik doang). Firestore sendiri sudah
  live-sync terus-menerus (docs/DATABASE.md), jadi satu-satunya "sync"
  sungguhan yang relevan buat tombol manual ini: (1) sentuh dokumen
  profil (`lastSyncAt`, lewat `SyncService` yang sama dipakai saat
  login), (2) cek chapter baru sungguhan untuk semua komik Library dari
  sumber asli (persis kerja `updatesProvider.refresh()` yang baru
  dibikin) — itu satu-satunya "tarik data baru dari luar" yang
  bermakna di arsitektur ini. Toast-nya sekarang kasih tau kalau ada
  chapter baru ketemu, bukan generik "selesai" doang.
- **`reader_screen.dart`** — toast diagnostik "Gagal simpan $what:
  $error" (ditambah sementara buat lacak bug "progres tidak
  ke-track") dicabut, balik ke silent-log. Root cause bug itu (orderBy
  + serverTimestamp) sudah ketemu & dibenerin beberapa putaran lalu,
  dan fitur-fitur belakangan (bookmark, tanda "Dibaca", Updates) semua
  udah terverifikasi jalan tanpa masalah simpan — nampilin pesan error
  Firestore mentah ke user bukan UX yang bagus buat kondisi normal.
- Sisa `TODO(backend)` yang SENGAJA tidak diutak-atik: retry parse di
  Source Detail (untuk sumber TANPA parser native — "retry" di situ
  memang selalu gagal karena betul-betul tidak ada logic buat
  nge-parse-nya, bukan bug), fetch index repository sungguhan (nilai
  gunanya terbatas — sebagian besar entri di index Tachiyomi/Mihon
  tetap gak bisa dipakai baca beneran tanpa parser native), unduhan
  chapter offline (fitur besar tersendiri, sengaja lokal-per-device
  per desain di docs/DATABASE.md).
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — tombol "Sinkronisasi & Cadangan" jalan tanpa error,
  toast "Sinkronisasi selesai" muncul benar (demo library tanpa
  `sourceMangaUrl` → 0 komik dicek, sesuai perilaku Updates refresh).

### 2026-07-16 — Fix akar: tombol "play" History jatuh ke mode demo/placeholder
User lapor tombol "play"/lanjut baca di History masih "template"
(halaman "PAGE N" placeholder), padahal seharusnya langsung buka
chapter asli komik yang bersangkutan.

Root cause: `history_screen.dart`'s `_resumeReading` push
`ReaderScreen(comic: comic, chapter: entry.chNum)` TANPA
`sourceChapters`/`initialChapterUrl` — dan `_isRealSource` di Reader
sebelumnya ditentukan murni dari "apakah `sourceChapters` diisi",
BUKAN dari komiknya sendiri (`comic.sourceMangaUrl`). Akibatnya, komik
yang jelas-jelas dari sumber asli tetap dianggap "bukan sumber asli"
kalau pemanggilnya (History, lewat play button) lupa fetch dulu daftar
chapternya — diam-diam jatuh ke mode demo/placeholder tanpa error
apa pun. Comic Detail tidak kena bug ini karena dia SELALU fetch
`_realChapters` duluan (initState-nya sendiri), tapi History tidak
pernah melakukan itu.

Daripada nambal cuma di `history_screen.dart` (rawan kejadian lagi di
pemanggil lain di masa depan), fix-nya di akar arsitekturnya:
- `reader_screen.dart` — `_isRealSource` sekarang berdasar
  `comic.sourceMangaUrl != null`, bukan `sourceChapters != null`.
  Ditambah `_chapters` (state internal, beda dari `widget.sourceChapters`
  yang cuma optional-optimization) + method baru `_loadChapterList()`:
  kalau komiknya dari sumber asli tapi `sourceChapters` tidak
  disediakan pemanggil, Reader fetch sendiri lewat
  `MangaSource.fetchChapterList`, lalu petakan `widget.chapter` (nomor
  chapter) balik ke index chapter yang tepat. Loading/error state buat
  proses ini digambar sama seperti loading/error halaman yang sudah
  ada (`_buildLoadError` — di-generalize dari `_buildPagesError`).
  Semua pemakaian `widget.sourceChapters!` lama diganti `_chapters`
  (dengan guard null di `_changeSourceChapter`/`_jumpToBookmark` biar
  tidak crash kalau di-tap pas daftar chapter belum selesai di-fetch).
- `history_screen.dart` — **tidak perlu diubah sama sekali**, karena
  fix-nya di level Reader: begitu Reader tahu `comic.sourceMangaUrl`
  ada isinya, dia otomatis fetch sendiri.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — komik demo (tanpa `sourceMangaUrl`) tetap benar
  pakai mode placeholder seperti sebelumnya (tidak regresi). Jalur
  komik sumber-asli-tanpa-sourceChapters tidak bisa dites live dari
  sandbox (jaringan ke situs sumber diblok, tapi logic-nya sudah benar
  secara struktural) — perlu dicoba langsung di HP dengan komik dari
  salah satu 4 sumber native yang dibuka lewat tombol play History.

### 2026-07-16 — Fix akar #2: nomor chapter History "loncat" (43/45/40 dst, tidak tetap)
Lanjutan langsung dari fix sebelumnya — user lapor History nunjukin
"Chapter 44", tapi tombol play kadang buka chapter 43/45/40, ganti-ganti
tiap dicoba.

Root cause: nomor chapter (`chNum`) di seluruh app itu **POSISI
relatif**, bukan identifier stabil — dihitung sebagai `total_chapter -
index` SAAT list itu di-fetch (lihat `comic_detail_screen.dart`'s
`_chaptersToShow`). Fix sebelumnya (`_loadChapterList`) motong nomor
itu balik ke index pakai rumus `chapters.length - widget.chapter` —
tapi rumus ini cuma valid kalau `chapters.length` SAMA PERSIS dengan
`total_chapter` yang dipakai waktu nomor itu pertama kali di-assign
(saat History pertama nyimpen `chNum`). Begitu situs sumbernya nambah
chapter baru di antara waktu History nyimpen posisi terakhir dan waktu
tombol play ditekan lagi (fetch baru, `chapters.length` beda dari yang
lama), rumus itu nunjuk ke chapter yang SALAH — geser sebanyak selisih
jumlah chapter baru yang terbit. Itu sebabnya angkanya "loncat-loncat"
tergantung berapa chapter baru yang kebetulan udah terbit tiap kali
dicoba.

- `history_state.dart` — `HistoryEntry` dapat field baru `chapterUrl`
  (nullable) — identifier STABIL (URL asli chapter), disimpan
  berdampingan dengan `chNum` (tetap disimpan buat label tampilan
  "Ch. N", tapi bukan lagi dipakai buat lompat balik).
  `upsert()` terima param `chapterUrl` baru.
- `bookmarks_state.dart` — `BookmarkEntry` + `toggle()` dapat field/
  param `chapterUrl` yang sama, alasan identik (bookmark juga simpan
  `chNum` posisional, kena bug yang sama kalau dipakai lintas sesi
  Reader yang beda fetch).
- `reader_screen.dart` — getter baru `_currentChapterUrl` (URL chapter
  yang lagi aktif), dikirim ke `historyProvider.upsert()` dan
  `bookmarksProvider.toggle()`. `_loadChapterList()` DAN
  `_jumpToBookmark()` sekarang cari chapter target via URL DULU (exact
  match, stabil terlepas dari panjang list berubah atau tidak) —
  rumus posisi lama cuma dipakai sebagai fallback buat entri
  lama yang belum punya `chapterUrl` tersimpan (dari sebelum fix ini).
- `history_screen.dart` — `_resumeReading` kirim
  `initialChapterUrl: entry.chapterUrl` ke `ReaderScreen`.
- `app_context_menu.dart` — `BookmarkListItem` dapat field `chapterUrl`
  buat diteruskan ke `_jumpToBookmark`.
- `docs/DATABASE.md` — dokumentasi field `chapterUrl` baru di
  `history` & `bookmarks`, sekalian catatan kenapa `chapter` (number)
  tidak stabil dipakai sendirian.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — komik demo (History play, toggle+lompat bookmark)
  tetap jalan normal tanpa regresi (fallback ke posisi lama karena
  `chapterUrl` null di data demo, sesuai desain). Skenario yang
  bener-bener nge-fix (chapter list situs berubah panjang antar sesi)
  butuh data real + waktu berlalu, gak bisa direproduksi dari sandbox
  — tapi root cause & fix-nya sudah jelas secara matematis/struktural.

### 2026-07-16 — Fix akar #3: History & Reader pakai DUA sistem penomoran chapter beda
User konfirmasi fix #2 membantu (entri lama masih meleset, entri baru
lumayan) tapi masih "kadang beda chapter" biar pun sudah baca ulang
pakai versi baru. Digali lebih dalam — ketemu akar masalah yang beda
dari dugaan awal, dan sudah ADA dari lama (bukan regresi baru).

Root cause: `chNum` yang ditampilkan History ("Ch. 4") itu POSISI hasil
hitungan APLIKASI SENDIRI (`total - index` saat fetch, lihat
`comic_detail_screen.dart`), BUKAN nomor chapter asli dari situs.
Sementara itu, tiap parser sumber (`shinigami_source.dart` dkk) SUDAH
nyimpen nomor/label asli dari situs di `SourceChapter.name` (mis. dari
`chapter_number` di API Shinigami, atau teks HTML asli di
MangaThemesia/Komiku) — tapi field ini cuma dipakai buat judul row di
Comic Detail, TIDAK PERNAH disimpan ke History. Begitu Reader dibuka
lewat "Lanjut Baca" dan berhasil nemu chapter yang PAS lewat
`chapterUrl` (fix #2, ini sudah benar — chapter yang kebuka memang
yang benar), Reader nampilin label ASLI situsnya (mis. "Chapter 3")
di toolbar atas — beda dari "Ch. 4" yang History tampilkan, karena
kalau komiknya punya chapter spesial/bonus/non-sekuensial di tengah
daftar (umum di situs-situs ini), hitungan posisi kita gampang geser
dari nomor asli situs. User ngeliat dua angka beda dan ngira "salah
buka chapter" — padahal kontennya sudah tepat, cuma LABEL yang
ditampilkan gak sinkron antar dua tempat.

- `history_state.dart` — `HistoryEntry` dapat field baru
  `chapterLabel` (nullable) — label chapter ASLI dari situs, sama
  seperti yang Reader tampilkan. `pageLabel` getter sekarang pakai ini
  duluan (`chapterLabel ?? 'Ch. $chNum'`), jadi History & Reader akan
  selalu nampilin label yang SAMA PERSIS. `upsert()` terima param baru.
- `reader_screen.dart` — `_saveProgress()` kirim `chapterLabel:
  _chapterLabel` (getter yang sama dipakai buat toolbar atas) ke
  `historyProvider.upsert()`.
- `docs/DATABASE.md` — dokumentasi field `chapterLabel` baru.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  smoke-test web — entri History yang baru disimpan pakai versi baru
  nampilin "Chapter 41" (label asli), entri lama (seed, belum punya
  `chapterLabel`) tetap fallback ke format "Ch. N" seperti sebelumnya
  — kompatibel mundur, tidak ada regresi.

### 2026-07-17 — Fix Updates gagal deteksi chapter baru + fitur auto-deteksi sumber custom

User lapor menu Updates gagal nampilin chapter baru padahal jelas-jelas
ada di situs sumbernya. Sekaligus minta dua hal lain: (1) status fitur
"tambah repository", dan (2) fitur biar app bisa "ngeget" (mengenali)
sumber komik apapun saat user nambah sumber custom sendiri, bukan cuma
4 situs bawaan.

**Fix Updates**: root cause SAMA PERSIS dengan fix akar #1/#3 di atas
(chapter number tidak stabil) tapi kena bagian deteksi, bukan tampilan.
`refresh()` lama bandingin `chapters.length > comic.ch` (jumlah mentah)
buat nentuin "ada update" — kalau situs punya chapter spesial/bonus
yang bikin hitungan geser TANPA nambah (atau pengurangan sementara),
chapter baru yang beneran ADA bisa gagal kedeteksi karena hitungannya
kebetulan sama/lebih kecil dari sebelumnya.

- `models.dart` — `Comic` dapat field baru `lastChapterUrl` (nullable) —
  URL chapter terbaru yang diketahui terakhir kali dicek/ditambah.
- `library_state.dart` — `applyNewChapters()` terima & simpan
  `lastChapterUrl`.
- `updates_state.dart` — `refresh()` sekarang bandingin
  `chapters.first.url` (chapter terbaru hasil fetch, identifier stabil)
  vs `comic.lastChapterUrl`, bukan jumlah mentah. Fallback ke
  perbandingan jumlah HANYA untuk komik lama yang belum punya
  `lastChapterUrl` (null). `UpdateEntry` juga dapat `chapterLabel`
  (label asli situs, sama pola dengan `HistoryEntry`) biar Updates dan
  History/Reader konsisten nampilin nomor yang sama.
- `comic_detail_screen.dart` — nyimpen `lastChapterUrl` (chapter
  terbaru saat itu) begitu komik pertama kali ditambah ke Library, jadi
  ada baseline buat deteksi Updates berikutnya.

**Fitur auto-deteksi sumber custom** ("ngeget semua jenis komik"):
app sudah punya 2 parser tema generik yang DIRANCANG buat kerja di
situs manapun yang pakai tema WordPress-manga umum tsb (MangaThemesia,
NatsuID) — sebelumnya cuma dipakai buat 2 dari 4 sumber bawaan
(Komikindo, Ikiru), padahal keduanya sudah menerima `name`/`baseUrl`
custom di constructor-nya. Manfaatkan itu: begitu user nambah sumber
custom, coba pasang tiap parser generik ke URL barunya dan panggil
`fetchPopular(1)` — kalau berhasil dapat hasil non-kosong, berarti
struktur situsnya cocok dan bisa dibaca native (bukan cuma WebView).

- `sources_state.dart` — `ComicSource` dapat field `parserKind`
  (nullable string) — hasil deteksi ("mangathemesia"/"natsuid"), null
  kalau tidak cocok satupun (tetap WebView-only).
- `source_catalog.dart` — `genericKinds`, `buildGeneric(kind, name,
  baseUrl)`, `detectGeneric(name, baseUrl)` (coba tiap kind, return
  kind pertama yang berhasil `fetchPopular` tanpa error & non-kosong).
- `source_resolver.dart` (baru) — `resolveMangaSource(sourceName,
  customSources)`: helper terpusat dipakai widget (`WidgetRef`) maupun
  Notifier (`Ref`) — coba 4 sumber native dulu, baru sumber custom yang
  punya `parserKind`. Diambil sebagai `List<ComicSource>` (bukan
  `Ref`/`WidgetRef` langsung) karena dua tipe itu beda di Riverpod dan
  tidak saling bisa dipakai gantian.
- `add_source_screen.dart` — tombol "Test Sumber" sekarang beneran coba
  `detectGeneric` kalau bukan salah satu dari 4 sumber bawaan (dulu
  cuma heuristik regex `error|fail|xxx` di URL, palsu). Hasil deteksi
  disimpan sebagai `parserKind` saat sumber disimpan; toast beda kalau
  terdeteksi ("struktur situs terdeteksi cocok · bisa dibaca otomatis").
- `comic_detail_screen.dart`, `reader_screen.dart`, `updates_state.dart`,
  `source_detail_screen.dart` — resolusi `MangaSource` buat Comic
  Detail, Reader, pengecekan Updates, dan grid discover Source Detail
  semuanya dialihkan lewat `resolveMangaSource`/`buildGeneric`, jadi
  sumber custom yang berhasil auto-detect bisa dipakai penuh (discover
  grid, baca chapter, cek update) — bukan cuma WebView pasif.
- `docs/DATABASE.md` — dokumentasi field `sources.parserKind` &
  `library.lastChapterUrl` baru.
- Repository ("tambah repository"): TIDAK diubah — sudah dijelaskan ke
  user sebelumnya kalau index repo Tachiyomi/Mihon-style isinya
  kebanyakan sumber yang butuh parser native per-situs (bukan generik),
  jadi kebanyakan entrinya tetap gak bisa langsung dibaca meski index-nya
  di-fetch beneran. Auto-deteksi tema generik di atas ini justru manfaat
  buat SEMUA jalur nambah sumber (manual maupun lewat repo), bukan cuma
  satu tempat, jadi prioritasnya di situ dulu.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos.
  Deteksi generik butuh network beneran ke situs sumber (tidak bisa
  direproduksi dari sandbox yang network-nya dibatasi) — tapi logika
  & pemanggilannya sudah diverifikasi lewat analyze/test yang cover
  parser MangaThemesia/NatsuID yang sudah ada testnya sendiri
  (`mangathemesia_source_test.dart`/`natsuid_source_test.dart`).

### 2026-07-17 — Setelan: hapus toggle Tema yang fake (Terang/Ikuti sistem)

User minta menu Setelan dibikin beneran jalan. Diaudit satu-satu: Reader
Settings, Sinkronisasi & Cadangan, Keluar, dan semua toggle demo state
ternyata sudah beneran berfungsi. Satu-satunya yang masih murni dekoratif
adalah baris "Tema" — sheet-nya nawarin pilihan "Gelap"/"Terang"/"Ikuti
sistem" tapi motong ke `ThemeModeLabel` doang (cuma nyimpen teks), TIDAK
pernah benar-benar ganti `ThemeMode`/`ColorScheme` aplikasi. Ditanya user:
implementasikan tema Terang sungguhan (kerjaan besar — `AppColors.xxx`
dipanggil sebagai konstanta statis langsung di puluhan file di seluruh
app, bukan lewat `Theme.of(context)`, jadi butuh refactor besar biar
warna ikut brightness aktif), atau jujurkan tampilannya jadi dark-only
tanpa pilihan palsu. User pilih opsi kedua.

- `settings_screen.dart` — baris "Tema" sekarang cuma nampilin teks statis
  "Gelap" tanpa `onTap`/chevron (bukan lagi tombol yang buka sheet
  pilihan) — gak ada lagi UI yang keliatan interaktif tapi sebenarnya
  gak ngefek apa-apa. `_openThemeSheet` (sheet pilihan tema) dihapus
  total, `_menuRow`'s `onTap` jadi nullable buat dukung baris info-only
  ini (InkWell otomatis non-interaktif kalau `onTap` null).
- `demo_state.dart` — `ThemeModeLabel`/`themeModeLabelProvider` dihapus
  (sudah tidak dipakai di manapun lagi).
- `app_theme.dart` — komentar diperbarui, dari "(TODO)" jadi penjelasan
  final: baris Tema di Settings sengaja cuma info, bukan pilihan.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos
  (`-j 1`, semua file test termasuk mangathemesia/natsuid ikut jalan),
  `flutter build web` sukses tanpa error kompilasi.

### 2026-07-17 — Setelan gaya Tachiyomi/Mihon: "Tentang" + edit nama koleksi

User minta menu Setelan diisi hal-hal ala Tachiyomi/Mihon yang relevan
buat fitur yang sudah dikembangkan: halaman "Tentang" (identitas
developer pakai nama GitHub, bukan nama generik prototipe), "Periksa
pembaruan" beneran (bukan simulasi), dan tombol edit nama koleksi di
"Kelola koleksi" (biar salah ketik nama koleksi nggak harus dihapus &
dibuat ulang).

**Halaman "Tentang"** (`lib/features/settings/about_screen.dart`, baru):
- Identitas: logo Kizen, versi (dari `pubspec.yaml`: 1.0.0 build 1),
  kredit developer "Reiky Aryanando Pratama · @reiky03" (dikonfirmasi
  lewat GitHub API `get_me` — bukan tebakan) yang tap-nya buka
  `github.com/reiky03`, dan "Kode sumber" yang buka
  `github.com/reiky03/Aplikasi_Comic`.
- "Periksa pembaruan": `lib/data/app_update_checker.dart` (baru) —
  `checkForAppUpdate()` betulan hit endpoint publik GitHub Releases
  (`/repos/reiky03/Aplikasi_Comic/releases/latest`, tanpa token) dan
  bandingkan tag rilis vs versi terpasang secara numerik per segmen
  (bukan string compare, biar "1.10.0" > "1.2.0" kebaca benar). Repo ini
  belum ada rilis publik saat ini — dicek jujur (404 → "Belum ada rilis
  publik", bukan diam-diam dianggap "sudah terbaru"). Semua kegagalan
  (offline, timeout, format tak terduga) ditangkap & dikasih pesan,
  tidak pernah crash.
- `_openUrl` awalnya TIDAK bungkus `launchUrl` dengan try/catch — ketauan
  lewat smoke-test: di web headless (popup diblokir) `launchUrl`
  nge-throw dan jadi unhandled exception (tidak crash UI, tapi tetap
  bug nyata — di device asli bisa kejadian serupa kalau tidak ada
  browser/app yang bisa handle link). Dibungkus try/catch, fallback ke
  toast "Gagal membuka link".
- `pubspec.yaml` — tambah dependency `url_launcher`. `AndroidManifest.xml`
  — tambah `<queries>` intent VIEW/https biar `url_launcher` bisa cek
  browser yang tersedia di Android 11+.
- `settings_screen.dart` — row baru "Tentang" di card "Aplikasi", push
  ke `AboutScreen`.

**Edit nama koleksi** (`collection_sheets.dart`, `library_state.dart`):
- `CollectionsNotifier.rename(id, newName)` — baru, symmetric sama
  `create`/`delete`.
- `SheetCollection` dapat field `id` (sebelumnya sheet-sheet koleksi
  cuma pegang `name` buat identitas — `onPick`/`onDelete` resolve balik
  ke id lewat `collections.firstWhere((c) => c.name == name)`, rapuh
  kalau ada nama kembar atau baru diganti nama di sesi yang sama).
  Semua callback (`onPick`, `onDelete`) diganti pakai `id` langsung,
  bukan `name` — perbaikan sekalian, bukan cuma buat rename.
  `onCreate` diganti jadi `Future<String> Function(String name)` (balikin
  id asli dari notifier) supaya row yang baru dibuat di sheet "Kelola
  koleksi" langsung punya id yang benar buat di-rename/dihapus tanpa
  perlu tutup-buka sheet dulu.
- Tombol pensil baru di tiap row "Kelola koleksi" (di sebelah tombol
  hapus) → `_showRenameSheet` (sheet baru, field pre-filled nama
  sekarang + tombol Batal/Simpan) → update `_items` lokal + panggil
  `onRename(id, newName)`.
- `library_screen.dart`, `comic_detail_screen.dart` — pemanggil
  `SheetCollection`/`showCollectionPickerSheet`/`showManageCollectionsSheet`
  disesuaikan ke id-based.
- Diverifikasi lewat smoke-test web (FAKE_AUTH, headless Chromium
  `--no-web-resources-cdn` + `--enable-unsafe-swiftshader` biar CanvasKit
  jalan tanpa GPU asli): buka Setelan → Tentang → nama/link developer
  tampil benar, "Periksa pembaruan" gagal dengan pesan yang masuk akal
  (jaringan sandbox diblok proxy, bukan crash) setelah fix try/catch.
  Kelola koleksi → tap pensil di "Sedang Dibaca" → ganti jadi "Favorit
  Banget" → tersimpan & toast konfirmasi muncul → chip filter di Library
  ikut ke-update ke nama baru secara live (listener Firestore/demo-state).
- `flutter analyze` bersih, `flutter test` 18/18 lolos, `flutter build
  web` sukses.

### 2026-07-17 — Fix crash saat edit nama koleksi (`_dependents.isEmpty`)

User coba fitur edit nama koleksi yang baru ditambah di atas dan langsung
kena red screen: `'package:flutter/src/widgets/framework.dart': Failed
assertion: line 6268 pos 12: '_dependents.isEmpty': is not true`.

Root cause: `_showRenameSheet` (implementasi awal) buka sheet BARU
(`showModalBottomSheet` lewat `showAppSheet`) DI ATAS sheet "Kelola
koleksi" yang sudah terbuka — nested modal route. Sheet rename itu
punya `TextField` yang dapat fokus (keyboard kebuka, `AnimatedPadding`
di `AppSheetShell` ikut animasi buat keyboard inset-nya). Begitu tombol
"Simpan" ditekan SELAGI keyboard masih kebuka, `Navigator.pop` nutup
sheet rename itu SAAT keyboard-close-animation & pop-route-animation
jalan bersamaan — race itu yang bikin assertion `_dependents.isEmpty`
di `InheritedElement.unmount()` gagal (elemen yang lagi di-unmount masih
punya dependent — `TextField`/`MediaQuery` terkait keyboard — yang
belum sempat "lepas" dengan benar sebelum elemen induknya dibongkar).
Pola serupa (bukan identik) sudah pernah kejadian & di-dokumentasikan
di fix tombol "Buat" sebelumnya (`FocusScope.of` vs `primaryFocus`),
tapi kali ini akarnya beda: bukan soal salah API unfocus, tapi soal
NESTED ROUTE + keyboard + pop yang barengan.

Fix (bukan sekadar nambah `unfocus()` sebelum `pop` — itu race
condition, tidak dijamin selesai sebelum pop jalan): buang nested sheet
sama sekali. `_ManageCollectionsBodyState` sekarang punya state
`_editing`/`_editController` — tombol pensil GANTI ISI sheet yang SAMA
di tempat (`_buildRenameView()`) alih-alih buka sheet kedua. Tidak ada
route/`AnimatedPadding` kedua yang bisa bentrok sama sekali, karena
cuma ada SATU sheet route dari awal sampai akhir. "Batal"/"Simpan"
tinggal `setState` balik ke `_editing = null`, tanpa `Navigator.pop`.

- `collection_sheets.dart` — `_showRenameSheet` (fungsi terpisah, sheet
  bersarang) dihapus total, diganti `_startRename`/`_cancelRename`/
  `_saveRename`/`_buildRenameView` di dalam `_ManageCollectionsBodyState`.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  `flutter build web` sukses. Smoke-test web (FAKE_AUTH, headless)
  ulang skenario yang sama persis yang bikin user kena crash (edit
  teks TANPA nutup keyboard dulu, langsung tekan Simpan) — sekarang
  lolos tanpa page error, rename tersimpan & chip Library ke-update.
  Dites juga alur Batal (kembali ke list tanpa perubahan) — normal.

### 2026-07-17 — Audit performa scroll (list chapter/komik/sumber)

User lapor "patah-patah" pas scroll list chapter, list komik, list
sumber, minta diaudit menyeluruh sesuai standar profesional. Diaudit
semua layar dengan list/grid besar:

**Sudah benar dari awal** (tidak diubah): semua list/grid besar SUDAH
pakai lazy loading (`GridView.builder`/`ListView.builder`/
`SliverChildBuilderDelegate`) — Library, Discover, History, Updates,
daftar chapter Comic Detail. `_onScroll` di Reader sudah di-throttle ke
1x per frame lewat `addPostFrameCallback` (fix sesi sebelumnya, ada
catatan soal ini di kode). List yang masih pakai `ListView` eager
(Sumber Saya, chip koleksi, form) semuanya berukuran kecil (puluhan
item paling banyak) — tidak relevan buat kasus lag ini.

**Ketemu & diperbaiki**:
1. `comic_cover_content.dart` — `Image.network` buat cover komik TIDAK
   punya `cacheWidth`, jadi Flutter decode gambar di RESOLUSI ASLI-nya
   biar pun cuma ditampilin ~110px di grid — boros CPU/GPU/memory kalau
   banyak cover baru discroll sekaligus. `reader_screen.dart` (halaman
   baca) sudah benar dari awal (ada `cacheWidth` + `RepaintBoundary` +
   catatan soal 120Hz), tapi grid Library/Discover ketinggalan. Sekarang
   3 pemanggil (`ComicGridCard`, `_DiscoverCard`, hero cover Comic
   Detail) hitung `cacheWidth` dari ukuran sel/tampil x
   `devicePixelRatio`, bukan biarin default (decode native res).
2. `ComicGridCard` & `_DiscoverCard` (kartu grid Library/Discover) —
   dibungkus `RepaintBoundary` di level cover — kartu yang sudah
   dirender bisa di-translate murah pas scroll (dari layer cache),
   bukan di-rasterisasi ulang tiap frame (gradient + shadow + gambar).
3. **Tidak ada `key` di 5 list `.builder`**: `ComicGridCard` (Library),
   `_DiscoverCard` (Discover), `_HistoryRow` (History), `_ChapterRow`
   (Comic Detail — bisa dibalik urutannya lewat toggle sort), `_UpdateRow`
   (Updates — item baru bisa nyelip di depan). Tanpa `key`, Flutter
   nyocokin widget lama/baru cuma berdasarkan POSISI, bukan identitas —
   pas urutan berubah (ganti sort, item baru masuk), state per-item
   (termasuk cache gambar yang baru didecode) bisa "ketuker" antar row
   dan micu rebuild/layout ulang yang harusnya gak perlu. Semua sekarang
   pakai `ValueKey` dari id stabil (`comic.id`/`entry.comicId`/
   `chapter.num`).

**Bukan soal kode — soal cara testing**: sepanjang sesi ini kamu selalu
test lewat `flutter run` (mode debug/JIT) — mode ini SELALU jauh lebih
lambat/patah dari build asli (banyak assertion tambahan, gak ada AOT
compile, gak ada tree-shaking) — ini standar/dikenal luas di Flutter,
bukan indikasi bug. Buat ngerasain performa yang SEBENARNYA, coba jalanin
`flutter run --profile -d 2A311FDH300122` (lebih dekat ke rilis, tapi
masih bisa di-profile) atau install APK release
(`flutter build apk --release` lalu install manual). Kalau masih
kerasa patah di situ, baru itu sinyal ada masalah nyata yang perlu
digali lebih lanjut.

- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  `flutter build web` sukses, smoke-test web — grid Library & daftar
  chapter Comic Detail tampil identik (tidak ada regresi visual dari
  `RepaintBoundary`/`cacheWidth`). Perbaikan `cacheWidth`/`RepaintBoundary`
  butuh gambar cover ASLI (network) buat kerasa efeknya — data demo
  di sandbox ini semua pakai gradient placeholder (tanpa `coverUrl`),
  jadi dampak nyatanya baru kelihatan begitu ada sumber yang benar-benar
  ngasih `coverUrl` (situs real, bukan demo) — tapi kode & logikanya
  sudah benar secara struktural, konsisten sama pola yang sudah terbukti
  jalan di Reader.

### 2026-07-17 — Fix progres baca: gak kesimpan, kesimpan salah, "sudah tamat" gak kedetek

User lapor 3 bug soal progres baca di Reader: (1) beberapa komik gagal
kesimpan progresnya, (2) kadang kesimpan tapi begitu coba chapter lain
angka "hal X/Y"-nya keganti jadi salah, (3) baca sampai tamat tapi
counter/slider di reader belum nunjuk halaman terakhir, jadi keluar
chapter-nya gak ketandain "sudah dibaca". Digali `reader_screen.dart`
menyeluruh (bukan cuma baca sepintas) + smoke-test berulang buat
mereproduksi — ketemu 4 akar masalah beda, semuanya di seputar mekanisme
simpan progres yang di-debounce 2 detik:

1. **Progres chapter lama ketiban chapter baru** (akar bug #2): cuma ADA
   SATU `Timer` debounce buat seluruh sesi baca. Kalau user pindah
   chapter SEBELUM debounce chapter lama (2 detik) sempat jalan,
   `_scheduleProgressSave()` yang dipanggil abis pindah nge-`cancel()`
   timer lama itu TANPA PERNAH nyimpennya — progres chapter yang lagi
   ditinggalkan hilang begitu saja, ketiban timer baru yang nyimpen data
   chapter BARU begitu jalan.
2. **"pages" kesimpan salah kalau ganti chapter pas sumbernya lambat**
   (akar bug #1 & #2): `_totalPages` jatuh ke nilai MOCK (8) selama
   halaman asli suatu chapter masih di-fetch. Kalau debounce 2 detik
   sempat jalan SEBELUM fetch beres (situs lambat), yang kesimpan ke
   History itu `pages: 8` (salah), bukan angka asli (mis. 24).
3. **"Sudah tamat" gak kedetek kalau langsung tap Next/footer**: tanda
   chapter selesai cuma jalan kalau `_page` sempat "sadar" sudah di
   halaman terakhir lewat listener scroll (`_computeCurrentPage`,
   dipicu `addPostFrameCallback` — async). Kalau user langsung tap
   tombol Next atau footer "Akhir chapter" TEPAT sebelum listener itu
   sempat jalan, `markChapterRead` tidak pernah terpanggil buat chapter
   yang sebenarnya sudah tamat dibaca.
4. **`ref` dipakai di `dispose()`** (ke-reproduksi lewat smoke-test,
   root cause KONKRET buat "beberapa komik gak bisa kesimpan"): kode
   lama manggil `ref.read(historyProvider.notifier)`/
   `ref.read(libraryProvider.notifier)` di `_saveProgress()`, yang juga
   dipanggil dari `dispose()` (nyimpen progres terakhir pas Reader
   ditutup). Riverpod nolak pemakaian `ref` begitu widget "about to or
   has been unmounted" — persis pas KELUAR chapter (kesempatan terakhir
   nyimpen) jadi momen paling rawan exception ini, bikin simpanan
   terakhir GAGAL diam-diam.

Fix:
- `_leavingChapter()` (baru) — dipanggil SEBELUM state chapter/halaman
  berubah (`_changeChapter`, `_changeSourceChapter`, `_jumpToBookmark`):
  cek ulang posisi scroll sekarang (`_computeCurrentPage()`, nangkep
  kasus #3) lalu flush SEKARANG progres yang masih nunggu di debounce
  (`_flushPendingSave()`, nangkep kasus #1) — sebelum apa pun soal
  chapter baru disentuh.
- `_saveProgress()` — tambah guard di awal: kalau masih fetch daftar
  chapter/halaman asli (`!_pageCountKnown`) DAN belum ada error permanen,
  reschedule lagi (bukan simpan pakai mock, bukan drop) — nangkep
  kasus #2.
- `_historyNotifier`/`_libraryNotifier` — diambil SEKALI di `initState`
  (`ref.read(...)`) dan disimpan sebagai field, dipakai ulang di
  `_saveProgress()` alih-alih `ref.read(...)` fresh tiap kali — provider-
  nya sendiri hidup sepanjang sesi app (bukan `.autoDispose`), jadi aman
  dipanggil kapan saja termasuk dari `dispose()` — nangkep kasus #4.
- Sekalian ketemu (efek samping investigasi ini, bukan salah satu dari 3
  yang dilaporkan tapi di titik kode yang sama): `WakelockPlus.enable()`/
  `.disable()` di `_applyWakelock()` & `dispose()` tidak pernah
  ditangkap errornya — kalau API wake-lock platform nolak (izin, device
  tertentu), jadi unhandled Future rejection. Dibungkus `.catchError`.
- Diverifikasi: `flutter analyze` bersih, `flutter test` 18/18 lolos,
  `flutter build web` sukses. Smoke-test web berulang (headless,
  FAKE_AUTH) — reproduksi persis skenario "ganti chapter cepat berkali-
  kali" (yang sebelumnya micu exception `ref` tak tertangani DAN unhandled
  wakelock rejection, keduanya kekonfirmasi lewat stack trace) — sekarang
  bersih tanpa satu pun page/console error, chapter berpindah normal
  sampai mentok "Sudah chapter terakhir" tanpa crash.

### 2026-07-17 — Fix progress parsial per-chapter tidak boleh saling overwrite

User tes di Pixel 7 Pro profile mode: performa jauh lebih lancar daripada
debug, tapi bug progres masih terasa secara spesifik: baca chapter 300
berhenti di "Hal 3/16", lalu baca chapter 298 berhenti di "Hal 4/16" —
tanda chapter 300 hilang dan pindah ke chapter 298.

Root cause: desain data sebelumnya memang cuma punya **satu** posisi aktif
per komik (`history/{comicId}`) untuk "Lanjut Baca". Comic Detail juga
menampilkan label progress parsial dari `history` itu saja. Jadi saat
chapter 298 jadi posisi terakhir, label parsial chapter 300 pasti hilang.
Ini bukan bug debounce/debug lagi, tapi kebutuhan data baru: progress
parsial harus disimpan **per chapter**, sementara History tetap satu posisi
terakhir.

- `models.dart` — tambah `ChapterProgress` + field
  `Comic.chapterProgress` (`Map<int, ChapterProgress>`), diserialisasi ke
  Firestore sebagai map string-keyed: `chapterProgress: {"300":
  {page,pages,chapterUrl,chapterLabel}}`.
- `library_state.dart` — `updateProgress()` sekarang menerima
  `page/pages/chapterUrl/chapterLabel` dan menyimpan progress untuk chapter
  yang sedang dibaca tanpa menghapus progress chapter lain. `markChapterRead`
  menghapus progress parsial chapter yang sudah tamat dan tetap menandainya
  di `readChapters`.
- `comic_detail_screen.dart` — row chapter sekarang membaca label
  "Hal X/Y" dari `Comic.chapterProgress` untuk semua chapter, dengan
  `history` hanya sebagai fallback/posisi terakhir. Jadi chapter 300 dan
  298 bisa sama-sama punya progress parsial.
- `reader_screen.dart` — `_saveProgress()` meneruskan data halaman+label ke
  `LibraryNotifier.updateProgress()`.
- `docs/DATABASE.md` — dokumentasi field `library.chapterProgress`.

Perlu verifikasi di HP asli: ulang skenario chapter 300 → chapter 298 →
kembali ke Comic Detail, kedua label parsial harus tetap tampil masing-masing
selama chapter belum tamat dibaca.

### 2026-07-17 — Tambah dukungan sumber: Asura + Luvyaa alias + WordPress date format

User minta sumber custom di Jelajahi lebih leluasa, karena Asura Scans hanya
jatuh ke WebView, Luvyaa gagal load chapter, dan Comick juga gagal.

- Status push: perubahan masih lokal, belum di-push ke branch Claude.
- `lib/sources/asura_source.dart` (baru) — parser native Asura Scans modern:
  search lewat `https://api.asurascans.com/api/search`, chapter list lewat
  `https://api.asurascans.com/api/series/{slug-hash}/chapters`, detail dan
  halaman chapter dari props SSR Astro di HTML. Halaman image Asura sudah
  kebaca dari `pages` props.
- `source_catalog.dart` — Asura masuk built-in source. Luvyaa juga masuk
  built-in sebagai `MangaThemesiaSource(name: 'Luvyaa',
  baseUrl: 'https://v4.luvyaa.co')`, plus alias URL `luvyaa.my.id`,
  `luvyaa.co`, `v4.luvyaa.co`. Jadi kalau user mengetik launcher
  `luvyaa.my.id`, app tetap resolve ke host baca sebenarnya.
- `mangathemesia_source.dart` — parser tanggal chapter ditambah format
  `dd/MM/yyyy` (contoh Luvyaa `14/07/2026`), selain format lama
  `MMMM dd, yyyy`.
- `test/sources/asura_source_test.dart` (baru) — fixture mock untuk search,
  detail props Astro, chapter API, dan pages props Astro.
- `test/sources/mangathemesia_source_test.dart` — tambah cakupan format
  tanggal numerik.
- Comick: belum ditambah native reading. Saat dicek, `comick.dev` kena
  Cloudflare challenge dari request non-browser dan status komunitasnya kini
  cenderung tracking/wiki, bukan host baca langsung. Untuk Comick masih
  fallback WebView sampai ada endpoint/API reader yang stabil dan accessible.
- Diverifikasi: `flutter analyze lib test` bersih, `flutter test` 22/22 lolos.

Follow-up tes HP:
- Asura: sebagian gambar sudah kebaca tapi agak buram. Penyebabnya cap decode
  sebelumnya terlalu konservatif untuk strip webtoon panjang. Reader sekarang
  tetap memakai DPR penuh selama tinggi bitmap aman, lalu cap tinggi decode di
  ~12k px agar tidak melewati batas GPU Android.
- Asura: beberapa chapter gagal. URL chapter sekarang memakai `slug` dari API
  Asura kalau tersedia (bukan selalu `number`), karena route slug juga valid dan
  lebih tahan untuk chapter special/numbering aneh.
- Luvyaa: `v4.luvyaa.co` saat dicek mengembalikan Redis error, sementara
  `luvyaa.my.id` kena Cloudflare JS challenge untuk request native Dart. Base
  Luvyaa dikembalikan ke `https://luvyaa.my.id`, tapi parser sekarang mendeteksi
  challenge/Redis dan menampilkan error yang jelas alih-alih jatuh ke template.
- MangaThemesia/Luvyaa: page parser sekarang membuang URL gambar placeholder
  (`data:`, `placeholder`, `loading`, `blank`) dan melempar error kalau tidak
  ada gambar asli, supaya Reader tidak menampilkan halaman template palsu.
- Source Detail: source tanpa parser native/generic tidak lagi menampilkan dummy
  discover/reader walau status dokumen `normal`; fallback-nya WebView/error.
- Diverifikasi ulang: `flutter analyze lib test` bersih, `flutter test` 22/22
  lolos.

Correction: forced `AspectRatio` di webtoon page ternyata bikin gambar Asura
terpotong saat metadata page kosong/meleset. Reverted: setelah image berhasil
load, tinggi layout kembali mengikuti tinggi asli `Image.network` + `fitWidth`
(cara aman yang sudah pernah diperbaiki). Placeholder loading saja yang tetap
punya rasio sementara. Luvyaa dicabut dari built-in parser karena host aktifnya
antara 500 Redis (`v4.luvyaa.co`) atau Cloudflare JS challenge (`luvyaa.my.id`);
sementara fallback yang benar adalah WebView, bukan native parser 404/template.

Follow-up iQOO 120Hz: reader webtoon masih bisa nyendat saat gambar besar baru
ter-decode. Ditambah controlled precache untuk halaman sekitar posisi aktif
(`current-1..current+2`) memakai `NetworkImage` + headers + `cacheWidth` yang
sama dengan `Image.network`, supaya scroll berikutnya tidak selalu decode
dadakan. Luvyaa lama yang masih punya `parserKind: mangathemesia` juga diblok
di `SourceCatalog.buildGeneric()` untuk host `luvyaa.*`, jadi tidak lagi
memaksa parser generik/template; fallback WebView.

### 2026-07-17 — Universal HTML parser untuk sumber baru

User menegaskan niat awal app: user bisa menaruh URL web komik baru dan app
harus mencoba banyak metode otomatis, bukan selalu perlu parser per-web manual.

- Tambah `UniversalHtmlSource`: fallback generic yang mencoba banyak pola HTML
  umum sekaligus untuk listing komik, detail, daftar chapter, dan gambar reader
  (`MangaThemesia`/WordPress-like, Madara-like, selector reader umum seperti
  `#readerarea`, `.reading-content`, `.chapter-content`, `.entry-content`, dan
  regex URL gambar di script).
- `SourceCatalog.genericKinds` sekarang mencoba `mangathemesia`, `natsuid`,
  lalu `universal-html`. Jadi Add Source punya pipeline auto-detection yang
  lebih luas sebelum fallback WebView.
- `AddSourceScreen._saveSource()` sekarang auto-detect generic parser saat user
  langsung menekan Simpan tanpa menekan Test Sumber. Jadi flow lebih dekat ke
  "paste URL → simpan → kalau struktur dikenali langsung kebaca".
- Tetap ada batas: Cloudflare JS challenge, Redis/server error, login, dan web
  yang render penuh via JS browser tidak bisa diekstrak native HTTP; untuk itu
  fallback-nya WebView.
- Tambah `test/sources/universal_html_source_test.dart`.
- Diverifikasi: `flutter analyze lib test` bersih, `flutter test` 26/26 lolos.

### 2026-07-17 — Repository Tachiyomi/Keiyoushi/Yuzono mulai dibaca sungguhan

User memberi contoh repo:
- `https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json`
- `https://raw.githubusercontent.com/yuzono/manga-repo/repo/index.min.json`

Temuan: formatnya array extension Tachiyomi-style. Tiap item punya `pkg`,
`apk`, `lang`, `version`, dan `sources[]` berisi `name`, `lang`, `id`,
`baseUrl`. Ini metadata extension APK, bukan parser yang bisa langsung
dieksekusi Dart/Flutter.

- `repository_state.dart` sekarang punya `fetchRepositoryIndex()` untuk fetch
  dan parse index Tachiyomi-style. Source diflatten ke `RepoSource` dengan
  `baseUrl`, `pkg`, `apk`, `version`, dan fallback `parserKind:
  universal-html`.
- `RepoSource` menyimpan metadata extension tambahan ke Firestore.
- Add/Edit Repository tidak lagi dummy. Tombol `Periksa Repository` benar-benar
  fetch URL index, menampilkan preview, dan simpan sumber asli. Jika user
  langsung menekan Tambah Repository, app tetap coba fetch dulu.
- Repo Browse membuka source repo memakai `baseUrl` source, bukan URL index
  repo. Karena APK extension belum dieksekusi, source repo dicoba lewat
  `UniversalHtmlSource`; kalau struktur situsnya custom/Cloudflare/JS-only,
  tetap butuh port parser atau engine extension beneran.
- Tambah bahasa `ALL` untuk source multi-language dari repo Tachiyomi.
- Tambah `test/data/repository_state_test.dart`.

### 2026-07-17 — Fondasi Android Extension Runtime

User menanyakan kenapa Tachimanga di iOS bisa mendukung extension ala
Tachiyomi. Klarifikasi: artinya bukan APK Android dijalankan langsung di iOS,
tapi ada compatibility/runtime layer yang memahami kontrak extension.

Implementasi awal:
- `android/app/src/main/kotlin/.../MainActivity.kt` sekarang register
  `ExtensionRuntimeBridge`.
- `android/app/src/main/kotlin/.../extensions/ExtensionRuntimeBridge.kt`
  menambah `MethodChannel` `kizen/extension_runtime`.
- Method native tahap awal:
  - `runtimeInfo`
  - `listInstalledExtensions`
- `AndroidManifest.xml` menambah `QUERY_ALL_PACKAGES` agar runtime bisa melihat
  APK extension Tachiyomi/Mihon yang sudah terpasang di device (perlu direview
  ulang jika target distribusi Play Store).
- `lib/data/extension_runtime.dart` menambah wrapper Dart dan model runtime.
- `settings_screen.dart` menambah row `Extension Runtime` di Setelan → Library
  & Sumber untuk sanity check native bridge dari HP.
- `test/data/extension_runtime_test.dart` menambah test kontrak channel.
- `docs/EXTENSION_RUNTIME.md` mencatat desain/roadmap menuju DexClassLoader +
  compatibility layer Tachiyomi.

Catatan penting: tahap ini belum menjalankan parser Kotlin dari APK extension.
Capability `apkClassLoading`, `tachiyomiSourceApi`, `tachiyomiSourceFactory`,
dan `networkBridge` sengaja dilaporkan `false` sampai runtime beneran dibuat.

### 2026-07-17 — Pencarian Repository + WebView fallback untuk source repo

User minta isi Repository enak dicari seperti `Sumber Saya`, dan source dari
repository/custom tidak mentok kalau parser otomatis gagal.

- `repo_browse_tab.dart` sekarang stateful dan punya search field di bagian
  atas tab Repository. Filter mencari dari nama source, nama repo, `baseUrl`,
  dan package extension (`pkg`). Hasil tetap dikelompokkan per bahasa aktif.
- Bookmark repository juga ikut terfilter sesuai query.
- `SourceDetailScreen` meneruskan `fallbackSource` ke `WebViewScreen`.
- `WebViewScreen` sekarang bisa membuka source sintetis dari Repository (yang
  belum ada di `sourcesProvider`) memakai URL asli source. Ini memperbaiki
  kasus tombol WebView dari source repo membuka `about:blank`.
- URL WebView sekarang aman untuk source yang sudah menyimpan `http(s)://`
  maupun yang hanya menyimpan domain.

Catatan: ini membuat semua source punya jalur buka website asli, tapi tidak
berarti semua website otomatis bisa di-parse native. Website yang Cloudflare,
login-only, atau full JS tetap perlu WebView/session atau runtime extension
yang lebih dalam.

### 2026-07-17 — DexClassLoader POC untuk extension Tachiyomi/Mihon

User minta lanjut supaya source dari Repository dan `Sumber Saya` makin dekat
ke cara Tachiyomi/Tachimanga. Implementasi kali ini mulai masuk runtime native:

- Menarik dan inspect APK Komiku dari Pixel. Manifest extension punya metadata
  `tachiyomi.extension.class = .ExtensionGenerated`, jadi runtime tidak perlu
  menebak entrypoint.
- Tambah dependency Android:
  - `okhttp`
  - `jsoup`
- Tambah compatibility stub minimal API Tachiyomi:
  - `eu.kanade.tachiyomi.network.NetworkHelper`
  - `Source`, `SourceFactory`
  - `HttpSource`
  - `SManga`, `SChapter`, `Page`, `MangasPage`, `Filter`, `FilterList`
- `ExtensionRuntimeBridge` sekarang punya:
  - `inspectExtension(packageName)` — load APK via `DexClassLoader`, instantiate
    class dari metadata, lalu baca `name/baseUrl/lang/id`.
  - `fetchPopularFromExtension(packageName, page)` — jalankan
    `popularMangaRequest`, eksekusi OkHttp, lalu panggil `popularMangaParse`
    dari class extension.
- `ExtensionRuntimeBridge.runtimeInfo()` sekarang melaporkan
  `apkClassLoading`, `tachiyomiSourceApi`, dan `networkBridge` sebagai aktif.
- `lib/data/extension_runtime.dart` menambah model Dart untuk source info dan
  hasil manga extension.
- Tombol Setelan → `Extension Runtime` sekarang mencoba load extension Komiku
  (atau extension pertama yang tersedia) dan fetch daftar populer sebagai sanity
  check.

Catatan: ini masih POC. Belum ada wrapper `MangaSource` Dart yang memakai
runtime ini untuk semua source repository, dan belum ada method details/chapter/
pages. Langkah berikutnya adalah membungkus method runtime ini jadi source
Flutter sungguhan, lalu tambah `fetchSearch`, `fetchMangaDetails`,
`fetchChapterList`, dan `fetchPageList`.
- Diverifikasi: `flutter analyze lib test` bersih, `flutter test` 27/27 lolos.

Follow-up dari tes HP: kalau Asura/Luvyaa sudah pernah disimpan ketika masih
belum didukung, dokumen source di Firestore tetap punya status `webview`.
Sebelumnya `SourceDetailScreen` tetap memblokir tampilan parser berdasarkan
status lama itu, jadi perubahan parser baru tidak kelihatan di HP. Sudah
diubah: bila URL source match parser native/generic, layar detail langsung
memakai automatic reader meskipun status lama masih `webview`. `AddSource`
juga sekarang menyimpan built-in source sebagai `normal` walaupun tombol test
sempat gagal.

### 2026-07-17 — Polish Jelajahi/Settings + stabilisasi Reader Asura

Follow-up tes HP: Asura sudah bisa kebuka, tapi sebagian chapter gagal dan
sebagian gambar terlihat placeholder/terpotong. Sekalian user minta edit
sumber di Jelajahi, urut daftar sumber, Settings tidak lagi berisi demo
state, serta History/Updates pakai cover asli.

- `SourcePage` sekarang bisa membawa `width`, `height`, dan `headers`.
  `AsuraSource.fetchPageList()` mengisi metadata ini dari props Astro dan
  menambahkan header `Referer`/`User-Agent` untuk request image CDN.
- `AsuraSource.fetchChapterList()` menyembunyikan chapter locked/premium
  dari daftar native supaya tidak muncul sebagai chapter yang pasti gagal.
  Kalau halaman Asura tidak punya pages, error-nya sekarang jelas.
- `ReaderScreen` memakai aspect ratio asli halaman source dan menurunkan
  `cacheWidth` untuk strip webtoon sangat panjang supaya bitmap tidak
  melewati batas GPU Android (akar kemungkinan gambar Asura tampak
  kepotong/placeholder di Pixel).
- `AddSourceScreen` bisa dipakai sebagai Edit Source. Long-press sumber di
  Jelajahi → `Edit sumber` sekarang membuka form edit dan menyimpan ke
  Firestore lewat `SourcesNotifier.update()`.
- Daftar `Sumber Saya` di Jelajahi diurutkan alfabetis berdasarkan nama.
- Settings: section `Demo state (prototype)` diganti jadi `Library &
  Sumber` dengan aksi `Periksa Update Chapter` dan `Bersihkan History`.
- `history/{comicId}` dan `updates/{comicId}` sekarang menyimpan `coverUrl`.
  Layar History/Updates juga fallback ke cover dari Library untuk entri lama.
- Diverifikasi: `flutter analyze lib test` bersih, `flutter test` 22/22 lolos.

### 2026-07-18 — Audit Omega Scans repo: blokir jaringan + stub rateLimit

User melaporkan Omega Scans dari repository tidak bisa dibuka lagi. Dicek di
iQOO:
- APK extension Omega terpasang dan sudah versi repo terbaru
  (`eu.kanade.tachiyomi.extension.en.omegascans` v1.4.50).
- Index Keiyoushi/Yuzono masih menunjuk `https://omegascans.org`.
- Dari HP, `curl https://omegascans.org` gagal TLS hostname mismatch; saat
  dipaksa `-k`, responsnya halaman `internetbaik.telkomsel.com`, bukan situs
  Omega. Jadi akar kegagalan saat ini adalah jaringan/DNS/filter belum lewat
  VPN/default network yang benar.
- Screenshot app juga sudah menampilkan
  `CERTIFICATE_VERIFY_FAILED: Hostname mismatch`, jadi source jatuh sebelum
  bisa memuat daftar komik.

Fix aditif supaya Omega siap jalan saat jaringan sudah lolos:
- `android/app/src/main/kotlin/keiyoushi/network/RateLimit.kt` ditambah sebagai
  compatibility helper untuk extension Keiyoushi modern yang memanggil
  `OkHttpClient.Builder.rateLimit(...)` (Omega/HeanCms memakainya saat client
  dibuat).
- `android/app/build.gradle.kts` menambah `androidx.preference:preference-ktx`
  karena HeanCms mengimplementasikan `ConfigurableSource` dan mereferensikan
  `EditTextPreference`/`SwitchPreferenceCompat`.

Catatan penting buat agent berikutnya: ini bukan bypass blokir ISP dan tidak
boleh disamakan dengan “Omega sudah pasti bisa tanpa VPN”. Kalau HP masih
return `internetbaik/telkomsel`, parser resmi Tachiyomi pun akan gagal. Setelah
VPN aktif sebagai default network, kalau Omega masih error baru cek logcat
`KizenExtensionRuntime` untuk dependency compatibility berikutnya.

Diverifikasi:
- `flutter analyze lib test` bersih.
- `flutter test -j 1` 48/48 lolos.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke iQOO.

### 2026-07-18 — Tambah metode parser/runtime repo + fondasi cek jaringan

User minta app lebih maksimal membuka sumber manual (`Sumber Saya`) dan sumber
repository Tachiyomi/Keiyoushi/Yuzono, dengan catatan fitur yang sudah jalan
jangan disentuh. Implementasi kali ini aditif:

- Android extension runtime:
  - Tambah alias `uy.kohesive.injekt.Injekt` plus helper `api.get<T>()` tanpa
    menghapus `injekt` lama.
  - Tambah stub Keiyoushi kecil yang sering dipakai extension modern:
    `keiyoushi.utils.Collections`, `Context`, `Preferences`, `Date`, dan
    `Json`.
  - Tetap mempertahankan stub lama; tidak rewrite `ConfigurableSource`,
    `HttpSource`, atau model Tachiyomi yang sudah dipakai source lama.
- Universal HTML parser:
  - Daftar sumber kini juga mencoba endpoint JSON umum: `api.<host>/query`,
    `<host>/query`, `<host>/api/query`, WP REST, `/api/manga(s)`,
    `/api/comic(s)`, `/api/series`, dan subdomain `api.`.
  - Parser JSON mengenali pola HeanCms (`series_slug`, `id`, `meta.current_page`
    / `last_page`), sehingga URL manga bisa disimpan sebagai
    `/series/{slug}#{id}` dan chapter fallback bisa lanjut memakai
    `series_id`.
  - Detail/chapter/page sekarang punya fallback API tambahan:
    `/series/{slug}`, `/chapter/query?series_id=...`,
    `/chapter/{seriesSlug}/{chapterSlug}`, `/api/chapter(s)`, dan JSON reader
    yang menyimpan gambar di field `images`, `image_url`, `src`, `path`, dll.
  - Inline script biasa (`window.__NUXT__`, `__INITIAL_STATE__`,
    `__APOLLO_STATE__`, object berisi `manga/series/chapters/pages`) ikut
    diekstrak, bukan hanya `script[type=application/json]`.
- Extension runtime bridge:
  - Native bridge menambah `probeUrl` untuk fondasi cek akses per-sumber nanti:
    bisa membedakan akses sumber yang benar vs blokir jaringan (`internetbaik`,
    `internetpositif`, hostname mismatch).
  - `openVpnSettings` masih ada sebagai util native, tapi menu
    `Akses Jaringan / VPN` di Setelan sudah dibuang lagi karena user merasa
    tidak kepakai.

Catatan batasan:
- App tidak memasang/bundling VPN gratis. Itu sengaja dihindari karena risiko
  privasi, tracking, dan policy.
- Source yang butuh Cloudflare browser challenge, login khusus, atau API
  berproteksi tetap bisa gagal sampai ada session WebView/cookie atau stub
  runtime spesifik berikutnya.

Diverifikasi:
- `flutter analyze lib test` bersih.
- `flutter test -j 1` 53/53 lolos.
- `flutter build apk --profile` sukses.
- APK profile terinstall ke Pixel 7 Pro yang sedang tersambung.
- `flutter build web --dart-define=FAKE_AUTH=true --no-web-resources-cdn`
  sukses.
- Smoke test web via Playwright + Chrome lokal: screenshot Setelan/menu VPN
  tidak blank dan tidak overlap (`/tmp/kizen-web-settings-vpn.png`,
  `/tmp/kizen-web-vpn-sheet.png`).

### 2026-07-18 — Runtime extension makin mirip Tachiyomi: cookie WebView + URL normalizer

User minta tambah metode yang paling manjur supaya sumber repository APK dan
`Sumber Saya` lebih banyak kebuka, tanpa mengganggu parser yang sudah jalan.
Akar kurangnya runtime sebelumnya: walaupun app sudah punya WebView Session
Mode, panggilan ke APK extension belum membawa cookie/session itu ke native
runtime. Jadi situs yang butuh `cf_clearance`, login browser, atau cookie hasil
redirect tetap dipanggil seperti request OkHttp kosong. Selain itu, beberapa
alur lama bisa mengirim URL absolut dari UI ke method extension yang biasanya
mengharapkan path relatif ala Tachiyomi (`/manga/foo`), sehingga default
`HttpSource` berisiko membuat request salah.

Fix aditif:
- `lib/sources/extension_runtime_source.dart` sekarang mengirim
  `SourceSessionStore.headersFor(...)` ke semua operasi extension:
  popular/latest/search/details/chapter/page. Session dipilih dari `baseUrl`
  dan URL manga/chapter yang sedang dibuka.
- `lib/data/extension_runtime.dart` menambah parameter `sessionHeaders` di
  semua method fetch extension, lalu meneruskannya lewat MethodChannel.
- `android/.../eu/kanade/tachiyomi/network/NetworkHelper.kt` menambah
  `WebViewCookieJar` yang membaca/menyimpan cookie dari `CookieManager`
  Android. Ini bikin client extension yang memakai `network.client` /
  `cloudflareClient` otomatis berbagi cookie dengan WebView, lebih dekat ke
  cara app reader native menjaga sesi browser.
- `ExtensionRuntimeBridge.kt` menormalisasi URL manga/chapter sebelum memanggil
  request extension: URL absolut dengan host yang sama diubah ke path relatif,
  sedangkan URL host lain tetap dibiarkan apa adanya. Ini mengurangi kasus
  request rusak karena `baseUrl + absoluteUrl`.
- Test `extension_runtime_source_test.dart` ditambah untuk memastikan cookie
  WebView benar-benar ikut terkirim ke native bridge.

Catatan batasan:
- Ini bukan jaminan semua website langsung kebuka. Source yang butuh runtime API
  Tachiyomi lain, JavaScript challenge penuh, atau proteksi server yang benar-
  benar memerlukan browser aktif tetap perlu kompatibilitas berikutnya. Tapi ini
  fondasi paling berdampak karena menyatukan WebView session dengan APK parser.

Diverifikasi:
- `flutter analyze lib test` bersih.
- `flutter test -j 1` 54/54 lolos.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro.

### 2026-07-18 — Universal parser tambah fallback DOM WebView-render

User minta metode tambahan yang lebih dekat ke Tachimanga/Tachiyomi supaya
website manual dan repo lebih banyak kebuka. Setelah cookie/session pipeline
masuk, celah besar berikutnya adalah website modern yang HTML awalnya cuma
shell kosong (`<div id="app">`) dan daftar manga/chapter/gambar baru muncul
setelah JavaScript jalan. Parser HTTP biasa tidak akan pernah melihat DOM itu,
walaupun cookie sudah benar.

Fix aditif:
- `ExtensionRuntimeBridge.kt` menambah method native
  `renderHtmlWithWebView(url, sessionHeaders)`:
  - berjalan di main thread Android;
  - membuat WebView tersembunyi;
  - mengaktifkan JavaScript + DOM storage;
  - memasukkan cookie dari `sessionHeaders` ke `CookieManager`;
  - memakai User-Agent dari WebView/session;
  - menunggu page selesai + delay pendek, lalu membaca
    `document.documentElement.outerHTML`.
- `lib/data/extension_runtime.dart` menambah wrapper Dart
  `renderHtmlWithWebView`.
- `lib/sources/universal_html_source.dart` sekarang mencoba DOM hasil WebView
  sebagai fallback untuk:
  - listing popular/latest/search bila HTML awal berhasil di-fetch tapi tidak
    menghasilkan kartu manga;
  - detail sumber yang gagal HTTP/non-200/challenge ringan;
  - daftar chapter bila HTML awal tidak berisi chapter;
  - halaman reader bila HTML awal tidak berisi gambar.
- Ekstraksi chapter/page di universal parser dipecah jadi helper reusable supaya
  HTML biasa dan DOM WebView-render melewati parser yang sama, bukan logic baru
  yang mudah meleset.
- Test ditambah:
  - bridge memastikan `renderHtmlWithWebView` membawa `sessionHeaders`;
  - universal parser memastikan shell HTML kosong bisa berhasil bila MethodChannel
    mengembalikan DOM hasil render.

Catatan batasan:
- Ini tetap fallback, bukan browser reader penuh. WebView disetel tidak memuat
  gambar agar ringan, jadi cocok untuk membaca DOM/list URL, bukan untuk render
  visual chapter. Website yang sengaja menyembunyikan data sampai user gesture,
  CAPTCHA, atau challenge interaktif masih perlu WebView manual/session.

Diverifikasi:
- `flutter analyze lib test` bersih.
- `flutter test -j 1` 56/56 lolos.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro.

### 2026-07-18 — WebView snapshot state JS + fallback gambar non-img

User minta ditambah lagi supaya makin mirip Tachiyomi/Tachimanga dan lebih
leluasa parse banyak web komik. Setelah fallback DOM WebView-render, masih ada
kelas website modern yang datanya tidak muncul sebagai elemen DOM biasa.
Contohnya data daftar manga/chapter/pages disimpan di `window.__NUXT__`,
`__NEXT_DATA__`, Apollo cache, atau `localStorage`, lalu komponen frontend
yang merendernya tidak selalu meninggalkan HTML yang gampang diparse.

Fix aditif:
- `ExtensionRuntimeBridge.kt` memperluas `renderHtmlWithWebView`:
  - setelah WebView selesai load, JavaScript runtime sekarang mengambil snapshot
    state umum dari `window`: `__NEXT_DATA__`, `__NUXT__`,
    `__INITIAL_STATE__`, `__APOLLO_STATE__`, `__remixContext`, `__SAPPER__`,
    `__INITIAL_DATA__`, `__APP_DATA__`, `__ROUTE_DATA__`, `NUXT_DATA`, dan
    `pageProps`;
  - localStorage juga disapu terbatas untuk key/value yang mengandung sinyal
    manga/comic/series/chapter/page/image, dan value JSON string dicoba
    `JSON.parse`;
  - snapshot disisipkan balik ke HTML sebagai
    `<script id="kizen-webview-state" type="application/json">...`;
  - ada guard circular reference, fungsi, BigInt, dan batas ukuran supaya
    MethodChannel tidak kebanjiran payload.
- `UniversalHtmlSource` tidak perlu parser khusus baru untuk state itu, karena
  script JSON hasil snapshot otomatis ikut dibaca oleh parser JSON embedded yang
  sudah ada.
- Reader image fallback diperluas: selain `<img>`, sekarang juga membaca
  `picture source[srcset]`, `link rel=preload as=image`, `og:image`,
  `twitter:image`, dan anchor yang langsung mengarah ke file gambar.
- Test baru:
  - universal parser bisa membaca manga dari state `__NUXT__` hasil snapshot
    WebView;
  - reader bisa membaca gambar dari `source srcset` dan preload image.

Catatan batasan:
- Ini makin mendekati mode “browser-assisted parser”, tapi tetap bukan emulator
  penuh Tachiyomi/Tachimanga untuk semua source. Website dengan CAPTCHA,
  gesture wajib, login berbayar, atau API yang terenkripsi khusus tetap bisa
  perlu parser extension/stub native tambahan.

Diverifikasi:
- `flutter analyze lib test` bersih.
- `flutter test -j 1` 58/58 lolos.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro.

### 2026-07-18 — WebView network/API capture + Comick-like payload support

User minta gas lagi supaya lebih dekat ke Tachiyomi/Tachimanga karena masih ada
contoh sumber manual yang belum kebuka seperti Comick/SoulScans. Dicek cepat:
`https://comick.io/search?...` dari curl biasa balik Cloudflare `Just a
moment`, jadi lapisan HTTP/HTML saja memang tidak cukup. Metode yang paling
masuk berikutnya adalah browser-assisted network capture: biarkan WebView
membuka halaman, lalu tangkap respons API/XHR yang dipakai frontend.

Fix aditif:
- `ExtensionRuntimeBridge.renderHtmlWithWebView` sekarang punya
  `shouldInterceptRequest` untuk request GET yang kelihatan seperti API payload
  (`/api/`, `/graphql`, `/query`, `/search`, `/manga`, `/comic`, `/series`,
  `/chapter`, `/reader`, `/pages`, query `page=`/`q=`).
- Request API tersebut diambil lewat OkHttp dengan header WebView + session
  headers, responsnya tetap dikembalikan ke WebView sebagai
  `WebResourceResponse` supaya halaman tidak putus.
- Respons text/json/javascript/html kecil ikut ditangkap terbatas:
  maksimal 40 payload, maksimal 1.2 MB per payload. Payload JSON object/array
  langsung disisipkan sebagai JSON, bukan string mentah.
- HTML hasil WebView sekarang ditambah script
  `kizen-webview-network` berisi `responses` dari API yang ketangkap. Universal
  parser otomatis menyapu script ini lewat parser JSON embedded.
- `UniversalHtmlSource._jsonMaps` sekarang juga mencoba decode string yang
  terlihat seperti JSON dan mengandung sinyal manga/comic/series/chapter/image.
  Ini membantu localStorage atau API yang membungkus JSON sebagai string.
- Parser cover/gambar ditambah support `b2key` Comick-like:
  - cover manga `b2key` diarahkan ke `https://meo.comick.pictures/{b2key}`;
  - reader page JSON yang cuma punya `b2key` juga diubah ke CDN yang sama.
- Test baru memastikan:
  - payload API dari `kizen-webview-network` bisa menghasilkan manga;
  - cover `b2key` Comick-like menghasilkan URL CDN yang benar.

Catatan batasan:
- Ini sudah lebih dekat ke browser-assisted parser milik reader modern, tapi
  tetap tidak bisa menjamin 200% semua website. CAPTCHA/interaksi manual,
  WebSocket-only, payload terenkripsi per-session, atau proteksi yang sengaja
  memblokir WebView tetap perlu penanganan khusus atau extension/stub tambahan.

Diverifikasi:
- `flutter analyze lib test` bersih.
- `flutter test -j 1` 60/60 lolos.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro.

### 2026-07-18 — Fix regresi reader Doujindesu setelah runtime/network capture

User melaporkan Doujindesu yang sebelumnya bisa baca chapter tiba-tiba gagal
dengan pesan `Gambar chapter Doujindesu belum dikenali`. Dicek logcat:

- Listing masih jalan lewat fallback khusus:
  `Doujindesu fallback parser OK count=24`.
- Saat masuk reader, extension resmi gagal di `pageListParse` karena interceptor
  extension mengira respons pageList adalah JSON, tapi situs mengembalikan HTML:
  `JsonDecodingException: Expected start of the object '{', but had '<'`.
- Karena error extension ditelan lalu jatuh ke universal HTML parser, UI akhirnya
  menampilkan error generic gambar belum dikenali.

Fix aditif dan scoped hanya untuk Doujindesu:
- `ExtensionRuntimeBridge.fetchPageListFromExtension` sekarang kalau package
  mengandung `doujindesu` dan extension pageList gagal, langsung mencoba fallback
  native `fetchDoujindesuPages(...)`.
- Fallback ini bypass interceptor extension yang rusak:
  - request HTML chapter langsung lewat OkHttp bersih;
  - pakai WebView User-Agent, Referer chapter, dan session headers;
  - parse image dari `img` (`data-src`, `data-original`, `srcset`, `src`, dll)
    plus regex URL gambar di script inline;
  - filter placeholder/logo/icon/avatar/ads;
  - mengembalikan format page map yang sama dengan runtime extension normal.
- Tambah helper `absoluteUrlForSource` supaya path chapter dari extension bisa
  di-resolve ke URL absolut sebelum fallback HTML request.

Catatan:
- Ini sengaja bukan rewrite universal parser besar, karena regresinya spesifik:
  extension Doujindesu rusak sebelum parse gambar. Fallback khusus ini menjaga
  source lain tetap memakai jalur runtime/network capture yang baru.

Diverifikasi:
- `flutter analyze lib test` bersih.
- Targeted test `flutter test -j 1 test/sources/extension_runtime_source_test.dart
  test/data/extension_runtime_test.dart` lolos 9/9.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro.

Follow-up: user masih melihat error yang sama. Saat dicek, focus HP sedang di
Mihon (`xyz.jmir.tachiyomi.mi`), bukan Kizen, jadi perlu hati-hati memastikan
yang dites adalah APK Kizen terbaru. Tetap diperkuat lagi karena fallback image
Doujindesu bisa gagal kalau gambar tersimpan sebagai JSON string/relative URL:
- `UniversalHtmlSource._embeddedImageUrls` sekarang decode JSON string yang
  berisi image/page sebelum menganggap string sebagai URL gambar. Ini mencegah
  seluruh JSON string dianggap sebagai satu URL.
- Regex gambar universal dan fallback Doujindesu native sekarang mengenali
  protocol-relative/relative image URL seperti `//cdn...jpg`,
  `/wp-content/...webp`, `/uploads/...jpg`, `/reader/...png`, dll.
- Boundary check ditambah supaya regex relatif tidak salah menangkap potongan
  tengah dari URL absolut (`https://cdn.example/reader/001.webp` tidak lagi
  menghasilkan duplikat `https://source.example/reader/001.webp`).
- Fallback native Doujindesu menulis log
  `Doujindesu page fallback scanned ... images=N`, supaya kalau masih gagal bisa
  langsung terlihat apakah HTML-nya memang tidak mengandung gambar atau pola
  gambarnya belum dikenali.
- Test universal baru menutup pola JSON string + relative URL.

Diverifikasi tambahan:
- `flutter analyze lib test` bersih.
- `flutter test -j 1 test/sources/universal_html_source_test.dart` 17/17 lolos.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro.

### 2026-07-18 — Guard ANR setelah WebView network capture terlalu agresif

User melaporkan app sampai force close / muncul `Kizen tidak menanggapi` setelah
metode browser-assisted terakhir dicoba. Root cause paling masuk: jalur
`renderHtmlWithWebView` sebelumnya memasang `shouldInterceptRequest` lalu ikut
fetch request API/XHR lewat OkHttp dari WebView. Di perangkat asli, pola ini
bisa ngeblok load WebView terlalu lama, apalagi kalau situs banyak request,
redirect, VPN/proxy, atau proteksi anti-bot. Selain itu universal parser juga
terlalu gampang memanggil WebView render untuk banyak kandidat URL list.

Fix:
- `ExtensionRuntimeBridge.renderHtmlWithWebView` dicabut lagi bagian network/API
  capture-nya:
  - tidak ada lagi `shouldInterceptRequest`;
  - tidak ada lagi fetch OkHttp sinkron dari dalam WebView;
  - tetap mempertahankan WebView DOM/state snapshot yang lebih ringan
    (`kizen-webview-state`) karena ini cuma baca state setelah halaman selesai.
- Helper/konstanta capture yang sudah tidak dipakai ikut dibersihkan supaya
  agent berikutnya tidak mengaktifkan lagi tanpa sadar.
- `UniversalHtmlSource._getHtml` sekarang tidak otomatis render WebView untuk
  semua status non-200. Render cuma dicoba untuk status yang memang sering
  berarti challenge/rate-limit/server block (`403`, `429`, `5xx`, `520-524`,
  dll), bukan untuk kandidat URL yang normalnya `404`.
- `UniversalHtmlSource._list` membatasi fallback render saat daftar komik:
  WebView hanya dicoba pada kandidat pertama atau HTML yang kelihatan seperti
  shell JavaScript (`#app`, `#__next`, `__nuxt`, `window.__`, dll). Ini mencegah
  banyak WebView tersembunyi dibuat beruntun saat parser sedang nyoba banyak
  bentuk URL.

Catatan:
- Ini sengaja bukan buang semua metode baru. Parser HTML/API, snapshot state
  WebView, fallback gambar, dan fallback khusus Doujindesu tetap dipertahankan.
- Yang dimatikan hanya capture network lewat intercept WebView karena dampaknya
  paling mungkin bikin ANR.

Diverifikasi:
- `dart format lib/sources/universal_html_source.dart` selesai.
- `flutter analyze lib test` bersih.
- Targeted test `flutter test -j 1 test/sources/universal_html_source_test.dart
  test/sources/extension_runtime_source_test.dart
  test/data/extension_runtime_test.dart` lolos 26/26.
- Full test `flutter test -j 1` lolos 61/61.
- `flutter build apk --profile` sukses.
- APK profile `build/app/outputs/flutter-apk/app-profile.apk` terinstall ulang
  ke Pixel 7 Pro.
- App berhasil dibuka via `adb shell monkey -p com.reikypratama.aplikasi_komik
  1`; log startup pendek tidak menunjukkan `FATAL EXCEPTION`/ANR.

### 2026-07-18 — Guard ANR lanjutan: WebView snapshot dimatikan otomatis

User masih melaporkan `Kizen tidak menanggapi` setelah network capture dimatikan.
Logcat jelas menunjukkan ANR:
`Input dispatching timed out ... Waited 5002ms for MotionEvent`. Trace ANR
tidak bisa dibaca langsung dari `/data/anr` karena permission Android, tapi
kode terakhir masih punya kandidat berat: `WEBVIEW_RENDER_SCRIPT` melakukan
`JSON.stringify` ke banyak object global (`__NEXT_DATA__`, `__NUXT__`,
`__APOLLO_STATE__`, dll) dan menyapu `localStorage`. Di website modern, object
ini bisa besar/circular/berisi cache banyak, sehingga evaluate JS di WebView
bisa menahan main thread cukup lama.

Fix:
- `WEBVIEW_RENDER_SCRIPT` sekarang dibuat DOM-only:
  `document.documentElement.outerHTML` / `document.body.outerHTML`.
- Snapshot object global dan localStorage tidak lagi otomatis disisipkan ke
  `kizen-webview-state`. Parser Dart masih bisa membaca script state kalau HTML
  website memang sudah punya script JSON sendiri, tapi native WebView tidak lagi
  membuat snapshot besar sendiri.
- Timeout WebView render dipercepat:
  - settle dari `1500ms` ke `750ms`;
  - timeout dari `10000ms` ke `6000ms`.
- `inspectExtension` dipindah ke background `Thread`, karena load/inspect APK
  extension bisa melibatkan class loading dan tidak boleh menahan main thread
  saat user membuka source repo.

Catatan:
- Ini sengaja memprioritaskan stabil dulu. Efek sampingnya, sebagian source
  JavaScript-heavy yang tadinya berharap pada snapshot global buatan Kizen bisa
  balik lebih sering gagal parse, tapi app tidak boleh sampai ANR/force close.

Diverifikasi:
- `flutter analyze lib test` bersih.
- Targeted test `flutter test -j 1 test/data/extension_runtime_test.dart
  test/sources/extension_runtime_source_test.dart
  test/sources/universal_html_source_test.dart` lolos 26/26.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro.
- App dibuka via `adb shell monkey -p com.reikypratama.aplikasi_komik 1`;
  log startup pendek setelah install ulang tidak menunjukkan ANR/crash.

### 2026-07-18 — Safe mode parser universal setelah APK masih ANR

User masih melaporkan APK tetap `Kizen tidak menanggapi` dan terasa hancur.
Kesimpulan: eksperimen parser all-in harus ditarik lebih jauh. Walau network
capture dan snapshot WebView sudah dimatikan, universal parser masih terlalu
agresif karena:
- WebView render otomatis tetap bisa dibuat dari beberapa jalur parser;
- deep JSON walk bisa menyapu script/state HTML besar di isolate UI Flutter;
- regex gambar bisa nyapu `outerHtml` besar dua kali.

Fix stabilitas:
- `UniversalHtmlSource` masuk safe mode:
  `_enableAutomaticWebViewRendering = false`, jadi parser universal tidak lagi
  membuat hidden WebView otomatis.
- Scan embedded JSON dibatasi:
  - script JSON besar di-skip;
  - inline script besar di-skip;
  - recursive JSON walk dibatasi depth/visited/result count.
- Scan raw image URL dari `outerHtml` dibatasi maksimal ukuran HTML tertentu.
  Kalau HTML terlalu besar, parser hanya pakai selector DOM + embedded JSON yang
  sudah lolos batas aman.
- Test WebView otomatis di `universal_html_source_test.dart` tidak dihapus, tapi
  di-`skip` dengan reason safe mode ANR. Ini supaya nanti bisa diaktifkan lagi
  kalau WebView/parser berat sudah dipindah ke jalur yang benar-benar non-blocking.

Catatan:
- Ini mengorbankan sebagian support source JavaScript-heavy demi mengembalikan
  APK agar responsif dulu. Setelah stabil, support website berat harus dibangun
  ulang lebih selektif/per-source atau worker/isolate/native yang tidak ngeblok
  UI.

Diverifikasi:
- `dart format lib/sources/universal_html_source.dart
  test/sources/universal_html_source_test.dart` selesai.
- `flutter analyze lib test` bersih.
- Targeted test `flutter test -j 1 test/sources/universal_html_source_test.dart
  test/data/extension_runtime_test.dart
  test/sources/extension_runtime_source_test.dart` lolos; 3 test WebView
  otomatis di-skip sengaja karena safe mode ANR.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro setelah `am force-stop`.
- App dibuka via `adb shell monkey -p com.reikypratama.aplikasi_komik 1`;
  log 8 detik setelah startup tidak menunjukkan ANR/FATAL. Log yang muncul
  hanya Surface/ProfileInstaller/clipboard denied normal.

### 2026-07-18 — Fix URL relatif Doujindesu setelah safe mode

Setelah safe mode, user melaporkan force close berhenti, tapi Doujindesu gagal
load dengan pesan `Gagal menghubungi Doujindesu: No host specified in URI`.
Root cause: beberapa extension/source mengembalikan `mangaUrl` atau
`chapterUrl` relatif (`/series/...`, `/chapter/...`). Universal fallback masih
langsung `Uri.parse(...)` lalu `http.Client.get(...)`, sehingga request tanpa
host meledak sebelum sampai ke website.

Fix:
- `UniversalHtmlSource` tambah helper `_absUri(...)` dan semua request HTML/JSON
  sekarang di-resolve terhadap `baseUrl` sebelum `http.get`.
- `_getRenderedHtml` juga pakai URL absolut kalau suatu saat safe mode WebView
  dibuka lagi.
- `fetchPageList` sekarang membuat `absoluteChapterUrl` untuk request dan
  `Referer`, supaya image request Doujindesu tidak membawa referer relatif.
- `ExtensionRuntimeSource._sessionHeadersFor(...)` sekarang resolve URL relatif
  terhadap `baseUrl` sebelum mengambil cookie/session.
- `_sameSite(...)` juga resolve image URL relatif sebelum membandingkan host.
- Test baru memastikan `fetchPageList('/series/.../chapter-2/')` tetap request
  ke `https://generic.example/...` dan tidak lagi memicu URI tanpa host.

Diverifikasi:
- `dart format lib/sources/universal_html_source.dart
  lib/sources/extension_runtime_source.dart
  test/sources/universal_html_source_test.dart` selesai.
- Targeted test `flutter test -j 1 test/sources/universal_html_source_test.dart
  test/sources/extension_runtime_source_test.dart` lolos; 3 test WebView
  otomatis tetap di-skip sengaja karena safe mode ANR.
- `flutter analyze lib test` bersih.
- `flutter build apk --profile` sukses.
- APK profile terinstall ulang ke Pixel 7 Pro setelah `am force-stop`.
- App dibuka via `adb shell monkey -p com.reikypratama.aplikasi_komik 1`;
  log startup tidak menunjukkan ANR/FATAL/`no host specified`.

### 2026-07-18 — Kunci urutan tab Terbaru Soulscans

User melihat tab `Terbaru` masih menampilkan jumlah/urutan yang mencurigakan.
Root cause-nya bukan data komik lama, tapi request parser belum menyatakan
aturan sorting secara eksplisit sehingga masih bergantung pada default route
website.

Fix:
- `SvelteKitComicSource.fetchLatest()` sekarang mengirim
  `sort=latest&order=desc` ke route `/allcomic`.
- Query ini tetap memakai katalog penuh, bukan section homepage yang cuma
  berisi beberapa komik.
- Unit test menegaskan parameter sorting tersebut selalu ikut terkirim.

Diverifikasi:
- Live Soulscans mengembalikan data `updated_at` menurun saat memakai
  `sort=latest&order=desc`.
- Unit test parser SvelteKit lolos setelah perubahan.

### 2026-07-18 — Hindari daftar Terbaru Soulscans yang stale dari extension APK

User menemukan webview Soulscans sudah update sekitar 9 menit lalu, tapi tab
`Terbaru` aplikasi masih berhenti di komik yang update sekitar seminggu lalu.
Root cause: `ExtensionRuntimeSource` selalu menerima hasil parser APK sebagai
final kalau jumlah itemnya sudah banyak. Akibatnya parser katalog SvelteKit
yang mengambil data fresh dari `/allcomic` tidak pernah diberi kesempatan.

Fix:
- Untuk host Soulscans, `fetchLatest()` sekarang selalu mencoba katalog web
  fresh setelah hasil extension.
- Hasil katalog web dipakai jika tidak kosong; hasil extension tetap dipakai
  kalau request web gagal.
- Source lain tetap mempertahankan aturan lama supaya perubahan ini tidak
  mengganggu parser APK yang sudah berjalan.

Diverifikasi:
- Ditambah test saat extension mengirim 20 item stale; katalog fallback tetap
  dipilih untuk Soulscans.

### 2026-07-18 — Pakai API terbaru Soulscans dan rapikan label First chapter

User masih melihat daftar satu minggu walau webview menampilkan update 9 menit
lalu. Setelah dicek, halaman Soulscans menyediakan endpoint resmi
`/api/search?type=COMIC&limit=50&page=1&sort=latest&order=desc` yang berisi
`updated_at` terbaru. Parser HTML sebelumnya masih bisa menangkap payload/route
yang tidak tepat.

Fix:
- `SvelteKitComicSource.fetchLatest()` sekarang mencoba endpoint API tersebut
  langsung, lalu baru fallback ke HTML kalau API tidak tersedia.
- Daftar chapter sekarang memprioritaskan label dari payload chapter. Tombol
  navigasi situs yang berlabel `First chapter` tidak lagi menimpa label asli
  seperti `Chapter 1`.
- Test ditambah untuk query API terbaru dan kasus label `First chapter`.

### 2026-07-18 — Sambungkan fallback repo Soulscans ke parser API yang benar

User masih melihat daftar sekitar satu minggu meskipun parser SvelteKit dan
endpoint API sudah benar. Root cause terakhir ada di resolver repository:
`ExtensionRuntimeSource` memakai `UniversalHtmlSource` sebagai fallback default,
jadi parser API Soulscans tidak pernah dipanggil ketika extension APK
mengembalikan data lama.

Fix:
- Fallback default `ExtensionRuntimeSource` untuk host `soulscans.asia` sekarang
  langsung `SvelteKitComicSource`.
- Source Soulscans dari repository maupun sumber manual kini melewati endpoint
  `/api/search` terbaru sebelum fallback lain.
- Host lain tetap memakai `UniversalHtmlSource` seperti sebelumnya.

### 2026-07-18 — Bypass extension stale Soulscans di resolver

User masih melihat data lama setelah fallback diarahkan ke SvelteKit. Supaya
tidak ada jalur extension APK lama yang masih bisa menang, `SourceCatalog` kini
langsung memilih `SvelteKitComicSource` untuk semua source dengan host
`soulscans.asia`, termasuk source yang metadata repository-nya bertipe
`extension-runtime`.

Dengan begitu tab terbaru, detail, chapter, dan halaman baca Soulscans memakai
parser API/HTML langsung yang sama, sementara extension APK tetap dipakai untuk
source repository lain.

### 2026-07-18 — Cegah request Populer menimpa tab Terbaru

Screenshot dari device menunjukkan tab `Terbaru` aktif, tetapi isi grid bisa
berasal dari request `Populer` yang dimulai saat layar pertama dibuka. Karena
dua request berjalan bersamaan, response yang selesai belakangan dapat menimpa
hasil tab yang baru dipilih.

Fix:
- `SourceDetailScreen` sekarang memberi ID generasi pada setiap request
  discover/load-more.
- Response lama diabaikan kalau sudah bukan request aktif.
- Posisi grid di-reset ke atas saat pindah tab supaya item terbaru tidak
  tertutup offset daftar sebelumnya.

### 2026-07-18 — API resmi dipakai untuk Terbaru dan Populer Soulscans

User masih melihat Terbaru kembali menjadi 4 item. Root cause-nya adalah
fallback HTML yang masih boleh turun ke homepage/section ringkas setelah API
gagal. Endpoint Soulscans sendiri menyediakan sorting resmi untuk dua mode.

Fix:
- `fetchLatest()` memakai `/api/search` dengan `sort=latest&order=desc`.
- `fetchPopular()` memakai endpoint yang sama dengan `sort=popular&order=desc`.
- Jalur fallback Terbaru hanya `/allcomic`; tidak lagi turun ke homepage 4
  item yang bisa terlihat seperti hasil terbaru.
- Request API diberi header JSON dan cache-control yang sesuai.

### 2026-07-20 — Probe nyata source repository sebelum ditandai normal

User menambahkan `www.toongod.org/webtoons`. Tes sumber sebelumnya bisa
menampilkan berhasil hanya karena URL ditemukan di metadata repository dan APK
extension-nya ada, padahal request aktual masih mentok Cloudflare.

Fix additive:
- `SourceCatalog.probeGeneric()` menjalankan `fetchPopular(1)` sungguhan untuk
  source repository sebelum statusnya dianggap normal.
- Add Source sekarang menyimpan source yang gagal probe sebagai `WebView`,
  bukan memberi sinyal normal palsu.
- Parser lama dan runtime extension tidak diubah.

Catatan keamanan:
- Tidak ditambahkan Botasaurus/CAPTCHA bypass atau spoof fingerprint.
- User tetap bisa menyelesaikan challenge normal lewat WebView, menekan
  `Tandai Session Aktif`, lalu mencoba ulang parser dengan cookie session.

### 2026-07-20 — Tambah route katalog Toongod `/webtoons`

User sudah bisa membuka WebView Toongod, tapi menu manhwa tetap tidak muncul.
Root cause-nya parser generik hanya mencoba route umum seperti `/manga/`,
sedangkan katalog Toongod ada di `/webtoons/`.

Fix additive:
- `UniversalHtmlSource` sekarang mencoba `/webtoons/` paling awal, lalu
  variasi `/webtoon/`, `/webton/`, dan `/manhwa/` sebelum route lama.
- Ditambah test yang memastikan request pertama dan hasil kartu berasal dari
  `/webtoons/`.
- Parser lama, extension runtime, dan alur WebView tidak dirombak.

Verifikasi: test source parser lulus; setelah build profile, selesaikan
Cloudflare di WebView Toongod, tandai session aktif, lalu buka ulang sumber.

### 2026-07-20 — Fallback browser session khusus Toongod

Session cookie sudah ditandai aktif, tetapi request HTTP biasa masih menerima
403 Cloudflare. Root cause-nya clearance Cloudflare kadang perlu JavaScript
WebView dan User-Agent browser yang sama, bukan hanya header Cookie.

Fix additive:
- `UniversalHtmlSource` punya opsi `enableBrowserSessionFallback`, default-nya
  tetap mati agar source lain tidak memicu WebView tersembunyi.
- Opsi itu hanya aktif untuk host `toongod.org`, termasuk source manual,
  source generik, dan extension runtime fallback.
- Android bridge menunggu JavaScript WebView lebih lama sebelum mengambil DOM,
  sehingga redirect clearance normal punya waktu selesai.
- Parser lama dan metode source lain tidak diubah.

Catatan: ini memakai session browser normal yang sudah dibuat user; tidak ada
CAPTCHA solver, spoof fingerprint, proxy rotation, atau bypass Cloudflare.

### 2026-07-20 — Toongod terverifikasi sampai reader di Pixel

Setelah user masih melihat fallback WebView, pengecekan dilakukan langsung di
Pixel lewat log native dan smoke-test UI. WebView ternyata sudah melewati
Cloudflare dan menghasilkan DOM katalog sekitar 181 KB. Extension package
`eu.kanade.tachiyomi.extension.en.toongod` memang tidak terpasang, tetapi jalur
browser fallback bisa mengambil alih dengan benar.

Hasil smoke-test device:
- `/webtoons/` menampilkan 18 judul halaman pertama.
- Detail `Never Just Friends` terbuka dan 28 chapter terbaca.
- Chapter 27 terbuka di reader dengan 50 gambar asli.
- Snapshot memastikan halaman bukan Cloudflare challenge.

Fix final:
- Timeout Dart untuk menunggu hasil render native dinaikkan dari 12 ke 20
  detik. Native bridge sendiri maksimal 12 detik, jadi hasil DOM besar tidak
  kalah balapan dengan timeout Flutter.
- Diagnostik snapshot sementara sudah dibuang; tidak ada HTML situs yang
  disimpan permanen oleh aplikasi.

### 2026-07-20 — Pagination, tab terbaru, dan cover Toongod

Setelah katalog bisa dibuka, user menemukan hanya sedikit komik, cover kosong,
dan tab Terbaru sama dengan Populer.

Root cause:
- Madara Toongod memakai `/webtoons/page/N/`, bukan query `?page=N`.
- Tombol next memakai class `nextpostslink` yang belum dikenali parser umum.
- Populer dan Terbaru perlu `m_orderby=trending` dan `m_orderby=latest`.
- Cover di host Toongod mengembalikan Cloudflare 403 ke image loader, sedangkan
  salinan CDN WordPress `i0.wp.com` bisa diambil dengan status 200.

Fix additive:
- URL katalog Toongod kini memakai path pagination dan parameter urutan asli.
- `nextpostslink` dikenali sehingga infinite scroll dapat memuat halaman lanjut.
- Search Toongod membawa `post_type=wp-manga`.
- Gambar dalam `/wp-content/uploads/` diarahkan ke CDN WordPress, tanpa
  mengubah gambar reader dari host lain.
- Header Cookie/User-Agent Toongod tidak diteruskan ke `i0.wp.com`; CDN
  menerima request cover lintas-domain yang bersih.
- Test mencakup route halaman dua, tab terbaru/populer, next page, dan cover.

### 2026-07-20 — Tanggal chapter, batal simpan, dan validasi judul ganda

Tanggal chapter Toongod sebelumnya kosong walau daftar chapter sudah terbaca.
Root cause-nya theme Madara menaruh tanggal sebagai saudara link chapter di
`.chapter-release-date`, sedangkan parser universal cuma mengambil URL dan
nama dari tag `<a>`.

Fix:
- `UniversalHtmlSource` sekarang mengambil tanggal dari container chapter
  terdekat (`time`, `.chapter-release-date`, `.chapterdate`, dan variasinya),
  termasuk field tanggal dari payload JSON/API.
- Parser tanggal menerima ISO/timestamp, format `dd/mm/yyyy`, nama bulan
  Inggris, serta waktu relatif Inggris/Indonesia. Kalau website memang tidak
  memberi tanggal, UI tetap kosong dan tidak mengarang nilai.
- Sheet pindah koleksi menampilkan ikon `X` merah pada koleksi yang sedang
  aktif. Ikon itu membuka konfirmasi di sheet yang sama lalu menghapus komik
  dari Library; dipakai dari Detail maupun menu Library.
- Sebelum menyimpan komik beda URL/source, judul dinormalisasi (case, spasi,
  dan tanda baca umum diabaikan). Bila judul sama sudah ada, user bisa pilih
  `Tetap tambah`, `Ganti yang lama`, atau `Batal`.
- Pilihan ganti memakai batch Firestore: semua entri beda-source dengan judul
  sama dihapus dan versi baru ditulis sekaligus ke koleksi tujuan.
- `analysis_options.yaml` mengecualikan `build/**` karena Swift Package Manager
  menaruh source generated Firebase di sana dan sempat membuat `flutter
  analyze` ikut memeriksa ratusan file dependency.

Verifikasi:
- `flutter analyze` nol issue.
- `flutter test -j 1`: 75 lulus, 3 safe-mode diskip.
- Build web FAKE_AUTH lulus dan smoke-test viewport 412×915 memastikan ikon
  `X`, konfirmasi hapus, toast, serta state bookmark tidak overflow.
- APK profile 90,5 MB berhasil dibangun, dipasang, dan dibuka di Pixel 7 Pro.

### 2026-07-20 — Format tanggal resmi Toongod dan judul terkandung

User mengonfirmasi tanggal chapter Toongod masih kosong dan menginginkan
deteksi duplikat berdasarkan judul yang terkandung, bukan hanya judul penuh
yang sama.

Root cause tanggal:
- Source resmi Toongod di repository Keiyoushi menetapkan format
  `d MMM yyyy` (contoh `20 Jul 2026`). Parser universal sebelumnya baru
  menerima nama bulan di depan (`July 20, 2026`), jadi selector tanggal sudah
  menemukan teksnya tetapi parser mengembalikan null.

Fix:
- Parser tanggal sekarang mendukung urutan hari-bulan-tahun serta singkatan
  bulan Inggris (`Jan` sampai `Dec`), sambil mempertahankan semua format lama.
- Deteksi duplikat sekarang memakai kandungan frasa dua arah setelah
  normalisasi. Batas kata tetap dijaga: `Solo Leveling` cocok dengan
  `Solo Leveling Official`, tetapi `One` tidak cocok dengan `Someone`.
- Karena hasilnya tetap berupa konfirmasi tiga pilihan, kecocokan kandungan
  tidak otomatis menghapus atau mengganti komik.

Verifikasi:
- `flutter analyze` nol issue.
- `flutter test -j 1`: 76 lulus, 3 safe-mode diskip.
- APK profile terbaru berhasil dibangun, dipasang, dan dibuka di Pixel 7 Pro.

### 2026-07-20 — Parser API lengkap MangaFire

User menambahkan `https://mangafire.to/`, tetapi sumber tidak bisa dibuka
lewat parser universal. Root cause-nya MangaFire versi sekarang tidak memakai
katalog/chapter HTML biasa; extension resminya mengambil seluruh data dari
endpoint JSON khusus.

Fix additive:
- Ditambah `MangaFireSource` dengan endpoint `/api/titles` untuk Populer,
  Terbaru, dan pencarian (50 item per halaman).
- Detail memakai `/api/titles/{hid}` dan mengurai sinopsis HTML, author,
  artist, genre/theme, status, serta poster.
- Chapter memakai `/api/titles/{hid}/chapters`, limit 200 dan pagination
  sampai seluruh halaman selesai. Tanggal epoch ikut diteruskan ke UI.
- Reader memakai `/api/chapters/{chapterId}` dan mengambil semua URL gambar.
- Source manual/repository maupun source lama yang sebelumnya tersimpan
  sebagai `universal-html` otomatis dialihkan berdasarkan host
  `mangafire.to`; user tidak perlu hapus dan tambah ulang sumber.
- `AdaptiveSource` dan fallback `ExtensionRuntimeSource` ikut mengenali
  MangaFire, tetapi strategi API ini tidak dicoba pada website lain supaya
  tidak menambah timeout global.

Verifikasi:
- Lima test khusus mencakup katalog populer/terbaru/search, detail, chapter
  multi-page + tanggal, reader, dan migrasi source lama.
- `flutter analyze` nol issue.
- `flutter test -j 1`: 81 lulus, 3 safe-mode diskip.
