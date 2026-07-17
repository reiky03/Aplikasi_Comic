import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/source_session_store.dart';
import 'manga_source.dart';

/// Parser native untuk Komiku (https://komiku.org) — diporting dari
/// extension Kotlin open-source `keiyoushi/extensions-source`
/// (src/id/komiku/.../Komiku.kt).
///
/// Catatan: selector jsoup di Kotlin memakai `:contains()`/`:has()` yang
/// tidak didukung `package:html` di Dart — bagian itu ditulis ulang
/// sebagai traversal manual, logikanya tetap sama.
class KomikuSource implements MangaSource {
  KomikuSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiUrl = 'https://api.komiku.org';

  @override
  String get name => 'Komiku';

  @override
  String get baseUrl => 'https://komiku.org';

  Map<String, String> get _headers => {
    'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(baseUrl),
  };

  Future<Document> _getHtml(Uri url) async {
    late final http.Response response;
    try {
      response = await _client.get(url, headers: _headers);
    } catch (e) {
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
    if (response.statusCode == 404) {
      return html_parser.parse('');
    }
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    return html_parser.parse(response.body);
  }

  String _absUrl(String href) => Uri.parse(baseUrl).resolve(href).toString();

  String _removeQuery(String url) {
    final i = url.indexOf('?');
    return i == -1 ? url : url.substring(0, i);
  }

  Map<String, String> _imageHeaders(String imageUrl, String referer) => {
    ..._headers,
    'Accept':
        'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'Referer': referer,
    'Sec-Fetch-Dest': 'image',
    'Sec-Fetch-Mode': 'no-cors',
    'Sec-Fetch-Site': _sameSite(imageUrl) ? 'same-site' : 'cross-site',
  };

  bool _sameSite(String imageUrl) {
    final imageHost = Uri.tryParse(imageUrl)?.host;
    final baseHost = Uri.tryParse(baseUrl)?.host;
    if (imageHost == null || baseHost == null) return false;
    return imageHost == baseHost || imageHost.endsWith('.$baseHost');
  }

  Future<SourceMangaPage> _list({
    required int page,
    String? orderby,
    String? query,
  }) async {
    final segments = [
      'manga',
      if (page > 1) ...['page', '$page'],
    ];
    final url = Uri.parse(_apiUrl).replace(
      pathSegments: segments,
      queryParameters: {
        'orderby': ?orderby,
        if (query != null && query.isNotEmpty) 's': query,
      },
    );
    final document = await _getHtml(url);
    final mangas = document.querySelectorAll('div.bge').map((el) {
      final titleEl = el.querySelector('h3');
      final linkEl = el.querySelector('a');
      final imgEl = el.querySelector('img');
      final href = linkEl?.attributes['href'] ?? '';
      return SourceManga(
        url: _absUrl(href),
        title: titleEl?.text.trim() ?? '',
        thumbnailUrl: imgEl == null
            ? null
            : _removeQuery(_absUrl(imgEl.attributes['src'] ?? '')),
      );
    }).toList();
    final hasNextPage =
        document.querySelector('span[hx-get]') != null || mangas.length >= 10;
    return SourceMangaPage(mangas: mangas, hasNextPage: hasNextPage);
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) =>
      _list(page: page, orderby: 'meta_value_num');

  @override
  Future<SourceMangaPage> fetchLatest(int page) =>
      _list(page: page, orderby: 'modified');

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      _list(page: page, query: query);

  /// Cari `<td>` yang teksnya mengandung salah satu [labels], lalu
  /// kembalikan teks `<td>` berikutnya (setara `td:contains(x)+td` jsoup).
  String? _tableValue(Document document, List<String> labels) {
    for (final td in document.querySelectorAll('table.inftable td')) {
      final text = td.text.trim();
      if (labels.any((l) => text.toLowerCase().contains(l.toLowerCase()))) {
        final next = td.nextElementSibling;
        if (next != null && next.localName == 'td') {
          return next.text.trim();
        }
      }
    }
    return null;
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));

    final sinopsis = document.querySelector('#Sinopsis > p')?.text.trim();
    final judulIndonesia = _tableValue(document, ['Judul Indonesia']);
    final description = [
      if (sinopsis != null && sinopsis.isNotEmpty) sinopsis,
      if (judulIndonesia != null && judulIndonesia.isNotEmpty)
        'Judul Indonesia: $judulIndonesia',
    ].join('\n\n');

    final author = _tableValue(document, ['Pengarang', 'Komikus']);
    final genres = document
        .querySelectorAll('ul.genre li.genre a span')
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final statusText = _tableValue(document, ['Status']);
    final thumb = document.querySelector('div.ims > img');

    return SourceMangaDetails(
      description: description.isEmpty ? null : description,
      author: author,
      genres: genres,
      status: _parseStatus(statusText),
      thumbnailUrl: thumb == null
          ? null
          : _removeQuery(_absUrl(thumb.attributes['src'] ?? '')),
    );
  }

  SourceMangaStatus _parseStatus(String? status) {
    if (status == null) return SourceMangaStatus.unknown;
    final s = status.toLowerCase();
    if (s.contains('ongoing') || s.contains('on going')) {
      return SourceMangaStatus.ongoing;
    }
    if (s.contains('end') || s.contains('completed')) {
      return SourceMangaStatus.completed;
    }
    return SourceMangaStatus.unknown;
  }

  DateTime? _parseChapterDate(String text) {
    final trimmed = text.trim();
    if (trimmed.contains('lalu')) {
      final parts = trimmed.split(' lalu').first.trim().split(' ');
      if (parts.length < 2) return null;
      final n = int.tryParse(parts[0]) ?? 0;
      final unit = parts[1].toLowerCase();
      final now = DateTime.now();
      if (unit.startsWith('jam')) return now.subtract(Duration(hours: n));
      if (unit.startsWith('menit')) return now.subtract(Duration(minutes: n));
      if (unit.startsWith('detik')) return now;
      return now;
    }
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));
    final container = document.querySelector('#Daftar_Chapter');
    if (container == null) return const [];
    final rows = container
        .querySelectorAll('tr')
        .where((tr) => tr.querySelector('td.judulseries') != null);
    return rows.map((tr) {
      final a = tr.querySelector('a')!;
      final dateText = tr.querySelector('td.tanggalseries')?.text.trim() ?? '';
      return SourceChapter(
        url: _absUrl(a.attributes['href'] ?? ''),
        name: a.text.trim(),
        dateUpload: _parseChapterDate(dateText),
      );
    }).toList();
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final document = await _getHtml(Uri.parse(chapterUrl));
    final imgs = document.querySelectorAll('#Baca_Komik img');
    return [
      for (var i = 0; i < imgs.length; i++)
        SourcePage(
          index: i,
          imageUrl: _absUrl(imgs[i].attributes['src'] ?? ''),
          headers: _imageHeaders(
            _absUrl(imgs[i].attributes['src'] ?? ''),
            chapterUrl,
          ),
        ),
    ];
  }
}
