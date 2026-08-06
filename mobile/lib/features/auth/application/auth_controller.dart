import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/auth_session.dart';
import 'auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  Future<AuthSession?>? _restoration;
  bool _authenticationInFlight = false;

  @override
  Future<AuthSession?> build() {
    final restoration = _restoreSession();
    _restoration = restoration;
    return restoration;
  }

  Future<AuthSession?> _restoreSession() async {
    try {
      return await ref.read(authRepositoryProvider).restoreSession();
    } on Object {
      // Oturum geri yükleme hatası giriş ekranını kilitlememeli.
      return null;
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    if (_authenticationInFlight) return;
    _authenticationInFlight = true;
    try {
      await _restoration;
      state = const AsyncLoading();
      state = await AsyncValue.guard(
        () => ref
            .read(authRepositoryProvider)
            .login(identifier: identifier, password: password),
      );
    } finally {
      _authenticationInFlight = false;
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) async {
    if (_authenticationInFlight) return;
    _authenticationInFlight = true;
    try {
      await _restoration;
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
    } finally {
      _authenticationInFlight = false;
    }
  }

  Future<void> loginWithGoogle(String idToken) async {
    if (_authenticationInFlight) return;
    _authenticationInFlight = true;
    try {
      await _restoration;
      state = const AsyncLoading();
      state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).loginWithGoogle(idToken),
      );
    } finally {
      _authenticationInFlight = false;
    }
  }

  Future<void> logout() async {
    if (state.value == null) return;

    // Route away immediately; browser storage and remote revocation must not
    // keep the user on a protected screen.
    state = const AsyncData(null);

    try {
      unawaited(ref.read(googleIdentityServiceProvider).signOut());
      await ref.read(authRepositoryProvider).logout();
      await ref
          .read(secureStorageProvider)
          .delete(key: 'cache.statistics.summary');
    } on Object {
      // A cleanup failure must not restore the in-memory UI session.
    }
  }
}
