import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../data/datasources/auth_remote_data_source.dart';
import '../data/datasources/auth_token_store.dart';
import '../data/interceptors/auth_interceptor.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';

Dio _createDio() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const {'Accept': Headers.jsonContentType},
    ),
  );
}

/*
 * Login, register, refresh ve logout işlemlerinde kullanılan
 * tokensız Dio nesnesi.
 */
final authDioProvider = Provider<Dio>((ref) {
  final dio = _createDio();

  ref.onDispose(dio.close);

  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  return SecureAuthTokenStore(ref.watch(secureStorageProvider));
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return DioAuthRemoteDataSource(ref.watch(authDioProvider));
});

/*
 * Task, FocusSession ve UserSettings gibi korumalı
 * endpoint'lerde kullanılacak Dio nesnesi.
 */
final dioProvider = Provider<Dio>((ref) {
  final dio = _createDio();

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokenStore: ref.watch(authTokenStoreProvider),
      remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    ),
  );

  ref.onDispose(dio.close);

  return dio;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
  );
});
