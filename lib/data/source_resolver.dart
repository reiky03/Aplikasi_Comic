import '../sources/manga_source.dart';
import '../sources/source_catalog.dart';
import 'repository_state.dart';
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
  List<ComicRepository> repositories,
) {
  final builtIn = SourceCatalog.sources
      .where((s) => s.name == sourceName)
      .firstOrNull;
  if (builtIn != null) return builtIn;
  final custom = customSources.where((s) => s.name == sourceName).firstOrNull;
  if (custom != null) {
    final customBaseUrl = custom.url.startsWith('http')
        ? custom.url
        : 'https://${custom.url}';
    final repoMatch = findRepoSource(
      repositories: repositories,
      rawUrl: customBaseUrl,
      packageName: custom.repoPackage,
      sourceId: custom.repoSourceId,
    );
    final baseUrl = repoMatch?.source.baseUrl ?? customBaseUrl;
    final kind = repoMatch?.source.pkg == null
        ? custom.parserKind
        : 'extension-runtime:${repoMatch!.source.pkg}';
    if (kind == null) {
      return SourceCatalog.buildAutomatic(custom.name, customBaseUrl);
    }
    return SourceCatalog.buildGeneric(
      kind,
      custom.name,
      baseUrl,
      lang: repoMatch?.source.lang,
    );
  }

  // Komik dari tab Repository memakai source sintetis: source-nya tidak
  // disimpan di `sourcesProvider`, tetapi nama source tetap dibawa di
  // `Comic.src`. Cari kembali metadata repo supaya detail, chapter, dan
  // reader tetap memakai extension runtime yang sama.
  for (final repository in repositories) {
    final repoSource = repository.sources
        .where((source) => source.name == sourceName)
        .firstOrNull;
    if (repoSource == null || repoSource.baseUrl == null) continue;
    final baseUrl = repoSource.baseUrl!.startsWith('http')
        ? repoSource.baseUrl!
        : 'https://${repoSource.baseUrl}';
    final kind = repoSource.pkg == null
        ? repoSource.parserKind
        : 'extension-runtime:${repoSource.pkg}';
    if (kind == null) {
      return SourceCatalog.buildAutomatic(repoSource.name, baseUrl);
    }
    return SourceCatalog.buildGeneric(
      kind,
      repoSource.name,
      baseUrl,
      lang: repoSource.lang,
    );
  }
  return null;
}
