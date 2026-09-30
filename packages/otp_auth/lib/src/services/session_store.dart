import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dónde vive el token de sesión en el dispositivo. Abstraído para que los
/// tests no dependan del Keychain/Keystore reales.
abstract class SessionStore {
  Future<String?> read();
  Future<void> save(String token);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  static const _key = 'otp_session_token';

  final FlutterSecureStorage _storage;

  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> save(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemorySessionStore implements SessionStore {
  String? _token;

  InMemorySessionStore([this._token]);

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
