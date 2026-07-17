import '../sources/manga_source.dart';
import '../sources/source_catalog.dart';
import 'sources_state.dart';

/// Cari `MangaSource` yang bisa dipakai buat baca komik dari sumber
/// bernama [sourceName] — coba 4 sumber native dulu (lib/sources/), lalu
/// [customSources] (dari `sourcesProvider`) yang berhasil di-auto-detect
/// cocok dengan salah satu parser tema generik (`ComicSource.parserKind`,
/// lihat `SourceCatalog.detectGeneric` & `add_source_screen.dart`). Null
/// kalau tidak ada parser otomatis sama sekali (WebView Session Mode saja).
///
/// Ambil `List<ComicSource>` langsung (bukan `Ref`/`WidgetRef`) supaya
/// bisa dipanggil dari widget (`WidgetRef`) maupun `Notifier` (`Ref`) —
/// dua tipe itu tidak sama di Riverpod, jadi pemanggil yang baca provider-nya
/// sendiri lewat `ref.read(sourcesProvider)`.
MangaSource? resolveMangaSource(
  String sourceName,
  List<ComicSource> customSources,
) {
  final builtIn =
      SourceCatalog.sources.where((s) => s.name == sourceName).firstOrNull;
  if (builtIn != null) return builtIn;
  final custom = customSources
      .where((s) => s.name == sourceName && s.parserKind != null)
      .firstOrNull;
  if (custom == null) return null;
  return SourceCatalog.buildGeneric(
      custom.parserKind!, custom.name, 'https://${custom.url}');
}
