import 'asura_source.dart';
import 'adaptive_source.dart';
import 'doujindesu_source.dart';
import 'extension_runtime_source.dart';
import 'imhentai_source.dart';
import 'komiku_source.dart';
import 'manga_source.dart';
import 'mangafire_source.dart';
import 'madara_source.dart';
import 'mangathemesia_source.dart';
import 'natsuid_source.dart';
import 'shinigami_source.dart';
import 'sveltekit_comic_source.dart';
import 'universal_html_source.dart';

import '../data/source_url.dart';

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
    NatsuIdSource(name: 'Ikiru', baseUrl: 'https://07.ikiru.wtf'),
  ];

  static const Map<String, List<String>> _hostAliases = {
    'Asura Scans': ['asurascans.com', 'asuracomic.net'],
    // Shinigami rutin memakai subdomain bernomor (contoh yang tersimpan di HP
    // user: 11.shinigami.asia), sedangkan parser API kanonis memakai
    // g.shinigami.asia. Cocokkan domain induknya supaya keduanya satu sumber.
    'Shinigami': ['shinigami.asia', 'shngm.io', 'shngm.id'],
    'Ikiru': ['ikiru.id', 'ikiru.wtf', '07.ikiru.wtf'],
  };

  /// Cari parser yang host base URL-nya cocok dengan [url] yang diketik user.
  static MangaSource? matchByUrl(
    String url, {
    Iterable<String> fallbackBaseUrls = const [],
  }) {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final source in sources) {
      final host = Uri.tryParse(source.baseUrl)?.host.toLowerCase() ?? '';
      final aliases = _hostAliases[source.name] ?? const <String>[];
      if ((host.isNotEmpty && normalized.contains(host)) ||
          aliases.any((alias) => normalized.contains(alias))) {
        return buildAutomatic(
          source.name,
          _originFromUrl(url),
          fallbackBaseUrls: fallbackBaseUrls,
        );
      }
    }
    return null;
  }

  /// Jalur buka sumber juga mengenali parser bawaan dari NAMA sumber. Tes
  /// Sumber wajib punya fallback yang sama agar domain mirror/nomor baru tidak
  /// merah padahal komiknya bisa dibuka lewat parser native.
  static MangaSource? matchByName(String name, String url) {
    final normalizedName = name.trim().toLowerCase();
    final source = sources
        .where((candidate) => candidate.name.toLowerCase() == normalizedName)
        .firstOrNull;
    if (source == null) return null;
    return buildAutomatic(source.name, _originFromUrl(url));
  }

  /// Parser TEMA GENERIK — bukan situs spesifik, tapi pola/struktur HTML
  /// yang dipakai BANYAK situs komik Indonesia sekaligus (mis. WordPress
  /// theme "MangaThemesia" dipakai ratusan situs, bukan cuma Komikindo).
  /// Kalau situs custom yang user tambahkan kebetulan pakai salah satu
  /// tema ini, kita bisa langsung baca otomatis TANPA perlu nulis parser
  /// baru khusus — lihat [detectGeneric].
  static const genericKinds = [
    'sveltekit-comic',
    'mangathemesia',
    'natsuid',
    'universal-html',
    'madara',
  ];

  /// Bangun instance parser generik dari [kind] (hasil [detectGeneric]
  /// yang tersimpan di `ComicSource.parserKind`) + nama/base URL sumber
  /// custom-nya.
  static MangaSource? buildGeneric(
    String kind,
    String name,
    String baseUrl, {
    String? lang,
    Iterable<String> fallbackBaseUrls = const [],
  }) {
    // Berlaku juga buat source lama yang telanjur tersimpan sebagai
    // universal-html/extension-runtime sebelum parser API ini tersedia.
    if (_isMangaFire(baseUrl)) {
      return MangaFireSource(name: name, baseUrl: baseUrl, lang: lang);
    }
    if (_isDoujindesu(baseUrl) || name.trim().toLowerCase().contains('doujindesu')) {
      return DoujindesuSource(name: name, baseUrl: baseUrl);
    }
    if (_isImhentai(baseUrl) || name.trim().toLowerCase().contains('imhentai')) {
      return ImhentaiSource(name: name, baseUrl: baseUrl);
    }
    if (kind.startsWith('extension-runtime:')) {
      // Extension Soulscans yang terpasang bisa tertinggal dari API situsnya.
      // Untuk katalog/chapter, parser API langsung lebih dapat dipercaya.
      if (_isSoulScans(baseUrl)) {
        return SvelteKitComicSource(name: name, baseUrl: baseUrl);
      }
      final packageName = kind.substring('extension-runtime:'.length).trim();
      if (packageName.isEmpty) return null;
      return ExtensionRuntimeSource(
        name: name,
        packageName: packageName,
        baseUrl: baseUrl,
        lang: lang,
        fallbackBaseUrls: fallbackBaseUrls,
      );
    }
    return switch (kind) {
      'mangafire-api' => MangaFireSource(
        name: name,
        baseUrl: baseUrl,
        lang: lang,
      ),
      'sveltekit-comic' => SvelteKitComicSource(name: name, baseUrl: baseUrl),
      'mangathemesia' => MangaThemesiaSource(name: name, baseUrl: baseUrl),
      'natsuid' => NatsuIdSource(name: name, baseUrl: baseUrl),
      'madara' => MadaraSource(name: name, baseUrl: baseUrl),
      'universal-html' => UniversalHtmlSource(
        name: name,
        baseUrl: baseUrl,
        enableBrowserSessionFallback: true,
      ),
      _ => null,
    };
  }

  static bool _isDoujindesu(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == 'doujin.desu.xxx' ||
        host == 'doujindesu.tv' ||
        host == 'doujindesu.bid' ||
        host?.endsWith('.desu.xxx') == true;
  }

  static bool _isImhentai(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == 'imhentai.xxx' ||
        host == 'imhentai.com' ||
        host == 'imhentai.to' ||
        host?.endsWith('.imhentai.xxx') == true;
  }

  static bool _isSoulScans(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == 'soulscans.asia' ||
        host?.endsWith('.soulscans.asia') == true;
  }

  static bool _isMangaFire(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == 'mangafire.to' || host?.endsWith('.mangafire.to') == true;
  }

  /// Parser otomatis untuk sumber custom yang belum punya parserKind. Ini
  /// dipakai supaya URL baru tidak langsung dilempar ke WebView sebelum
  /// semua parser generik dicoba.
  static MangaSource buildAutomatic(
    String name,
    String baseUrl, {
    String? preferredKind,
    String? lang,
    Iterable<String> fallbackBaseUrls = const [],
  }) {
    final normalizedBase = normalizeSourceBaseUrl(baseUrl);
    final normalizedFallbacks = fallbackBaseUrls
        .map(normalizeSourceBaseUrl)
        .where((url) => url.isNotEmpty && url != normalizedBase)
        .toSet();
    normalizedFallbacks.addAll(
      _knownMirrorFallbacks(
        name,
        normalizedBase,
      ).where((url) => url.isNotEmpty && url != normalizedBase),
    );
    final preferred = <MangaSource>[
      if (preferredKind != null)
        ?buildGeneric(
          preferredKind,
          name,
          normalizedBase,
          lang: lang,
          fallbackBaseUrls: normalizedFallbacks,
        ),
      ?_knownPreferredSource(name, normalizedBase),
    ];
    // Extension runtime sudah punya urutan APK -> parser HTML -> alternatif
    // sendiri. Pertahankan tipe konkretnya supaya bridge native dan kontrak
    // instal/update extension tidak berubah.
    final extension = preferred.whereType<ExtensionRuntimeSource>().firstOrNull;
    if (extension != null) return extension;
    final doujin = preferred.whereType<DoujindesuSource>().firstOrNull;
    if (doujin != null) return doujin;
    final imhentai = preferred.whereType<ImhentaiSource>().firstOrNull;
    if (imhentai != null) return imhentai;
    return AdaptiveSource(
      name: name,
      baseUrl: normalizedBase,
      preferredStrategies: preferred,
      fallbackBaseUrls: normalizedFallbacks,
    );
  }

  static MangaSource? _knownPreferredSource(String name, String baseUrl) {
    final lower = name.trim().toLowerCase();
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';

    if (lower.contains('asura') || host.contains('asuracomic') || host.contains('asurascans')) {
      return AsuraSource();
    }
    if (lower.contains('shinigami') || host.contains('shinigami') || host.contains('shngm')) {
      return ShinigamiSource();
    }
    if (lower.contains('komiku') || host.contains('komiku')) {
      return KomikuSource();
    }
    if (lower.contains('doujindesu') || host.contains('doujindesu') || host.contains('doujin.desu')) {
      final effectiveUrl = (host.contains('doujindesu.tv') || host.contains('doujindesu.bid'))
          ? 'https://doujin.desu.xxx'
          : baseUrl;
      return DoujindesuSource(name: name, baseUrl: effectiveUrl);
    }
    if (lower.contains('imhentai') || host.contains('imhentai')) {
      return ImhentaiSource(name: name, baseUrl: baseUrl);
    }
    if (lower.contains('soulscans') || host.contains('soulscans')) {
      return SvelteKitComicSource(name: name, baseUrl: baseUrl);
    }
    if (lower.contains('ikiru') || host.contains('ikiru')) {
      final effectiveUrl = host.contains('ikiru.wtf') ? 'https://ikiru.id' : baseUrl;
      return NatsuIdSource(name: name, baseUrl: effectiveUrl);
    }
    if (lower.contains('kiryu') || lower.contains('kiryuu') || host.contains('kiryuu')) {
      final effectiveUrl = (host.contains('kiryuu01') || host == 'kiryuu.id')
          ? 'https://v7.kiryuu.to'
          : baseUrl;
      return MangaThemesiaSource(name: name, baseUrl: effectiveUrl);
    }
    if (lower.contains('komikcast') || host.contains('komikcast')) {
      final effectiveUrl = (host.contains('komikcast01') || host.contains('komikcast.bz') || host.contains('komikcast05'))
          ? 'https://komikcast.net'
          : baseUrl;
      return MangaThemesiaSource(name: name, baseUrl: effectiveUrl);
    }
    if (lower.contains('toongod') || host.contains('toongod')) {
      return MadaraSource(name: name, baseUrl: baseUrl);
    }
    if (lower.contains('mgkomik') || host.contains('mgkomik')) {
      final effectiveUrl = host == 'mgkomik.id' ? 'https://www.mgkomik.id' : baseUrl;
      return MadaraSource(name: name, baseUrl: effectiveUrl);
    }
    if (lower.contains('softkomik') || host.contains('softkomik')) {
      final effectiveUrl = (host.contains('softkomik.com') || host.contains('softkomik.co'))
          ? 'https://softkomik.app'
          : baseUrl;
      return MangaThemesiaSource(name: name, baseUrl: effectiveUrl);
    }
    if (lower.contains('komikindo') || host.contains('komikindo')) {
      return MangaThemesiaSource(name: name, baseUrl: baseUrl);
    }
    return null;
  }

  /// Mirror kanonis yang sudah diumumkan extension upstream. Ini hanya masuk
  /// sebagai fallback paling belakang; URL aktif user dan alias repository
  /// tetap dicoba lebih dulu.
  static Iterable<String> _knownMirrorFallbacks(
    String name,
    String baseUrl,
  ) sync* {
    final lower = name.trim().toLowerCase();
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
    if (lower == 'ikiru' ||
        host.contains('ikiru')) {
      yield 'https://ikiru.id';
      yield 'https://07.ikiru.wtf';
    }
    if (lower.contains('imhentai') || host.contains('imhentai')) {
      yield 'https://imhentai.xxx';
      yield 'https://m.imhentai.xxx';
    }
    if (lower.contains('toongod') || host.contains('toongod')) {
      yield 'https://www.toongod.org';
      yield 'https://toongod.cc';
    }
    if (lower.contains('kiryu') || host.contains('kiryuu')) {
      yield 'https://v7.kiryuu.to';
      yield 'https://kiryuu.io';
      yield 'https://kiryuu.id';
    }
    if (lower.contains('komikcast') || host.contains('komikcast')) {
      yield 'https://komikcast.net';
      yield 'https://bacakomik.my';
      yield 'https://v2.komikcast.fit';
    }
    if (lower.contains('softkomik') || host.contains('softkomik')) {
      yield 'https://softkomik.app';
      yield 'https://softkomik.co';
    }
    if (lower.contains('mgkomik') || host.contains('mgkomik')) {
      yield 'https://www.mgkomik.id';
      yield 'https://mgkomik.id';
    }
    if (lower.contains('doujindesu') || host.contains('doujindesu') || host.contains('doujin.desu')) {
      yield 'https://doujin.desu.xxx';
      yield 'https://doujindesu.tv';
    }
  }

  static String _originFromUrl(String raw) {
    final normalized = normalizeSourceBaseUrl(raw);
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return normalized;
    return uri.replace(path: '', query: null, fragment: null).toString();
  }

  /// Probe nyata untuk source repository. Metadata APK saja belum berarti
  /// source bisa mengambil daftar: Cloudflare/login bisa tetap memblokirnya.
  static Future<bool> probeSource(MangaSource source) async {
    try {
      final page = await source.fetchPopular(1);
      return page.mangas.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> probeGeneric(
    String kind,
    String name,
    String baseUrl, {
    String? lang,
  }) async {
    final source = buildGeneric(kind, name, baseUrl, lang: lang);
    if (source == null) return false;
    return probeSource(source);
  }

  /// Coba tiap parser tema generik terhadap [baseUrl] — "banyak metode
  /// coba buka link komiknya", persis yang diminta user. Kembalikan kind
  /// parser PERTAMA yang berhasil ambil daftar populer TANPA error dan
  /// hasilnya tidak kosong (sinyal kuat struktur HTML-nya cocok).
  /// Sekuensial, berhenti di percobaan pertama yang berhasil.
  static Future<String?> detectGeneric(String name, String baseUrl) async {
    if (_isMangaFire(baseUrl)) {
      final source = MangaFireSource(name: name, baseUrl: baseUrl);
      try {
        final result = await source.fetchPopular(1);
        if (result.mangas.isNotEmpty) return 'mangafire-api';
      } catch (_) {
        return null;
      }
    }
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
