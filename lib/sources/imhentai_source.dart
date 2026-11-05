import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../data/extension_runtime.dart';
import '../data/kizen_http_client.dart';
import '../data/source_session_store.dart';
import '../data/source_url.dart';
import 'manga_source.dart';

/// Sumber bawaan untuk IMHentai (https://imhentai.xxx).
///
/// IMHentai menyajikan manga/doujinshi dalam bentuk galeri utuh.
/// Seluruh halaman pembaca (page list) dihitung langsung dari metadata
/// gambar JSON tersemat (`load_server`, `load_dir`, `load_id`, dan `g_th`)
/// sehingga pembacaan cepat tanpa perlu request halaman satu per satu.
class ImhentaiSource implements MangaSource {
  ImhentaiSource({
    this.name = 'IMHentai',
    this.baseUrl = 'https://imhentai.xxx',
    http.Client? client,
  }) : _client = client ?? createKizenHttpClient();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;

  Map<String, String> get _headers {
    final session = SourceSessionStore.headersFor(baseUrl);
    return {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'same-origin',
      'Upgrade-Insecure-Requests': '1',
      'Referer': '$baseUrl/',
      'User-Agent': session['User-Agent'] ??
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      if (session.containsKey('Cookie')) 'Cookie': session['Cookie']!,
    };
  }

  Future<Document> _fetchDocument(String targetUrl) async {
    final uri = Uri.parse(targetUrl);
    http.Response? response;
    try {
      response = await _client.get(uri, headers: _headers);
    } catch (_) {
      // Jika request network gagal (koneksi ditolak/diblokir), coba langsung via headless WebView
    }

    final isBlocked = response == null ||
        response.statusCode == 403 ||
        response.body.contains('Just a moment...') ||
        response.body.contains('challenges.cloudflare.com');

    if (isBlocked) {
      // 1. Coba periksa apakah CookieManager native Android sudah memiliki sesi/clearance
      try {
        final session = await const ExtensionRuntimeBridge().readWebViewSession(baseUrl);
        final cookie = session.cookie ?? '';
        if (cookie.isNotEmpty) {
          await SourceSessionStore.save(
            url: baseUrl,
            cookie: cookie,
            userAgent: session.userAgent,
          );
          response = await _client.get(uri, headers: _headers);
        }
      } catch (_) {}
    }

    final stillBlocked = response == null ||
        response.statusCode == 403 ||
        response.body.contains('Just a moment...') ||
        response.body.contains('challenges.cloudflare.com');

    if (stillBlocked) {
      // 2. Coba headless WebView render bawaan Kizen
      try {
        final renderedHtml = await const ExtensionRuntimeBridge()
            .renderHtmlWithWebView(
              targetUrl,
              sessionHeaders: _headers,
            )
            .timeout(const Duration(seconds: 12));
        if (renderedHtml.isNotEmpty &&
            !renderedHtml.contains('Just a moment...') &&
            !renderedHtml.contains('challenges.cloudflare.com') &&
            (renderedHtml.contains('thumb') ||
                renderedHtml.contains('left_cover') ||
                renderedHtml.contains('gthumb') ||
                renderedHtml.contains('load_id'))) {
          try {
            final updatedSession =
                await const ExtensionRuntimeBridge().readWebViewSession(baseUrl);
            if (updatedSession.cookie != null &&
                updatedSession.cookie!.isNotEmpty) {
              await SourceSessionStore.save(
                url: baseUrl,
                cookie: updatedSession.cookie!,
                userAgent: updatedSession.userAgent,
              );
            }
          } catch (_) {}
          return html.parse(renderedHtml);
        }
      } catch (_) {}
    }

    if (response == null) {
      throw MangaSourceWebViewException(
        url: targetUrl,
        message:
            'Gagal menghubungi IMHentai. Aktifkan VPN Kizen atau buka lewat WebView.',
      );
    }

    if (response.statusCode == 403 ||
        response.body.contains('Just a moment...') ||
        response.body.contains('challenges.cloudflare.com')) {
      throw MangaSourceWebViewException(
        url: targetUrl,
        message:
            'Cloudflare Turnstile terdeteksi (HTTP 403). Selesaikan verifikasi sekali di WebView untuk membuka akses.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'HTTP ${response.statusCode} saat mengakses $targetUrl',
      );
    }

    return html.parse(response.body);
  }

