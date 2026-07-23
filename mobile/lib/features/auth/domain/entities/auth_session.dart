class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;

  bool get isAccessTokenUsable {
    return expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)));
  }
}
