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
└── settings/
    ├── reader                       ← preferensi reader (spek 13)
    └── app                          ← bahasa aktif, bookmark repo, tema (spek 08/14)
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
| `read` | number | chapter terakhir dibaca (drive label "Ch. N", "Lanjut Baca", tag "Dibaca") |
| `unread` | number | badge grid |
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
| `title`, `sourceName`, `hue` | | denormalized untuk render row tanpa join |
| `chapter` | number | `chNum` |
| `page`, `pages` | number | progress bar `page/pages` |
| `readAt` | timestamp | label relatif ("2 jam lalu") dihitung saat render |

> "Bersihkan" = hapus semua dokumen di subcollection ini (batch delete).
> Query default: `orderBy('readAt', descending: true)`.

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
| `themeMode` | string | "Gelap" (dekoratif dulu) |

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
   `library/{comicId}.read/unread` (debounce ~2–3 detik biar hemat write).

## Estimasi kuota (Spark free tier)

Pemakaian personal: puluhan dokumen kecil, ratusan write/hari saat aktif membaca
(dengan debounce) — jauh di bawah limit 20k write & 50k read per hari. Aman.
