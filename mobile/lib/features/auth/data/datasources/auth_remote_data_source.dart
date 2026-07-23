import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../models/auth_token_dto.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthTokenDto> login({
    required String identifier,
    required String password,
  });

  Future<AuthTokenDto> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  });

  Future<AuthTokenDto> refresh(String refreshToken);

  Future<void> logout(String refreshToken);
}

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  const DioAuthRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<AuthTokenDto> login({
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = identifier.trim().toLowerCase();
    final identityField = normalizedIdentifier.contains('@')
        ? 'email'
        : 'username';

    return _requestToken(
      '/auth/login',
      data: {identityField: normalizedIdentifier, 'password': password},
    );
  }

  @override
  Future<AuthTokenDto> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) {
    return _requestToken(
      '/auth/register',
      data: {
        'email': email.trim().toLowerCase(),
        'username': username.trim().toLowerCase(),
        'full_name': fullName?.trim().isEmpty == true ? null : fullName?.trim(),
        'password': password,
      },
    );
  }

  @override
  Future<AuthTokenDto> refresh(String refreshToken) {
    return _requestToken(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  Future<AuthTokenDto> _requestToken(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      final body = response.data;
      if (body == null) {
        throw const AppException(
          message: 'Sunucudan geçersiz bir yanıt alındı.',
          code: 'INVALID_RESPONSE',
        );
      }
      return AuthTokenDto.fromResponse(body);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } on FormatException {
      throw const AppException(
        message: 'Sunucudan geçersiz bir yanıt alındı.',
        code: 'INVALID_RESPONSE',
      );
    }
  }
}
