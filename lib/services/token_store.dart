import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session token lives. Kept behind an interface so tests can use
/// memory instead of the platform keystore.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String key = 'gratideo_session';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: key);
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._value]);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> delete() async => _value = null;
}
