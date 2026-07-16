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
