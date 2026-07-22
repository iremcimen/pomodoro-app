import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/auth_session.dart';
import 'auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password),
    );
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .register(
            email: email,
            username: username,
            password: password,
            fullName: fullName,
          ),
    );
  }

  Future<void> logout() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).logout();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
