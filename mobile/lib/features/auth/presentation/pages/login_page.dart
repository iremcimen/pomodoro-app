import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/validation/input_validators.dart';
import '../../application/auth_controller.dart';
import '../../application/auth_providers.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_switch_prompt.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/submit_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  StreamSubscription<String>? _googleIdTokenSubscription;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  bool _isGoogleReady = false;
  Object? _googleInitializationError;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeGoogle());
  }

  @override
  void dispose() {
    unawaited(_googleIdTokenSubscription?.cancel());
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting ||
        _isGoogleSubmitting ||
        !_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            identifier: _identifierController.text,
            password: _passwordController.text,
          );

      if (mounted && ref.read(authControllerProvider).value != null) {
        TextInput.finishAutofillContext();
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _initializeGoogle() async {
    final service = ref.read(googleIdentityServiceProvider);
    try {
      await service.initialize();
      if (!mounted) return;

      if (kIsWeb) {
        _googleIdTokenSubscription = service.idTokens.listen(
          _exchangeGoogleToken,
          onError: _handleGoogleStreamError,
        );
      }

      setState(() => _isGoogleReady = true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _googleInitializationError = error);
    }
  }

  Future<void> _startGoogleLogin() async {
    if (!_isGoogleReady || _isSubmitting || _isGoogleSubmitting) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isGoogleSubmitting = true);
    try {
      final idToken = await ref
          .read(googleIdentityServiceProvider)
          .authenticate();
      if (idToken != null) await _completeGoogleLogin(idToken);
    } on Object catch (error) {
      if (mounted) _showGoogleError(error);
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _exchangeGoogleToken(String idToken) async {
    if (_isSubmitting || _isGoogleSubmitting) return;

    setState(() => _isGoogleSubmitting = true);
    try {
      await _completeGoogleLogin(idToken);
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _completeGoogleLogin(String idToken) async {
    await ref.read(authControllerProvider.notifier).loginWithGoogle(idToken);
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.value != null) {
      TextInput.finishAutofillContext();
    } else if (authState.hasError) {
      unawaited(ref.read(googleIdentityServiceProvider).signOut());
    }
  }

  void _handleGoogleStreamError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    if (_isGoogleSubmitting) setState(() => _isGoogleSubmitting = false);
    _showGoogleError(error);
  }

  void _showGoogleError(Object error) {
    final message = error is AppException
        ? error.message
        : 'Google ile giriş tamamlanamadı. Lütfen tekrar deneyin.';
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    listenForAuthErrors(ref, context);

    return AuthLayout(
      title: 'Tekrar hoş geldin',
      subtitle: 'Hedeflerine kaldığın yerden devam etmek için giriş yap.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _identifierController,
                label: 'E-posta veya kullanıcı adı',
                hint: 'ornek@mail.com veya kullanici_adi',
                icon: Icons.alternate_email_rounded,
                validator: InputValidators.loginIdentifier,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
              ),
              const SizedBox(height: 20),
              AuthTextField(
                controller: _passwordController,
                label: 'Şifre',
                hint: 'En az 8 karakter',
                icon: Icons.lock_outline_rounded,
                validator: InputValidators.password,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                obscureText: true,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 26),
              SubmitButton(
                label: 'Giriş yap',
                loadingLabel: 'Giriş yapılıyor…',
                isLoading: _isSubmitting,
                isEnabled: !_isGoogleSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: GoogleSignInButton.maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _AuthDivider(),
                      const SizedBox(height: 20),
                      if (_isGoogleReady)
                        GoogleSignInButton(
                          isLoading: _isGoogleSubmitting,
                          isEnabled: !_isSubmitting,
                          onPressed: kIsWeb ? null : _startGoogleLogin,
                        )
                      else if (_googleInitializationError != null)
                        const _GoogleUnavailableMessage()
                      else
                        const SizedBox(height: 44),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      footer: AuthSwitchPrompt(
        question: 'Henüz hesabın yok mu?',
        actionLabel: 'Hesap oluştur',
        onPressed: () => context.go(AppRoutes.register),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('veya', style: textStyle),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

class _GoogleUnavailableMessage extends StatelessWidget {
  const _GoogleUnavailableMessage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Google ile giriş şu anda kullanılamıyor. '
              'E-posta ve şifrenizle devam edebilirsiniz.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
