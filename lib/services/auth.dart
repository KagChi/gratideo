import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'credentials.dart';
import 'token_store.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthService extends ChangeNotifier {
  bool get isSignedIn;
  String get email;

  /// Session token for the API, or null when signed out.
  String? get token;

  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();

  /// Re-reads the account from the server; safe to call when offline.
  Future<void> refresh();
}

/// Talks to the Gratideo Worker. The password is stretched on this device with
/// PBKDF2-SHA256 and only the verifier is sent over the wire.
class ApiAuthService extends AuthService {
  ApiAuthService._(this._api, this._store, this._iterations);

  static Future<ApiAuthService> load({
    ApiClient? api,
    TokenStore? store,
    int iterations = kdfIterations,
  }) async {
    final service = ApiAuthService._(
      api ?? ApiClient(),
      store ?? SecureTokenStore(),
      iterations,
    );
    await service._restore();
    return service;
  }

  final ApiClient _api;
  final TokenStore _store;
  final int _iterations;

  String? _token;
  String _email = '';
  DateTime? _expiresAt;
  bool _signedIn = false;

  @override
  bool get isSignedIn => _signedIn;

  @override
  String get email => _email;

  @override
  String? get token => _token;

  Future<void> _restore() async {
    try {
      final raw = await _store.read();
      if (raw == null || raw.isEmpty) return;
      final session = jsonDecode(raw) as Map<String, dynamic>;
      final token = session['token'] as String?;
      final expiresAt = DateTime.tryParse((session['expiresAt'] as String?) ?? '');
      if (token == null || expiresAt == null || expiresAt.isBefore(DateTime.now())) {
        await _store.delete();
        return;
      }
      _token = token;
      _email = (session['email'] as String?) ?? '';
      _expiresAt = expiresAt;
      _signedIn = true;
    } catch (_) {
      await _store.delete();
    }
  }

  Future<void> _persist() async {
    final token = _token;
    final expiresAt = _expiresAt;
    if (token == null || expiresAt == null) return;
    await _store.write(jsonEncode({
      'token': token,
      'email': _email,
      'expiresAt': expiresAt.toIso8601String(),
    }));
  }

  Future<void> _adopt(Map<String, dynamic> body) async {
    final user = (body['user'] as Map).cast<String, dynamic>();
    _token = body['token'] as String;
    _email = (user['email'] as String?) ?? '';
    _expiresAt = DateTime.tryParse((body['expiresAt'] as String?) ?? '') ??
        DateTime.now().add(const Duration(days: 30));
    _signedIn = true;
    await _persist();
    notifyListeners();
  }

  Future<void> _clear() async {
    _token = null;
    _email = '';
    _expiresAt = null;
    _signedIn = false;
    await _store.delete();
    notifyListeners();
  }

  Future<Map<String, dynamic>> _guard(Future<Map<String, dynamic>> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  Future<String> _verifier(String email, String password) => deriveVerifierInBackground(
        email,
        password,
        iterations: _iterations,
      );

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final address = normalizeEmail(email);
    final verifier = await _verifier(address, password);
    final body = await _guard(() => _api.post('/v1/auth/register', body: {
          'name': name.trim(),
          'email': address,
          'verifier': verifier,
          'kdf': {'algo': kdfAlgorithm, 'iterations': _iterations},
        }));
    await _adopt(body);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final address = normalizeEmail(email);
    final verifier = await _verifier(address, password);
    final body = await _guard(() => _api.post('/v1/auth/login', body: {
          'email': address,
          'verifier': verifier,
        }));
    await _adopt(body);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _guard(() => _api.post('/v1/auth/password/reset-request', body: {
          'email': normalizeEmail(email),
        }));
  }

  @override
  Future<void> signOut() async {
    final token = _token;
    await _clear();
    if (token == null) return;
    try {
      await _api.post('/v1/auth/logout', token: token);
    } catch (_) {
      // Best effort: the local session is already gone.
    }
  }

  @override
  Future<void> refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final body = await _api.get('/v1/auth/me', token: token);
      final user = (body['user'] as Map).cast<String, dynamic>();
      final email = (user['email'] as String?) ?? _email;
      if (email != _email) {
        _email = email;
        await _persist();
        notifyListeners();
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _clear();
    }
  }
}

