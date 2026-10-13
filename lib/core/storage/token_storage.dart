import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Conserva access token e refresh token nel keychain / keystore.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'repbirds.access_token';
  static const _refreshKey = 'repbirds.refresh_token';

  // Cache in memoria per non leggere il keychain a ogni richiesta.
  String? _access;
  String? _refresh;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _access = await _storage.read(key: _accessKey);
    _refresh = await _storage.read(key: _refreshKey);
    _loaded = true;
  }

  Future<String?> get accessToken async {
    await _ensureLoaded();
    return _access;
  }

  Future<String?> get refreshToken async {
    await _ensureLoaded();
    return _refresh;
  }

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
