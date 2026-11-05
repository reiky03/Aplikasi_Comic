import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/kizen_http_client.dart';
import '../data/source_session_store.dart';
import 'manga_source.dart';

/// Parser khusus untuk Softkomik (Next.js SSR).
class SoftkomikSource implements MangaSource {
  SoftkomikSource({
    this.name = 'Softkomik',
    this.baseUrl = 'https://softkomik.app',
    http.Client? client,
  }) : _client = client ?? createKizenHttpClient();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;

  String get _canonicalBaseUrl {
    final lower = baseUrl.toLowerCase();
    if (lower.contains('softkomik.co') || lower.contains('softkomik.org')) {
      return 'https://softkomik.app';
    }
    return baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  }

  Map<String, String> get _headers => {
    'Referer': '$_canonicalBaseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(_canonicalBaseUrl),
  };

  Uri _resolve(String raw) => Uri.parse(_canonicalBaseUrl).resolve(raw);

  String _cleanCoverUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('/_next/image?url=')) {
      final uri = Uri.tryParse(raw.startsWith('http') ? raw : '$_canonicalBaseUrl$raw');
      final inner = uri?.queryParameters['url'];
      if (inner != null && inner.isNotEmpty) {
        return Uri.decodeComponent(inner);
      }
    }
    return _resolve(raw).toString();
  }

  Future<dom.Document> _get(Uri url) async {
    try {
      final response = await _client
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 403) {
        throw MangaSourceWebViewException(
          url: url.toString(),
          message: '$name memerlukan verifikasi di WebView (HTTP 403).',
        );
      }
      if (response.statusCode != 200) {
        throw MangaSourceException(
          '$name mengembalikan status ${response.statusCode}.',
        );
      }
      return html_parser.parse(response.body);
    } catch (e) {
      if (e is MangaSourceWebViewException || e is MangaSourceException) rethrow;
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
  }

  List<SourceManga> _parseCards(dom.Document document) {
    final mangas = <SourceManga>[];
    final seen = <String>{};

    for (final anchor in document.querySelectorAll('a[href*="-bahasa-indonesia"]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty || href.contains('/chapter/')) continue;
      final fullUrl = _resolve(href).toString();
      if (!seen.add(fullUrl)) continue;

      var title = anchor.text.trim();
      final img = anchor.querySelector('img') ??
          anchor.parent?.querySelector('img') ??
          anchor.previousElementSibling?.querySelector('img');
      if (title.isEmpty || title == 'manhwa' || title == 'manga' || title == 'manhua') {
        title = img?.attributes['alt']?.trim() ?? '';
      }
      if (title.isEmpty) continue;

      final cover = _cleanCoverUrl(
        img?.attributes['src'] ?? img?.attributes['data-src'],
      );

      mangas.add(
        SourceManga(
          url: fullUrl,
          title: title,
          thumbnailUrl: cover.isEmpty ? null : cover,
          headers: _headers,
        ),
      );
    }

    return mangas;
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    final url = _resolve(page <= 1 ? '/komik/list' : '/komik/list?page=$page');
    final doc = await _get(url);
    final mangas = _parseCards(doc);
    return SourceMangaPage(
      mangas: mangas,
      hasNextPage: mangas.isNotEmpty && mangas.length >= 20,
    );
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    final url = _resolve(page <= 1 ? '/' : '/komik/list?page=$page');
    final doc = await _get(url);
    final mangas = _parseCards(doc);
    return SourceMangaPage(
      mangas: mangas,
      hasNextPage: mangas.isNotEmpty && mangas.length >= 20,
    );
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    final cleanQuery = query.trim();
    final url = _resolve(
      page <= 1
          ? '/komik/list?name=${Uri.encodeComponent(cleanQuery)}'
          : '/komik/list?name=${Uri.encodeComponent(cleanQuery)}&page=$page',
    );
    final doc = await _get(url);
    final mangas = _parseCards(doc);
    return SourceMangaPage(
      mangas: mangas,
      hasNextPage: mangas.isNotEmpty && mangas.length >= 20,
    );
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final doc = await _get(_resolve(mangaUrl));
    final ogDesc = doc.querySelector('meta[property="og:description"]')?.attributes['content'];
    final metaDesc = doc.querySelector('meta[name="description"]')?.attributes['content'];
    final ogImage = doc.querySelector('meta[property="og:image"]')?.attributes['content'];

    var description = ogDesc ?? metaDesc;
    final cover = _cleanCoverUrl(
      ogImage ?? doc.querySelector('img[src*="cover"]')?.attributes['src'],
    );

    final genres = <String>[];
    for (final badge in doc.querySelectorAll('a[href*="/type/"], a[href*="/genre/"]')) {
      final text = badge.text.trim();
      if (text.isNotEmpty && !genres.contains(text)) genres.add(text);
    }

    var status = SourceMangaStatus.ongoing;
    final bodyText = doc.body?.text.toLowerCase() ?? '';
    if (bodyText.contains('tamat') || bodyText.contains('completed')) {
      status = SourceMangaStatus.completed;
    }

    return SourceMangaDetails(
      description: description,
      status: status,
      genres: genres,
      thumbnailUrl: cover.isEmpty ? null : cover,
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final doc = await _get(_resolve(mangaUrl));
    final chapters = <SourceChapter>[];
    final seen = <String>{};

    for (final anchor in doc.querySelectorAll('a[href*="/chapter/"]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final fullUrl = _resolve(href).toString();
      if (!seen.add(fullUrl)) continue;

      var label = anchor.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (label.isEmpty) {
        final segments = Uri.parse(fullUrl).pathSegments;
        label = 'Chapter ${segments.isNotEmpty ? segments.last : ""}';
      }

      chapters.add(
        SourceChapter(
          url: fullUrl,
          name: label,
        ),
      );
    }

    if (chapters.isEmpty) {
      throw MangaSourceException('Daftar chapter $name belum dikenali.');
    }

    return chapters;
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final resolvedUrl = _resolve(chapterUrl);
    final doc = await _get(resolvedUrl);
    final pages = <SourcePage>[];
    final seen = <String>{};
    final referer = resolvedUrl.toString();

    for (final img in doc.querySelectorAll('img')) {
      final raw = img.attributes['src'] ?? img.attributes['data-src'];
      if (raw == null || raw.isEmpty) continue;
      if (raw.contains('icon.jpg') || raw.contains('logo') || raw.contains('manifest')) continue;
      if (!raw.contains('img-file') && !raw.contains('komik.im') && !raw.contains('softdevices')) continue;

      final fullUrl = _resolve(raw).toString();
      if (!seen.add(fullUrl)) continue;

      pages.add(
        SourcePage(
          index: pages.length,
          imageUrl: fullUrl,
          headers: {
            ..._headers,
            'Referer': referer,
          },
        ),
      );
    }

    if (pages.isEmpty) {
      throw MangaSourceException('Halaman baca chapter $name belum dikenali.');
    }

    return pages;
  }
}
