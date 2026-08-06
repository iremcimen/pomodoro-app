import 'dart:async';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_token_store.dart';
import '../models/auth_token_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthTokenStore tokenStore,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStore = tokenStore;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthTokenStore _tokenStore;
  static const _refreshTimeout = Duration(seconds: 4);

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final token = await _remoteDataSource.login(
      identifier: identifier,
      password: password,
    );
    return _persist(token);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) async {
    final token = await _remoteDataSource.register(
      email: email,
      username: username,
      password: password,
      fullName: fullName,
    );
    return _persist(token);
  }

  @override
  Future<AuthSession> loginWithGoogle(String idToken) async {
    final token = await _remoteDataSource.loginWithGoogle(idToken);
    return _persist(token);
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final storedToken = await _tokenStore.read();
    if (storedToken == null) return null;
    if (storedToken.toDomain().isAccessTokenUsable) {
      return storedToken.toDomain();
    }

    try {
      final refreshed = await _remoteDataSource
          .refresh(storedToken.refreshToken)
          .timeout(_refreshTimeout);
      return _persist(refreshed);
    } on TimeoutException {
      await _tokenStore.clear();
      return null;
    } on AppException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _tokenStore.clear();
        return null;
      }

      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final storedToken = await _tokenStore.read();
    await _tokenStore.clear();

    if (storedToken != null) {
      unawaited(_revokeRemoteSession(storedToken.refreshToken));
    }
  }

  Future<void> _revokeRemoteSession(String refreshToken) async {
    try {
      await _remoteDataSource.logout(refreshToken);
    } on Object {
      // Local logout must remain successful when the API is unavailable.
    }
  }

  Future<AuthSession> _persist(AuthTokenDto token) async {
    await _tokenStore.write(token);
    return token.toDomain();
  }
}
