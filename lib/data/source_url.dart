// Utilitas URL sumber yang sengaja tidak bergantung pada parser tertentu.
//
// Website komik cukup sering pindah domain, sementara path manga/chapter-nya
// tetap sama. Data lama di Library tidak perlu ditulis ulang massal: URL lama
// di-rebase saat dipakai dan identitas resource dibandingkan dari path stabil.

String normalizeSourceBaseUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final withScheme = value.startsWith('http://') || value.startsWith('https://')
      ? value
      : 'https://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return withScheme;
  return uri
      .replace(fragment: null, path: _trimTrailingSlash(uri.path))
      .toString();
}

/// Alihkan URL absolut dari domain lama ke [currentBaseUrl]. URL relatif dan
/// opaque ID (mis. UUID API Shinigami) dibiarkan supaya kontrak parser tidak
/// berubah. Subdomain dari situs yang sama juga tidak disentuh karena sering
/// merupakan endpoint API/CDN yang memang sengaja berbeda.
String rebaseSourceUrl(String raw, String currentBaseUrl) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final base = Uri.tryParse(normalizeSourceBaseUrl(currentBaseUrl));
  if (base == null || base.host.isEmpty) return value;

  if (value.startsWith('/')) return base.resolve(value).toString();
  final parsed = Uri.tryParse(value);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return value;
  if (parsed.scheme != 'http' && parsed.scheme != 'https') return value;
  if (_sameSiteHost(parsed.host, base.host)) return value;

  return base
      .replace(
        path: parsed.path.isEmpty ? base.path : parsed.path,
        query: parsed.hasQuery ? parsed.query : null,
        fragment: parsed.hasFragment ? parsed.fragment : null,
      )
      .toString();
}

/// Cocokkan dua URL sebagai resource sumber yang sama. Perbandingan biasa
/// tetap paling utama; host baru diabaikan hanya bila keduanya punya path
/// non-root yang sama. Jadi dua homepage berbeda tidak pernah dianggap sama.
bool sameSourceResourceIdentity(String? first, String? second) {
  final a = _normalizedResource(first);
  final b = _normalizedResource(second);
  if (a == null || b == null) return false;
  if (a.raw == b.raw) return true;
  if (a.path.isEmpty || a.path == '/' || b.path.isEmpty || b.path == '/') {
    return false;
  }
  return a.path == b.path && a.query == b.query;
}

({String raw, String path, String query})? _normalizedResource(String? raw) {
  var value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final hash = value.indexOf('#');
  if (hash >= 0) value = value.substring(0, hash);
  value = _trimTrailingSlash(value);
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null) return (raw: value, path: value, query: '');
  final path = _trimTrailingSlash(uri.path);
  return (raw: value, path: path, query: _stableQuery(uri.queryParametersAll));
}

String _stableQuery(Map<String, List<String>> values) {
  final keys = values.keys.where((key) {
    final lower = key.toLowerCase();
    return !lower.startsWith('utm_') && lower != 'ref' && lower != 'source';
  }).toList()..sort();
  return [
    for (final key in keys)
      for (final value in [...values[key]!]..sort()) '$key=$value',
  ].join('&');
}

bool _sameSiteHost(String first, String second) {
  final a = first.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final b = second.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return a == b || a.endsWith('.$b') || b.endsWith('.$a');
}

String _trimTrailingSlash(String value) {
  var result = value;
  while (result.length > 1 && result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}
