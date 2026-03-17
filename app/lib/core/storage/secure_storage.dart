import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kToken     = 'access_token';
const _kEmail     = 'user_email';
const _kServerUrl = 'server_url';
const _kThemeMode = 'theme_mode';

/// Thin wrapper over FlutterSecureStorage.
/// On web: backed by localStorage (via flutter_secure_storage web impl).
/// On iOS: Keychain. On Android: EncryptedSharedPreferences.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Token ──────────────────────────────────────────────────────────────────

  Future<String?> readToken()         => _storage.read(key: _kToken);
  Future<void>    writeToken(String t) => _storage.write(key: _kToken, value: t);
  Future<void>    deleteToken()        => _storage.delete(key: _kToken);

  // ── Email ──────────────────────────────────────────────────────────────────

  Future<String?> readEmail()          => _storage.read(key: _kEmail);
  Future<void>    writeEmail(String e) => _storage.write(key: _kEmail, value: e);

  // ── Server URL ─────────────────────────────────────────────────────────────

  Future<String?> readServerUrl()          => _storage.read(key: _kServerUrl);
  Future<void>    writeServerUrl(String u) => _storage.write(key: _kServerUrl, value: u);

  // ── Theme mode ─────────────────────────────────────────────────────────────

  Future<String?> readThemeMode()           => _storage.read(key: _kThemeMode);
  Future<void>    writeThemeMode(String m)  => _storage.write(key: _kThemeMode, value: m);

  // ── User Profile ──────────────────────────────────────────────────────────

  Future<String?> readProfile()          => _storage.read(key: 'user_profile');
  Future<void>    writeProfile(String p) => _storage.write(key: 'user_profile', value: p);

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}
