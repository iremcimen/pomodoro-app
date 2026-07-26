import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/app/app.dart';
import 'package:pomodoro_app/features/auth/application/auth_providers.dart';
import 'package:pomodoro_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:pomodoro_app/features/auth/data/datasources/auth_token_store.dart';
import 'package:pomodoro_app/features/auth/data/models/auth_token_dto.dart';
import 'package:pomodoro_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pomodoro_app/features/auth/domain/entities/auth_session.dart';
import 'package:pomodoro_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  testWidgets('logout redirects an authenticated user to login', (
    tester,
  ) async {
    final repository = _AuthenticatedRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const PomodoroApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar yükleniyor…'), findsOneWidget);

    await tester.tap(find.byTooltip('Çıkış yap'));
    await tester.pumpAndSettle();

    expect(repository.logoutCalled, isTrue);
    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
  });

  test('local logout does not wait for remote session revocation', () async {
    final remoteDataSource = _PendingLogoutRemoteDataSource();
    final tokenStore = _InMemoryTokenStore(_tokenDto);
    final repository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      tokenStore: tokenStore,
    );

    await repository.logout().timeout(const Duration(seconds: 1));

    expect(tokenStore.token, isNull);
    expect(remoteDataSource.logoutToken, _tokenDto.refreshToken);

    remoteDataSource.completeLogout();
  });
}

final _tokenDto = AuthTokenDto(
  accessToken: 'access-token',
  refreshToken: 'refresh-token-that-is-long-enough-for-the-backend',
  tokenType: 'bearer',
  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
);

class _AuthenticatedRepository implements AuthRepository {
  bool logoutCalled = false;

  @override
  Future<AuthSession?> restoreSession() async => _tokenDto.toDomain();

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) {
    throw UnimplementedError();
  }
}

class _InMemoryTokenStore implements AuthTokenStore {
  _InMemoryTokenStore(this.token);

  AuthTokenDto? token;

  @override
  Future<void> clear() async {
    token = null;
  }

  @override
  Future<AuthTokenDto?> read() async => token;

  @override
  Future<void> write(AuthTokenDto token) async {
    this.token = token;
  }
}

class _PendingLogoutRemoteDataSource implements AuthRemoteDataSource {
  final _logoutCompleter = Completer<void>();
  String? logoutToken;

  void completeLogout() => _logoutCompleter.complete();

  @override
  Future<void> logout(String refreshToken) {
    logoutToken = refreshToken;
    return _logoutCompleter.future;
  }

  @override
  Future<AuthTokenDto> login({
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthTokenDto> refresh(String refreshToken) {
    throw UnimplementedError();
  }

  @override
  Future<AuthTokenDto> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) {
    throw UnimplementedError();
  }
}
