# Progress Tracking — My Comic (Flutter)

Rekreasi desain dari `design_handoff_my_comic/` (prototipe `My Comic.dc.html`).
Urutan build mengikuti `00_START_HERE.md`. Tiap item selesai → review & approve dulu sebelum lanjut.

## Status

| # | File spek | Scope | Status | Catatan |
|---|---|---|---|---|
| 1 | `01_design_system.md` | Design tokens (warna, tipografi, spacing, radii, ikon, motion) | ✅ Approved | `lib/core/theme/` |
| 2 | `15_shared_components.md` | Bottom nav, FAB, bottom sheet shell, toast, context menu, collection picker, empty state | 👀 Menunggu review | `lib/core/widgets/` |
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
