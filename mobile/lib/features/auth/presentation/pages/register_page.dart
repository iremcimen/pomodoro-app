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

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusManager.instance.primaryFocus?.unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .register(
          fullName: _fullNameController.text,
          username: _usernameController.text,
          email: _emailController.text,
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
      title: 'Hesabını oluştur',
      subtitle: 'Daha odaklı günler için ilk küçük adımını at.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _fullNameController,
                label: 'Ad soyad (isteğe bağlı)',
                hint: 'Adın Soyadın',
                icon: Icons.person_outline_rounded,
                validator: InputValidators.fullName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 18),
              AuthTextField(
                controller: _usernameController,
                label: 'Kullanıcı adı',
                hint: 'ornek_kullanici',
                icon: Icons.alternate_email_rounded,
                validator: InputValidators.username,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
              ),
              const SizedBox(height: 18),
              AuthTextField(
                controller: _emailController,
                label: 'E-posta',
                hint: 'ornek@mail.com',
                icon: Icons.mail_outline_rounded,
                validator: InputValidators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 18),
              AuthTextField(
                controller: _passwordController,
                label: 'Şifre',
                hint: '8-128 karakter',
                icon: Icons.lock_outline_rounded,
                validator: InputValidators.password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                obscureText: true,
              ),
              const SizedBox(height: 18),
              AuthTextField(
                controller: _passwordConfirmationController,
                label: 'Şifre tekrarı',
                hint: 'Şifreni yeniden gir',
                icon: Icons.lock_reset_rounded,
                validator: (value) {
                  final passwordError = InputValidators.password(value);
                  if (passwordError != null) return passwordError;
                  if (value != _passwordController.text) {
                    return 'Şifreler birbiriyle eşleşmiyor.';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                obscureText: true,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 26),
              SubmitButton(
                label: 'Hesap oluştur',
                isLoading: authState.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
      footer: AuthSwitchPrompt(
        question: 'Zaten hesabın var mı?',
        actionLabel: 'Giriş yap',
        onPressed: () => context.go(AppRoutes.login),
      ),
    );
  }
}
