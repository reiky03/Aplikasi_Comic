import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_source.dart';

/// Parser native untuk situs bertema WordPress "MangaThemesia" (dipakai
/// ratusan situs komik, termasuk Komikindo) — diporting dari
/// `lib-multisrc/mangathemesia` di `keiyoushi/extensions-source`.
/// Reusable: cukup buat instance baru dengan [baseUrl]/[name] beda untuk
/// situs MangaThemesia lain.
class MangaThemesiaSource implements MangaSource {
  MangaThemesiaSource({
    required this.name,
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;

  Map<String, String> get _headers => {
        'Referer': '$baseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      };

  Future<Document> _getHtml(Uri url) async {
    late final http.Response response;
    try {
      response = await _client.get(url, headers: _headers);
    } catch (e) {
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    return html_parser.parse(response.body);
  }

  String _absUrl(String href) => Uri.parse(baseUrl).resolve(href).toString();

  /// Setara `imgAttr()` Kotlin — situs lazy-load gambar via atribut lain.
  String _imgAttr(Element img) {
    for (final attr in ['data-lazy-src', 'data-src', 'data-cfsrc']) {
      final v = img.attributes[attr];
      if (v != null && v.isNotEmpty) return _absUrl(v);
    }
    return _absUrl(img.attributes['src'] ?? '');
  }

  Future<SourceMangaPage> _search({
    required int page,
    String query = '',
    required String order,
  }) async {
    final url = Uri.parse('$baseUrl/manga/').replace(queryParameters: {
      'title': query,
      'page': '$page',
      'order': order,
    });
    final document = await _getHtml(url);
    final mangas = document
        .querySelectorAll('.utao .uta .imgu, .listupd .bs .bsx, .listo .bs .bsx')
        .map((el) {
      final a = el.querySelector('a');
      final img = el.querySelector('img');
      return SourceManga(
        url: _absUrl(a?.attributes['href'] ?? ''),
        title: a?.attributes['title'] ?? '',
        thumbnailUrl: img == null ? null : _imgAttr(img),
      );
    }).toList();
    final hasNextPage =
        document.querySelector('div.pagination .next, div.hpage .r') != null;
    return SourceMangaPage(mangas: mangas, hasNextPage: hasNextPage);
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) =>
      _search(page: page, order: 'popular');

  @override
  Future<SourceMangaPage> fetchLatest(int page) =>
      _search(page: page, order: 'update');

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      _search(page: page, query: query, order: '');

  /// Cari label (mis. "Author"/"Pengarang") di pola umum tema
  /// (`.infotable tr`, `.tsinfo .imptdt`) lalu ambil isinya — setara
  /// `td:contains(x) td:last-child` dkk di jsoup (tak didukung Dart).
  String? _labelValue(Document document, List<String> labels) {
    for (final tr in document.querySelectorAll('.infotable tr')) {
      final cells = tr.querySelectorAll('td');
      if (cells.length < 2) continue;
      final label = cells.first.text.trim();
      if (labels.any((l) => label.toLowerCase().contains(l.toLowerCase()))) {
        final value = cells.last.text.trim();
        if (value.isNotEmpty && value != '-') return value;
      }
    }
    for (final el in document.querySelectorAll('.tsinfo .imptdt')) {
      final text = el.text.trim();
      if (labels.any((l) => text.toLowerCase().startsWith(l.toLowerCase()))) {
        final value = el.querySelector('i')?.text.trim() ??
            el.querySelector('a')?.text.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));
    final description = document
        .querySelectorAll('.desc, .entry-content[itemprop=description]')
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
    final genres = document
        .querySelectorAll('div.gnr a, .mgen a, .seriestugenre a')
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final thumb = document.querySelector(
        '.infomanga > div[itemprop=image] img, .thumb img');
    final status = _labelValue(document, ['status']);

    return SourceMangaDetails(
      description: description.isEmpty ? null : description,
      author: _labelValue(document, ['author', 'pengarang', 'mangaka']),
      artist: _labelValue(document, ['artist', 'seniman']),
      genres: genres,
      status: _parseStatus(status),
      thumbnailUrl: thumb == null ? null : _imgAttr(thumb),
    );
  }

  SourceMangaStatus _parseStatus(String? status) {
    if (status == null) return SourceMangaStatus.unknown;
    final s = status.toLowerCase();
    if (['ongoing', 'on going', 'berjalan', 'publishing']
        .any((k) => s.contains(k))) {
      return SourceMangaStatus.ongoing;
    }
    if (['completed', 'tamat', 'finished'].any((k) => s.contains(k))) {
      return SourceMangaStatus.completed;
    }
    if (['hiatus', 'on hold', 'pausado'].any((k) => s.contains(k))) {
      return SourceMangaStatus.hiatus;
    }
    if (['dropped', 'discontinued', 'canceled', 'cancelled']
        .any((k) => s.contains(k))) {
      return SourceMangaStatus.cancelled;
    }
    return SourceMangaStatus.unknown;
  }

  static const _months = [
    'january', 'february', 'march', 'april', 'may', 'june', 'july',
    'august', 'september', 'october', 'november', 'december', //
  ];

  /// Parser tanggal format umum tema ("January 15, 2024") tanpa perlu
  /// paket `intl`.
  DateTime? _parseChapterDate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match =
        RegExp(r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$').firstMatch(text.trim());
    if (match == null) return null;
    final monthIndex = _months.indexOf(match.group(1)!.toLowerCase());
    if (monthIndex == -1) return null;
    return DateTime(
      int.parse(match.group(3)!),
      monthIndex + 1,
      int.parse(match.group(2)!),
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));
    final rows =
        document.querySelectorAll('div.bxcl li, div.cl li, #chapterlist li');
    return rows.map((el) {
      final a = el.querySelector('a');
      final name = el.querySelector('.lch a, .chapternum')?.text.trim() ??
          a?.text.trim() ??
          '';
      final date = el.querySelector('.chapterdate')?.text.trim();
      return SourceChapter(
        url: _absUrl(a?.attributes['href'] ?? ''),
        name: name,
        dateUpload: _parseChapterDate(date),
      );
    }).toList();
  }

  static final _imageListRegex = RegExp(r'"images"\s*:\s*(\[.*?\])');

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final document = await _getHtml(Uri.parse(chapterUrl));
    final imgs = document.querySelectorAll('div#readerarea img');
    if (imgs.isNotEmpty) {
      return [
        for (var i = 0; i < imgs.length; i++)
          SourcePage(index: i, imageUrl: _imgAttr(imgs[i])),
      ];
    }
    // Sejumlah situs memuat halaman lewat JavaScript — cari array
    // "images": [...] tertanam di script.
    final match = _imageListRegex.firstMatch(document.outerHtml);
    if (match == null) return const [];
    final urls = RegExp(r'"([^"]+)"')
        .allMatches(match.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
    return [
      for (var i = 0; i < urls.length; i++)
        SourcePage(index: i, imageUrl: urls[i]),
    ];
  }
}
