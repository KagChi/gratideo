import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/settings.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

/// Replace this service with a backend implementation when it is ready.
abstract class AuthService extends ChangeNotifier {
  bool get isSignedIn;
  String get email;

  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();
}

/// One local account per device. The password is never stored. Existing app
/// content is device-wide and is not separated by account.
class LocalAuthService extends AuthService {
  LocalAuthService._(this._prefs, this._settings);

  final SharedPreferences _prefs;
  final Settings _settings;

  static Future<LocalAuthService> load(Settings settings) async =>
      LocalAuthService._(await SharedPreferences.getInstance(), settings);

  @override
  bool get isSignedIn => _prefs.getBool('auth_signed_in') ?? false;

  @override
  String get email => _prefs.getString('auth_email') ?? '';

  static const _iterations = 120000;

  static List<int> _derive(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_prefs.containsKey('auth_verifier')) {
      throw const AuthException(
        'An account already exists on this device. Sign in to continue.',
      );
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final verifier = await compute(_derivePassword, (password, salt));
    await _prefs.setString('auth_salt', base64Encode(salt));
    await _prefs.setString('auth_verifier', base64Encode(verifier));
    await _prefs.setString('auth_email', email.trim().toLowerCase());
    await _settings.setName(name);
    await _prefs.setBool('auth_signed_in', true);
    notifyListeners();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final savedSalt = _prefs.getString('auth_salt');
    final savedVerifier = _prefs.getString('auth_verifier');
    if (this.email.isEmpty ||
        savedSalt == null ||
        savedVerifier == null ||
        this.email != email.trim().toLowerCase()) {
      throw const AuthException('Email or password is incorrect.');
    }
    final verifier = await compute(_derivePassword, (
      password,
      base64Decode(savedSalt),
    ));
    if (!_sameBytes(verifier, base64Decode(savedVerifier))) {
      throw const AuthException('Email or password is incorrect.');
    }
    await _prefs.setBool('auth_signed_in', true);
    notifyListeners();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    throw const AuthException('Password reset email is not available yet.');
  }

  @override
  Future<void> signOut() async {
    await _prefs.setBool('auth_signed_in', false);
    notifyListeners();
  }
}

List<int> _derivePassword((String, List<int>) input) =>
    LocalAuthService._derive(input.$1, input.$2);
