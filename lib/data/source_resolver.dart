import '../sources/manga_source.dart';
import '../sources/source_catalog.dart';
import 'library_state.dart';
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
  // Sumber yang diedit user harus menang atas domain built-in hardcode.
  // Sebelumnya nama seperti "Ikiru" selalu mengambil instance lama dulu,
  // sehingga URL baru yang sudah disimpan user justru tidak pernah dipakai.
  final custom = customSources
      .where(
        (source) =>
            source.matchesName(sourceName) ||
            sameLibraryTitle(source.name, sourceName),
      )
      .firstOrNull;
  if (custom != null) {
    final customBaseUrl = custom.url.startsWith('http')
        ? custom.url
        : 'https://${custom.url}';
    final repoMatch = findRepoSource(
      repositories: repositories,
      rawUrl: customBaseUrl,
      packageName: custom.repoPackage,
      sourceId: custom.repoSourceId,
      name: custom.name,
      nameAliases: custom.nameAliases,
      urlAliases: custom.urlAliases,
    );
    final baseUrl = repoMatch?.source.baseUrl ?? customBaseUrl;
    final kind = repoMatch?.source.pkg == null
        ? (repoMatch?.source.parserKind ?? custom.parserKind)
        : 'extension-runtime:${repoMatch!.source.pkg}';
    final fallbackBaseUrls = <String>{
      ...custom.urlAliases,
      if (baseUrl != customBaseUrl) customBaseUrl,
      ...?repoMatch?.source.baseUrlAliases,
    };
    return SourceCatalog.buildAutomatic(
      custom.name,
      baseUrl,
      preferredKind: kind,
      lang: repoMatch?.source.lang ?? custom.lang,
      fallbackBaseUrls: fallbackBaseUrls,
    );
  }

  // Komik dari tab Repository memakai source sintetis: source-nya tidak
  // disimpan di `sourcesProvider`, tetapi nama source tetap dibawa di
  // `Comic.src`. Cari kembali metadata repo supaya detail, chapter, dan
  // reader tetap memakai extension runtime yang sama.
  for (final repository in repositories) {
    final repoSource = repository.sources
        .where(
          (source) =>
              source.matchesName(sourceName) ||
              sameLibraryTitle(source.name, sourceName),
        )
        .firstOrNull;
    if (repoSource == null || repoSource.baseUrl == null) continue;
    final baseUrl = repoSource.baseUrl!.startsWith('http')
        ? repoSource.baseUrl!
        : 'https://${repoSource.baseUrl}';
    final kind = repoSource.pkg == null
        ? repoSource.parserKind
        : 'extension-runtime:${repoSource.pkg}';
    return SourceCatalog.buildAutomatic(
      repoSource.name,
      baseUrl,
      preferredKind: kind,
      lang: repoSource.lang,
      fallbackBaseUrls: repoSource.baseUrlAliases,
    );
  }

  final builtIn = SourceCatalog.sources
      .where(
        (source) =>
            source.name == sourceName ||
            sameLibraryTitle(source.name, sourceName),
      )
      .firstOrNull;
  if (builtIn == null) return null;
  return SourceCatalog.buildAutomatic(sourceName, builtIn.baseUrl);
}
