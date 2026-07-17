# Rancangan Database — My Comic (Firestore)

Backend: **Firebase** — Auth (Google Sign-In) + Cloud Firestore (free tier / Spark).
Prinsip: semua data milik user digantung di bawah `users/{uid}` (uid dari Firebase Auth).
Login akun Google yang sama di device lain ⇒ path yang sama ⇒ sync otomatis.
Firestore offline cache aktif ⇒ app tetap jalan tanpa internet, perubahan
ke-sync sendiri saat online (last-write-wins per dokumen via `updatedAt`).

## Peta koleksi

```
users/{uid}                          ← profil + meta sync
├── sources/{sourceId}               ← "Sumber Saya" (spek 07/09)
├── repositories/{repoId}            ← repository terpasang (spek 08/11)
├── library/{comicId}                ← komik tersimpan + progress (spek 04/12)
├── collections/{collectionId}       ← koleksi/kategori library (spek 04/15)
├── history/{comicId}                ← posisi baca terakhir per komik (spek 06)
├── bookmarks/{bookmarkId}           ← halaman ditandai manual saat baca (spek 13)
├── updates/{comicId}                ← chapter baru terdeteksi per komik (spek 05)
└── settings/
    ├── reader                       ← preferensi reader (spek 13)
    └── app                          ← bahasa aktif, bookmark repo (spek 08)
```

## Detail per koleksi

### `users/{uid}` (dokumen profil)
| Field | Tipe | Contoh / catatan |
|---|---|---|
| `name` | string | dari Google ("Reiky Pratama") |
| `email` | string | dari Google |
| `photoUrl` | string? | avatar Google (null → inisial gradient) |
| `createdAt` | timestamp | first login |
| `lastSyncAt` | timestamp | dipakai badge "Tersinkron" di Setelan |

