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
  List<ComicRepository> repositories, {
  String? sourceMangaUrl,
  String? comicId,
}) {
  // Sumber yang diedit user harus menang atas domain built-in hardcode.
  // Sebelumnya nama seperti "Ikiru" selalu mengambil instance lama dulu,
  // sehingga URL baru yang sudah disimpan user justru tidak pernah dipakai.
  ComicSource? custom = customSources
      .where(
        (source) =>
            source.matchesName(sourceName) ||
            sameLibraryTitle(source.name, sourceName),
      )
      .firstOrNull;

  // Fallback 1: Cocokkan ID sumber dari ID komik (mis. src_s1_... atau src_rp-...)
  if (custom == null && comicId != null) {
    custom = customSources
        .where((source) => comicId.startsWith('src_${source.id}_'))
        .firstOrNull;
  }

  // Fallback 2: Cocokkan host URL komik dengan URL / aliases sumber
  if (custom == null && sourceMangaUrl != null && sourceMangaUrl.isNotEmpty) {
    final mangaUri = Uri.tryParse(sourceMangaUrl);
    final mangaHost = mangaUri?.host.toLowerCase() ?? '';
    if (mangaHost.isNotEmpty) {
      custom = customSources.where((source) {
        final uri = Uri.tryParse(
          source.url.startsWith('http') ? source.url : 'https://${source.url}',
        );
        final host = uri?.host.toLowerCase() ?? '';
        return host == mangaHost ||
            source.urlAliases.any(
              (alias) => alias.toLowerCase().contains(mangaHost),
            );
      }).firstOrNull;
    }
  }

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
    final fallbackBaseUrls = <String>{
      ...custom.urlAliases,
      if (baseUrl != customBaseUrl) customBaseUrl,
      ...?repoMatch?.source.baseUrlAliases,
    };

    final isExplicitWebParser = custom.parserKind != null &&
        !custom.parserKind!.startsWith('extension-runtime:');
    final builtInMatch = SourceCatalog.matchByName(custom.name, baseUrl) ??
        SourceCatalog.matchByUrl(baseUrl, fallbackBaseUrls: fallbackBaseUrls);

    final kind = isExplicitWebParser
        ? custom.parserKind
        : (builtInMatch != null
            ? null
            : (custom.parserKind?.startsWith('extension-runtime:') == true
                ? custom.parserKind
                : (repoMatch?.source.pkg != null
                    ? 'extension-runtime:${repoMatch!.source.pkg}'
                    : (repoMatch?.source.parserKind ?? custom.parserKind))));

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
    RepoSource? repoSource = repository.sources
        .where(
          (source) =>
              source.matchesName(sourceName) ||
              sameLibraryTitle(source.name, sourceName),
        )
        .firstOrNull;

    if (repoSource == null && comicId != null) {
      repoSource = repository.sources
          .where(
            (source) =>
                comicId.startsWith('src_rp-${repository.id}-${source.id}_'),
          )
          .firstOrNull;
    }

    if (repoSource == null && sourceMangaUrl != null && sourceMangaUrl.isNotEmpty) {
      final mangaUri = Uri.tryParse(sourceMangaUrl);
      final mangaHost = mangaUri?.host.toLowerCase() ?? '';
      if (mangaHost.isNotEmpty) {
        repoSource = repository.sources.where((source) {
          final uri = Uri.tryParse(source.baseUrl ?? '');
          final host = uri?.host.toLowerCase() ?? '';
          return host == mangaHost ||
              source.baseUrlAliases.any(
                (alias) => alias.toLowerCase().contains(mangaHost),
              );
        }).firstOrNull;
      }
    }

    if (repoSource == null) continue;
    final repoBase = repoSource.baseUrl ?? repository.url;
    final baseUrl = repoBase.startsWith('http')
        ? repoBase
        : 'https://$repoBase';
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
  if (builtIn != null) {
    final effectiveBaseUrl =
        sourceMangaUrl != null && sourceMangaUrl.trim().isNotEmpty
            ? SourceCatalog.originFromUrl(sourceMangaUrl)
            : builtIn.baseUrl;
    return SourceCatalog.buildAutomatic(sourceName, effectiveBaseUrl);
  }

  // Fallback darurat: jika nama tidak cocok di database manapun (misal saat
  // provider belum selesai sync atau komik web baru), gunakan langsung origin
  // URL komik yang tersimpan di library agar chapter tetap bisa dibuka.
  if (sourceMangaUrl != null && sourceMangaUrl.trim().isNotEmpty) {
    final origin = SourceCatalog.originFromUrl(sourceMangaUrl);
    if (origin.isNotEmpty) {
      return SourceCatalog.buildAutomatic(sourceName, origin);
    }
  }

  return null;
}
