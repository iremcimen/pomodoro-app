import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  Future<AuthSession> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  });

  Future<AuthSession> loginWithGoogle(String idToken);

  Future<AuthSession?> restoreSession();

  Future<void> logout();
}
