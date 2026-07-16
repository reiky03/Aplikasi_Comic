import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jalankan dengan `--dart-define=FAKE_AUTH=true` untuk memakai auth palsu
/// (dev/preview tanpa OAuth client ID, mis. di web preview).
const bool kUseFakeAuth = bool.fromEnvironment('FAKE_AUTH');

class AuthUser {
  const AuthUser({required this.name, required this.email, this.photoUrl});

  final String name;
  final String email;
  final String? photoUrl;
}

/// Dilempar saat sign-in gagal (bukan karena user membatalkan).
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Dilempar saat user menutup/membatalkan dialog Google Sign-In.
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

abstract interface class AuthRepository {
  /// Cek sesi yang masih valid tanpa UI (dipanggil dari Splash).
  Future<AuthUser?> restoreSession();

  /// Alur sign-in interaktif.
  Future<AuthUser> signIn();

  Future<void> signOut();
}

/// Google Sign-In + Firebase Authentication — sinkronisasi akun (lihat
/// docs/DATABASE.md; semua data digantung di `users/{uid}` dari Firebase Auth).
///
/// Catatan setup per platform (google_sign_in v7):
/// - Android: SHA-1/SHA-256 fingerprint didaftarkan di Firebase Console
///   (Project Settings → Android app → Add fingerprint).
/// - iOS: URL scheme (REVERSED_CLIENT_ID) di Info.plist.
/// - Web: `authenticate()` tidak didukung; perlu tombol GIS (renderButton) —
///   pakai FAKE_AUTH untuk preview web sementara.
class FirebaseAuthRepository implements AuthRepository {
  // Web Client ID (client_type: 3) dari Firebase project kizen-da39f —
  // wajib diisi supaya Android/iOS dapat idToken yang valid (bukan cuma
  // accessToken) untuk ditukar ke Firebase via GoogleAuthProvider.
  static const _webClientId =
      '1029784256621-nkq5dro519rtnlsrvsqs65287o11ucu2.apps.googleusercontent.com';

  GoogleSignIn get _signIn => GoogleSignIn.instance;
  Future<void>? _init;

  Future<void> _ensureInitialized() =>
      _init ??= _signIn.initialize(serverClientId: _webClientId);

  AuthUser _toUser(fb.User user) => AuthUser(
        name: user.displayName ?? user.email ?? 'Pengguna',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );

  @override
  Future<AuthUser?> restoreSession() async {
    // Firebase Auth sudah persist sesi sendiri (tanpa perlu Google
    // Sign-In silent auth) — cek user yang sedang login saat ini.
    final user = fb.FirebaseAuth.instance.currentUser;
    return user == null ? null : _toUser(user);
  }

  @override
  Future<AuthUser> signIn() async {
    try {
      await _ensureInitialized();
    } catch (e) {
      throw AuthException('Google Sign-In belum terkonfigurasi: $e');
    }
    if (!_signIn.supportsAuthenticate()) {
      throw const AuthException(
        'Platform ini belum mendukung alur sign-in tombol kustom.',
      );
    }
    final GoogleSignInAccount account;
    try {
      account = await _signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelledException();
      }
      throw AuthException(e.description ?? 'Login Google gagal.');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google tidak mengembalikan ID token.');
    }
    try {
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final result =
          await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const AuthException('Login Firebase gagal — user null.');
      }
      return _toUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Login Firebase gagal.');
    }
  }

  @override
  Future<void> signOut() async {
    await fb.FirebaseAuth.instance.signOut();
    await _ensureInitialized();
    await _signIn.signOut();
  }
}

/// Auth palsu untuk dev/preview: sukses setelah jeda singkat,
/// sesi disimpan di SharedPreferences agar Splash bisa skip login.
class FakeAuthRepository implements AuthRepository {
  static const _kSignedInKey = 'fake_auth_signed_in';

  static const _user = AuthUser(
    name: 'Reiky Pratama',
    email: 'wibugarxurang@gmail.com',
  );

  @override
  Future<AuthUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_kSignedInKey) ?? false) ? _user : null;
  }

  @override
  Future<AuthUser> signIn() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSignedInKey, true);
    return _user;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSignedInKey);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => kUseFakeAuth ? FakeAuthRepository() : FirebaseAuthRepository(),
);

/// User yang sedang login (null = belum login).
class AuthController extends Notifier<AuthUser?> {
  @override
  AuthUser? build() => null;

  Future<AuthUser?> restoreSession() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    state = user;
    return user;
  }

  Future<AuthUser> signIn() async {
    final user = await ref.read(authRepositoryProvider).signIn();
    state = user;
    return user;
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthUser?>(AuthController.new);