### `sources/{sourceId}` — mapping dari `ComicSource`
| Field | Tipe | Catatan |
|---|---|---|
| `name` | string | "KomikStation" |
| `url` | string | sudah dinormalisasi (tanpa https://, tanpa trailing /) — dipakai cek duplikat |
| `lang` | string | "ID" / "EN" |
| `hue` | number | placeholder cover |
| `active` | bool | toggle aktif/nonaktif |
| `status` | string | `normal` \| `webview` \| `limited` \| `failed` |
| `session` | bool | session WebView tersimpan (lihat catatan keamanan di bawah) |
| `desc` | string? | field Deskripsi di form Add Source |
| `parserKind` | string? | hasil auto-deteksi struktur situs saat "Test Sumber" (mis. `mangathemesia`, `natsuid`) — kalau cocok salah satu tema generik yang sudah didukung (`SourceCatalog.detectGeneric`), sumber custom ini otomatis bisa dibaca native (discover grid, chapter list, reader) tanpa WebView. Null = tidak terdeteksi / tetap WebView-only |
| `createdAt`, `updatedAt` | timestamp | urutan tampil + resolusi konflik |

> Catatan: **cookie/sesi WebView asli TIDAK disimpan di cloud** — itu tetap di
> cookie jar WebView per-device. Yang di-sync hanya flag `session` (status UI).
> Kalau user pindah device, dia verifikasi ulang di device itu — sesuai prinsip
> "tanpa bypass otomatis" di spek 10.

### `repositories/{repoId}` — mapping dari `ComicRepository`
| Field | Tipe | Catatan |
|---|---|---|
| `name` | string | "Komunitas Scan ID" |
| `url` | string | link index |
| `sources` | array<map> | `[{id, name, hue, lang}]` — di-embed (bukan subcollection) karena kecil (<50 item) & selalu dibaca bersama repo-nya |
| `createdAt`, `updatedAt` | timestamp | |

### `library/{comicId}` — mapping dari `Comic`
| Field | Tipe | Catatan |
|---|---|---|
| `title` | string | |
| `sourceName` | string | `src` sekarang (denormalized, biar tetap tampil walau sumber dihapus) |
| `sourceId` | string? | relasi ke `sources` bila ada |
| `hue` | number | placeholder cover — nanti diganti `coverUrl` saat artwork asli ada |
| `totalChapters` | number | `ch` |
| `read` | number | nomor chapter TERJAUH yang pernah dibuka (drive label "Ch. N", "Lanjut Baca") — bukan hitungan chapter selesai, lihat `readChapters` |
| `unread` | number | badge grid |
| `readChapters` | array<number> | nomor chapter yang halaman terakhirnya BENAR-BENAR tercapai (per-chapter, dipakai tanda "Dibaca" di Comic Detail) — sengaja terpisah dari `read` karena user bisa baca lompat-lompat, bukan urut dari chapter 1 |
| `chapterProgress` | map<string,map> | progres parsial per chapter, key = nomor chapter sintetis sebagai string (`"300"`, `"298"`), value = `{page, pages, chapterUrl?, chapterLabel?}`. Dipakai Comic Detail untuk menampilkan beberapa label "Hal X/Y" sekaligus. Ini sengaja terpisah dari `history`, karena `history/{comicId}` cuma posisi TERAKHIR untuk tombol "Lanjut Baca"; tanpa field ini, progress chapter 300 akan hilang begitu user lanjut baca chapter 298 |
| `lastChapterUrl` | string? | URL chapter TERBARU yang diketahui saat komik ditambah/di-cek terakhir kali — identifier stabil dipakai [`UpdatesNotifier.refresh`] buat deteksi "ada chapter baru": bandingkan URL chapter terbaru hasil fetch vs field ini, bukan `totalChapters > ch` (jumlah mentah bisa tidak stabil kalau situs punya chapter spesial/bonus). Null untuk komik lama sebelum field ini ada ⇒ fallback sekali ke perbandingan jumlah |
| `collectionId` | string? | null = hanya di "Semua" |
| `addedAt`, `updatedAt` | timestamp | urutan "Terakhir dibaca" pakai `updatedAt` desc |

### `collections/{collectionId}` — mapping dari `ComicCollection`
| Field | Tipe | Catatan |
|---|---|---|
| `name` | string | "Sedang Dibaca" |
| `createdAt` | timestamp | urutan chips |

> "Semua" itu virtual (bukan dokumen). Hapus koleksi ⇒ batch update:
> semua `library` dengan `collectionId` itu di-set null (komik tidak ikut terhapus).

### `history/{comicId}` — mapping dari `HistoryEntry`
Satu dokumen **per komik** (posisi terakhir), bukan per event — karena UI-nya
"lanjut baca", bukan log. Doc id = comicId ⇒ update posisi = 1 write, tanpa dedup.
| Field | Tipe | Catatan |
|---|---|---|
| `title`, `sourceName`, `hue`, `coverUrl` | | denormalized untuk render row tanpa join. `coverUrl` opsional; entri lama fallback ambil dari `library/{comicId}` kalau masih ada |
| `chapter` | number | `chNum` — POSISI relatif ke total chapter saat di-fetch, BUKAN identifier stabil, lihat `chapterUrl`/`chapterLabel` |
| `chapterUrl` | string? | URL chapter asli — identifier stabil dipakai Reader buat lompat balik lewat "Lanjut Baca". `chapter` doang bisa salah kalau daftar chapter situsnya sudah berubah panjang sejak disimpan (chapter baru terbit) — null untuk komik demo atau entri lama sebelum field ini ada |
| `chapterLabel` | string? | label chapter ASLI dari situs (mis. "Chapter 43.5 Extra"), sama seperti yang ditampilkan Reader — ditampilkan apa adanya di History (bukan "Ch. `chapter`") karena `chapter` cuma posisi hasil hitungan sendiri (`total - index`), bisa beda dari nomor asli situs kalau ada chapter spesial/bonus/non-sekuensial di daftarnya. Fallback ke "Ch. `chapter`" kalau null (entri lama) |
| `page`, `pages` | number | progress bar `page/pages` |
| `readAt` | timestamp | label relatif ("2 jam lalu") dihitung saat render |

> "Bersihkan" = hapus semua dokumen di subcollection ini (batch delete).
> Query: TANPA `orderBy` di Firestore — diurutkan manual di client setelah
> snapshot masuk. `readAt` ditulis pakai `FieldValue.serverTimestamp()`,
> yang nilainya `null` di cache lokal selama tulisan masih pending;
> `orderBy` di query akan mengecualikan dokumen dengan field urut yang
> belum ke-resolve, jadi entri baru bisa hilang total dari hasil listener.

### `bookmarks/{bookmarkId}` — mapping dari `BookmarkEntry`
Beda dari `history` (satu dokumen per komik, posisi TERAKHIR): bisa banyak
dokumen per komik/chapter, tidak ketimpa progres baca biasa — murni
penanda manual ("momen epic") lewat ikon bookmark di Reader.
Doc id = `{comicId}_ch{chNum}_p{page}` (deterministik) ⇒ toggle on/off =
set/delete dokumen yang sama, tidak ada duplikat untuk halaman yang sama.
| Field | Tipe | Catatan |
|---|---|---|
| `comicId` | string | buat query/filter per komik di client |
| `title`, `sourceName`, `hue`, `coverUrl` | | denormalized untuk render row tanpa join. `coverUrl` opsional; entri lama fallback ambil dari `library/{comicId}` kalau masih ada |
| `chapter` | number | `chNum` — posisi relatif, sama catatan seperti `history.chapter` |
| `chapterUrl` | string? | identifier stabil, sama catatan seperti `history.chapterUrl` |
| `chapterLabel` | string | nama chapter asli, atau "Chapter N" untuk komik demo |
| `page`, `pages` | number | posisi halaman yang ditandai |
| `createdAt` | timestamp | urutan tampil (terbaru dulu), diurutkan di client (alasan sama seperti `history`) |

### `updates/{comicId}` — mapping dari `UpdateEntry`
Satu dokumen per komik (chapter TERBARU yang terdeteksi), doc id = comicId.
Diisi lewat `UpdatesNotifier.refresh()` — iterasi semua komik Library yang
punya `sourceMangaUrl` (dari sumber asli, lihat lib/sources/), panggil
`fetchChapterList` sungguhan, dan cuma nulis dokumen kalau jumlah chapter
di situs > `totalChapters` yang tercatat di `library`. Komik dari sumber
tanpa parser native (WebView-only) dilewati — tidak bisa dicek otomatis,
konsisten dengan prinsip "tanpa bypass otomatis" di app ini. Sekuensial
(bukan paralel) biar tidak membanjiri situs sumber sekaligus; kegagalan
per-komik (situs down/parser meleset) dilewati, tidak menggagalkan
keseluruhan pengecekan.
| Field | Tipe | Catatan |
|---|---|---|
| `comicId` | string | sama dengan doc id, disimpan juga buat kemudahan query |
| `title`, `sourceName`, `hue` | | denormalized untuk render row tanpa join |
| `chapter` | number | nomor chapter terbaru yang terdeteksi |
| `detectedAt` | timestamp | dasar hitung `dateGroup`/`time` relatif saat render, tanpa `orderBy` di query (alasan sama seperti `history`) |

> Begitu chapter baru ketemu, `library/{comicId}` ikut di-update
> (`totalChapters` + `unread`) lewat `LibraryNotifier.applyNewChapters()` —
> badge unread di grid Library otomatis kebawa tanpa perlu baca `updates`.

### `settings/reader` — mapping dari `ReaderSettings`
| Field | Tipe |
|---|---|
| `direction` | string (`vertical` \| `horizontal` \| `rtl`) |
| `bg` | string hex ("#000000") |
| `gap` | number (0–30) |
| `brightness` | number (30–100) |
| `keepScreenOn` | bool |

### `settings/app`
| Field | Tipe | Catatan |
|---|---|---|
| `activeLangs` | array<string> | `["ID","EN"]` — global, bukan per repo (spek 08) |
| `repoBookmarks` | array<string> | id `rp-{repoId}-{sourceId}` — terpisah dari sources (keputusan desain: bookmark ≠ Sumber Saya) |

> Tidak ada field `themeMode` — app dark-only by design (lihat
> `app_theme.dart`), baris "Tema" di Settings cuma info statis "Gelap",
> tidak ada state yang perlu disimpan/disinkronkan.

## Yang sengaja TIDAK di-cloud

| Data | Alasan | Simpan di |
|---|---|---|
| Unduhan chapter (gambar) | per-device, besar, bikin jebol free tier | storage lokal device (path file + flag di SQLite/Hive lokal) |
| Cookie/sesi WebView | keamanan + memang per-device | cookie jar WebView |
| Gambar halaman komik | di-fetch langsung dari website sumber | — (cache sementara saja) |

Status "chapter diunduh" (`downloadsProvider`) jadi **lokal per device** — kalau mau
ditampilkan lintas device nanti, cukup sync daftar key `comicId-chapterNum` ke
`settings/app`, tapi file-nya tetap lokal.

## Security rules (inti)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```
User hanya bisa baca/tulis datanya sendiri. Tidak ada data publik/shared.

## Alur sync (mengisi TODO(backend) yang ada)

1. **Login** (`AuthRepository`) → Firebase Auth `signInWithCredential(Google)` → `uid`.
2. **SyncScreen** (`SyncService.syncAll`) → prefetch `sources`, `repositories`,
   `library`, `collections`, `history`, `settings` (Firestore otomatis mengisi
   offline cache di sini — inilah "Mengambil library, sumber & riwayat").
3. **Runtime** — setiap Notifier di `lib/data/` diganti stream Firestore
   (`snapshots()`); mutasi UI = write dokumen; Firestore yang urus offline queue
   & propagasi antar device. UI tidak berubah sama sekali.
4. **Reader** — tiap pindah halaman/chapter: update `history/{comicId}` +
   `library/{comicId}.read/unread/chapterProgress` (debounce ~2–3 detik
   biar hemat write). `history` tetap satu posisi terakhir; progress
   parsial per-chapter disimpan di `library.chapterProgress`.

## Estimasi kuota (Spark free tier)

Pemakaian personal: puluhan dokumen kecil, ratusan write/hari saat aktif membaca
(dengan debounce) — jauh di bawah limit 20k write & 50k read per hari. Aman.
