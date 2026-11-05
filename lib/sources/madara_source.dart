import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/kizen_http_client.dart';
import '../data/source_session_store.dart';
import 'manga_source.dart';

/// Parser tambahan buat keluarga WordPress Madara/MangaBooth.
///
/// Banyak situs terlihat seperti HTML WordPress biasa, tetapi katalog halaman
/// lanjut dan chapter-nya baru muncul lewat `madara_load_more` atau endpoint
/// AJAX `manga_get_chapters`. Parser universal tetap dicoba seperti sebelumnya;
/// class ini menjadi strategi tambahan ketika endpoint khusus itu dibutuhkan.
class MadaraSource implements MangaSource {
  MadaraSource({required this.name, required this.baseUrl, http.Client? client})
    : _client = client ?? createKizenHttpClient();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;
  bool? _usesLoadMore;

  Map<String, String> get _headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(baseUrl),
  };

  Map<String, String> get _xhrHeaders => {
    ..._headers,
    'X-Requested-With': 'XMLHttpRequest',
  };

  Uri _resolve(String raw) => Uri.parse(baseUrl).resolve(raw);

  String _absoluteUrl(String raw) => _resolve(raw).toString();

  Future<http.Response> _get(Uri url) async {
    try {
      return await _client
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      throw MangaSourceException('Gagal menghubungi $name: $error');
    }
  }

  Future<http.Response> _post(Uri url, Map<String, String> fields) async {
    try {
      return await _client
          .post(url, headers: _xhrHeaders, body: fields)
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      throw MangaSourceException('Gagal menghubungi $name: $error');
    }
  }

  Document _document(http.Response response) {
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    return html_parser.parse(response.body);
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) =>
      _catalog(page: page, order: _MadaraOrder.popular);

  @override
  Future<SourceMangaPage> fetchLatest(int page) =>
      _catalog(page: page, order: _MadaraOrder.latest);

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      _catalog(page: page, order: _MadaraOrder.latest, query: query.trim());

  Future<SourceMangaPage> _catalog({
    required int page,
    required _MadaraOrder order,
    String query = '',
  }) async {
    if (_usesLoadMore == true && page > 1) {
      final loaded = await _loadMore(page: page, order: order, query: query);
      if (loaded.mangas.isNotEmpty) return loaded;
    }

    final response = await _get(
      _archiveUri(page: page, order: order, query: query),
    );
    final document = _document(response);
    _usesLoadMore ??= document.querySelector('nav.navigation-ajax') != null;
    final mangas = _parseCards(document);
    if (mangas.isNotEmpty) {
      return SourceMangaPage(
        mangas: mangas,
        hasNextPage: _hasNextPage(document),
      );
    }

    if (_usesLoadMore != false) {
      final loaded = await _loadMore(page: page, order: order, query: query);
      if (loaded.mangas.isNotEmpty) {
        _usesLoadMore = true;
        return loaded;
      }
    }
    throw MangaSourceException('Katalog Madara $name belum dikenali.');
  }

  Uri _archiveUri({
    required int page,
    required _MadaraOrder order,
    required String query,
  }) {
    final pagePath = page <= 1 ? '' : 'page/$page/';
    if (query.isNotEmpty) {
      return _resolve(
        '/$pagePath',
      ).replace(queryParameters: {'s': query, 'post_type': 'wp-manga'});
    }
    return _resolve('/manga/$pagePath').replace(
      queryParameters: {
        'm_orderby': order == _MadaraOrder.latest ? 'latest' : 'views',
      },
    );
  }

  Future<SourceMangaPage> _loadMore({
    required int page,
    required _MadaraOrder order,
    required String query,
  }) async {
    final fields = <String, String>{
      'action': 'madara_load_more',
      'page': '${page - 1}',
      'template': query.isEmpty
          ? 'madara-core/content/content-archive'
          : 'madara-core/content/content-search',
      'vars[paged]': '1',
      'vars[post_type]': 'wp-manga',
      'vars[post_status]': 'publish',
      'vars[sidebar]': 'right',
      'vars[manga_archives_item_layout]': 'big_thumbnail',
      'vars[meta_query][0][key]': '_wp_manga_chapter_type',
      'vars[meta_query][0][value]': 'manga',
      if (query.isNotEmpty) ...{
        'vars[template]': 'archive',
        'vars[s]': query,
      } else ...{
        'vars[orderby]': 'meta_value_num',
        'vars[meta_key]': order == _MadaraOrder.latest
            ? '_latest_update'
            : '_wp_manga_views',
        'vars[order]': 'desc',
      },
    };
    final response = await _post(_resolve('/wp-admin/admin-ajax.php'), fields);
    if (response.statusCode != 200) {
      return const SourceMangaPage(mangas: [], hasNextPage: false);
    }
    final document = html_parser.parse(response.body);
    final mangas = _parseCards(document);
    return SourceMangaPage(
      mangas: mangas,
      hasNextPage:
          mangas.isNotEmpty &&
          !document.outerHtml.toLowerCase().contains('no-posts'),
    );
  }

  List<SourceManga> _parseCards(Document document) {
    final cards = document.querySelectorAll(
      'div.page-item-detail, .manga__item, div.c-tabs-item__content',
    );
    final mangas = <SourceManga>[];
    final seen = <String>{};
    for (final card in cards) {
      final link = card.querySelector(
        'div.post-title a, .post-title a, h3 a, h2 a',
      );
      final href = link?.attributes['href'];
      if (link == null || href == null || href.isEmpty) continue;
      final title = link.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (title.isEmpty) continue;
      final url = _absoluteUrl(href);
      if (!seen.add(url)) continue;
      final thumbnail = _imageUrl(card.querySelector('img'));
      mangas.add(
        SourceManga(
          url: url,
          title: title,
          thumbnailUrl: thumbnail,
          headers: thumbnail == null ? const {} : _headers,
        ),
      );
    }
    return mangas;
  }

  bool _hasNextPage(Document document) =>
      document.querySelector(
        'div.nav-previous, nav.navigation-ajax, a.nextpostslink, '
        '.pagination .next, .nav-links .next',
      ) !=
      null;

  String? _imageUrl(Element? image) {
    if (image == null) return null;
    for (final attribute in [
      'data-src',
      'data-lazy-src',
      'data-cfsrc',
      'data-manga-src',
      'srcset',
      'src',
    ]) {
      var value = image.attributes[attribute]?.trim();
      if (value == null || value.isEmpty || value.startsWith('data:')) continue;
      if (attribute == 'srcset') {
        final candidates = value
            .split(',')
            .map((part) => part.trim().split(RegExp(r'\s+')).first)
            .where((part) => part.isNotEmpty)
            .toList();
        if (candidates.isEmpty) continue;
        value = candidates.last;
      }
      final lower = value.toLowerCase();
      if (lower.contains('placeholder') || lower.contains('loading.')) continue;
      return _absoluteUrl(value);
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final document = _document(await _get(Uri.parse(_absoluteUrl(mangaUrl))));
    final description = document
        .querySelector(
          'div.description-summary div.summary__content, '
          'div.summary_content div.manga-excerpt, .summary__content',
        )
        ?.text
        .trim();
    final author = _joinedText(
      document.querySelectorAll(
        'div.author-content > a, div.manga-authors > a',
      ),
    );
    final artist = _joinedText(
      document.querySelectorAll('div.artist-content > a'),
    );
    final genres = document
        .querySelectorAll('div.genres-content a')
        .map((element) => element.text.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final statusText = document
        .querySelectorAll('div.summary-content')
        .map((element) => element.text.trim())
        .firstWhere(
          (value) => RegExp(
            r'ongoing|completed|complete|hiatus|cancel',
            caseSensitive: false,
          ).hasMatch(value),
          orElse: () => '',
        )
        .toLowerCase();
    return SourceMangaDetails(
      description: description == null || description.isEmpty
          ? null
          : description,
      author: author,
      artist: artist,
      genres: genres,
      status: statusText.contains('complete')
          ? SourceMangaStatus.completed
          : statusText.contains('hiatus')
          ? SourceMangaStatus.hiatus
          : statusText.contains('cancel')
          ? SourceMangaStatus.cancelled
          : statusText.contains('ongoing')
          ? SourceMangaStatus.ongoing
          : SourceMangaStatus.unknown,
      thumbnailUrl: _imageUrl(document.querySelector('div.summary_image img')),
    );
  }

  String? _joinedText(List<Element> elements) {
    final values = elements
        .map((element) => element.text.trim())
        .where(
          (value) =>
              value.isNotEmpty && !value.toLowerCase().contains('updating'),
        )
        .toSet()
        .toList();
    return values.isEmpty ? null : values.join(', ');
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final absoluteMangaUrl = _absoluteUrl(mangaUrl);
    final document = _document(await _get(Uri.parse(absoluteMangaUrl)));
    var chapters = _parseChapters(document);
    if (chapters.isNotEmpty) return chapters;

    final holder = document.querySelector('div[id^="manga-chapters-holder"]');
    final mangaId = holder?.attributes['data-id']?.trim();
    if (mangaId != null && mangaId.isNotEmpty) {
      final oldResponse = await _post(_resolve('/wp-admin/admin-ajax.php'), {
        'action': 'manga_get_chapters',
        'manga': mangaId,
      });
      if (oldResponse.statusCode == 200) {
        chapters = _parseChapters(html_parser.parse(oldResponse.body));
        if (chapters.isNotEmpty) return chapters;
      }
    }

    final newEndpoint = Uri.parse(
      '${absoluteMangaUrl.replaceFirst(RegExp(r'/+$'), '')}/ajax/chapters',
    );
    final newResponse = await _post(newEndpoint, const {});
    if (newResponse.statusCode == 200) {
      chapters = _parseChapters(html_parser.parse(newResponse.body));
      if (chapters.isNotEmpty) return chapters;
    }
    throw MangaSourceException('Daftar chapter Madara $name belum dikenali.');
  }

  List<SourceChapter> _parseChapters(Document document) {
    final chapters = <SourceChapter>[];
    final seen = <String>{};
    for (final row in document.querySelectorAll(
      'li.wp-manga-chapter, ul.main.version-chap li, .chapter-li, '
      'div.chapter-item, #chapterlist li, .listing-chapters_wrap li',
    )) {
      final link = row.querySelector('a');
      final href = link?.attributes['href'];
      if (link == null || href == null || href.isEmpty) continue;
      final url = _absoluteUrl(href);
      if (!seen.add(url)) continue;
      final chapterName = link.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      chapters.add(
        SourceChapter(
          url: url,
          name: chapterName.isEmpty ? _chapterNameFromUrl(url) : chapterName,
          dateUpload: _parseDate(
            row.querySelector('span.chapter-release-date')?.text ??
                row.querySelector('span a')?.attributes['title'] ??
                row.querySelector('img:not(.thumb)')?.attributes['alt'],
          ),
        ),
      );
    }
    return chapters;
  }

  String _chapterNameFromUrl(String url) {
    final segments = Uri.parse(
      url,
    ).pathSegments.where((segment) => segment.isNotEmpty).toList();
    return (segments.isEmpty ? 'Chapter' : segments.last)
        .replaceAll('-', ' ')
        .replaceAll('_', ' ');
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final value = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final lower = value.toLowerCase();
    final now = DateTime.now();
    if (lower == 'today' || lower == 'hari ini') return now;
    if (lower == 'yesterday' || lower == 'kemarin') {
      return now.subtract(const Duration(days: 1));
    }
    final relative = RegExp(
      r'(\d+)\s*(second|minute|hour|day|week|month|year|detik|menit|jam|hari|minggu|bulan|tahun)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (relative != null) {
      final count = int.parse(relative.group(1)!);
      final unit = relative.group(2)!;
      return now.subtract(switch (unit) {
        'second' || 'detik' => Duration(seconds: count),
        'minute' || 'menit' => Duration(minutes: count),
        'hour' || 'jam' => Duration(hours: count),
        'day' || 'hari' => Duration(days: count),
        'week' || 'minggu' => Duration(days: count * 7),
        'month' || 'bulan' => Duration(days: count * 30),
        _ => Duration(days: count * 365),
      });
    }
    final monthDate = RegExp(
      r'^(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(value);
    if (monthDate == null) return null;
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return DateTime(
      int.parse(monthDate.group(3)!),
      months[monthDate.group(1)!.toLowerCase()]!,
      int.parse(monthDate.group(2)!),
    );
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final absoluteChapterUrl = _absoluteUrl(chapterUrl);
    final document = _document(await _get(Uri.parse(absoluteChapterUrl)));
    final pages = <SourcePage>[];
    final seen = <String>{};
    final pageHeaders = {..._headers, 'Referer': absoluteChapterUrl};
    for (final element in document.querySelectorAll(
      'div.page-break, li.blocks-gallery-item, '
      '.reading-content .text-left img, .reading-content img, '
      '#readerarea img, .chapter-content img, .wp-manga-chapter-img img, '
      'div.page-break img, .entry-content img, div.item-content img',
    )) {
      final image = element.localName == 'img'
          ? element
          : element.querySelector('img');
      final url = _imageUrl(image);
      if (url == null || !seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
      );
    }
    if (pages.isEmpty) {
      throw MangaSourceException('Gambar chapter Madara $name belum dikenali.');
    }
    return pages;
  }
}

enum _MadaraOrder { popular, latest }
