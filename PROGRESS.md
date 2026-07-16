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
