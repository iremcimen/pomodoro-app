import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/validation/input_validators.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_switch_prompt.dart';
import '../widgets/auth_text_field.dart';
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

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusManager.instance.primaryFocus?.unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .login(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );

    if (mounted && ref.read(authControllerProvider).value != null) {
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    listenForAuthErrors(ref, context);
    final authState = ref.watch(authControllerProvider);

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
                isLoading: authState.isLoading,
                onPressed: _submit,
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
