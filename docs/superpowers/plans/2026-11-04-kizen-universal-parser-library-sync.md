# Kizen Universal Parser, Library Multi-Selection & Repository Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memperkuat algoritma parser komik agar universal dan adaptif untuk semua jenis web komik (WP MangaThemesia, Madara AJAX, NatsuId, Next.js/Nuxt hydration, universal HTML heuristics & WebView fallback), menambah fitur multi-selection & pengelompokan per sumber di Library, menyelaraskan sinkronisasi "Sumber Saya" dengan "Repository", serta memperbaiki bug kritis & celah keamanan Reader dan native bridge.

**Architecture:** 
- Universal Scraping Engine: Pipeline heuristik bertingkat di `AdaptiveSource` dan `UniversalHtmlSource` yang mencakup deteksi JSON hydration (`__NEXT_DATA__`, `__NUXT__`, `data-page`), microdata/JSON-LD, WP REST API, Madara AJAX endpoints, serta semantic DOM selectors fallback.
- Library Batch Management: Notifier API di `LibraryNotifier` untuk operasi atomik batch (`deleteBatch`, `moveToCollectionBatch`, `markReadBatch`), ringkasan komik per sumber (`comicsBySource`), dan UI multi-selection mode di `LibraryScreen` dengan Action Bar serta modal "Kelola per Sumber".
- Two-way Source & Repository Synchronization: Unifikasi identitas sumber via `syncSourcesWithRepositories` yang otomatis menautkan domain, alias, dan package extension ketika repo di-refresh, mencegah tabrakan ID dan duplikasi komik.
- Reader & Security Hardening: Menghilangkan pembersihan disk cache destruktif di `ReaderSessionImageCache`, membatasi concurrency pre-fetch, mencegah `_suppressScroll` lock, memvalidasi URL scheme di WebView Android Kotlin (`allowFileAccess = false`), dan memfilter navigasi ad redirects di `WebViewScreen`.

**Tech Stack:** Flutter, Dart, Riverpod (`NotifierProvider`), Cloud Firestore, Html/Jsoup parser, OkHttp, Kotlin/Android WebView, CachedNetworkImage.

**Spec / Requirements:**
- Universal parsing untuk segala link web komik yang dimasukkan di Sumber Saya.
- Library multi-selection: pilih banyak komik, hapus batch, pindahkan koleksi batch.
- Pengelompokan / statistik komik per sumber web di Library beserta aksi per sumber.
- Sinkronisasi selaras antara Sumber Saya dan Repository tanpa tabrakan saat update.
- Perbaikan bug Reader (cache wipe, freeze scroll, webtoon seek) dan keamanan (LFI, cookie leak, intent ads).

---

## Global Constraints
- Target platform: Android & iOS saja (Web build hanya untuk sanity/smoke-test CanvasKit).
- Gaya penulisan: Bahasa Indonesia casual ("beb", santai).
- Firestore queries: DILARANG menggunakan `orderBy` pada field dengan `FieldValue.serverTimestamp()` (selalu sort client-side).
- Riverpod: Hindari `ref.read` di `dispose()`.
- Verifikasi wajib sebelum commit: `flutter analyze` (0 issue), `flutter test -j 1` (semua lulus).

---

## Review Focus
- Input URL komik dari web non-standar (Next.js/Nuxt/WP Ajax/Blogspot) menghasilkan daftar komik, detail, dan gambar reader tanpa crash.
- Multi-selection di Library menghapus atau memindahkan puluhan komik sekaligus di Firestore tanpa race condition.
- Aksi "Hapus semua komik dari sumber X" hanya menghapus komik yang bersangkutan tanpa menyentuh komik dari web lain.
- Sinkronisasi repo tidak menimpa atau menduplikasi sumber custom yang sudah ada, melainkan menautkan alias dan package-nya.
- Keluar-masuk Reader tidak lagi menghapus file cache gambar di disk.

---

## Tasks

### Task 1: Perbaikan Bug Kritis Reader & Keamanan Native (P0 / P1)
**Files:**
- Modify: `lib/features/reader/reader_session_image_cache.dart`
- Modify: `lib/features/reader/reader_screen.dart`
- Modify: `android/app/src/main/kotlin/com/reikypratama/aplikasi_komik/extensions/ExtensionRuntimeBridge.kt`
- Modify: `lib/sources/extension_runtime_source.dart`
- Modify: `lib/features/browse/web_view_screen.dart`
- Test: `test/features/reader/reader_screen_test.dart`

- [ ] Hapus pemanggilan `emptyCache()` saat `acquire()` dan `release()` di `_ReaderCacheCoordinator` agar cache bertahan sebagai persistent LRU.
- [ ] Batasi worker `warmChapter` hanya untuk 3 halaman di depan dan 1 di belakang halaman aktif, dengan throttling ramah Cloudflare.
- [ ] Perbaiki `_commitWebtoonZoom` di `reader_screen.dart` agar `_suppressScroll = false` selalu dieksekusi di post-frame callback terlepas dari kecocokan requestId.
- [ ] Perbaiki `_seekToPage` agar memperhitungkan rasio halaman terukur (`_measuredPageAspectRatios`) saat melompat di mode Webtoon.
- [ ] Di `ExtensionRuntimeBridge.kt`, tambahkan validasi URL hanya skema `http` dan `https`, serta set `allowFileAccess = false` dan `allowContentAccess = false`.
- [ ] Di `extension_runtime_source.dart`, filter header cookie agar tidak dikirim ke host CDN pihak ketiga yang berbeda domain.
- [ ] Di `web_view_screen.dart`, tambahkan `NavigationDelegate.onNavigationRequest` untuk menolak skema selain `http`/`https` (`intent://`, `market://`).
- [ ] Jalankan test dan pastikan verifikasi awal lulus.

