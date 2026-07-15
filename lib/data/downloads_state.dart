import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chapter yang ditandai terunduh — key "comicId-chapterNum".
/// Toggle visual saja (mengikuti prototipe).
/// TODO(backend): sambungkan ke logika unduh offline sungguhan.
class DownloadsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Toggle; return true bila kini terunduh.
  bool toggle(String comicId, int chapterNum) {
    final key = '$comicId-$chapterNum';
    if (state.contains(key)) {
      state = {...state}..remove(key);
      return false;
    }
    state = {...state, key};
    return true;
  }

  bool isDownloaded(String comicId, int chapterNum) =>
      state.contains('$comicId-$chapterNum');
}

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, Set<String>>(DownloadsNotifier.new);
