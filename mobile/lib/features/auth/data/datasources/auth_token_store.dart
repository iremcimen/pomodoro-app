import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_token_dto.dart';

abstract interface class AuthTokenStore {
  Future<AuthTokenDto?> read();

  Future<void> write(AuthTokenDto token);

  Future<void> clear();
}

class SecureAuthTokenStore implements AuthTokenStore {
  const SecureAuthTokenStore(this._storage);

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _tokenTypeKey = 'auth.token_type';
  static const _expiresAtKey = 'auth.expires_at';
  static const _readTimeout = Duration(seconds: 2);
  static const _writeTimeout = Duration(seconds: 4);

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokenDto?> read() async {
    final Map<String, String> values;
    try {
      values = await _storage.readAll().timeout(_readTimeout);
    } on Object {
      // Web storage unavailable olduğunda kullanıcı giriş yapabilmeye devam
      // etmeli; eski oturum geri yüklenmeden login ekranı açılır.
      return null;
    }
    final accessToken = values[_accessTokenKey];
    final refreshToken = values[_refreshTokenKey];
    final expiresAt = values[_expiresAtKey];

    if (accessToken == null || refreshToken == null || expiresAt == null) {
      return null;
    }

    try {
      return AuthTokenDto.fromStorage({
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': values[_tokenTypeKey] ?? 'bearer',
        'expires_at': expiresAt,
      });
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokenDto token) async {
    final values = token.toStorage();
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: values['access_token']),
      _storage.write(key: _refreshTokenKey, value: values['refresh_token']),
      _storage.write(key: _tokenTypeKey, value: values['token_type']),
      _storage.write(key: _expiresAtKey, value: values['expires_at']),
    ]).timeout(_writeTimeout);
  }

  @override
  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
        _storage.delete(key: _tokenTypeKey),
        _storage.delete(key: _expiresAtKey),
      ]).timeout(_writeTimeout);
    } on Object {
      // Temizleme hatası kullanıcıyı giriş ekranında kilitlememeli.
    }
  }
}
