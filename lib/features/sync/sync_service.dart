import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dilempar saat sync awal gagal.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;
}

/// Sync data awal setelah login (library, sumber, riwayat).
///
/// Backend sync belum ada — durasi mengikuti timing prototipe (~1.5s).
/// TODO(backend): ganti dengan panggilan API sungguhan saat backend siap;
/// pertahankan UI loading di SyncScreen apa adanya.
class SyncService {
  SyncService({this.simulateFailure = false});

  /// Di-set true oleh debug toggle "simulate sync failure" di Settings (14).
  final bool simulateFailure;

  Future<void> syncAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (simulateFailure) {
      throw const SyncException('Gagal sync, coba lagi');
    }
  }
}

/// Debug toggle dari Settings (14) — "simulate sync failure" di prototipe.
class SyncDebugFail extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final syncDebugFailProvider =
    NotifierProvider<SyncDebugFail, bool>(SyncDebugFail.new);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(simulateFailure: ref.watch(syncDebugFailProvider)),
);