  SourceMangaPage _parseCatalog(Document doc) {
    final thumbs = doc.querySelectorAll('div.thumb');
    final mangas = <SourceManga>[];

    for (final thumb in thumbs) {
      final captionEl = thumb.querySelector('.caption');
      final title = captionEl?.text.trim() ?? '';
      if (title.isEmpty) continue;

      final linkEl = thumb.querySelector('.inner_thumb a');
      final rawHref = linkEl?.attributes['href']?.trim() ?? '';
      if (rawHref.isEmpty) continue;

      final mangaUrl = rawHref.startsWith('http')
          ? rawHref
          : rebaseSourceUrl(rawHref, baseUrl);

      final imgEl = thumb.querySelector('.inner_thumb img');
      final thumbUrl =
          imgEl?.attributes['data-src']?.trim() ??
          imgEl?.attributes['src']?.trim();

      mangas.add(
        SourceManga(
          title: title,
          url: mangaUrl,
          thumbnailUrl: thumbUrl,
          headers: {'Referer': '$baseUrl/'},
        ),
      );
    }

    final hasNext =
        doc.querySelector('.pagination li.active + li:not(.disabled)') !=
            null ||
        doc.querySelector("a[rel='next']") != null;

    return SourceMangaPage(mangas: mangas, hasNextPage: hasNext);
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    final url = '$baseUrl/popular/?page=$page';
    final doc = await _fetchDocument(url);
    return _parseCatalog(doc);
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    final url = '$baseUrl/?page=$page';
    final doc = await _fetchDocument(url);
    return _parseCatalog(doc);
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    final cleanQuery = Uri.encodeComponent(query.trim());
    final url = '$baseUrl/search/?key=$cleanQuery&page=$page';
    final doc = await _fetchDocument(url);
    return _parseCatalog(doc);
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final fullUrl = mangaUrl.startsWith('http')
        ? mangaUrl
        : rebaseSourceUrl(mangaUrl, baseUrl);
    final doc = await _fetchDocument(fullUrl);

    final coverEl =
        doc.querySelector('.left_cover img') ?? doc.querySelector('.cover img');
    final coverUrl =
        coverEl?.attributes['data-src']?.trim() ??
        coverEl?.attributes['src']?.trim();

    final tags = doc
        .querySelectorAll('a.tag')
        .map((e) => e.text.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    final artistEl = doc
        .querySelectorAll('li')
        .where((li) => li.querySelector('.tags_text')?.text.contains('Artists:') == true)
        .expand((li) => li.querySelectorAll('a.tag'))
        .firstOrNull;
    final author = artistEl?.text.trim();

    final totalPages =
        doc.querySelector('input#load_pages')?.attributes['value']?.trim();

    final descParts = <String>[];
    if (totalPages != null && totalPages.isNotEmpty) {
      descParts.add('Pages: $totalPages');
    }
    final subtitle = doc.querySelector('h1 + h2, .subtitle')?.text.trim();
    if (subtitle != null && subtitle.isNotEmpty) {
      descParts.add('Subtitle: $subtitle');
    }

    return SourceMangaDetails(
      thumbnailUrl: coverUrl,
      author: author,
      artist: author,
      description: descParts.join('\n'),
      genres: tags,
      status: SourceMangaStatus.completed,
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final fullUrl = mangaUrl.startsWith('http')
        ? mangaUrl
        : rebaseSourceUrl(mangaUrl, baseUrl);

    return [
      SourceChapter(
        name: 'Full Gallery',
        url: fullUrl,
        dateUpload: null,
      ),
    ];
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final fullUrl = chapterUrl.startsWith('http')
        ? chapterUrl
        : rebaseSourceUrl(chapterUrl, baseUrl);
    final doc = await _fetchDocument(fullUrl);

    final server =
        doc.querySelector('input#load_server')?.attributes['value']?.trim() ??
        '';
    final loadDir =
        doc.querySelector('input#load_dir')?.attributes['value']?.trim() ?? '';
    final loadId =
        doc.querySelector('input#load_id')?.attributes['value']?.trim() ?? '';
    final totalPages = int.tryParse(
      doc.querySelector('input#load_pages')?.attributes['value']?.trim() ?? '',
    );

    final serverHost = server.isNotEmpty ? 'm$server.imhentai.xxx' : 'm1.imhentai.xxx';

    // Coba parsing JSON dari blok script $.parseJSON('...')
    final scriptContent = doc
        .querySelectorAll('script')
        .map((s) => s.text)
        .firstWhere(
          (text) => text.contains('parseJSON('),
          orElse: () => '',
        );

    final pages = <SourcePage>[];
    if (scriptContent.isNotEmpty && loadDir.isNotEmpty && loadId.isNotEmpty) {
      final match = RegExp(r"parseJSON\('([^']+)'\)").firstMatch(scriptContent);
      if (match != null) {
        final rawJson = match.group(1);
        if (rawJson != null) {
          try {
            final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
            final sortedKeys = decoded.keys.toList()
              ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

            for (final key in sortedKeys) {
              final rawVal = decoded[key].toString();
              final extCode = rawVal.split(',').first.replaceAll('"', '').trim();
              final ext = switch (extCode) {
                'p' => 'png',
                'b' => 'bmp',
                'g' => 'gif',
                'w' => 'webp',
                _ => 'jpg',
              };
              final pageNum = int.tryParse(key) ?? 1;
              final pageIdx = pageNum - 1;
              final imageUrl = 'https://$serverHost/$loadDir/$loadId/$key.$ext';

              pages.add(
                SourcePage(
                  index: pageIdx,
                  imageUrl: imageUrl,
                  headers: {
                    'Referer': '$baseUrl/',
                    'User-Agent': _headers['User-Agent']!,
                  },
                ),
              );
            }
          } catch (_) {}
        }
      }
    }

    if (pages.isNotEmpty) return pages;

    // Fallback: jika parseJSON tidak ada, gunakan thumbnails dari .gthumb
    final thumbImgs = doc.querySelectorAll('.gthumb img, .gallery_thumb img');
    if (thumbImgs.isNotEmpty) {
      for (var i = 0; i < thumbImgs.length; i++) {
        final tUrl =
            thumbImgs[i].attributes['data-src']?.trim() ??
            thumbImgs[i].attributes['src']?.trim() ??
            '';
        if (tUrl.isEmpty) continue;
        // Thumbnail biasanya /u_dir/gallery/123/1t.jpg -> jadikan /u_dir/gallery/123/1.jpg
        final fullImgUrl = tUrl.replaceAllMapped(
          RegExp(r't\.([a-zA-Z]+)$'),
          (m) => '.${m[1]}',
        );
        pages.add(
          SourcePage(
            index: i,
            imageUrl: fullImgUrl,
            headers: {
              'Referer': '$baseUrl/',
              'User-Agent': _headers['User-Agent']!,
            },
          ),
        );
      }
      return pages;
    }

    // Fallback terakhir: jika hanya loadPages yang diketahui
    if (totalPages != null && totalPages > 0 && loadDir.isNotEmpty && loadId.isNotEmpty) {
      for (var i = 1; i <= totalPages; i++) {
        pages.add(
          SourcePage(
            index: i - 1,
            imageUrl: 'https://$serverHost/$loadDir/$loadId/$i.jpg',
            headers: {
              'Referer': '$baseUrl/',
              'User-Agent': _headers['User-Agent']!,
            },
          ),
        );
      }
    }

    return pages;
  }
}
