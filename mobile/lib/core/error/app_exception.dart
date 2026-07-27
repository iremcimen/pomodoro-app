import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException({
    required this.message,
    this.code = 'UNKNOWN_ERROR',
    this.statusCode,
    this.requestId,
  });

  final String message;
  final String code;
  final int? statusCode;
  final String? requestId;

  factory AppException.fromDio(DioException exception) {
    final response = exception.response;
    final data = response?.data;

    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final code = error['code']?.toString() ?? 'REQUEST_FAILED';
        return AppException(
          message: _localizedMessage(code, error['message']?.toString()),
          code: code,
          statusCode: response?.statusCode,
          requestId: data['request_id']?.toString(),
        );
      }
    }

    return AppException(
      message: _messageForType(exception.type),
      code: 'NETWORK_ERROR',
      statusCode: response?.statusCode,
    );
  }

  static String _messageForType(DioExceptionType type) {
    return switch (type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
      DioExceptionType.connectionError =>
        'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      DioExceptionType.cancel => 'İstek iptal edildi.',
      _ => 'Bir sorun oluştu. Lütfen tekrar deneyin.',
    };
  }

  static String _localizedMessage(String code, String? fallback) {
    return switch (code) {
      'INVALID_CREDENTIALS' => 'E-posta/kullanıcı adı veya şifre hatalı.',
      'EMAIL_ALREADY_EXISTS' => 'Bu e-posta adresi zaten kayıtlı.',
      'USERNAME_ALREADY_EXISTS' => 'Bu kullanıcı adı zaten alınmış.',
      'INACTIVE_USER' => 'Bu kullanıcı hesabı aktif değil.',
      'ACTIVE_SESSION_EXISTS' =>
        'Açık oturumunuz geri yüklenemedi. Lütfen tekrar deneyin.',
      'VALIDATION_ERROR' => 'Bilgileri kontrol edip tekrar deneyin.',
      'DATABASE_UNAVAILABLE' => 'Hizmet geçici olarak kullanılamıyor.',
      _ =>
        fallback?.trim().isNotEmpty == true
            ? fallback!
            : 'Bir sorun oluştu. Lütfen tekrar deneyin.',
    };
  }

  @override
  String toString() => message;
}
