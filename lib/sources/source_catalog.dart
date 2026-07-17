import 'asura_source.dart';
import 'extension_runtime_source.dart';
import 'komiku_source.dart';
import 'manga_source.dart';
import 'mangathemesia_source.dart';
import 'natsuid_source.dart';
import 'shinigami_source.dart';
import 'universal_html_source.dart';

/// Sumber yang punya parser native (lihat file lain di `lib/sources/`),
/// dicocokkan dari URL yang diketik user di Add Source. Situs di luar
/// daftar ini tetap bisa ditambahkan seperti biasa, tapi baca kontennya
/// masih lewat WebView Session Mode (spek 10), bukan parser otomatis.
abstract final class SourceCatalog {
  static final List<MangaSource> sources = [
    AsuraSource(),
    ShinigamiSource(),
    KomikuSource(),
    MangaThemesiaSource(name: 'Komikindo', baseUrl: 'https://komikindo.ch'),
    NatsuIdSource(name: 'Ikiru', baseUrl: 'https://06.ikiru.wtf'),
  ];

  static const Map<String, List<String>> _hostAliases = {
    'Asura Scans': ['asurascans.com', 'asuracomic.net'],
  };

  /// Cari parser yang host base URL-nya cocok dengan [url] yang diketik user.
  static MangaSource? matchByUrl(String url) {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final source in sources) {
      final host = Uri.parse(source.baseUrl).host.toLowerCase();
      final aliases = _hostAliases[source.name] ?? const <String>[];
      if (normalized.contains(host) ||
          aliases.any((alias) => normalized.contains(alias))) {
        return source;
      }
    }
    return null;
  }

  /// Parser TEMA GENERIK — bukan situs spesifik, tapi pola/struktur HTML
  /// yang dipakai BANYAK situs komik Indonesia sekaligus (mis. WordPress
  /// theme "MangaThemesia" dipakai ratusan situs, bukan cuma Komikindo).
  /// Kalau situs custom yang user tambahkan kebetulan pakai salah satu
  /// tema ini, kita bisa langsung baca otomatis TANPA perlu nulis parser
  /// baru khusus — lihat [detectGeneric].
  static const genericKinds = ['mangathemesia', 'natsuid', 'universal-html'];

  /// Bangun instance parser generik dari [kind] (hasil [detectGeneric]
  /// yang tersimpan di `ComicSource.parserKind`) + nama/base URL sumber
  /// custom-nya.
  static MangaSource? buildGeneric(
    String kind,
    String name,
    String baseUrl, {
    String? lang,
  }) {
    if (kind.startsWith('extension-runtime:')) {
      final packageName = kind.substring('extension-runtime:'.length).trim();
      if (packageName.isEmpty) return null;
      return ExtensionRuntimeSource(
        name: name,
        packageName: packageName,
        baseUrl: baseUrl,
        lang: lang,
      );
    }
    return switch (kind) {
      'mangathemesia' => MangaThemesiaSource(name: name, baseUrl: baseUrl),
      'natsuid' => NatsuIdSource(name: name, baseUrl: baseUrl),
      'universal-html' => UniversalHtmlSource(name: name, baseUrl: baseUrl),
      _ => null,
    };
  }

  /// Coba tiap parser tema generik terhadap [baseUrl] — "banyak metode
  /// coba buka link komiknya", persis yang diminta user. Kembalikan kind
  /// parser PERTAMA yang berhasil ambil daftar populer TANPA error dan
  /// hasilnya tidak kosong (sinyal kuat struktur HTML-nya cocok).
  /// Sekuensial, berhenti di percobaan pertama yang berhasil.
  static Future<String?> detectGeneric(String name, String baseUrl) async {
    for (final kind in genericKinds) {
      final source = buildGeneric(kind, name, baseUrl);
      if (source == null) continue;
      try {
        final result = await source.fetchPopular(1);
        if (result.mangas.isNotEmpty) return kind;
      } catch (_) {
        // Struktur gak cocok / situs nolak — lanjut coba kind berikutnya.
      }
    }
    return null;
  }
}
