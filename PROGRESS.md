# Progress Tracking — My Comic (Flutter)

Rekreasi desain dari `design_handoff_my_comic/` (prototipe `My Comic.dc.html`).
Urutan build mengikuti `00_START_HERE.md`. Tiap item selesai → review & approve dulu sebelum lanjut.

## Status

| # | File spek | Scope | Status | Catatan |
|---|---|---|---|---|
| 1 | `01_design_system.md` | Design tokens (warna, tipografi, spacing, radii, ikon, motion) | ✅ Selesai — menunggu review | `lib/core/theme/` |
| 2 | `15_shared_components.md` | Bottom nav, FAB, bottom sheet shell, toast, context menu, collection picker, empty state | ⬜ Belum | |
| 3 | `03_onboarding.md` | Splash → Login (Google) → Sync | ⬜ Belum | |
| 4 | `04_library.md` | Tab Library (kategori, search, sort, grid, empty state) | ⬜ Belum | |
| 5 | `05_updates.md` | Tab Updates (feed per tanggal + refresh) | ⬜ Belum | |
| 6 | `06_history.md` | Tab History (lanjut baca, hapus riwayat) | ⬜ Belum | |
| 7 | `07_browse_sumber_saya.md` | Tab Jelajahi — sub-tab "Sumber Saya" | ⬜ Belum | |
| 8 | `09_add_source.md` | Layar Add Source URL (form, test/validate, simpan) | ⬜ Belum | |
| 9 | `10_source_detail_webview.md` | Source Detail + WebView Session Mode | ⬜ Belum | |
| 10 | `08_browse_repository.md` | Tab Jelajahi — sub-tab "Repository" | ⬜ Belum | |
| 11 | `11_repository_management.md` | Repository List, Add/Edit Repository, language picker | ⬜ Belum | |
| 12 | `12_comic_detail.md` | Comic Detail (daftar chapter, download, koleksi) | ⬜ Belum | |
| 13 | `13_reader.md` | Reader (webtoon + manga paged, settings sheet, nav chapter) | ⬜ Belum | |
| 14 | `14_settings.md` | Settings (akun, tema, reader default, sync, sign out) | ⬜ Belum | |
| 15 | `02_flow_overview.md` | Final pass: navigation graph lengkap + back-stack | ⬜ Belum | |

Legenda: ⬜ Belum · 🔨 Dikerjakan · 👀 Menunggu review · ✅ Approved

## Log

### 2026-07-15 — 01_design_system.md
- Setup dependency: `flutter_riverpod` (state management), `google_fonts` (Plus Jakarta Sans + JetBrains Mono), `lucide_icons_flutter` (ikon outline Feather/Lucide-style).
- `lib/core/theme/app_colors.dart` — semua token warna + `accentGradient` (150deg) + radial wash splash/login.
- `lib/core/theme/app_typography.dart` — preset text style sesuai tabel tipografi; helper `mono()` untuk URL.
- `lib/core/theme/app_dimens.dart` — padding layar, radii, tombol, FAB (58px, bottom 104), nav pill, sheet, grid 3 kolom gap 14, cover 2:3.
- `lib/core/theme/app_motion.dart` — durasi/curve (screen 280ms, sheet cubic-bezier(0.2,0.8,0.2,1), spinner 750ms, toast 2.4s) + `FadeSlideUpPageTransitionsBuilder`.
- `lib/core/theme/app_icons.dart` — mapping ikon Lucide sesuai daftar Iconography.
- `lib/core/theme/app_theme.dart` — `ThemeData` dark (satu-satunya tema; toggle tema terang di Settings = TODO dekoratif sesuai handoff).
- `lib/main.dart` — `ProviderScope` + `MaterialApp` pakai tema; home placeholder sementara.
