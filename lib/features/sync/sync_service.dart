import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firestore_scope.dart';
import '../auth/auth_repository.dart';

/// Dilempar saat sync awal gagal.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;
}

/// Sync data awal setelah login (library, sumber, riwayat).
///
/// Firestore sendiri yang mengurus offline cache & propagasi antar device
/// (lihat docs/DATABASE.md) — semua "sync" yang perlu dilakukan di sini
/// hanya memastikan dokumen profil (`users/{uid}`) ada & memperbarui
/// `lastSyncAt`. Timing UI (~1.5s) dipertahankan apa adanya (brand moment
/// SyncScreen), dijalankan paralel dengan kerja Firestore di atas.
class SyncService {
  SyncService({this.simulateFailure = false, this.user});

  /// Di-set true oleh debug toggle "simulate sync failure" di Settings (14).
  final bool simulateFailure;

  /// User yang baru login — dipakai untuk mengisi/memperbarui profil.
  final AuthUser? user;

  Future<void> syncAll() async {
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      _ensureProfile(),
    ]);
    if (simulateFailure) {
      throw const SyncException('Gagal sync, coba lagi');
    }
  }

  Future<void> _ensureProfile() async {
    final doc = FirestoreScope.userDoc;
    final u = user;
    if (doc == null || u == null) return;
    await doc.set({
      'name': u.name,
      'email': u.email,
      'photoUrl': u.photoUrl,
      'lastSyncAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // createdAt hanya diisi sekali (dokumen baru), tidak pernah ditimpa.
    final snap = await doc.get();
    if (!(snap.data()?.containsKey('createdAt') ?? false)) {
      await doc.set({'createdAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
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
  (ref) => SyncService(
    simulateFailure: ref.watch(syncDebugFailProvider),
    user: ref.watch(authControllerProvider),
  ),
);
