import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../sources/manga_source.dart';

/// Cache file sementara untuk satu sesi Reader.
///
/// File encoded disimpan di direktori cache OS supaya zoom dengan ukuran decode
/// berbeda tidak mengunduh URL yang sama lagi. Cache dibersihkan saat Reader
/// terakhir ditutup; clear pertama juga membuang sisa sesi yang terputus karena
/// aplikasi pernah di-force close.
class ReaderSessionImageCache {
  final _coordinator = _ReaderCacheCoordinator.instance;
  final Set<ImageProvider> _resolvedProviders = {};

  bool _opened = false;
  int _warmGeneration = 0;

  Future<void> open() async {
    if (_opened || kIsWeb) return;
    _opened = true;
    await _coordinator.acquire();
  }

  ImageProvider providerFor(SourcePage page) {
    final headers = page.headers.isEmpty ? null : page.headers;
    if (kIsWeb || !_opened) {
      return NetworkImage(page.imageUrl, headers: headers);
    }
    return CachedNetworkImageProvider(
      page.imageUrl,
      headers: headers,
      cacheManager: _coordinator.manager,
    );
  }

  T rememberProvider<T extends ImageProvider>(T provider) {
    if (!kIsWeb && _opened) _resolvedProviders.add(provider);
    return provider;
  }

  /// Mulai dari halaman yang sedang dibaca, lalu prioritaskan halaman terdekat
  /// secara bertahap agar scrolling tetap mulus tanpa membanjiri server
  /// komik dengan puluhan request bersamaan (ramah Cloudflare).
  void warmChapter(List<SourcePage> pages, {required int center}) {
    if (kIsWeb || !_opened || pages.isEmpty) return;
    final generation = ++_warmGeneration;
    final order = readerChapterCacheOrder(pages.length, center);
    var cursor = 0;

    Future<void> worker() async {
      while (_opened && generation == _warmGeneration) {
        final position = cursor++;
        if (position >= order.length) return;
        final page = pages[order[position]];
        try {
          await _coordinator.manager.downloadFile(
            page.imageUrl,
            authHeaders: page.headers.isEmpty ? null : page.headers,
          );
          // Beri jeda 60ms antar download agar tidak memicu HTTP 429
          await Future<void>.delayed(const Duration(milliseconds: 60));
        } catch (error) {
          debugPrint(
            'Cache sementara gambar gagal: ${page.imageUrl} error=$error',
          );
        }
      }
    }

    unawaited(worker());
  }

  Future<void> close() async {
    if (!_opened || kIsWeb) return;
    _opened = false;
    _warmGeneration++;
    final providers = _resolvedProviders.toList(growable: false);
    _resolvedProviders.clear();
    for (final provider in providers) {
      try {
        await provider.evict();
      } catch (error) {
        debugPrint('Evict bitmap Reader gagal: $error');
      }
    }
    await _coordinator.release();
  }
}

class _ReaderCacheCoordinator {
  _ReaderCacheCoordinator._();

  static final instance = _ReaderCacheCoordinator._();

  BaseCacheManager? _manager;
  int _activeReaders = 0;

  BaseCacheManager get manager => _manager ??= CacheManager(
    Config(
      'kizen_reader_session_images_v1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 800,
    ),
  );

  Future<void> acquire() {
    _activeReaders++;
    return Future<void>.value();
  }

  Future<void> release() {
    if (_activeReaders > 0) _activeReaders--;
    return Future<void>.value();
  }
}

@visibleForTesting
List<int> readerChapterCacheOrder(int pageCount, int center) {
  if (pageCount <= 0) return const [];
  final safeCenter = center.clamp(0, pageCount - 1);
  final result = <int>[safeCenter];
  for (var distance = 1; result.length < pageCount; distance++) {
    final ahead = safeCenter + distance;
    final behind = safeCenter - distance;
    if (ahead < pageCount) result.add(ahead);
    if (behind >= 0) result.add(behind);
  }
  return result;
}
