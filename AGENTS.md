# AGENTS.md — Kizen (aplikasi_komik)

Konteks buat AI agent manapun (Claude Code, Codex, atau lainnya) yang
lanjut ngerjain project ini gantian sama agent lain — biar gak perlu
re-explain dari nol tiap ganti tool. User biasa manggil sesi Claude Code
"beb".

## Project ini apa

Kizen — Flutter comic/manga reader **pribadi** (bukan produk komersial),
target **Android + iOS SAJA**. Build web di sandbox ini HANYA dipakai
internal buat smoke-testing otomatis (sandbox gak bisa jalanin emulator
Android/iOS) — jangan pernah anggap ini web app beneran, jangan optimasi
apa pun buat web selain sebagai alat verifikasi.

User native bahasa Indonesia, gaya casual. Semua komentar kode, commit
message, dan `PROGRESS.md` ditulis bahasa Indonesia casual (bukan
formal/textbook) — ikuti gaya yang udah ada, jangan switch ke English.

## WAJIB dibaca dulu sebelum mulai kerja

1. **`PROGRESS.md`** — changelog lengkap & kronologis: tiap entri ada
   root cause, fix per-file, dan cara verifikasi. Ini SUMBER KEBENARAN
   riwayat kerja, bukan cuma catatan tambahan. Baca minimal beberapa
   entri TERAKHIR sebelum mulai kerja, biar tau state terkini & alasan
   di balik keputusan desain yang udah diambil — supaya gak re-introduce
   bug yang udah pernah dibenerin.
2. **`docs/DATABASE.md`** — skema Firestore lengkap + alasan tiap
   keputusan desain (mis. kenapa query gak pakai `orderBy`, kenapa ada
   `chapterUrl` selain `chNum`, dst).
3. **Tambah entri baru ke `PROGRESS.md`** (bertanggal, JANGAN overwrite
   entri lama) tiap kali selesai kerja signifikan — root cause, fix
   per-file, cara verifikasi. Ini yang bikin agent lain (atau diri
   sendiri di sesi berikutnya) bisa langsung paham tanpa tanya ulang ke
   user.

## Konvensi kerja

- **Branch**: `claude/kind-johnson-lebss6` — kerja & push ke branch ini
  kecuali diminta lain secara eksplisit.
- **Verifikasi wajib sebelum commit**:
  - `flutter analyze` — harus bersih, nol issue.
  - `flutter test -j 1` — 18/18 harus lolos (pakai `-j 1`; ada gotcha di
    test runner paralel yang bikin sebagian file test kelewat kehitung
    kalau dijalanin default).
  - `flutter build web --dart-define=FAKE_AUTH=true --no-web-resources-cdn`
    — compile sanity check + basis buat smoke-test manual (lihat bawah).
- **Smoke-test manual** (bukan cuma percaya test lolos = beneran jalan):
  kalau ubah UI/behavior, serve `build/web` (`python3 -m http.server`)
  dan drive pakai Playwright headless — Chromium ada di
  `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`, wajib pakai args
  `--enable-unsafe-swiftshader --use-gl=swiftshader --ignore-gpu-blocklist`
  biar CanvasKit render tanpa GPU asli di sandbox. CanvasKit render ke
  satu `<canvas>` — Playwright text locator TIDAK bisa nemu elemen,
  klik pakai koordinat piksel (`page.mouse.click(x, y)`) hasil baca
  screenshot. Ambil screenshot tiap langkah penting buat verifikasi
  visual, JANGAN cuma andalin "gak ada error" — beberapa bug sesi lalu
  (nested-sheet crash, unhandled Future rejection dari `ref`/wakelock di
  `dispose()`) cuma ketauan lewat cara ini, gak kelihatan dari baca kode
  doang.
- **Commit message**: bahasa Indonesia, jelasin root cause + fix + cara
  verifikasi (ikuti gaya di `git log` yang udah ada).
- Jangan commit/push kalau user gak eksplisit minta, KECUALI konteks
  kerja yang sedang berlangsung memang polanya "kerjain lalu auto
  commit+push" (itu pola yang dipakai sepanjang sesi-sesi sebelumnya).

## Arsitektur & gotcha penting (ringkasan — detail lengkap ada di `PROGRESS.md`)

