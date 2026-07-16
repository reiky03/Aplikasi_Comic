import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Akses Firestore ter-scope ke user login (`users/{uid}`), lihat
/// docs/DATABASE.md. Semua getter aman dipanggil walau Firebase belum
/// di-init (mode `--dart-define=FAKE_AUTH=true`, atau widget test yang
/// tidak melalui `main()`) — akan mengembalikan null, pemanggilnya lalu
/// fallback ke data lokal in-memory.
abstract final class FirestoreScope {
  static String? get uid {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static DocumentReference<Map<String, dynamic>>? get userDoc {
    final id = uid;
    if (id == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(id);
  }

  static CollectionReference<Map<String, dynamic>>? collection(String name) =>
      userDoc?.collection(name);
}
