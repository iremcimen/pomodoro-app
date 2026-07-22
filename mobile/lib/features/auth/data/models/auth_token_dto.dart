import '../../domain/entities/auth_session.dart';

class AuthTokenDto {
  const AuthTokenDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;

  factory AuthTokenDto.fromResponse(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num?)?.toInt();
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;

    if (expiresIn == null || accessToken == null || refreshToken == null) {
      throw const FormatException('Invalid authentication response.');
    }

    return AuthTokenDto(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  factory AuthTokenDto.fromStorage(Map<String, String> values) {
    return AuthTokenDto(
      accessToken: values['access_token']!,
      refreshToken: values['refresh_token']!,
      tokenType: values['token_type'] ?? 'bearer',
      expiresAt: DateTime.parse(values['expires_at']!),
    );
  }

  Map<String, String> toStorage() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_at': expiresAt.toIso8601String(),
  };

  AuthSession toDomain() => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    tokenType: tokenType,
    expiresAt: expiresAt,
  );
}
