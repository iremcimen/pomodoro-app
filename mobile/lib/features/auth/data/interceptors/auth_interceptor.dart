import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_token_store.dart';
import '../models/auth_token_dto.dart';

final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required AuthTokenStore tokenStore,
    required AuthRemoteDataSource remoteDataSource,
  }) : _dio = dio,
       _tokenStore = tokenStore,
       _remoteDataSource = remoteDataSource;

  static const _retryKey = 'auth_request_retried';

  final Dio _dio;
  final AuthTokenStore _tokenStore;
  final AuthRemoteDataSource _remoteDataSource;

  Future<AuthTokenDto?>? _refreshFuture;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final storedToken = await _tokenStore.read();

      if (storedToken != null) {
        options.headers['Authorization'] = _authorizationHeader(storedToken);
      }

      handler.next(options);
    } on Object {
      // Token storage okunamazsa isteği tokensız gönder.
      // Korumalı endpoint güvenli şekilde 401 döndürecektir.
      handler.next(options);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final statusCode = err.response?.statusCode;
    final alreadyRetried = request.extra[_retryKey] == true;

    if (statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final failedAuthorization = request.headers['Authorization'];

      var storedToken = await _tokenStore.read();

      if (storedToken == null) {
        handler.next(err);
        return;
      }

      final currentAuthorization = _authorizationHeader(storedToken);

      if (failedAuthorization == currentAuthorization) {
        storedToken = await _refreshOnce();
      }

      if (storedToken == null) {
        handler.next(err);
        return;
      }

      request.extra[_retryKey] = true;
      request.headers['Authorization'] = _authorizationHeader(storedToken);

      final response = await _dio.fetch<dynamic>(request);

      handler.resolve(response);
    } on Object {
      handler.next(err);
    }
  }

  Future<AuthTokenDto?> _refreshOnce() {
    final activeRefresh = _refreshFuture;

    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = _performRefresh();

    _refreshFuture = refresh.whenComplete(() {
      _refreshFuture = null;
    });

    return _refreshFuture!;
  }

  Future<AuthTokenDto?> _performRefresh() async {
    final storedToken = await _tokenStore.read();

    if (storedToken == null) {
      return null;
    }

    try {
      final refreshedToken = await _remoteDataSource.refresh(
        storedToken.refreshToken,
      );

      await _tokenStore.write(refreshedToken);

      return refreshedToken;
    } on AppException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _tokenStore.clear();
        return null;
      }

      rethrow;
    }
  }

  String _authorizationHeader(AuthTokenDto token) {
    return '${token.tokenType} ${token.accessToken}';
  }
}
