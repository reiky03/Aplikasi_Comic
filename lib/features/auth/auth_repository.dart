import 'package:flutter/foundation.dart';
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

/// Integrasi Google Sign-In asli.
///
/// Catatan setup per platform (google_sign_in v7):
/// - Android: daftarkan OAuth client + SHA-1 di Google Cloud Console.
/// - iOS: isi CFBundleURLTypes + GIDClientID di Info.plist.
/// - Web: authenticate() tidak didukung; butuh tombol GIS
///   (renderButton) — pakai FAKE_AUTH untuk preview web sementara.
class GoogleAuthRepository implements AuthRepository {
  GoogleSignIn get _signIn => GoogleSignIn.instance;
  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _signIn.initialize();

  AuthUser _toUser(GoogleSignInAccount account) => AuthUser(
        name: account.displayName ?? account.email,
        email: account.email,
        photoUrl: account.photoUrl,
      );

  @override
  Future<AuthUser?> restoreSession() async {
    try {
      await _ensureInitialized();
      final account = await _signIn.attemptLightweightAuthentication();
      return account == null ? null : _toUser(account);
    } catch (e) {
      // Plugin belum terkonfigurasi / platform tak didukung → anggap
      // tidak ada sesi; user tetap bisa login manual.
      debugPrint('restoreSession gagal: $e');
      return null;
    }
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
    try {
      final account = await _signIn.authenticate();
      return _toUser(account);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelledException();
      }
      throw AuthException(e.description ?? 'Login Google gagal.');
    }
  }

  @override
  Future<void> signOut() async {
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
  (ref) => kUseFakeAuth ? FakeAuthRepository() : GoogleAuthRepository(),
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
