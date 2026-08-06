import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/app_exception.dart';

abstract interface class GoogleIdentityService {
  Stream<String> get idTokens;

  Future<void> initialize();

  Future<String?> authenticate();

  Future<void> signOut();

  Future<void> dispose();
}

class GoogleSignInIdentityService implements GoogleIdentityService {
  GoogleSignInIdentityService() : _googleSignIn = GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  final StreamController<String> _idTokenController =
      StreamController<String>.broadcast();

  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  Future<void>? _initialization;
  bool _initialized = false;

  @override
  Stream<String> get idTokens => _idTokenController.stream;

  @override
  Future<void> initialize() {
    return _initialization ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      throw const AppException(
        message: 'Google ile giriş bu platformda kullanılamıyor.',
        code: 'GOOGLE_PLATFORM_UNSUPPORTED',
      );
    }

    final webClientId = AppConfig.googleWebClientId;
    final serverClientId = AppConfig.googleServerClientId;

    if (kIsWeb && webClientId.isEmpty) {
      throw const AppException(
        message: 'Google web client ID yapılandırılmamış.',
        code: 'GOOGLE_CLIENT_NOT_CONFIGURED',
      );
    }
    if (!kIsWeb && serverClientId.isEmpty) {
      throw const AppException(
        message: 'Google server client ID yapılandırılmamış.',
        code: 'GOOGLE_CLIENT_NOT_CONFIGURED',
      );
    }

    try {
      await _googleSignIn.initialize(
        clientId: kIsWeb ? webClientId : null,
        serverClientId: kIsWeb ? null : serverClientId,
      );
      _initialized = true;

      if (kIsWeb) {
        _authSubscription = _googleSignIn.authenticationEvents.listen(
          _handleAuthenticationEvent,
          onError: _handleAuthenticationError,
        );
      }
    } on GoogleSignInException catch (error) {
      throw _mapException(error);
    } on Object {
      throw const AppException(
        message: 'Google ile giriş başlatılamadı. Lütfen tekrar deneyin.',
        code: 'GOOGLE_INITIALIZATION_FAILED',
      );
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    if (event case GoogleSignInAuthenticationEventSignIn()) {
      _emitIdToken(event.user);
    }
  }

  void _handleAuthenticationError(Object error, StackTrace stackTrace) {
    if (_idTokenController.isClosed) return;
    _idTokenController.addError(
      error is GoogleSignInException ? _mapException(error) : error,
      stackTrace,
    );
  }

  void _emitIdToken(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken?.trim();
    if (_idTokenController.isClosed) return;
    if (idToken == null || idToken.isEmpty) {
      _idTokenController.addError(
        const AppException(
          message: 'Google kimlik bilgisi alınamadı. Lütfen tekrar deneyin.',
          code: 'GOOGLE_ID_TOKEN_MISSING',
        ),
      );
      return;
    }
    _idTokenController.add(idToken);
  }

  @override
  Future<String?> authenticate() async {
    await initialize();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AppException(
        message: 'Google ile giriş bu platformda kullanılamıyor.',
        code: 'GOOGLE_INTERACTIVE_LOGIN_UNSUPPORTED',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken?.trim();
      if (idToken == null || idToken.isEmpty) {
        throw const AppException(
          message: 'Google kimlik bilgisi alınamadı. Lütfen tekrar deneyin.',
          code: 'GOOGLE_ID_TOKEN_MISSING',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw _mapException(error);
    }
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await _googleSignIn.signOut();
    } on Object {
      // Uygulamadaki yerel oturum Google SDK temizliği başarısız olsa da kapanır.
    }
  }

  AppException _mapException(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        const AppException(
          message: 'Google giriş yapılandırması geçersiz.',
          code: 'GOOGLE_CONFIGURATION_ERROR',
        ),
      GoogleSignInExceptionCode.uiUnavailable => const AppException(
        message: 'Google giriş ekranı açılamadı. Lütfen tekrar deneyin.',
        code: 'GOOGLE_UI_UNAVAILABLE',
      ),
      _ => const AppException(
        message: 'Google ile giriş tamamlanamadı. Lütfen tekrar deneyin.',
        code: 'GOOGLE_SIGN_IN_FAILED',
      ),
    };
  }

  @override
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _idTokenController.close();
  }
}