### Task 2: Peningkatan Algoritma Universal Parser Komik
**Files:**
- Modify: `lib/sources/universal_html_source.dart`
- Modify: `lib/sources/adaptive_source.dart`
- Modify: `lib/sources/source_catalog.dart`
- Test: `test/sources/universal_html_source_test.dart`
- Test: `test/sources/adaptive_source_test.dart`

- [ ] Tambahkan extractor untuk aplikasi modern yang memakai hydration JSON (`__NEXT_DATA__`, `__NUXT__`, `data-page` Inertia) untuk mengambil katalog, detail, dan gambar chapter.
- [ ] Perluas heuristik parsing chapter list dan reader images untuk mencakup tema Blogspot/NatsuId/Madara/WP MangaReader serta lazy loading attributes (`data-lazy-src`, `data-original`, `data-url`, noscript).
- [ ] Integrasikan fallback WebView DOM rendering otomatis jika request HTTP biasa mengembalikan status 403 / proteksi Cloudflare atau daftar chapter kosong.
- [ ] Perbaiki sanitasi URL di `SourceCatalog.matchByUrl` dan method parser agar aman terhadap karakter spesial/spasi tanpa melempar `FormatException`.
- [ ] Buat unit test yang memvalidasi parsing berbagai struktur payload HTML dan JSON modern.

### Task 3: Library Multi-Selection & Batch Actions
**Files:**
- Modify: `lib/data/library_state.dart`
- Modify: `lib/features/library/library_screen.dart`
- Test: `test/data/library_state_test.dart`
- Test: `test/features/library/library_screen_test.dart`

- [ ] Tambahkan method batch di `LibraryNotifier`:
  - `deleteComics(List<String> comicIds)`
  - `moveComicsToCollection(List<String> comicIds, String? collectionId)`
  - `markComicsRead(List<String> comicIds, bool isRead)`
- [ ] Implementasikan mode multi-selection di `LibraryScreen`:
  - Toggle selection mode via long-press atau tombol "Pilih" di header.
  - Checkbox overlay di kartu komik (`_ComicGridCard`).
  - Bar status pilihan di atas (Jumlah dipilih, Pilih Semua, Batal).
  - Floating/bottom action bar dengan tombol Pindahkan Koleksi, Tandai Dibaca, dan Hapus.
- [ ] Tulis widget test untuk alur multi-selection, select all, batch delete, dan batch move collection.

### Task 4: Ringkasan & Pengelompokan Komik Berdasarkan Sumber di Library
**Files:**
- Modify: `lib/data/library_state.dart`
- Modify: `lib/features/library/library_screen.dart`
- Test: `test/features/library/library_screen_test.dart`

- [ ] Tambahkan getter/helper di `library_state.dart` untuk menghitung agregasi komik per sumber (`Map<String, List<Comic>> comicsGroupedBySource`).
- [ ] Tambahkan tombol "Kelola per Sumber" di header Library (misal icon globe/list).
- [ ] Buat bottom sheet `_SourceManagementSheet`:
  - Menampilkan daftar semua sumber web yang ada di Library beserta jumlah komik masing-masing.
  - Aksi filter: tap pada sumber untuk memfilter grid Library khusus sumber tersebut.
  - Aksi pilih semua: tombol untuk memilih semua komik dari sumber tersebut ke mode multi-selection.
  - Aksi hapus sumber: tombol hapus semua komik dari sumber tersebut dengan konfirmasi keamanan.
- [ ] Tulis test untuk memverifikasi agregasi sumber dan aksi hapus semua komik dari satu sumber.

### Task 5: Sinkronisasi Selaras Antara "Sumber Saya" dan "Repository"
**Files:**
- Modify: `lib/data/sources_state.dart`
- Modify: `lib/data/repository_state.dart`
- Modify: `lib/data/source_resolver.dart`
- Modify: `lib/features/browse/browse_screen.dart`
- Modify: `lib/features/browse/repo_browse_tab.dart`
- Test: `test/data/repository_state_test.dart`
- Test: `test/data/source_resolver_test.dart`

- [ ] Buat fungsi sinkronisasi `syncSourcesWithRepositories(List<ComicSource> userSources, List<ComicRepository> repos)`:
  - Mencocokkan sumber di Sumber Saya dengan sumber di Repository berdasarkan domain, package, alias, atau kesamaan nama.
  - Memperbarui `repoPackage`, `repoSourceId`, dan URL aktif jika repo membawa URL yang lebih baru.
  - Mempertahankan `urlAliases` dan `nameAliases` agar komik lama di Library tetap terhubung.
- [ ] Panggil sinkronisasi ini otomatis saat repository di-refresh atau ketika extension baru di-install.
- [ ] Di tab Repository, jika sebuah extension yang sudah ada di "Sumber Saya" di-update, update metadata `ComicSource` tanpa membuat entri ganda.
- [ ] Tulis test untuk memverifikasi sinkronisasi otomatis, penggabungan alias, dan penyelarasan update repository ke sumber saya.

### Task 6: Verifikasi Penuh, Smoke Test, dan Dokumentasi PROGRESS.md
**Files:**
- Modify: `PROGRESS.md`

- [ ] Jalankan `flutter analyze` dan pastikan 0 issue.
- [ ] Jalankan `flutter test -j 1` dan pastikan seluruh test (termasuk test baru) lulus 100%.
- [ ] Jalankan build web sanity check.
- [ ] Tulis entri kronologis baru di `PROGRESS.md` menjelaskan seluruh perbaikan, root cause, detail per-file, dan bukti verifikasi.
