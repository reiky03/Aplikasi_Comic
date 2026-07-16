import 'komiku_source.dart';
import 'manga_source.dart';
import 'mangathemesia_source.dart';
import 'natsuid_source.dart';
import 'shinigami_source.dart';

/// Sumber yang punya parser native (lihat file lain di `lib/sources/`),
/// dicocokkan dari URL yang diketik user di Add Source. Situs di luar
/// daftar ini tetap bisa ditambahkan seperti biasa, tapi baca kontennya
/// masih lewat WebView Session Mode (spek 10), bukan parser otomatis.
abstract final class SourceCatalog {
  static final List<MangaSource> sources = [
    ShinigamiSource(),
    KomikuSource(),
    MangaThemesiaSource(name: 'Komikindo', baseUrl: 'https://komikindo.ch'),
    NatsuIdSource(name: 'Ikiru', baseUrl: 'https://06.ikiru.wtf'),
  ];

  /// Cari parser yang host base URL-nya cocok dengan [url] yang diketik user.
  static MangaSource? matchByUrl(String url) {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final source in sources) {
      final host = Uri.parse(source.baseUrl).host.toLowerCase();
      if (normalized.contains(host)) return source;
    }
    return null;
  }
}