- **State management**: Riverpod `NotifierProvider` buat semua state
  (library, history, bookmarks, collections, updates, sources).
  Firestore-backed kalau login asli; in-memory demo data kalau
  `FAKE_AUTH`/belum login (`FirestoreScope.collection(...)` balikin
  `null` di mode demo — semua notifier punya cabang `if (col == null)`).
- **Firestore `orderBy` + `serverTimestamp()` = BAHAYA**: query yang
  pakai `orderBy` pada field yang ditulis lewat
  `FieldValue.serverTimestamp()` bisa exclude dokumen yang tulisannya
  masih pending (nilainya `null` di cache lokal, Firestore buang dari
  hasil `orderBy`). Semua query di app ini SENGAJA gak pakai `orderBy`
  — sort manual di client setelah snapshot masuk. Jangan tambah
  `orderBy` baru tanpa notes tambahan.
- **Chapter number itu MULTI-SISTEM, jangan campur**: `chNum`/`ch` (int)
  = posisi hasil hitungan sendiri (`total - index` saat fetch), BUKAN
  nomor asli situs — bisa meleset kalau situs punya chapter
  bonus/non-sekuensial. Selalu prefer `chapterUrl` (String, identifier
  stabil) buat LOOKUP/re-cari chapter yang sama, dan `chapterLabel`
  (String, label asli situs) buat DITAMPILKAN ke user. Jangan pernah
  nulis logic baru yang cuma andalin `chNum` doang buat salah satu dari
  dua kebutuhan itu.
- **`resolveMangaSource(sourceName, customSources)`**
  (`lib/data/source_resolver.dart`) — satu-satunya cara yang benar buat
  resolve `MangaSource` (built-in 4 sumber + custom yang auto-terdeteksi
  lewat `ComicSource.parserKind`). Jangan panggil
  `SourceCatalog.sources.where(...)` langsung lagi di tempat baru.
- **Reader progress-save** (`lib/features/reader/reader_screen.dart`)
  baru dibenerin dari 4 bug berbeda (lihat entri PROGRESS.md tanggal
  terbaru soal ini): debounce timer tunggal bisa ke-`cancel()` pas ganti
  chapter sebelum sempat nyimpen, `_totalPages` race pas halaman asli
  masih di-fetch (mock value ikut kesimpan), "sudah tamat" gak kedetek
  kalau user langsung tap Next/footer sebelum listener scroll sempat
  jalan, dan `ref.read(...)` dipanggil dari `dispose()` (Riverpod
  nolak). Kalau nyentuh area ini lagi, WAJIB baca entri PROGRESS.md yang
  relevan dulu sebelum ubah apa pun.
- **`ref` (Riverpod) TIDAK aman dipanggil di `State.dispose()`** — kalau
  butuh notifier di `dispose()`, simpan referensinya sebagai field pas
  `initState()` (`late final XNotifier _xNotifier = ref.read(xProvider.notifier);`),
  jangan `ref.read(...)` fresh di `dispose()`.
- **Cover/gambar network** — selalu kasih `cacheWidth` (skala ukuran
  tampil × `devicePixelRatio`, BUKAN biarin decode resolusi asli) dan
  bungkus `RepaintBoundary` buat gambar di list/grid yang di-scroll —
  pola ini udah dipakai konsisten di grid Library/Discover & halaman
  baca Reader.
- **List besar** (chapter, komik, sumber, updates, history) — selalu
  `.builder()`/`SliverChildBuilderDelegate` (lazy), JANGAN `ListView`
  eager `children:` kecuali listnya emang kecil & bounded (form, chip
  row, dsb). Kasih `ValueKey` dari id stabil di tiap item builder kalau
  urutan list bisa berubah (sort, item baru masuk) — tanpa itu Flutter
  bisa "ketuker" state antar-item pas urutan geser.

## Yang HARUS dicek sebelum lapor "selesai" ke user

Jangan cuma percaya `flutter analyze`/`flutter test` lolos = beneran
jalan di UI. Kalau ubah UI/interaksi, JALANIN beneran (smoke-test
Playwright seperti di atas) dan lihat screenshot-nya dulu sebelum bilang
"sudah fix" — baca poin "Smoke-test manual" di atas buat caranya.
